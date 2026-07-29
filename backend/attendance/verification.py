import cv2
import numpy as np
import io
import re
from django.conf import settings


def _load_image(image_file):
    """Load image file into OpenCV format. Handles both local files and Cloudinary FieldFile."""
    try:
        # Django FieldFile (local or Cloudinary) - open and read
        if hasattr(image_file, 'open'):
            image_file.open('rb')
            image_bytes = image_file.read()
            image_file.close()
        else:
            # Raw uploaded file
            image_file.seek(0)
            image_bytes = image_file.read()
    except Exception:
        # Fallback: try reading URL if it's a Cloudinary file
        try:
            import requests
            url = image_file.url
            resp = requests.get(url, timeout=15)
            resp.raise_for_status()
            image_bytes = resp.content
        except Exception as e:
            raise ValueError(f'Cannot read image: {e}')

    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Invalid image file')
    return image


def _extract_text_from_image(image):
    """Use pytesseract OCR to extract all text from image."""
    import pytesseract
    # Convert to grayscale for better OCR
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    # Apply adaptive threshold to handle different lighting
    thresh = cv2.adaptiveThreshold(
        gray, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, 11, 2
    )
    # OCR with multiple configs to maximize accuracy
    configs = [
        '--psm 6 --oem 3',   # Assume block of text
        '--psm 11 --oem 3',  # Sparse text - find as much as possible
        '--psm 3 --oem 3',   # Fully automatic page segmentation
    ]
    all_text = ''
    for cfg in configs:
        try:
            text = pytesseract.image_to_string(thresh, config=cfg)
            all_text += ' ' + text
        except Exception:
            pass
    return all_text.upper().replace(' ', '').replace('\n', '')


def _preprocess_for_matching(image):
    """
    Preprocess an image for robust feature extraction.
    Applies CLAHE contrast enhancement and resizes to a standard canvas.
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # CLAHE: locally enhances contrast so faint whiteboard markers become visible
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)

    # Resize to max 1024px on longest side (preserves aspect ratio)
    h, w = enhanced.shape
    scale = 1024.0 / max(h, w)
    if scale < 1.0:
        enhanced = cv2.resize(enhanced, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

    return enhanced


def _check_screen_spoof(image):
    """
    Lightweight anti-spoof: detect screen pixel grids via FFT analysis.
    Returns (is_real, reason).
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if len(image.shape) == 3 else image

    # --- A. Flash Glare on Glass Screen ---
    _, bright_mask = cv2.threshold(gray, 250, 255, cv2.THRESH_BINARY)
    bright_ratio = np.sum(bright_mask == 255) / gray.size
    if bright_ratio > 0.10:
        return False, f'Screen glass flash glare detected (bright ratio: {bright_ratio:.2%})'

    # --- B. FFT Moiré Pattern Detection ---
    f = np.fft.fft2(gray.astype(np.float32))
    fshift = np.fft.fftshift(f)
    magnitude = 20 * np.log(np.abs(fshift) + 1e-8)

    h, w = gray.shape
    cy, cx = h // 2, w // 2
    # Zero out the central low-frequency region
    high_freq = magnitude.copy()
    radius = min(30, min(cy, cx) - 1)  # Guard against very small images
    high_freq[cy - radius:cy + radius, cx - radius:cx + radius] = 0

    spectral_energy = float(np.mean(high_freq))
    if spectral_energy > 155.0:
        return False, f'Screen pixel grid pattern detected (spectral energy: {spectral_energy:.1f})'

    return True, 'Passed anti-spoof checks'


def _match_boards_sift(ref_image, student_image, min_inliers=10, min_inlier_ratio=0.25):
    """
    SIFT-based feature matching with geometric verification.

    Uses SIFT (Scale-Invariant Feature Transform) which is the gold standard
    for matching the same scene from different viewpoints, zoom levels, and
    lighting conditions. Combined with FLANN-based matching, Lowe's ratio test,
    and RANSAC homography for maximum accuracy.

    Returns (is_match, inlier_count, detail_message).
    """
    # Preprocess both images (CLAHE + resize)
    ref_proc = _preprocess_for_matching(ref_image)
    stu_proc = _preprocess_for_matching(student_image)

    # Create SIFT detector with generous feature count
    sift = cv2.SIFT_create(nfeatures=2000, contrastThreshold=0.03, edgeThreshold=15)

    kp1, des1 = sift.detectAndCompute(ref_proc, None)
    kp2, des2 = sift.detectAndCompute(stu_proc, None)

    if des1 is None or des2 is None:
        return False, 0, 'Could not extract features from one or both images.'

    if len(kp1) < 5 or len(kp2) < 5:
        return False, 0, f'Too few features detected (ref: {len(kp1)}, student: {len(kp2)}).'

    # FLANN-based matcher (optimized for float descriptors like SIFT)
    index_params = dict(algorithm=1, trees=5)  # FLANN_INDEX_KDTREE
    search_params = dict(checks=80)
    flann = cv2.FlannBasedMatcher(index_params, search_params)

    # KNN match with k=2 for Lowe's ratio test
    raw_matches = flann.knnMatch(des1, des2, k=2)

    # Lowe's ratio test: keep matches where best is significantly better than second-best
    good_matches = []
    for pair in raw_matches:
        if len(pair) == 2:
            m, n = pair
            if m.distance < 0.7 * n.distance:
                good_matches.append(m)

    if len(good_matches) < 4:
        return False, len(good_matches), (
            f'Insufficient feature matches: only {len(good_matches)} found. '
            'The images do not appear to show the same board content.'
        )

    # Extract matched keypoint coordinates
    pts_ref = np.float32([kp1[m.queryIdx].pt for m in good_matches]).reshape(-1, 1, 2)
    pts_stu = np.float32([kp2[m.trainIdx].pt for m in good_matches]).reshape(-1, 1, 2)

    # RANSAC homography: verifies matched points form a valid perspective transform
    # (i.e., a real 3D board viewed from a different angle, not random noise)
    _, mask = cv2.findHomography(pts_ref, pts_stu, cv2.RANSAC, 5.0)

    if mask is None:
        return False, 0, 'Could not compute geometric transform between images.'

    inlier_count = int(np.sum(mask))
    inlier_ratio = inlier_count / len(good_matches)

    if inlier_count >= min_inliers and inlier_ratio >= min_inlier_ratio:
        return True, inlier_count, (
            f'Board match confirmed: {inlier_count} geometric inliers '
            f'({inlier_ratio:.0%} ratio) from {len(good_matches)} feature matches.'
        )
    else:
        return False, inlier_count, (
            f'Board mismatch: {inlier_count} inliers ({inlier_ratio:.0%} ratio) '
            f'from {len(good_matches)} matches — below threshold '
            f'(need {min_inliers} inliers at {min_inlier_ratio:.0%} ratio). '
            'The photo does not appear to be of the same board.'
        )


def verify_offline_code(expected_code, reference_image, student_image):
    """
    Robust multi-layer offline attendance verification:
      Layer 1: OCR — verify the 6-char pattern code is present in the student photo.
      Layer 2: Anti-Spoof — FFT screen pixel grid detection.
      Layer 3: SIFT Feature Matching — verify student photo shows the same board.
    Returns (matched: bool, detail: str).
    """
    try:
        ref_img = _load_image(reference_image)
        stu_img = _load_image(student_image)

        # --- LAYER 1: OCR Code Verification ---
        extracted_text = _extract_text_from_image(stu_img)
        code_upper = expected_code.upper().strip()

        # Exact match first
        ocr_matched = code_upper in extracted_text

        # Fuzzy fallback: tolerate 1 character error (handles I/1, O/0, etc.)
        if not ocr_matched:
            for i in range(len(code_upper)):
                pattern = code_upper[:i] + '.' + code_upper[i+1:]
                if re.search(pattern, extracted_text):
                    ocr_matched = True
                    break

        if not ocr_matched:
            return False, (
                f'Code not found: The code "{expected_code}" was not detected in your photo. '
                f'Please ensure the code is clearly visible and in focus.'
            )

        # --- LAYER 2: Anti-Spoof Check ---
        is_real, spoof_detail = _check_screen_spoof(stu_img)
        if not is_real:
            return False, f'Anti-spoof check failed: {spoof_detail}'

        # --- LAYER 3: SIFT Board Matching ---
        is_match, match_count, match_detail = _match_boards_sift(ref_img, stu_img)

        if not is_match:
            return False, (
                f'Board verification failed: {match_detail} '
                'Please make sure you are photographing the actual classroom board.'
            )

        return True, (
            f'Verified! Code "{expected_code}" found and board environment confirmed '
            f'({match_count} keypoints matched).'
        )

    except ImportError:
        # Tesseract not installed - fall back to Gemini OCR only
        return _gemini_fallback(expected_code, reference_image, student_image)
    except Exception as e:
        return False, f'Verification error: {str(e)}'


def _gemini_fallback(expected_code, reference_image, student_image):
    """Fallback to Gemini if Tesseract is not installed."""
    try:
        import json
        import google.generativeai as genai
        import PIL.Image

        api_key = getattr(settings, 'GEMINI_API_KEY', '')
        if not api_key:
            return False, 'GEMINI_API_KEY is not configured on the server.'

        genai.configure(api_key=api_key)

        reference_image.seek(0)
        ref_img = PIL.Image.open(io.BytesIO(reference_image.read()))
        student_image.seek(0)
        stu_img = PIL.Image.open(io.BytesIO(student_image.read()))

        model = genai.GenerativeModel('gemini-1.5-flash')
        prompt = f"""
        You are an AI proctor. Look at Image 2 (student scan).
        Does Image 2 contain the exact text "{expected_code}" written on it?
        Also, does Image 2 appear to be a photo of the same physical board as Image 1?
        Respond ONLY in JSON: {{"matched": boolean, "reason": "brief explanation"}}
        """
        response = model.generate_content([prompt, ref_img, stu_img])
        response_text = response.text.strip().lstrip('```json').rstrip('```').strip()
        data = json.loads(response_text)
        return data.get('matched', False), data.get('reason', 'No reason provided')
    except Exception as e:
        return False, f'AI Verification failed: {str(e)}'


def validate_focal_distance(focal_distance):
    """Reject photos taken too close (likely a screen photo)."""
    min_distance = getattr(settings, 'MIN_FOCAL_DISTANCE_METERS', 0.5)
    try:
        distance = float(focal_distance)
    except (TypeError, ValueError):
        return False, 'focal_distance must be a number'

    if distance < min_distance:
        return False, (
            'Suspected cheating: photo taken too close to subject '
            f'({distance:.2f}m < {min_distance:.2f}m minimum)'
        )

    return True, distance

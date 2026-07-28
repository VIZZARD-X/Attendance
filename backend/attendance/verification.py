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


def _match_environment(ref_image, student_image, min_good_matches=8):
    """
    Use ORB feature matching to verify both images are from the same physical board.
    Returns (is_same_environment, match_count, detail_message).
    """
    orb = cv2.ORB_create(nfeatures=1000)

    kp1, des1 = orb.detectAndCompute(ref_image, None)
    kp2, des2 = orb.detectAndCompute(student_image, None)

    if des1 is None or des2 is None or len(kp1) < 5 or len(kp2) < 5:
        return False, 0, 'Could not extract features from one or both images.'

    # BFMatcher with Hamming distance for ORB descriptors
    bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=False)
    matches = bf.knnMatch(des1, des2, k=2)

    # Lowe's ratio test to filter good matches
    good_matches = []
    for m_n in matches:
        if len(m_n) == 2:
            m, n = m_n
            if m.distance < 0.75 * n.distance:
                good_matches.append(m)

    if len(good_matches) >= min_good_matches:
        return True, len(good_matches), f'Environment verified: {len(good_matches)} matching keypoints found.'
    else:
        return False, len(good_matches), (
            f'Environment mismatch: Only {len(good_matches)} keypoints matched '
            f'(minimum {min_good_matches} required). '
            'The student\'s photo does not appear to be from the same board.'
        )


def verify_offline_code(expected_code, reference_image, student_image):
    """
    Robust two-stage offline attendance verification:
    Stage 1: OCR - verify the 6-char code is present in the student image.
    Stage 2: ORB Feature Matching - verify student photo is from the same physical board.
    Returns (matched: bool, detail: str).
    """
    try:
        ref_img = _load_image(reference_image)
        stu_img = _load_image(student_image)

        # --- STAGE 1: OCR Code Verification ---
        extracted_text = _extract_text_from_image(stu_img)
        code_upper = expected_code.upper().strip()

        # Allow slight OCR misreads: check exact match first, then fuzzy
        ocr_matched = code_upper in extracted_text

        # Fuzzy fallback: tolerate 1 character error (handles I/1, O/0, etc.)
        if not ocr_matched:
            for i in range(len(code_upper)):
                # Try replacing each character with a wildcard
                pattern = code_upper[:i] + '.' + code_upper[i+1:]
                if re.search(pattern, extracted_text):
                    ocr_matched = True
                    break

        if not ocr_matched:
            return False, (
                f'Code not found: The code "{expected_code}" was not detected in your photo. '
                f'Please ensure the code is clearly visible and in focus.'
            )

        # --- STAGE 2: Environment / Board Verification ---
        env_matched, match_count, env_detail = _match_environment(ref_img, stu_img)

        if not env_matched:
            return False, (
                f'Board verification failed: {env_detail} '
                'Please make sure you are photographing the actual classroom board.'
            )

        return True, f'Verified! Code "{expected_code}" found and board environment confirmed ({match_count} keypoints matched).'

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

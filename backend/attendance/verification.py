import cv2
import numpy as np
import io
import re
import json
import logging
from django.conf import settings

logger = logging.getLogger(__name__)


def _load_image_bytes(image_file):
    """Load image file into raw bytes. Handles Django FieldFile, Cloudinary, and raw uploads."""
    try:
        if hasattr(image_file, 'open'):
            image_file.open('rb')
            image_bytes = image_file.read()
            image_file.close()
        else:
            image_file.seek(0)
            image_bytes = image_file.read()
    except Exception:
        try:
            import requests
            url = image_file.url
            resp = requests.get(url, timeout=15)
            resp.raise_for_status()
            image_bytes = resp.content
        except Exception as e:
            raise ValueError(f'Cannot read image: {e}')
    return image_bytes


def _bytes_to_cv2(image_bytes):
    """Convert raw image bytes to OpenCV image array."""
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Invalid image file')
    return image


# ============================================================
# PRIMARY ENGINE: Gemini Flash Vision API
# ============================================================

def _verify_with_gemini(expected_code, ref_bytes, stu_bytes):
    """
    Use Gemini Flash Vision to verify board attendance.
    Gemini understands visual content semantically — it can match
    the same board from completely different angles, zoom levels,
    and lighting conditions where local CV algorithms fail.

    Returns (matched: bool, detail: str).
    """
    import google.generativeai as genai
    import PIL.Image

    api_key = getattr(settings, 'GEMINI_API_KEY', '')
    if not api_key:
        raise ValueError('GEMINI_API_KEY is not configured.')

    genai.configure(api_key=api_key)

    ref_img = PIL.Image.open(io.BytesIO(ref_bytes))
    stu_img = PIL.Image.open(io.BytesIO(stu_bytes))

    model = genai.GenerativeModel('gemini-2.0-flash')

    prompt = f"""You are an AI attendance proctor for a classroom attendance system.

CONTEXT:
- A teacher drew a pattern/shapes on a physical whiteboard or blackboard and wrote the code "{expected_code}" on it.
- Image 1 is the teacher's reference photo of the board.
- Image 2 is a student's photo, supposedly of the same board from their seat in the classroom.

YOUR TASK — Analyze Image 2 and answer THREE questions:

1. CODE CHECK: Is the text "{expected_code}" visible anywhere in Image 2? Allow for slight handwriting variations but the characters must match. If the code is partially obscured but mostly readable, that counts as found.

2. BOARD MATCH: Does Image 2 show the SAME physical board content as Image 1? The drawings, shapes, text, and patterns should be recognizably the same content even if photographed from a different angle, distance, zoom level, or lighting condition. Focus on whether the CONTENT matches, not pixel-perfect similarity.

3. AUTHENTICITY: Does Image 2 appear to be a genuine photo taken of a real physical board in a room? Red flags include: visible screen pixels/bezels, moiré patterns, digital UI elements, or obvious signs it's a photo of a phone/laptop/tablet screen rather than a real board.

Respond ONLY with this exact JSON format, no markdown, no explanation outside the JSON:
{{"code_found": true/false, "board_matches": true/false, "is_authentic": true/false, "verdict": "VERIFIED" or "REJECTED", "reason": "one sentence explanation"}}"""

    response = model.generate_content(
        [prompt, ref_img, stu_img],
        generation_config=genai.types.GenerationConfig(
            temperature=0.1,
            max_output_tokens=256,
        )
    )

    # Parse the JSON response
    response_text = response.text.strip()
    # Strip markdown code fences if present
    if response_text.startswith('```'):
        response_text = response_text.split('\n', 1)[-1]
        response_text = response_text.rsplit('```', 1)[0]
    response_text = response_text.strip()

    data = json.loads(response_text)

    code_found = data.get('code_found', False)
    board_matches = data.get('board_matches', False)
    is_authentic = data.get('is_authentic', True)
    reason = data.get('reason', 'No reason provided')

    if not code_found:
        return False, f'Code "{expected_code}" was not found in your photo. Please ensure the code is clearly visible.'
    if not is_authentic:
        return False, f'Photo appears to be taken from a screen, not a real board. {reason}'
    if not board_matches:
        return False, f'Board content does not match the teacher\'s reference. {reason}'

    return True, f'Verified! {reason}'


# ============================================================
# FALLBACK ENGINE: SIFT Feature Matching (if Gemini is unavailable)
# ============================================================

def _preprocess_for_matching(image):
    """Preprocess image for SIFT: CLAHE contrast enhancement + resize."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)
    h, w = enhanced.shape
    scale = 1024.0 / max(h, w)
    if scale < 1.0:
        enhanced = cv2.resize(enhanced, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return enhanced


def _verify_with_sift(expected_code, ref_image, stu_image):
    """
    Fallback SIFT-based verification.
    Used only when Gemini API is unavailable.
    """
    # OCR check first
    try:
        import pytesseract
        gray = cv2.cvtColor(stu_image, cv2.COLOR_BGR2GRAY)
        thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
        configs = ['--psm 6 --oem 3', '--psm 11 --oem 3', '--psm 3 --oem 3']
        all_text = ''
        for cfg in configs:
            try:
                all_text += ' ' + pytesseract.image_to_string(thresh, config=cfg)
            except Exception:
                pass
        extracted = all_text.upper().replace(' ', '').replace('\n', '')
        code_upper = expected_code.upper().strip()

        ocr_matched = code_upper in extracted
        if not ocr_matched:
            for i in range(len(code_upper)):
                pattern = code_upper[:i] + '.' + code_upper[i+1:]
                if re.search(pattern, extracted):
                    ocr_matched = True
                    break
        if not ocr_matched:
            return False, f'Code "{expected_code}" was not detected in your photo.'
    except ImportError:
        logger.warning("pytesseract not available, skipping OCR check in fallback")

    # SIFT matching
    ref_proc = _preprocess_for_matching(ref_image)
    stu_proc = _preprocess_for_matching(stu_image)

    sift = cv2.SIFT_create(nfeatures=2000, contrastThreshold=0.03, edgeThreshold=15)
    kp1, des1 = sift.detectAndCompute(ref_proc, None)
    kp2, des2 = sift.detectAndCompute(stu_proc, None)

    if des1 is None or des2 is None or len(kp1) < 5 or len(kp2) < 5:
        return False, 'Could not extract enough features from the images.'

    index_params = dict(algorithm=1, trees=5)
    search_params = dict(checks=80)
    flann = cv2.FlannBasedMatcher(index_params, search_params)
    raw_matches = flann.knnMatch(des1, des2, k=2)

    good_matches = []
    for pair in raw_matches:
        if len(pair) == 2:
            m, n = pair
            if m.distance < 0.7 * n.distance:
                good_matches.append(m)

    if len(good_matches) < 4:
        return False, f'Insufficient matches ({len(good_matches)}). Images do not appear to show the same board.'

    pts_ref = np.float32([kp1[m.queryIdx].pt for m in good_matches]).reshape(-1, 1, 2)
    pts_stu = np.float32([kp2[m.trainIdx].pt for m in good_matches]).reshape(-1, 1, 2)
    _, mask = cv2.findHomography(pts_ref, pts_stu, cv2.RANSAC, 5.0)

    inlier_count = int(np.sum(mask)) if mask is not None else 0

    if inlier_count >= 8:
        return True, f'Board verified via local matching ({inlier_count} geometric inliers).'
    else:
        return False, f'Board mismatch ({inlier_count} inliers). Photo does not match the reference board.'


# ============================================================
# MAIN ENTRY POINT
# ============================================================

def verify_offline_code(expected_code, reference_image, student_image):
    """
    Multi-engine offline attendance verification.

    Primary: Gemini Flash Vision API (semantic understanding, handles all angles/zoom/lighting).
    Fallback: SIFT + OCR (if Gemini is unavailable due to API issues).

    Returns (matched: bool, detail: str).
    """
    try:
        ref_bytes = _load_image_bytes(reference_image)
        stu_bytes = _load_image_bytes(student_image)
    except Exception as e:
        return False, f'Failed to load images: {str(e)}'

    # --- PRIMARY: Gemini Flash Vision ---
    gemini_key = getattr(settings, 'GEMINI_API_KEY', '')
    if gemini_key:
        try:
            matched, detail = _verify_with_gemini(expected_code, ref_bytes, stu_bytes)
            return matched, detail
        except json.JSONDecodeError as e:
            logger.error(f"Gemini returned unparseable response: {e}")
        except Exception as e:
            logger.error(f"Gemini verification failed: {e}")

    # --- FALLBACK: Local SIFT + OCR ---
    try:
        ref_img = _bytes_to_cv2(ref_bytes)
        stu_img = _bytes_to_cv2(stu_bytes)
        return _verify_with_sift(expected_code, ref_img, stu_img)
    except Exception as e:
        return False, f'Verification error: {str(e)}'


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

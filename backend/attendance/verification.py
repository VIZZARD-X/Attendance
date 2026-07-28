import cv2
import numpy as np
from django.conf import settings


def _read_image(image_file):
    image_file.seek(0)
    image_bytes = image_file.read()
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Invalid image file')
    return image


def compare_patterns(reference_image, student_image):
    """Compare patterns in two uploaded images using ORB feature matching. Returns (matched, detail)."""
    try:
        reference = _read_image(reference_image)
        student = _read_image(student_image)
    except Exception as e:
        return False, f'Error reading images: {str(e)}'

    # Convert to grayscale
    reference_gray = cv2.cvtColor(reference, cv2.COLOR_BGR2GRAY)
    student_gray = cv2.cvtColor(student, cv2.COLOR_BGR2GRAY)

    # Initialize ORB detector
    orb = cv2.ORB_create(nfeatures=1000)

    # Find keypoints and descriptors
    kp1, des1 = orb.detectAndCompute(reference_gray, None)
    kp2, des2 = orb.detectAndCompute(student_gray, None)

    if des1 is None or des2 is None or len(des1) < 10 or len(des2) < 10:
        return False, 'Not enough features detected in images'

    # BFMatcher with default params
    bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
    
    try:
        matches = bf.match(des1, des2)
    except Exception:
        return False, 'Failed to match features'

    # Sort them in the order of their distance
    matches = sorted(matches, key=lambda x: x.distance)

    # Calculate score based on good matches
    # We consider a match "good" if its distance is below a threshold (e.g., 50)
    good_matches = [m for m in matches if m.distance < 50]
    
    # The score is the ratio of good matches to the minimum total features, or simply the count of good matches
    score = len(good_matches)
    
    # Threshold for match (adjust this based on real-world testing, usually 15-20 good matches is solid)
    # The settings threshold from FACE_MATCH_THRESHOLD was likely a float (e.g., 0.45).
    # We will use a fixed threshold of 15 good matches for pattern matching.
    threshold = 15
    matched = score >= threshold
    
    detail = f'Match score: {score} good features (threshold: {threshold})'
    return matched, detail


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

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


import json
import google.generativeai as genai
import PIL.Image
import io

def compare_patterns(reference_image, student_image):
    """Compare patterns and context using Gemini Vision API. Returns (matched, detail)."""
    api_key = getattr(settings, 'GEMINI_API_KEY', '')
    if not api_key:
        return False, 'GEMINI_API_KEY is not configured on the server.'
    
    try:
        genai.configure(api_key=api_key)
        
        # Load images for Gemini
        reference_image.seek(0)
        ref_img = PIL.Image.open(io.BytesIO(reference_image.read()))
        
        student_image.seek(0)
        stu_img = PIL.Image.open(io.BytesIO(student_image.read()))
        
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        prompt = """
        You are an advanced AI proctor for a university attendance system. 
        You are provided with two images:
        Image 1 (Reference): The teacher's drawing of a shape containing a 2-digit number.
        Image 2 (Student Scan): The student's photo of the classroom board.
        
        Your task is to verify TWO things to prevent cheating:
        1. Pattern Match: Does Image 2 clearly contain the exact same shape and 2-digit number as Image 1?
        2. Anti-Cheat Context: Does Image 2 appear to be a photo of a large classroom whiteboard, blackboard, or projector screen? 
           If Image 2 looks like a photo of a piece of paper (e.g. A4 sheet), a digital screen (like another phone), or a small drawing held by hand, you MUST flag it as cheating.
        
        Respond ONLY in the following JSON format:
        {
            "matched": boolean,
            "reason": "String explaining why it matched or failed (keep it brief and friendly for the student)."
        }
        """
        
        response = model.generate_content([prompt, ref_img, stu_img])
        
        # Parse JSON
        response_text = response.text.strip()
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
            
        data = json.loads(response_text.strip())
        
        matched = data.get("matched", False)
        reason = data.get("reason", "No reason provided")
        
        return matched, reason

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

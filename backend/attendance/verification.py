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

def verify_offline_code(expected_code, reference_image, student_image):
    """Verify alphanumeric code and context using Gemini Vision API. Returns (matched, detail)."""
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
        
        prompt = f"""
        You are an AI proctor for a university attendance system. 
        You are provided with TWO photos:
        Image 1 (Reference): The teacher's photo of the classroom board.
        Image 2 (Student Scan): The student's photo of the board.
        
        Verify the following:
        1. Code Verification: Read the handwritten text in the student's photo (Image 2). Does it clearly contain the exact 6-character code "{expected_code}"? (Ignore case, spaces, or other text around it).
        2. Environment Match: Does the physical environment in Image 2 (the board texture, wall, lighting, markers) match the environment shown in Image 1? 
           (This prevents a student from writing the code on a piece of paper at home. If Image 2 looks like a different environment, or is a photo of a phone screen/laptop/small piece of paper, flag it as cheating!).
        
        Respond ONLY in this exact JSON format:
        {{
            "matched": boolean,
            "reason": "Short, friendly explanation of your decision."
        }}
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

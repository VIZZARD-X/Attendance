import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'attend_backend.settings')
django.setup()

from attendance.models import User, StudentProfile

# Find a student who does NOT have a student_profile
user = User.objects.filter(role='student').first()

# Let's delete their profile if they have one to test
try:
    if hasattr(user, 'student_profile'):
        print("hasattr returned true")
        profile = user.student_profile
        profile.delete()
        print("deleted profile")
except Exception as e:
    print("Error deleting:", e)

# Now they definitely don't have one
try:
    print("Testing hasattr...")
    result = hasattr(user, 'student_profile')
    print(f"hasattr result: {result}")
    
    if result:
        print("Trying to access it even though it doesn't exist...")
        print(user.student_profile)
except Exception as e:
    print(f"Exception caught during hasattr or access: {type(e).__name__}: {e}")

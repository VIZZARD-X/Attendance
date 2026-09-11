import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'attend_backend.settings')
django.setup()

from django.test import RequestFactory
from django.contrib.auth import get_user_model
from attendance.analytics_views import teacher_analytics_overview, student_analytics_overview

User = get_user_model()
factory = RequestFactory()

teacher = User.objects.filter(role='teacher').first()
if teacher:
    print(f"Testing teacher: {teacher.email}")
    request = factory.get('/api/v1/analytics/teacher/overview/')
    request.user = teacher
    try:
        response = teacher_analytics_overview(request)
        print("Teacher response:", response.status_code)
    except Exception as e:
        import traceback
        traceback.print_exc()

student = User.objects.filter(role='student').first()
if student:
    print(f"Testing student: {student.email}")
    request = factory.get('/api/v1/analytics/student/overview/')
    request.user = student
    try:
        response = student_analytics_overview(request)
        print("Student response:", response.status_code)
    except Exception as e:
        import traceback
        traceback.print_exc()

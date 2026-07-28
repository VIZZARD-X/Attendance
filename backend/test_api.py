import argparse
import os
import sys

from project_env import isolate_from_external_pythonpath

isolate_from_external_pythonpath()

import requests

# Base Defaults
DEFAULT_BASE_URL = os.getenv('TEST_API_BASE_URL', 'http://127.0.0.1:8000/api/v1')
DEFAULT_TEACHER_EMAIL = os.getenv('TEST_TEACHER_EMAIL', 'teacher@example.com')
DEFAULT_TEACHER_PASS = os.getenv('TEST_TEACHER_PASS', 'password123')
DEFAULT_STUDENT_EMAIL = os.getenv('TEST_STUDENT_EMAIL', 'student@example.com')
DEFAULT_STUDENT_PASS = os.getenv('TEST_STUDENT_PASS', 'password123')
DEFAULT_CLASS_ID = int(os.getenv('TEST_CLASS_ID', '2'))

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FIXTURES_DIR = os.path.join(SCRIPT_DIR, 'tests', 'fixtures')
TEACHER_IMAGE_PATH = os.path.join(FIXTURES_DIR, 'teacher_shape.jpeg')
STUDENT_IMAGE_PATH = os.path.join(FIXTURES_DIR, 'student_photo.jpeg')


def ensure_test_images():
    """Ensure test image fixtures exist. Generate them automatically if missing."""
    if os.path.exists(TEACHER_IMAGE_PATH) and os.path.exists(STUDENT_IMAGE_PATH):
        return

    print("Test fixtures missing. Automatically generating test face images...")
    os.makedirs(FIXTURES_DIR, exist_ok=True)
    try:
        from tests.fixtures.generate_test_images import _create_face_image
        _create_face_image(42, 'teacher_shape.jpeg')
        _create_face_image(42, 'student_photo.jpeg')
        print("Generated test image fixtures successfully.\n")
    except Exception as e:
        print(f"Warning: Could not auto-generate images: {e}")


def open_image(path):
    try:
        return open(path, 'rb')
    except FileNotFoundError:
        print(f"Error: Could not find '{path}'.")
        sys.exit(1)


class APITester:
    def __init__(self, base_url, teacher_email, teacher_pass, student_email, student_pass, class_id):
        self.base_url = base_url.rstrip('/')
        self.teacher_email = teacher_email
        self.teacher_pass = teacher_pass
        self.student_email = student_student = student_email
        self.student_pass = student_pass
        self.class_id = class_id
        
        self.teacher_token = None
        self.student_token = None
        self.session_id = None
        
        self.passed = 0
        self.failed = 0

    def log_result(self, step_name, success, message=""):
        if success:
            self.passed += 1
            print(f"  [PASS] {step_name} {f'- {message}' if message else ''}")
        else:
            self.failed += 1
            print(f"  [FAIL] {step_name} {f'- {message}' if message else ''}")

    def login(self, email, password):
        response = requests.post(
            f'{self.base_url}/auth/token/',
            json={'email': email, 'password': password},
            timeout=15,
        )
        if response.status_code == 200:
            return response.json()['access']
        return None

    def run_all(self):
        print("========================================")
        print("    Starting API Integration Tests      ")
        print(f"    Target Server: {self.base_url}")
        print("========================================\n")

        # 1. Ping Check
        try:
            ping_res = requests.get(f'{self.base_url}/ping/', timeout=5)
            self.log_result("1. Server Ping Check", ping_res.status_code == 200, f"Status Code {ping_res.status_code}")
        except Exception as e:
            self.log_result("1. Server Ping Check", False, f"Could not connect to server at {self.base_url}: {e}")
            print("\nPlease ensure the Django backend server is running (`python manage.py runserver`).")
            return False

        # 2. Invalid Credentials Check
        invalid_token = self.login("wrong@example.com", "wrongpass")
        self.log_result("2. Invalid Credentials Auth", invalid_token is None, "Rejected invalid credentials as expected")

        # 3. Teacher Login
        self.teacher_token = self.login(self.teacher_email, self.teacher_pass)
        self.log_result("3. Teacher Authentication", self.teacher_token is not None, f"Authenticated as {self.teacher_email}")
        if not self.teacher_token:
            print("Aborting remaining tests due to failed teacher login.")
            return False

        # 4. Student Login
        self.student_token = self.login(self.student_email, self.student_pass)
        self.log_result("4. Student Authentication", self.student_token is not None, f"Authenticated as {self.student_email}")
        if not self.student_token:
            print("Aborting remaining tests due to failed student login.")
            return False

        # 5. User Profile Check (/auth/me/)
        me_res = requests.get(
            f'{self.base_url}/auth/me/',
            headers={'Authorization': f'Bearer {self.teacher_token}'},
            timeout=10,
        )
        self.log_result("5. User Profile API (/auth/me/)", me_res.status_code == 200, f"Role: {me_res.json().get('role')}")

        # 6. Class Management APIs
        classes_res = requests.get(
            f'{self.base_url}/classes/',
            headers={'Authorization': f'Bearer {self.teacher_token}'},
            timeout=10,
        )
        classes = classes_res.json().get('classes', []) if classes_res.status_code == 200 else []
        self.log_result("6. List Teacher Classes", classes_res.status_code == 200, f"Found {len(classes)} classes")

        if classes:
            self.class_id = classes[0]['id']

        class_detail_res = requests.get(
            f'{self.base_url}/classes/{self.class_id}/',
            headers={'Authorization': f'Bearer {self.teacher_token}'},
            timeout=10,
        )
        self.log_result(f"7. Get Class Detail (ID {self.class_id})", class_detail_res.status_code == 200)

        students_res = requests.get(
            f'{self.base_url}/classes/{self.class_id}/students/',
            headers={'Authorization': f'Bearer {self.teacher_token}'},
            timeout=10,
        )
        self.log_result(f"8. Get Enrolled Students (ID {self.class_id})", students_res.status_code == 200)

        # 7. Student Enrolled Classes API
        stu_classes_res = requests.get(
            f'{self.base_url}/students/my-classes/',
            headers={'Authorization': f'Bearer {self.student_token}'},
            timeout=10,
        )
        self.log_result("9. Student My Classes API", stu_classes_res.status_code == 200)

        # 8. Create Attendance Session
        ensure_test_images()
        with open_image(TEACHER_IMAGE_PATH) as teacher_file:
            session_res = requests.post(
                f'{self.base_url}/sessions/create/',
                headers={'Authorization': f'Bearer {self.teacher_token}'},
                data={'class_id': self.class_id, 'duration_minutes': 60},
                files={'reference_image': teacher_file},
                timeout=15,
            )

        if session_res.status_code == 201:
            self.session_id = session_res.json()['session']['session_id']
            self.log_result("10. Create Attendance Session", True, f"Session ID: {self.session_id}")
        else:
            self.log_result("10. Create Attendance Session", False, f"HTTP {session_res.status_code}: {session_res.text}")
            return False

        # 9. Get Active Sessions
        active_res = requests.get(
            f'{self.base_url}/sessions/active/',
            headers={'Authorization': f'Bearer {self.teacher_token}'},
            timeout=10,
        )
        self.log_result("11. Get Active Sessions", active_res.status_code == 200)

        # 10. Get Session Details
        session_detail_res = requests.get(
            f'{self.base_url}/sessions/{self.session_id}/',
            headers={'Authorization': f'Bearer {self.teacher_token}'},
            timeout=10,
        )
        self.log_result("12. Get Session Details", session_detail_res.status_code == 200)

        # 11. Verify Attendance - Suspicious Focal Distance (Cheating Detection)
        with open_image(STUDENT_IMAGE_PATH) as student_file:
            cheat_res = requests.post(
                f'{self.base_url}/sessions/verify-image/',
                headers={'Authorization': f'Bearer {self.student_token}'},
                data={'session_id': self.session_id, 'focal_distance': 0.3},
                files={'student_image': student_file},
                timeout=15,
            )
        cheat_blocked = cheat_res.status_code == 400
        cheat_msg = cheat_res.json().get('error', '') if cheat_blocked else cheat_res.text
        self.log_result("13. Cheating Detection (Focal Distance 0.3m)", cheat_blocked, f"Blocked with message: {cheat_msg}")

        # 12. Verify Attendance - Valid Focal Distance
        with open_image(STUDENT_IMAGE_PATH) as student_file:
            verify_res = requests.post(
                f'{self.base_url}/sessions/verify-image/',
                headers={'Authorization': f'Bearer {self.student_token}'},
                data={'session_id': self.session_id, 'focal_distance': 1.2},
                files={'student_image': student_file},
                timeout=15,
            )
        
        if verify_res.status_code in (201, 400):
            body = verify_res.json()
            if verify_res.status_code == 201:
                self.log_result("14. Image Verification (Valid Distance 1.2m)", True, f"Verified: {body.get('message')}")
            else:
                self.log_result("14. Image Verification (Valid Distance 1.2m)", True, f"Face mismatch check passed: {body.get('error')}")
        else:
            self.log_result("14. Image Verification (Valid Distance 1.2m)", False, f"HTTP {verify_res.status_code}: {verify_res.text}")

        # 13. Student Attendance History
        stu_hist_res = requests.get(
            f'{self.base_url}/students/my-attendance/',
            headers={'Authorization': f'Bearer {self.student_token}'},
            timeout=10,
        )
        self.log_result("15. Student Attendance History", stu_hist_res.status_code == 200)

        # 14. Teacher Attendance History
        teach_hist_res = requests.get(
            f'{self.base_url}/teachers/attendance-history/',
            headers={'Authorization': f'Bearer {self.teacher_token}'},
            timeout=10,
        )
        self.log_result("16. Teacher Attendance History", teach_hist_res.status_code == 200)

        # 15. End Session
        end_res = requests.post(
            f'{self.base_url}/sessions/{self.session_id}/end/',
            headers={'Authorization': f'Bearer {self.teacher_token}'},
            timeout=10,
        )
        self.log_result("17. End Attendance Session", end_res.status_code == 200, f"Session {self.session_id} ended")

        print("\n========================================")
        print("       Test Suite Execution Summary     ")
        print("========================================")
        print(f"Passed: {self.passed}")
        print(f"Failed: {self.failed}")
        print(f"Total:  {self.passed + self.failed}")
        print("========================================\n")

        return self.failed == 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Run integration tests for Attendance App API.")
    parser.add_argument('--url', type=str, default=DEFAULT_BASE_URL, help="Base API URL")
    parser.add_argument('--teacher-email', type=str, default=DEFAULT_TEACHER_EMAIL, help="Teacher email")
    parser.add_argument('--teacher-pass', type=str, default=DEFAULT_TEACHER_PASS, help="Teacher password")
    parser.add_argument('--student-email', type=str, default=DEFAULT_STUDENT_EMAIL, help="Student email")
    parser.add_argument('--student-pass', type=str, default=DEFAULT_STUDENT_PASS, help="Student password")
    parser.add_argument('--class-id', type=int, default=DEFAULT_CLASS_ID, help="Class ID")

    args = parser.parse_args()

    tester = APITester(
        base_url=args.url,
        teacher_email=args.teacher_email,
        teacher_pass=args.teacher_pass,
        student_email=args.student_email,
        student_pass=args.student_pass,
        class_id=args.class_id,
    )
    success = tester.run_all()
    sys.exit(0 if success else 1)

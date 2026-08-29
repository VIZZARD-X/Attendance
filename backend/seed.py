import argparse
import json
import os
import sys
import uuid
from datetime import timedelta

from project_env import isolate_from_external_pythonpath

isolate_from_external_pythonpath()

import django
from django.utils import timezone

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'attend_backend.settings')
django.setup()

from django.contrib.auth import get_user_model
from attendance.models import (
    AttendanceRecord,
    AttendanceSession,
    Class,
    Enrollment,
    StudentProfile,
)

User = get_user_model()


def seed_database(reset=False, default_password="password123"):
    print("========================================")
    print("    Planting Attendance Seed Data      ")
    print("========================================")

    if reset:
        print("[!] Reset option specified. Clearing test data...")
        AttendanceRecord.objects.all().delete()
        AttendanceSession.objects.all().delete()
        Enrollment.objects.all().delete()
        Class.objects.all().delete()
        StudentProfile.objects.all().delete()
        User.objects.filter(email__in=[
            'admin@example.com',
            'teacher@example.com',
            'prof_davis@example.com',
            'student@example.com',
            'alice@example.com',
            'bob@example.com',
        ]).delete()
        print("  Existing test data cleared successfully.")

    # 1. Create Admin
    admin_user, created = User.objects.get_or_create(
        email='admin@example.com',
        defaults={
            'username': 'seed_admin',
            'role': 'admin',
            'first_name': 'System',
            'last_name': 'Admin',
            'is_staff': True,
            'is_superuser': True,
        }
    )
    admin_user.set_password(default_password)
    admin_user.save()
    print(f"  [{'Created' if created else 'Updated'}] Admin: {admin_user.email}")

    # 2. Create Teachers
    teachers_data = [
        {'email': 'teacher@example.com', 'username': 'mr_teacher', 'first_name': 'John', 'last_name': 'Smith'},
        {'email': 'prof_davis@example.com', 'username': 'prof_davis', 'first_name': 'Sarah', 'last_name': 'Davis'},
    ]
    teachers = {}
    for t_info in teachers_data:
        t_user, created = User.objects.get_or_create(
            email=t_info['email'],
            defaults={
                'username': t_info['username'],
                'role': 'teacher',
                'first_name': t_info['first_name'],
                'last_name': t_info['last_name'],
            }
        )
        t_user.set_password(default_password)
        t_user.save()
        teachers[t_info['email']] = t_user
        print(f"  [{'Created' if created else 'Updated'}] Teacher: {t_user.email} ({t_user.username})")

    # 3. Create Students
    students_data = [
        {'email': 'student@example.com', 'username': 'john_student', 'first_name': 'John', 'last_name': 'Doe'},
        {'email': 'alice@example.com', 'username': 'alice_student', 'first_name': 'Alice', 'last_name': 'Johnson'},
        {'email': 'bob@example.com', 'username': 'bob_student', 'first_name': 'Bob', 'last_name': 'Williams'},
    ]
    students = {}
    for s_info in students_data:
        s_user, created = User.objects.get_or_create(
            email=s_info['email'],
            defaults={
                'username': s_info['username'],
                'role': 'student',
                'first_name': s_info['first_name'],
                'last_name': s_info['last_name'],
            }
        )
        s_user.set_password(default_password)
        s_user.save()

        # Update or create student profile
        s_profile, created = StudentProfile.objects.get_or_create(
            student=s_user
        )
        students[s_info['email']] = s_user
        print(f"  [{'Created' if created else 'Updated'}] Student: {s_user.email}")

    # 4. Create Classes
    classes_data = [
        {
            'class_code': 'TEST101',
            'class_name': 'AI Integration 101',
            'semester': 'Fall 2026',
            'teacher': teachers['teacher@example.com'],
            'enrolled_students': ['student@example.com', 'alice@example.com'],
        },
        {
            'class_code': 'CS101',
            'class_name': 'Introduction to Computer Science',
            'semester': 'Fall 2026',
            'teacher': teachers['teacher@example.com'],
            'enrolled_students': ['student@example.com', 'alice@example.com', 'bob@example.com'],
        },
        {
            'class_code': 'MATH201',
            'class_name': 'Advanced Mathematics',
            'semester': 'Fall 2026',
            'teacher': teachers['prof_davis@example.com'],
            'enrolled_students': ['alice@example.com', 'bob@example.com'],
        },
    ]

    created_classes = {}
    for c_info in classes_data:
        c_obj, created = Class.objects.get_or_create(
            class_code=c_info['class_code'],
            defaults={
                'class_name': c_info['class_name'],
                'semester': c_info['semester'],
                'teacher': c_info['teacher'],
            }
        )
        if not created:
            c_obj.class_name = c_info['class_name']
            c_obj.semester = c_info['semester']
            c_obj.teacher = c_info['teacher']
            c_obj.save()

        created_classes[c_info['class_code']] = c_obj
        print(f"  [{'Created' if created else 'Updated'}] Class: {c_obj.class_code} - {c_obj.class_name}")

        for s_email in c_info['enrolled_students']:
            s_obj = students[s_email]
            Enrollment.objects.get_or_create(class_obj=c_obj, student=s_obj)

    # 5. Create Sample Active Attendance Session & Record
    main_class = created_classes['TEST101']
    teacher_user = teachers['teacher@example.com']
    student_user = students['student@example.com']

    now = timezone.now()
    end_time = now + timedelta(minutes=60)
    session_id = uuid.uuid4()
    qr_payload = json.dumps({
        'session_id': str(session_id),
        'class_code': main_class.class_code,
        'timestamp': now.isoformat(),
    })

    session = AttendanceSession.objects.filter(class_obj=main_class, status='active').first()
    created_session = False
    if not session:
        session = AttendanceSession.objects.create(
            class_obj=main_class,
            status='active',
            session_id=session_id,
            teacher=teacher_user,
            duration_minutes=60,
            end_time=end_time,
            qr_code_data=qr_payload,
        )
        created_session = True
    print(f"  [{'Created' if created_session else 'Found'}] Active Session: {session.session_id} for {main_class.class_code}")

    record, created_record = AttendanceRecord.objects.get_or_create(
        session=session,
        student=student_user,
        defaults={'status': 'present'}
    )
    print(f"  [{'Created' if created_record else 'Found'}] Attendance Record for {student_user.username}: {record.status}")

    print("\n========================================")
    print("    Seed Data Planted Successfully!     ")
    print("========================================")
    print("Summary Credentials:")
    print(f"  Admin:    admin@example.com / {default_password}")
    print(f"  Teacher:  teacher@example.com / {default_password}")
    print(f"  Teacher:  prof_davis@example.com / {default_password}")
    print(f"  Student:  student@example.com / {default_password} (Roll: TEST001)")
    print(f"  Student:  alice@example.com / {default_password} (Roll: TEST002)")
    print(f"  Student:  bob@example.com / {default_password} (Roll: TEST003)")
    print("----------------------------------------")
    print(f"  Primary Class ID: {main_class.id} (Code: {main_class.class_code})")
    print(f"  Active Session:   {session.session_id}")
    print("========================================\n")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Plant seed data for Attendance App.")
    parser.add_argument('--reset', action='store_true', help="Reset/clear existing seed data before planting.")
    parser.add_argument('--password', type=str, default="password123", help="Default password for seeded accounts.")
    args = parser.parse_args()

    seed_database(reset=args.reset, default_password=args.password)

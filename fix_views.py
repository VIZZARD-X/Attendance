import re

with open(r'E:\Attend\Attendance\backend\attendance\views.py', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''        record = AttendanceRecord.objects.create(
            session=session,
            student=user,
            status=status_val,
            verification_score=final_score,
            verification_reasons=json.dumps(reasons)
        )

        if not matched:'''

replacement = '''        record = AttendanceRecord.objects.create(
            session=session,
            student=user,
            status=status_val,
            verification_score=final_score,
            verification_reasons=json.dumps(reasons)
        )

        if scan_time:
            AttendanceRecord.objects.filter(id=record.id).update(marked_at=scan_time)
            record.refresh_from_db()

        if not matched:'''

if target in content:
    content = content.replace(target, replacement)
    with open(r'E:\Attend\Attendance\backend\attendance\views.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Target not found")

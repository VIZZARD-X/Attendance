from django.db import models
from django.contrib.auth.models import AbstractUser
import uuid

class User(AbstractUser):
    ROLE_CHOICES = (
        ('student', 'Student'),
        ('teacher', 'Teacher'),
        ('admin', 'Admin')
    )
    email = models.EmailField(unique=True, blank=False)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='student')

    USERNAME_FIELD = 'email'  # Use email for authentication instead of username
    REQUIRED_FIELDS = ['username']  # Username becomes optional field

    def __str__(self):
        return f"{self.username} ({self.role})"
    
    class Meta:
        db_table = 'users'


class StudentProfile(models.Model):
    """Table for student roll numbers and student specific data"""
    student = models.OneToOneField(
        User, 
        on_delete=models.CASCADE,
        primary_key=True,  # Keep this as the only primary key
        related_name='student_profile',
        limit_choices_to={'role': 'student'}
    )

    class Meta:
        db_table = 'student_profiles'  # Table name in PostgreSQL

    def __str__(self):
        return f"{self.student.username}"

    
class AcademicTerm(models.Model):
    """
    Institutional academic term (semester/trimester).

    Exists so that analytics never has to hardcode the attendance requirement,
    the academic year, or the term boundaries. Every analytics computation is
    scoped to a term, which makes "remaining sessions" and therefore every
    forecast an honest number instead of a guess.
    """
    name = models.CharField(max_length=100)                  # e.g. "Semester 5"
    academic_year = models.CharField(max_length=20)          # e.g. "2025-2026"
    start_date = models.DateField()
    end_date = models.DateField()
    required_attendance_pct = models.FloatField(default=75.0)
    is_active = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'academic_terms'
        ordering = ['-start_date']
        unique_together = ('name', 'academic_year')

    def __str__(self):
        return f"{self.name} ({self.academic_year})"

    @property
    def total_weeks(self):
        return max(1, ((self.end_date - self.start_date).days + 1) // 7)

    def weeks_remaining(self, as_of=None):
        """Whole weeks left in the term from `as_of` (date), floored at 0."""
        from django.utils import timezone as _tz
        ref = as_of or _tz.localdate()
        if ref >= self.end_date:
            return 0
        return max(0, (self.end_date - ref).days / 7.0)

    @classmethod
    def current(cls):
        """Active term, else the term containing today, else the latest term."""
        from django.utils import timezone as _tz
        today = _tz.localdate()
        term = cls.objects.filter(is_active=True).first()
        if term:
            return term
        term = cls.objects.filter(start_date__lte=today, end_date__gte=today).first()
        if term:
            return term
        return cls.objects.first()


class Class(models.Model):
    """Table for class/course information"""
    class_code = models.CharField(max_length=20, unique=True)
    class_name = models.CharField(max_length=200)
    semester = models.CharField(max_length=50)
    teacher = models.ForeignKey(User, on_delete=models.CASCADE, related_name='classes_taught', limit_choices_to={'role': 'teacher'})
    term = models.ForeignKey(
        AcademicTerm,
        on_delete=models.SET_NULL,
        related_name='classes',
        null=True,
        blank=True,
    )
    # Planned total sessions for the term. When null, analytics infers the
    # cadence from observed session frequency instead of inventing a constant.
    expected_sessions_total = models.PositiveIntegerField(null=True, blank=True)
    sessions_per_week = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


    class Meta:
        db_table = 'classes'  # Table name in PostgreSQL
        verbose_name_plural = 'Classes'
        ordering = ['class_code']

    def __str__(self):
        return f"{self.class_code} - {self.class_name}"
    
    @property
    def teacher_name(self):
        return self.teacher.username or self.teacher.get_full_name()
    
    @property
    def student_count(self):
        return self.enrollments.count()
    
class Enrollment(models.Model):
    """Table for student enrollments in classes"""
    class_obj = models.ForeignKey(Class, on_delete=models.CASCADE, related_name='enrollments')
    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='enrolled_classes', limit_choices_to={'role': 'student'})
    enrolled_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'enrollments'  # Table name in PostgreSQL
        unique_together = ('class_obj', 'student')
        ordering = ['class_obj', 'student']
        indexes = [
            models.Index(fields=['student', 'class_obj'], name='enr_student_class_idx'),
            models.Index(fields=['enrolled_at'], name='enr_enrolled_at_idx'),
        ]


    def __str__(self):
        return f"{self.student.username} enrolled in {self.class_obj.class_code}"


# AttendanceSession
class AttendanceSession(models.Model):
    """Table for attendance sessions with QR codes"""
    STATUS_CHOICES = (
        ('active', 'Active'),
        ('expired', 'Expired'),
        ('completed', 'Completed'),
    )
    
    CLASS_TYPE_CHOICES = (
        ('qr', 'QR'),
        ('pattern', 'Pattern'),
    )
    

    session_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    class_obj = models.ForeignKey(Class, on_delete=models.CASCADE, related_name='sessions')
    teacher = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_sessions')
    
    class_type = models.CharField(max_length=10, choices=CLASS_TYPE_CHOICES, default='qr')

    pattern_code = models.CharField(max_length=50, blank=True, null=True)
    instruction_card = models.TextField(blank=True, null=True)
    shape_data = models.JSONField(blank=True, null=True)
    
    from django.utils import timezone
    start_time = models.DateTimeField(default=timezone.now)
    duration_minutes = models.IntegerField()  # Duration in minutes
    end_time = models.DateTimeField()  # Calculated: start_time + duration
    
    qr_code_data = models.TextField()  # JSON string with session info
    reference_image = models.ImageField(
        upload_to='session_references/%Y/%m/%d/',
        blank=True,
        null=True,
    )
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='active')
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'attendance_sessions'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['class_obj', 'start_time'], name='sess_class_start_idx'),
            models.Index(fields=['status', 'start_time'], name='sess_status_start_idx'),
            models.Index(fields=['teacher', 'start_time'], name='sess_teacher_start_idx'),
        ]


    def __str__(self):
        return f"{self.class_obj.class_code} - {self.start_time.strftime('%Y-%m-%d %H:%M')}"
    
    @property
    def is_active(self):
        """Check if session is still active"""
        from django.utils import timezone
        return self.status == 'active' and timezone.now() < self.end_time


# Attendance Record
class AttendanceRecord(models.Model):
    """Table for individual attendance records"""
    session = models.ForeignKey(AttendanceSession, on_delete=models.CASCADE, related_name='records')
    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='attendance_records')
    
    marked_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(
        max_length=20,
        choices=(('present', 'Present'), ('absent', 'Absent'), ('pending_review', 'Pending Review')),
        default='present'
    )
    
    verification_score = models.FloatField(null=True, blank=True)
    verification_reasons = models.TextField(null=True, blank=True)  # Store JSON string of reasons
    
    class Meta:
        db_table = 'attendance_records'
        unique_together = ('session', 'student')
        ordering = ['marked_at']
        indexes = [
            models.Index(fields=['student', 'session'], name='rec_student_session_idx'),
            models.Index(fields=['marked_at'], name='rec_marked_at_idx'),
            models.Index(fields=['status'], name='rec_status_idx'),
        ]

    def __str__(self):
        return f"{self.student.username} - {self.session.class_obj.class_code} - {self.status}"

    @property
    def latency_seconds(self):
        """
        Seconds between session start and the moment the mark landed.

        This is the raw signal behind all punctuality analytics. Negative values
        (marked before the scheduled start) are clamped to 0.
        """
        if not self.marked_at or not self.session_id:
            return None
        delta = (self.marked_at - self.session.start_time).total_seconds()
        return max(0.0, delta)



class Announcement(models.Model):
    TARGET_TYPE_CHOICES = (
        ('class', 'Class'),
        ('individual', 'Individual'),
        ('low_attendance', 'Low Attendance'),
    )

    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_announcements', limit_choices_to={'role': 'teacher'})
    title = models.CharField(max_length=200)
    content = models.TextField()
    
    target_type = models.CharField(max_length=20, choices=TARGET_TYPE_CHOICES, default='class')
    target_class = models.ForeignKey(Class, on_delete=models.CASCADE, related_name='announcements', null=True, blank=True)
    min_attendance_threshold = models.IntegerField(null=True, blank=True)
    
    is_urgent = models.BooleanField(default=False)
    recipients = models.ManyToManyField(User, related_name='announcements_received')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'announcements'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.title} by {self.sender.username}"


class AttendanceFlag(models.Model):
    """
    A persisted, auditable integrity anomaly.

    Anomalies are stored rather than recomputed-and-discarded so that a teacher's
    review decision survives, and so that any figure shown in the Integrity tab
    can be traced back to concrete evidence.
    """
    FLAG_TYPE_CHOICES = (
        ('low_verification', 'Low Verification Score'),
        ('burst_marking', 'Burst Marking (possible proxy cluster)'),
        ('session_collision', 'Session Collision (two places at once)'),
        ('late_outlier', 'Latency Outlier'),
        ('post_session_mark', 'Marked After Session End'),
        ('cohort_drop', 'Cohort Attendance Drop'),
    )
    SEVERITY_CHOICES = (
        ('info', 'Info'),
        ('warning', 'Warning'),
        ('critical', 'Critical'),
    )
    STATUS_CHOICES = (
        ('open', 'Open'),
        ('resolved', 'Resolved'),
        ('dismissed', 'Dismissed'),
    )

    session = models.ForeignKey(
        AttendanceSession, on_delete=models.CASCADE,
        related_name='flags', null=True, blank=True,
    )
    class_obj = models.ForeignKey(
        Class, on_delete=models.CASCADE, related_name='flags', null=True, blank=True,
    )
    student = models.ForeignKey(
        User, on_delete=models.CASCADE,
        related_name='attendance_flags', null=True, blank=True,
    )
    flag_type = models.CharField(max_length=32, choices=FLAG_TYPE_CHOICES)
    severity = models.CharField(max_length=10, choices=SEVERITY_CHOICES, default='warning')
    # Anomaly strength, 0..1. Higher means more confident it is a real anomaly.
    score = models.FloatField(default=0.0)
    # Machine-readable proof: the counts, timestamps and deltas that triggered it.
    evidence = models.JSONField(default=dict, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='open')
    resolution_note = models.TextField(blank=True, null=True)
    resolved_by = models.ForeignKey(
        User, on_delete=models.SET_NULL,
        related_name='resolved_flags', null=True, blank=True,
    )
    resolved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'attendance_flags'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', 'severity'], name='flag_status_sev_idx'),
            models.Index(fields=['class_obj', 'status'], name='flag_class_status_idx'),
            models.Index(fields=['student', 'status'], name='flag_student_status_idx'),
        ]
        # One live flag per (session, student, type); recompute updates in place.
        unique_together = ('session', 'student', 'flag_type')

    def __str__(self):
        who = self.student.username if self.student_id else 'cohort'
        return f"[{self.severity}] {self.flag_type} - {who}"


class InterventionLog(models.Model):
    """
    Closes the loop on low-attendance announcements.

    For each nudged student we snapshot attendance before the message, then
    recompute it after, and compare against a matched control group. This is what
    turns the dashboard into a measurable intervention system rather than a
    passive report.
    """
    OUTCOME_CHOICES = (
        ('pending', 'Pending (insufficient follow-up sessions)'),
        ('improved', 'Improved'),
        ('unchanged', 'Unchanged'),
        ('declined', 'Declined'),
    )

    announcement = models.ForeignKey(
        Announcement, on_delete=models.CASCADE, related_name='interventions',
    )
    student = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='interventions_received',
    )
    class_obj = models.ForeignKey(
        Class, on_delete=models.CASCADE, related_name='interventions', null=True, blank=True,
    )
    sent_at = models.DateTimeField()

    baseline_pct = models.FloatField(null=True, blank=True)
    baseline_sessions = models.PositiveIntegerField(default=0)
    followup_pct = models.FloatField(null=True, blank=True)
    followup_sessions = models.PositiveIntegerField(default=0)
    delta_points = models.FloatField(null=True, blank=True)
    # Same-class, same-risk-band students who were NOT messaged. Isolates the
    # message effect from whatever the whole cohort was doing anyway.
    control_delta_points = models.FloatField(null=True, blank=True)
    outcome = models.CharField(max_length=12, choices=OUTCOME_CHOICES, default='pending')
    computed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'intervention_logs'
        ordering = ['-sent_at']
        unique_together = ('announcement', 'student')
        indexes = [
            models.Index(fields=['student', 'sent_at'], name='iv_student_sent_idx'),
            models.Index(fields=['class_obj', 'outcome'], name='iv_class_outcome_idx'),
        ]

    def __str__(self):
        return f"{self.student.username} <- {self.announcement.title} ({self.outcome})"



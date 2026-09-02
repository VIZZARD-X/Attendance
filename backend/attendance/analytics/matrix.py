"""
AttendanceMatrix — the single core primitive all analytics is built on.

Why this exists
---------------
The previous implementation computed `present_records / total_records`. Because
an AttendanceRecord row only exists when a student was actually marked, a student
who never scans has no rows at all and therefore silently disappears from the
denominator. A class where half the cohort never attends would report 100%.

This module fixes that by building the *dense* expectation set:

    expected pairs = { (student, session) : student was enrolled when session ran }

Absences are derived, never written to the database. That keeps attendance truth
untouched (a missing row stays a missing row) while still giving every metric a
correct denominator.

It also loads everything in a fixed, small number of queries regardless of cohort
size, replacing the previous per-student query loop.
"""
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple

from django.db.models import Q

from ..models import AttendanceRecord, AttendanceSession, Enrollment

# Statuses that count as "the student was there".
PRESENT_STATUSES = ('present',)
# Recorded but not credited; still evidence the student interacted with a session.
REVIEW_STATUSES = ('pending_review',)


@dataclass(frozen=True)
class SessionInfo:
    id: int
    class_id: int
    class_code: str
    class_name: str
    start_time: object
    end_time: object
    duration_minutes: int
    class_type: str
    status: str

    @property
    def weekday(self) -> int:
        """0=Mon .. 6=Sun, in local time."""
        from django.utils import timezone
        return timezone.localtime(self.start_time).weekday()

    @property
    def hour(self) -> int:
        from django.utils import timezone
        return timezone.localtime(self.start_time).hour

    @property
    def local_date(self):
        from django.utils import timezone
        return timezone.localtime(self.start_time).date()


@dataclass(frozen=True)
class Mark:
    """One actual attendance record, plus its derived latency."""
    student_id: int
    session_id: int
    status: str
    marked_at: object
    verification_score: Optional[float]
    latency_seconds: Optional[float]

    @property
    def is_present(self) -> bool:
        return self.status in PRESENT_STATUSES


class AttendanceMatrix:
    """
    Dense (student x session) attendance view for a scope.

    Load once, then ask it questions. Nothing here issues queries after `load()`.
    """

    def __init__(self, ctx, class_ids: List[int], student_ids: Optional[List[int]] = None):
        self.ctx = ctx
        self.class_ids = list(class_ids)
        self._restrict_students = set(student_ids) if student_ids else None

        self.sessions: Dict[int, SessionInfo] = {}
        self.sessions_by_class: Dict[int, List[SessionInfo]] = defaultdict(list)
        # student_id -> {class_id: enrolled_at}
        self.enrollments: Dict[int, Dict[int, object]] = defaultdict(dict)
        self.student_names: Dict[int, Tuple[str, str]] = {}   # id -> (username, full_name)
        # (student_id, session_id) -> Mark
        self.marks: Dict[Tuple[int, int], Mark] = {}
        # student_id -> ordered list of expected SessionInfo
        self._expected_cache: Dict[int, List[SessionInfo]] = {}

    # ------------------------------------------------------------------ load

    def load(self) -> 'AttendanceMatrix':
        self._load_sessions()
        self._load_enrollments()
        self._load_marks()
        return self

    def _load_sessions(self):
        """Only concluded sessions count. An active session isn't a missed one yet."""
        qs = (
            AttendanceSession.objects
            .filter(class_obj_id__in=self.class_ids)
            .exclude(status='active')
            .select_related('class_obj')
        )
        if self.ctx.start:
            qs = qs.filter(start_time__gte=self.ctx.start)
        if self.ctx.end:
            qs = qs.filter(start_time__lte=self.ctx.end)

        rows = qs.values_list(
            'id', 'class_obj_id', 'class_obj__class_code', 'class_obj__class_name',
            'start_time', 'end_time', 'duration_minutes', 'class_type', 'status',
        ).order_by('start_time')

        for (sid, cid, code, name, start, end, dur, ctype, status) in rows:
            info = SessionInfo(
                id=sid, class_id=cid, class_code=code, class_name=name,
                start_time=start, end_time=end, duration_minutes=dur or 0,
                class_type=ctype, status=status,
            )
            self.sessions[sid] = info
            self.sessions_by_class[cid].append(info)

    def _load_enrollments(self):
        qs = Enrollment.objects.filter(class_obj_id__in=self.class_ids)
        if self._restrict_students is not None:
            qs = qs.filter(student_id__in=self._restrict_students)

        rows = qs.values_list(
            'student_id', 'class_obj_id', 'enrolled_at',
            'student__username', 'student__first_name', 'student__last_name',
        )
        for (stu, cid, enrolled_at, username, first, last) in rows:
            self.enrollments[stu][cid] = enrolled_at
            if stu not in self.student_names:
                full = f"{first or ''} {last or ''}".strip() or username
                self.student_names[stu] = (username, full)

    def _load_marks(self):
        if not self.sessions:
            return
        qs = AttendanceRecord.objects.filter(session_id__in=list(self.sessions.keys()))
        if self._restrict_students is not None:
            qs = qs.filter(student_id__in=self._restrict_students)

        rows = qs.values_list(
            'student_id', 'session_id', 'status', 'marked_at', 'verification_score',
        )
        for (stu, sess, status, marked_at, vscore) in rows:
            info = self.sessions.get(sess)
            latency = None
            if info is not None and marked_at is not None:
                latency = max(0.0, (marked_at - info.start_time).total_seconds())
            self.marks[(stu, sess)] = Mark(
                student_id=stu, session_id=sess, status=status,
                marked_at=marked_at, verification_score=vscore,
                latency_seconds=latency,
            )

    # ------------------------------------------------------------- expectation

    def expected_sessions_for(self, student_id: int) -> List[SessionInfo]:
        """
        Sessions this student was actually obliged to attend, chronologically.

        Enforces the enrolment gate: a student who joined at session 10 is not
        held responsible for sessions 1-9.
        """
        if student_id in self._expected_cache:
            return self._expected_cache[student_id]

        out: List[SessionInfo] = []
        for cid, enrolled_at in self.enrollments.get(student_id, {}).items():
            for s in self.sessions_by_class.get(cid, ()):
                if enrolled_at is None or s.start_time >= enrolled_at:
                    out.append(s)
        out.sort(key=lambda s: s.start_time)
        self._expected_cache[student_id] = out
        return out

    def expected_sessions_for_in_class(self, student_id: int, class_id: int) -> List[SessionInfo]:
        enrolled_at = self.enrollments.get(student_id, {}).get(class_id)
        if enrolled_at is None and class_id not in self.enrollments.get(student_id, {}):
            return []
        return [
            s for s in self.sessions_by_class.get(class_id, ())
            if enrolled_at is None or s.start_time >= enrolled_at
        ]

    def students_in_class(self, class_id: int) -> List[int]:
        return [sid for sid, cls in self.enrollments.items() if class_id in cls]

    @property
    def student_ids(self) -> List[int]:
        return list(self.enrollments.keys())

    def is_present(self, student_id: int, session_id: int) -> bool:
        m = self.marks.get((student_id, session_id))
        return bool(m and m.is_present)

    def mark(self, student_id: int, session_id: int) -> Optional[Mark]:
        return self.marks.get((student_id, session_id))

    # ----------------------------------------------------------------- counts

    def student_totals(self, student_id: int, class_id: Optional[int] = None) -> dict:
        """
        Honest attendance counts for one student.

        `expected` is derived from enrolment + concluded sessions, so a student
        with zero records still gets a correct 0% rather than vanishing.
        """
        sessions = (
            self.expected_sessions_for_in_class(student_id, class_id)
            if class_id is not None else
            self.expected_sessions_for(student_id)
        )
        expected = len(sessions)
        present = review = 0
        for s in sessions:
            m = self.marks.get((student_id, s.id))
            if m is None:
                continue
            if m.is_present:
                present += 1
            elif m.status in REVIEW_STATUSES:
                review += 1
        absent = expected - present - review
        return {
            'expected': expected,
            'present': present,
            'pending_review': review,
            'absent': max(0, absent),
            'pct': (present / expected * 100.0) if expected else None,
        }

    def cohort_totals(self, class_id: Optional[int] = None) -> dict:
        """
        Cohort-level counts using the dense denominator
        (enrolled students x sessions they were enrolled for).
        """
        expected = present = review = 0
        student_ids = self.students_in_class(class_id) if class_id is not None else self.student_ids
        for sid in student_ids:
            t = self.student_totals(sid, class_id)
            expected += t['expected']
            present += t['present']
            review += t['pending_review']
        return {
            'expected_marks': expected,
            'present_marks': present,
            'pending_review_marks': review,
            'absent_marks': max(0, expected - present - review),
            'students': len(student_ids),
            'sessions': len(self.sessions_by_class[class_id]) if class_id is not None else len(self.sessions),
            'pct': (present / expected * 100.0) if expected else None,
        }

    def session_totals(self, session: SessionInfo) -> dict:
        """Per-session turnout, denominated by who was enrolled at that moment."""
        expected = present = 0
        latencies: List[float] = []
        for sid in self.students_in_class(session.class_id):
            enrolled_at = self.enrollments[sid].get(session.class_id)
            if enrolled_at is not None and session.start_time < enrolled_at:
                continue
            expected += 1
            m = self.marks.get((sid, session.id))
            if m and m.is_present:
                present += 1
                if m.latency_seconds is not None:
                    latencies.append(m.latency_seconds)
        return {
            'session_id': session.id,
            'expected': expected,
            'present': present,
            'absent': max(0, expected - present),
            'pct': (present / expected * 100.0) if expected else None,
            'latencies': latencies,
        }

    def per_student_pct(self, class_id: Optional[int] = None) -> Dict[int, float]:
        """student_id -> attendance %, skipping students with no expected sessions."""
        out: Dict[int, float] = {}
        ids = self.students_in_class(class_id) if class_id is not None else self.student_ids
        for sid in ids:
            t = self.student_totals(sid, class_id)
            if t['expected'] > 0:
                out[sid] = t['pct']
        return out

    def attendance_series(self, student_id: int, class_id: Optional[int] = None) -> List[int]:
        """
        Session-ordered 1/0 outcome sequence for a student.

        This is the input to EWMA, slope, streaks and the Monte Carlo forecast —
        all of which need chronological order, which the old `-marked_at`
        ordering got backwards.
        """
        sessions = (
            self.expected_sessions_for_in_class(student_id, class_id)
            if class_id is not None else
            self.expected_sessions_for(student_id)
        )
        return [1 if self.is_present(student_id, s.id) else 0 for s in sessions]

    def latencies_for(self, student_id: int) -> List[float]:
        out = []
        for s in self.expected_sessions_for(student_id):
            m = self.marks.get((student_id, s.id))
            if m and m.is_present and m.latency_seconds is not None:
                out.append(m.latency_seconds)
        return out

    def verification_scores(self) -> List[float]:
        return [
            m.verification_score for m in self.marks.values()
            if m.verification_score is not None
        ]

    @property
    def has_data(self) -> bool:
        return bool(self.sessions) and bool(self.enrollments)


def build_matrix(ctx, class_ids, student_ids=None) -> AttendanceMatrix:
    return AttendanceMatrix(ctx, class_ids, student_ids).load()

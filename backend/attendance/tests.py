"""
Tests for the analytics engine.

The focus is on the properties that were actually wrong before, and that a
refactor could silently break again:

* the denominator is the expected (student x session) set, not the rows that
  happen to exist, so a student who never scans still counts as absent;
* the threshold comes from the academic term, not a hardcoded 75;
* sparse data produces an explicit insufficient_data marker, never a made-up
  number;
* forecasts refuse to project when remaining sessions are unknowable;
* teachers cannot read students outside their own classes.
"""
from datetime import timedelta

from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient

from .models import (
    AcademicTerm,
    AttendanceRecord,
    AttendanceSession,
    Class,
    Enrollment,
    User,
)
from .analytics import metrics as M
from .analytics.context import MIN_SAMPLE_SIZE
from .analytics.matrix import build_matrix


class AnalyticsFixtureMixin:
    """
    Builds a small but non-degenerate cohort:

    4 concluded sessions, 3 students —
      alice   present at all 4          -> 100%
      bob     present at 2              ->  50%
      carol   never marked at all       ->   0%  (the case the old code lost)

    Cohort truth: 6 present / 12 expected = 50%.
    """

    def build_fixture(self, *, with_term=True):
        now = timezone.now()
        self.now = now

        self.term = None
        if with_term:
            self.term = AcademicTerm.objects.create(
                name='Semester 5',
                academic_year='2025-2026',
                start_date=(now - timedelta(days=40)).date(),
                end_date=(now + timedelta(days=40)).date(),
                required_attendance_pct=80.0,   # deliberately not 75
                is_active=True,
            )

        self.teacher = User.objects.create_user(
            username='teach', email='teach@example.com',
            password='pw12345!', role='teacher',
        )
        self.other_teacher = User.objects.create_user(
            username='other', email='other@example.com',
            password='pw12345!', role='teacher',
        )

        self.klass = Class.objects.create(
            class_code='CS101', class_name='Intro to CS', semester='5',
            teacher=self.teacher, term=self.term,
            expected_sessions_total=10,
        )
        self.foreign_class = Class.objects.create(
            class_code='ZZ999', class_name='Not Yours', semester='5',
            teacher=self.other_teacher, term=self.term,
        )

        self.alice = self._student('alice')
        self.bob = self._student('bob')
        self.carol = self._student('carol')

        for s in (self.alice, self.bob, self.carol):
            self._enroll(s, self.klass, days_ago=30)

        # 4 concluded sessions, oldest first.
        self.sessions = [
            self._session(days_ago=d) for d in (20, 15, 10, 5)
        ]

        # alice: all four. bob: first two only. carol: nothing.
        for sess in self.sessions:
            self._mark(self.alice, sess)
        for sess in self.sessions[:2]:
            self._mark(self.bob, sess)

    def _student(self, name):
        return User.objects.create_user(
            username=name, email=f'{name}@example.com',
            password='pw12345!', role='student',
        )

    def _enroll(self, student, klass, *, days_ago):
        e = Enrollment.objects.create(class_obj=klass, student=student)
        # enrolled_at is auto_now_add; backdate it so the sessions below fall
        # inside the student's enrolment window.
        Enrollment.objects.filter(pk=e.pk).update(
            enrolled_at=self.now - timedelta(days=days_ago)
        )
        return e

    def _session(self, *, days_ago, klass=None, duration=60):
        start = self.now - timedelta(days=days_ago)
        return AttendanceSession.objects.create(
            class_obj=klass or self.klass,
            teacher=self.teacher,
            class_type='qr',
            start_time=start,
            duration_minutes=duration,
            end_time=start + timedelta(minutes=duration),
            qr_code_data='{}',
            status='completed',
        )

    def _mark(self, student, session, status='present'):
        rec = AttendanceRecord.objects.create(
            session=session, student=student, status=status,
        )
        # marked_at is auto_now_add; place it 2 minutes into the session so
        # latency-based metrics see a realistic value.
        AttendanceRecord.objects.filter(pk=rec.pk).update(
            marked_at=session.start_time + timedelta(minutes=2)
        )
        return rec


class _Ctx:
    """Minimal stand-in for a DRF request when only query_params are needed."""

    def __init__(self, **params):
        self.query_params = params


class MatrixDenominatorTests(AnalyticsFixtureMixin, TestCase):
    """The bug that motivated the rewrite: absent students vanishing."""

    def setUp(self):
        self.build_fixture()
        from .analytics.context import build_context
        self.ctx = build_context(_Ctx(), [self.klass.id])
        self.matrix = build_matrix(self.ctx, [self.klass.id])

    def test_expected_marks_are_dense(self):
        cohort = self.matrix.cohort_totals()
        self.assertEqual(cohort['students'], 3)
        self.assertEqual(cohort['sessions'], 4)
        self.assertEqual(cohort['expected_marks'], 12)
        self.assertEqual(cohort['present_marks'], 6)
        self.assertAlmostEqual(cohort['pct'], 50.0)

    def test_student_with_no_records_is_zero_not_absent_from_the_report(self):
        totals = self.matrix.student_totals(self.carol.id, self.klass.id)
        self.assertEqual(totals['expected'], 4)
        self.assertEqual(totals['present'], 0)
        self.assertEqual(totals['absent'], 4)
        self.assertAlmostEqual(totals['pct'], 0.0)

        pcts = self.matrix.per_student_pct(self.klass.id)
        self.assertIn(self.carol.id, pcts)
        self.assertAlmostEqual(pcts[self.carol.id], 0.0)

    def test_partial_attendance(self):
        totals = self.matrix.student_totals(self.bob.id, self.klass.id)
        self.assertEqual((totals['present'], totals['expected']), (2, 4))
        self.assertAlmostEqual(totals['pct'], 50.0)

    def test_series_is_chronological_and_dense(self):
        # bob attended the first two of four sessions.
        self.assertEqual(self.matrix.attendance_series(self.bob.id, self.klass.id),
                         [1, 1, 0, 0])
        self.assertEqual(self.matrix.attendance_series(self.carol.id, self.klass.id),
                         [0, 0, 0, 0])

    def test_active_sessions_are_excluded(self):
        start = self.now - timedelta(minutes=10)
        AttendanceSession.objects.create(
            class_obj=self.klass, teacher=self.teacher, class_type='qr',
            start_time=start, duration_minutes=60,
            end_time=start + timedelta(minutes=60),
            qr_code_data='{}', status='active',
        )
        m = build_matrix(self.ctx, [self.klass.id])
        # An in-progress session is not yet a missed one.
        self.assertEqual(m.cohort_totals()['sessions'], 4)

    def test_enrolment_date_bounds_expectations(self):
        late = self._student('dave')
        self._enroll(late, self.klass, days_ago=7)   # after 3 of 4 sessions
        m = build_matrix(self.ctx, [self.klass.id])
        self.assertEqual(m.student_totals(late.id, self.klass.id)['expected'], 1)


class ThresholdResolutionTests(AnalyticsFixtureMixin, TestCase):
    def test_threshold_comes_from_term(self):
        from .analytics.context import build_context
        self.build_fixture()
        ctx = build_context(_Ctx(), [self.klass.id])
        self.assertEqual(ctx.required_pct, 80.0)
        self.assertEqual(ctx.threshold_source, 'term')

    def test_threshold_falls_back_and_says_so(self):
        from .analytics.context import build_context
        self.build_fixture(with_term=False)
        ctx = build_context(_Ctx(), [self.klass.id])
        self.assertEqual(ctx.required_pct, 75.0)
        self.assertEqual(ctx.threshold_source, 'default')

    def test_explicit_override_is_labelled(self):
        from .analytics.context import build_context
        self.build_fixture()
        ctx = build_context(_Ctx(threshold='90'), [self.klass.id])
        self.assertEqual(ctx.required_pct, 90.0)
        self.assertEqual(ctx.threshold_source, 'override')


class MetricHonestyTests(TestCase):
    """Sparse input must yield markers, not numbers."""

    def test_slope_refuses_short_series(self):
        # Two points fit a line exactly; that is arithmetic, not a trend.
        self.assertIsNone(M.rolling_slope([1, 0]))
        self.assertIsNone(M.rolling_slope([1, 1, 0]))
        self.assertIsNotNone(M.rolling_slope([1, 1, 0, 0]))


    def test_ewma_of_empty_series_is_none(self):
        self.assertIsNone(M.ewma([]))

    def test_min_sessions_needed_is_exact(self):
        # 5/10 = 50%, need 75%: attending n more gives (5+n)/(10+n) >= 0.75 at n=10.
        self.assertEqual(M.min_sessions_needed(5, 10, 75.0), 10)

    def test_already_above_threshold_needs_nothing(self):
        self.assertEqual(M.min_sessions_needed(9, 10, 75.0), 0)

    def test_monte_carlo_is_deterministic(self):
        a = M.monte_carlo_forecast(5, 10, 10, 0.8, 75.0)
        b = M.monte_carlo_forecast(5, 10, 10, 0.8, 75.0)
        self.assertEqual(a, b)

    def test_gini_of_identical_values_is_zero(self):
        self.assertAlmostEqual(M.gini([50.0, 50.0, 50.0]), 0.0, places=6)


class ForecastHonestyTests(AnalyticsFixtureMixin, TestCase):
    def setUp(self):
        self.build_fixture()

    def test_declared_total_is_high_confidence(self):
        from .analytics import forecast as F
        from .analytics.context import build_context
        ctx = build_context(_Ctx(), [self.klass.id])
        info = F.remaining_sessions(self.klass, 4, ctx)
        self.assertEqual(info['source'], 'declared')
        self.assertEqual(info['confidence'], 'high')
        self.assertEqual(info['remaining'], 6)      # 10 planned - 4 held

    def test_no_term_and_no_plan_refuses_to_guess(self):
        from .analytics import forecast as F
        from .analytics.context import build_context
        bare = Class.objects.create(
            class_code='BARE1', class_name='Unplanned', semester='5',
            teacher=self.teacher, term=None,
        )
        ctx = build_context(_Ctx(term_id='all'), [bare.id])
        info = F.remaining_sessions(bare, 0, ctx)
        self.assertEqual(info['source'], 'unknown')
        self.assertEqual(info['confidence'], 'none')
        self.assertIn('cannot be determined', info['note'])

    def test_unreachable_threshold_is_stated_plainly(self):
        from .analytics import forecast as F
        # 0 present of 10, only 1 session left, 75% required -> impossible.
        pnr = F.point_of_no_return(0, 10, 1, 75.0)
        self.assertEqual(pnr['status'], 'unreachable')
        self.assertLess(pnr['best_possible_pct'], 75.0)


class TeacherEndpointTests(AnalyticsFixtureMixin, TestCase):
    def setUp(self):
        self.build_fixture()
        self.client = APIClient()

    def test_overview_reports_dense_percentage(self):
        self.client.force_authenticate(self.teacher)
        r = self.client.get('/api/v1/analytics/teacher/overview/')
        self.assertEqual(r.status_code, 200)
        body = r.json()

        self.assertAlmostEqual(body['summary']['attendance_pct'], 50.0)
        self.assertEqual(body['summary']['expected_marks'], 12)
        self.assertEqual(body['summary']['students'], 3)
        # Threshold provenance must always be visible.
        self.assertEqual(body['meta']['threshold_pct'], 80.0)
        self.assertEqual(body['meta']['threshold_source'], 'term')
        self.assertEqual(body['meta']['term'], 'Semester 5')

    def test_students_are_never_silently_dropped(self):
        self.client.force_authenticate(self.teacher)
        r = self.client.get('/api/v1/analytics/teacher/at-risk/')
        self.assertEqual(r.status_code, 200)
        ids = {row['student_id'] for row in r.json()['students']}
        self.assertIn(self.carol.id, ids)     # 0% student must appear
        self.assertEqual(len(ids), 3)

    def test_risk_scores_carry_their_reasons(self):
        self.client.force_authenticate(self.teacher)
        r = self.client.get('/api/v1/analytics/teacher/at-risk/')
        carol = next(x for x in r.json()['students'] if x['student_id'] == self.carol.id)
        self.assertTrue(carol['reasons'], 'a risk score must explain itself')
        self.assertIn('components', carol)

    def test_students_cannot_read_teacher_analytics(self):
        self.client.force_authenticate(self.alice)
        r = self.client.get('/api/v1/analytics/teacher/overview/')
        self.assertEqual(r.status_code, 403)

    def test_teacher_cannot_read_a_student_outside_their_classes(self):
        outsider = self._student('eve')
        Enrollment.objects.create(class_obj=self.foreign_class, student=outsider)
        self.client.force_authenticate(self.teacher)
        r = self.client.get(f'/api/v1/analytics/teacher/student/{outsider.id}/')
        self.assertEqual(r.status_code, 403)

    def test_teacher_student_detail_is_scoped_to_own_classes(self):
        self.client.force_authenticate(self.teacher)
        r = self.client.get(f'/api/v1/analytics/teacher/student/{self.bob.id}/')
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertEqual(len(body['per_class']), 1)
        self.assertEqual(body['per_class'][0]['class_code'], 'CS101')
        self.assertAlmostEqual(body['overall']['attendance_pct'], 50.0)

    def test_empty_scope_explains_itself(self):
        self.client.force_authenticate(self.other_teacher)
        r = self.client.get('/api/v1/analytics/teacher/overview/')
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertFalse(body['meta']['has_data'])
        self.assertIsNone(body['summary'])
        self.assertTrue(body['reason'])


class StudentEndpointTests(AnalyticsFixtureMixin, TestCase):
    def setUp(self):
        self.build_fixture()
        self.client = APIClient()

    def test_overview_uses_expected_denominator(self):
        self.client.force_authenticate(self.bob)
        r = self.client.get('/api/v1/analytics/student/overview/')
        self.assertEqual(r.status_code, 200)
        body = r.json()
        self.assertAlmostEqual(body['overall']['attendance_pct'], 50.0)
        self.assertEqual(body['overall']['expected'], 4)
        self.assertEqual(body['overall']['absent'], 2)
        self.assertFalse(body['overall']['meets_threshold'])

    def test_peers_are_never_named_to_a_student(self):
        self.client.force_authenticate(self.bob)
        body = self.client.get('/api/v1/analytics/student/overview/').json()
        blob = str(body)
        for name in ('alice', 'carol', 'Alice', 'Carol'):
            self.assertNotIn(name, blob)
        # An anonymised position is still allowed.
        cohort = body['per_class'][0]['cohort']
        self.assertIn('percentile_rank', cohort)

    def test_calendar_derives_absences(self):
        self.client.force_authenticate(self.carol)
        r = self.client.get('/api/v1/analytics/student/calendar/')
        self.assertEqual(r.status_code, 200)
        days = r.json()['days']
        # All four sessions appear even though carol has no records at all.
        self.assertEqual(len(days), 4)
        self.assertTrue(all(d['day_status'] == 'absent' for d in days))

    def test_simulator_is_deterministic_and_bounded(self):
        self.client.force_authenticate(self.bob)
        first = self.client.get('/api/v1/analytics/student/simulate/?attend_pct=100').json()
        second = self.client.get('/api/v1/analytics/student/simulate/?attend_pct=100').json()
        self.assertEqual(first['scenarios'], second['scenarios'])

        s = first['scenarios'][0]
        self.assertEqual(s['status'], 'ok')
        self.assertEqual(s['attend_rate_used'], 1.0)
        # 2 present of 4, 6 remaining, all attended -> 8/10 = 80%.
        self.assertAlmostEqual(s['projected_pct'], 80.0)

    def test_teachers_cannot_read_student_endpoints(self):
        self.client.force_authenticate(self.teacher)
        r = self.client.get('/api/v1/analytics/student/overview/')
        self.assertEqual(r.status_code, 403)


class SparseDataTests(AnalyticsFixtureMixin, TestCase):
    """A brand-new class must say 'not enough data', not report 0%."""

    def setUp(self):
        self.build_fixture()
        self.client = APIClient()

    def test_single_student_class_gets_insufficient_cohort_marker(self):
        solo_class = Class.objects.create(
            class_code='SOLO1', class_name='Solo', semester='5',
            teacher=self.teacher, term=self.term, expected_sessions_total=10,
        )
        solo = self._student('frank')
        self._enroll(solo, solo_class, days_ago=30)
        self._session(days_ago=3, klass=solo_class)

        self.client.force_authenticate(solo)
        body = self.client.get('/api/v1/analytics/student/overview/').json()
        cohort = body['per_class'][0]['cohort']
        self.assertEqual(cohort['status'], 'insufficient_data')
        self.assertEqual(cohort['required_n'], MIN_SAMPLE_SIZE)

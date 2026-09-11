"""
Analytics API endpoints.

These views are thin: they resolve scope, load the attendance matrix once, hand it
to the analytics engine and serialise the result. All arithmetic lives in
`attendance.analytics.*` so it can be unit-tested without HTTP.

Two guarantees are upheld at this layer:

1. Nothing is fabricated. Where the engine returns an insufficient-data marker it
   is passed through untouched rather than replaced with a plausible number.
2. Every response carries a `meta` block stating the term, threshold, threshold
   source and date window that produced the figures.
"""
from django.db.models import Q
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .models import AttendanceFlag, Class, Enrollment

from .analytics import metrics as M
from .analytics.context import (
    MIN_SAMPLE_SIZE,
    build_context,
    insufficient,
    resolve_teacher_classes,
)
from .analytics.matrix import build_matrix
from .analytics import forecast as F
from .analytics import health as H
from .analytics import insights as I
from .analytics import integrity as G
from .analytics import patterns as P
from .analytics import risk as R


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def _is_teacher(user) -> bool:
    return user.role == 'teacher' or user.is_staff


def _forbidden(msg):
    return Response({'error': msg}, status=status.HTTP_403_FORBIDDEN)


def _empty_scope(ctx, reason):
    """
    A valid, honest empty response.

    Returned when the teacher has no classes, or no concluded sessions exist in
    the window. An empty dashboard with a stated reason beats zeros that look
    like real measurements.
    """
    return Response({
        'meta': ctx.meta(has_data=False),
        'reason': reason,
        'summary': None,
        'health': None,
        'classes': [],
        'insights': [],
    })


def _sessions_sorted(matrix, class_id=None):
    if class_id is not None:
        return list(matrix.sessions_by_class.get(class_id, ()))
    return sorted(matrix.sessions.values(), key=lambda s: s.start_time)


def _distribution(per_student_pcts, required_pct):
    """
    Attendance spread across fixed bands plus the threshold-relative split.

    Fixed bands stay comparable across terms; the threshold split is what policy
    actually cares about. Both are reported rather than picking one.
    """
    bands = [
        ('90-100%', 90.0, 100.01),
        ('80-89%', 80.0, 90.0),
        ('75-79%', 75.0, 80.0),
        ('60-74%', 60.0, 75.0),
        ('<60%', -0.01, 60.0),
    ]
    rows = []
    total = len(per_student_pcts)
    for label, lo, hi in bands:
        n = sum(1 for p in per_student_pcts if lo <= p < hi)
        rows.append({
            'band': label,
            'students': n,
            'share_pct': round(n / total * 100.0, 1) if total else None,
        })
    return {
        'bands': rows,
        'total_students': total,
        'below_threshold': sum(1 for p in per_student_pcts if p < required_pct),
        'at_or_above_threshold': sum(1 for p in per_student_pcts if p >= required_pct),
        'threshold_pct': round(required_pct, 2),
        'gini': round(M.gini(per_student_pcts), 4) if len(per_student_pcts) > 1 else None,
        'lorenz': M.lorenz_curve(per_student_pcts) if len(per_student_pcts) > 1 else [],
        'median_pct': round(M.median(per_student_pcts), 2) if per_student_pcts else None,
        'p10_pct': round(M.percentile(per_student_pcts, 10), 2) if per_student_pcts else None,
        'p90_pct': round(M.percentile(per_student_pcts, 90), 2) if per_student_pcts else None,
    }


def _student_row(matrix, student_id, class_obj, ctx, sessions_held, remaining_info):
    """One class row on a student's dashboard, with forecast attached."""
    cid = class_obj.id
    totals = matrix.student_totals(student_id, cid)
    series = matrix.attendance_series(student_id, cid)
    expected = totals['expected']
    pct = totals['pct']

    remaining = remaining_info.get('remaining', 0)
    ewma_val = M.ewma(series)
    # Recent behaviour is the honest input to a forecast; a lifetime average
    # under-reacts to a student who stopped attending three weeks ago.
    attend_prob = ewma_val if ewma_val is not None else (
        (pct / 100.0) if pct is not None else 0.0
    )

    pnr = F.point_of_no_return(
        totals['present'], expected, remaining, ctx.required_pct
    ) if expected or remaining else insufficient(0, 1)

    row = {
        'class_id': cid,
        'class_code': class_obj.class_code,
        'class_name': class_obj.class_name,
        'attendance_pct': round(pct, 2) if pct is not None else None,
        'present': totals['present'],
        'absent': totals['absent'],
        'pending_review': totals['pending_review'],
        'expected': expected,
        'sessions_held': sessions_held,
        'meets_threshold': (pct >= ctx.required_pct) if pct is not None else None,
        'trend_slope_per_session': (
            round(M.rolling_slope(series), 5) if M.rolling_slope(series) is not None else None
        ),
        'recent_weighted_pct': round(ewma_val * 100.0, 2) if ewma_val is not None else None,
        'volatility': round(M.volatility(series), 3) if M.volatility(series) is not None else None,
        'streaks': M.streaks(series),
        'sparkline': [round(v, 3) for v in M.ewma_series(series)][-20:],
        'series': series[-20:],
        'remaining': remaining_info,
        'forecast': pnr,
        'sessions_needed_to_recover': (
            M.min_sessions_needed(totals['present'], expected, ctx.required_pct)
            if expected else 0
        ),
        'can_miss': M.can_miss(totals['present'], expected, remaining, ctx.required_pct),
    }

    # Projection only when a remaining-session estimate actually exists.
    if remaining_info.get('source') != 'unknown' and (expected or remaining):
        row['projection'] = M.monte_carlo_forecast(
            totals['present'], expected, remaining, attend_prob, ctx.required_pct
        )
        row['projected_pct_if_perfect'] = M.projected_pct(
            totals['present'], expected, remaining, 1.0
        )
    else:
        row['projection'] = {
            'status': 'unavailable',
            'reason': remaining_info.get('note'),
        }
        row['projected_pct_if_perfect'] = None

    # Cohort position, anonymised — a rank without names.
    cohort_pcts = list(matrix.per_student_pct(cid).values())
    if len(cohort_pcts) >= MIN_SAMPLE_SIZE and pct is not None:
        row['cohort'] = {
            'percentile_rank': round(M.percentile_rank(cohort_pcts, pct), 1),
            'cohort_median_pct': round(M.median(cohort_pcts), 2),
            'cohort_size': len(cohort_pcts),
        }
    else:
        row['cohort'] = insufficient(len(cohort_pcts), MIN_SAMPLE_SIZE)

    return row


# ---------------------------------------------------------------------------
# Teacher endpoints
# ---------------------------------------------------------------------------

@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def teacher_analytics_overview(request):
    """
    Portfolio analytics for a teacher.

    Query params: class_id, term_id, threshold, from, to, days, persist.
    """
    user = request.user
    if not _is_teacher(user):
        return _forbidden('Only teachers can access teacher analytics')

    classes = resolve_teacher_classes(user, request.query_params.get('class_id'))
    class_ids = [c.id for c in classes]
    ctx = build_context(request, class_ids)

    if not classes:
        return _empty_scope(ctx, 'No classes are assigned to this account.')

    matrix = build_matrix(ctx, class_ids)
    if not matrix.has_data:
        return _empty_scope(
            ctx,
            'No concluded sessions with enrolled students exist in this window. '
            'Active sessions are excluded until they end.',
        )

    sessions = _sessions_sorted(matrix)
    cohort = matrix.cohort_totals()
    per_student = list(matrix.per_student_pct().values())

    health = H.compute_health(matrix, ctx)
    portfolio = H.portfolio_comparison(matrix, ctx, classes)

    scored = R.rank_cohort(matrix, ctx.required_pct)
    bands = R.band_distribution(scored)
    rising = R.newly_at_risk(scored, ctx.required_pct)

    weekday = P.weekday_analysis(matrix, sessions)
    slots = P.time_slot_analysis(matrix, sessions)
    heat = P.heatmap(matrix, sessions)
    timeline = P.session_timeline(matrix, sessions)
    punct = P.punctuality(matrix, sessions)

    persist = request.query_params.get('persist', '1') not in ('0', 'false', 'no')
    integrity = G.integrity_summary(matrix, class_ids, persist=persist)

    narrative = I.teacher_insights(
        health=health,
        scored=scored,
        bands=bands,
        rising=rising,
        weekday=weekday,
        slots=slots,
        punct=punct,
        integrity=integrity,
        required_pct=ctx.required_pct,
        total_students=cohort['students'],
    )

    return Response({
        'meta': ctx.meta(
            has_data=True,
            classes_in_scope=len(classes),
            flags_persisted=persist,
        ),
        'summary': {
            'attendance_pct': round(cohort['pct'], 2) if cohort['pct'] is not None else None,
            'students': cohort['students'],
            'sessions': cohort['sessions'],
            'expected_marks': cohort['expected_marks'],
            'present_marks': cohort['present_marks'],
            'absent_marks': cohort['absent_marks'],
            'pending_review_marks': cohort['pending_review_marks'],
            'below_threshold_students': sum(1 for p in per_student if p < ctx.required_pct),
            'risk_bands': bands,
            'rising_risk_count': len(rising),
            'open_integrity_flags': integrity['open_count'],
            'denominator_note': (
                'Percentages are denominated by expected marks (each enrolled '
                'student x each concluded session from their enrolment onward), '
                'not by rows that happen to exist.'
            ),
        },
        'health': health,
        'classes': portfolio,
        'distribution': _distribution(per_student, ctx.required_pct),
        'trend': {
            'sessions': timeline,
            'cohort_slope_pts_per_session': health.get('cohort_slope_pts_per_session'),
            'change_points': [r['session_id'] for r in timeline if r.get('is_change_point')],
        },
        'temporal': {
            'weekday': weekday,
            'time_slots': slots,
            'heatmap': heat,
            'punctuality': punct,
        },
        'integrity': integrity,
        'insights': narrative,
    })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def teacher_at_risk_list(request):
    """
    Students ranked by explainable risk score, plus the students who are still
    above the threshold but trending downward — the group a percentage-sorted
    list can never surface.

    Query params: class_id, limit, band, term_id, threshold, from, to, days.
    """
    user = request.user
    if not _is_teacher(user):
        return _forbidden('Only teachers can access teacher analytics')

    class_id = request.query_params.get('class_id')
    classes = resolve_teacher_classes(user, class_id)
    class_ids = [c.id for c in classes]
    ctx = build_context(request, class_ids)

    if not classes:
        return Response({'meta': ctx.meta(has_data=False), 'students': [], 'rising_risk': []})

    matrix = build_matrix(ctx, class_ids)
    scope_class = classes[0].id if (class_id not in (None, '', 'all') and classes) else None
    scored = R.rank_cohort(matrix, ctx.required_pct, class_id=scope_class)

    band = request.query_params.get('band')
    if band:
        scored = [r for r in scored if r['risk_band'] == band]

    try:
        limit = int(request.query_params.get('limit', 0))
    except (TypeError, ValueError):
        limit = 0

    rising = R.newly_at_risk(scored, ctx.required_pct)

    return Response({
        'meta': ctx.meta(has_data=matrix.has_data),
        'bands': R.band_distribution(scored),
        'weights': R.WEIGHTS,
        'scoring_note': (
            'Risk combines deficit against the requirement, recent trend, '
            'recency-weighted attendance, consecutive absences and volatility. '
            'Each student carries the component values and reasons behind the score.'
        ),
        'students': scored[:limit] if limit > 0 else scored,
        'rising_risk': rising,
        'total': len(scored),
    })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def teacher_student_detail(request, student_id):
    """
    Single-student drilldown for a teacher, restricted to that teacher's classes.

    A teacher may only see the portion of a student's record that belongs to the
    classes they own.
    """
    user = request.user
    if not _is_teacher(user):
        return _forbidden('Only teachers can access teacher analytics')

    classes = resolve_teacher_classes(user, request.query_params.get('class_id'))
    class_ids = [c.id for c in classes]
    ctx = build_context(request, class_ids)

    shared = Enrollment.objects.filter(
        student_id=student_id, class_obj_id__in=class_ids
    ).values_list('class_obj_id', flat=True)
    shared_ids = set(shared)
    if not shared_ids:
        return _forbidden('This student is not enrolled in any of your classes')

    scoped = [c for c in classes if c.id in shared_ids]
    matrix = build_matrix(ctx, [c.id for c in scoped])

    sessions_held = {c.id: len(matrix.sessions_by_class.get(c.id, ())) for c in scoped}
    remaining_by_class = F.remaining_by_class(scoped, sessions_held, ctx)

    per_class = [
        _student_row(matrix, student_id, c, ctx, sessions_held[c.id], remaining_by_class[c.id])
        for c in scoped
    ]
    overall = matrix.student_totals(student_id)
    username, full_name = matrix.student_names.get(student_id, ('', ''))

    return Response({
        'meta': ctx.meta(has_data=matrix.has_data),
        'student': {
            'student_id': student_id,
            'username': username,
            'name': full_name,
        },
        'overall': {
            'attendance_pct': round(overall['pct'], 2) if overall['pct'] is not None else None,
            'present': overall['present'],
            'absent': overall['absent'],
            'expected': overall['expected'],
            'pending_review': overall['pending_review'],
        },
        'risk': R.score_student(matrix, student_id, ctx.required_pct),
        'per_class': per_class,
        'temporal': P.student_temporal_profile(matrix, student_id),
    })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def teacher_integrity_flags(request):
    """Open integrity flags for the teacher's classes, newest first."""
    user = request.user
    if not _is_teacher(user):
        return _forbidden('Only teachers can access teacher analytics')

    classes = resolve_teacher_classes(user, request.query_params.get('class_id'))
    class_ids = [c.id for c in classes]
    ctx = build_context(request, class_ids)

    qs = AttendanceFlag.objects.filter(
        Q(class_obj_id__in=class_ids) | Q(session__class_obj_id__in=class_ids)
    ).select_related('student', 'session').order_by('-created_at')

    flag_status = request.query_params.get('status', 'open')
    if flag_status != 'all':
        qs = qs.filter(status=flag_status)

    rows = [{
        'id': f.id,
        'flag_type': f.flag_type,
        'flag_label': f.get_flag_type_display(),
        'severity': f.severity,
        'score': round(f.score, 3),
        'status': f.status,
        'student_id': f.student_id,
        'student_name': (
            f.student.get_full_name() or f.student.username if f.student_id else None
        ),
        'session_id': f.session_id,
        'class_id': f.class_obj_id,
        'evidence': f.evidence,
        'explanation': (f.evidence or {}).get('explanation'),
        'created_at': f.created_at.isoformat(),
        'resolution_note': f.resolution_note,
        'resolved_at': f.resolved_at.isoformat() if f.resolved_at else None,
    } for f in qs[:200]]

    return Response({
        'meta': ctx.meta(has_data=bool(rows)),
        'flags': rows,
        'count': len(rows),
        'note': (
            'Flags are advisory. They never alter attendance records or the '
            'percentages computed from them.'
        ),
    })


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def resolve_integrity_flag(request, flag_id):
    """
    Resolve or dismiss one flag.

    Body: {"status": "resolved"|"dismissed", "note": "..."}. Attendance data is
    untouched — only the flag's review state changes.
    """
    user = request.user
    if not _is_teacher(user):
        return _forbidden('Only teachers can resolve integrity flags')

    flag = AttendanceFlag.objects.filter(id=flag_id).select_related(
        'class_obj', 'session__class_obj'
    ).first()
    if flag is None:
        return Response({'error': 'Flag not found'}, status=status.HTTP_404_NOT_FOUND)

    owner_id = None
    if flag.class_obj_id:
        owner_id = flag.class_obj.teacher_id
    elif flag.session_id:
        owner_id = flag.session.class_obj.teacher_id
    if owner_id != user.id and not user.is_staff:
        return _forbidden('This flag belongs to another teacher\'s class')

    allowed = {c[0] for c in AttendanceFlag.STATUS_CHOICES} - {'open'}
    new_status = request.data.get('status')
    if new_status not in allowed:
        return Response(
            {'error': f'status must be one of {sorted(allowed)}'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    flag.status = new_status
    flag.resolution_note = request.data.get('note') or None
    flag.resolved_by = user
    flag.resolved_at = timezone.now()
    flag.save(update_fields=['status', 'resolution_note', 'resolved_by', 'resolved_at'])

    return Response({
        'id': flag.id,
        'status': flag.status,
        'resolution_note': flag.resolution_note,
        'resolved_at': flag.resolved_at.isoformat(),
        'resolved_by': user.username,
    })


# ---------------------------------------------------------------------------
# Student endpoints
# ---------------------------------------------------------------------------

def _student_scope(request):
    """Classes the requesting student is enrolled in, plus the resolved context."""
    class_id = request.query_params.get('class_id')
    qs = Class.objects.filter(
        enrollments__student=request.user
    ).select_related('term').distinct().order_by('class_code')
    if class_id not in (None, '', 'all'):
        qs = qs.filter(id=class_id)
    classes = list(qs)
    ctx = build_context(request, [c.id for c in classes])
    return classes, ctx


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def student_analytics_overview(request):
    """
    A student's own analytics: standing per class, what is still reachable, and
    the temporal pattern behind their absences.

    No named peer comparison is returned — only an anonymised percentile rank.
    """
    user = request.user
    if user.role != 'student':
        return _forbidden('Only students can access student analytics')

    classes, ctx = _student_scope(request)
    if not classes:
        return Response({
            'meta': ctx.meta(has_data=False),
            'reason': 'You are not enrolled in any classes yet.',
            'overall': None,
            'per_class': [],
            'insights': [],
        })

    class_ids = [c.id for c in classes]
    # Unrestricted matrix: needed for the anonymised cohort percentile. Only
    # aggregate cohort figures are ever returned to a student.
    matrix = build_matrix(ctx, class_ids)

    sessions_held = {c.id: len(matrix.sessions_by_class.get(c.id, ())) for c in classes}
    remaining_by_class = F.remaining_by_class(classes, sessions_held, ctx)

    per_class = [
        _student_row(matrix, user.id, c, ctx, sessions_held[c.id], remaining_by_class[c.id])
        for c in classes
    ]

    overall = matrix.student_totals(user.id)
    overall_series = matrix.attendance_series(user.id)
    overall_streaks = M.streaks(overall_series)
    temporal = P.student_temporal_profile(matrix, user.id)

    narrative = I.student_insights(
        per_class=per_class,
        overall_pct=round(overall['pct'], 2) if overall['pct'] is not None else None,
        required_pct=ctx.required_pct,
        temporal=temporal,
        streaks=overall_streaks,
    )

    total_remaining = sum(
        r['remaining'].get('remaining', 0) for r in per_class
        if r['remaining'].get('source') != 'unknown'
    )

    return Response({
        'meta': ctx.meta(has_data=matrix.has_data, classes_in_scope=len(classes)),
        'overall': {
            'attendance_pct': round(overall['pct'], 2) if overall['pct'] is not None else None,
            'present': overall['present'],
            'absent': overall['absent'],
            'pending_review': overall['pending_review'],
            'expected': overall['expected'],
            'meets_threshold': (
                overall['pct'] >= ctx.required_pct if overall['pct'] is not None else None
            ),
            'margin_points': (
                round(overall['pct'] - ctx.required_pct, 2)
                if overall['pct'] is not None else None
            ),
            'streaks': overall_streaks,
            'recent_weighted_pct': (
                round(M.ewma(overall_series) * 100.0, 2)
                if M.ewma(overall_series) is not None else None
            ),
            'trend_slope_per_session': (
                round(M.rolling_slope(overall_series), 5)
                if M.rolling_slope(overall_series) is not None else None
            ),
            'sparkline': [round(v, 3) for v in M.ewma_series(overall_series)][-30:],
            'classes_below_threshold': sum(
                1 for r in per_class if r['meets_threshold'] is False
            ),
            'remaining_sessions_estimated': total_remaining,
        },
        'per_class': per_class,
        'temporal': temporal,
        'insights': narrative,
    })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def student_calendar_data(request):
    """
    Day-by-day attendance for the calendar view.

    Absences are derived from expected sessions, so a session a student never
    interacted with still appears as a miss instead of silently vanishing.
    """
    user = request.user
    if user.role != 'student':
        return _forbidden('Only students can access student analytics')

    classes, ctx = _student_scope(request)
    if not classes:
        return Response({'meta': ctx.meta(has_data=False), 'days': [], 'totals': None})

    matrix = build_matrix(ctx, [c.id for c in classes], student_ids=[user.id])

    by_date = {}
    for s in matrix.expected_sessions_for(user.id):
        mark = matrix.mark(user.id, s.id)
        if mark is None:
            state = 'absent'
        elif mark.is_present:
            state = 'present'
        else:
            state = mark.status
        day = s.local_date.isoformat()
        bucket = by_date.setdefault(day, {'date': day, 'sessions': [], 'present': 0, 'total': 0})
        bucket['sessions'].append({
            'session_id': s.id,
            'class_id': s.class_id,
            'class_code': s.class_code,
            'class_name': s.class_name,
            'start_time': s.start_time.isoformat(),
            'duration_minutes': s.duration_minutes,
            'status': state,
            'latency_seconds': (
                round(mark.latency_seconds, 1)
                if mark and mark.latency_seconds is not None else None
            ),
            'verification_score': mark.verification_score if mark else None,
        })
        bucket['total'] += 1
        if state == 'present':
            bucket['present'] += 1

    days = []
    for day in sorted(by_date):
        b = by_date[day]
        b['attendance_pct'] = round(M.safe_pct(b['present'], b['total']), 1)
        b['day_status'] = (
            'present' if b['present'] == b['total']
            else 'absent' if b['present'] == 0
            else 'partial'
        )
        days.append(b)

    totals = matrix.student_totals(user.id)
    return Response({
        'meta': ctx.meta(has_data=bool(days)),
        'days': days,
        'totals': {
            'attendance_pct': round(totals['pct'], 2) if totals['pct'] is not None else None,
            'present': totals['present'],
            'absent': totals['absent'],
            'pending_review': totals['pending_review'],
            'expected': totals['expected'],
            'days_recorded': len(days),
        },
    })


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def student_forecast_simulator(request):
    """
    "What if I attend X% of what's left?"

    Params: class_id (optional), attend_pct (0-100, defaults to the student's own
    recent-weighted rate). Returns the arithmetic outcome and a seeded Monte
    Carlo distribution, or an explicit unavailable marker when the number of
    remaining sessions cannot be established.
    """
    user = request.user
    if user.role != 'student':
        return _forbidden('Only students can access student analytics')

    classes, ctx = _student_scope(request)
    if not classes:
        return Response({'meta': ctx.meta(has_data=False), 'scenarios': []})

    class_ids = [c.id for c in classes]
    matrix = build_matrix(ctx, class_ids, student_ids=[user.id])
    sessions_held = {c.id: len(matrix.sessions_by_class.get(c.id, ())) for c in classes}
    remaining_by_class = F.remaining_by_class(classes, sessions_held, ctx)

    raw = request.query_params.get('attend_pct')
    override = None
    if raw is not None:
        try:
            override = min(1.0, max(0.0, float(raw) / 100.0))
        except (TypeError, ValueError):
            override = None

    scenarios = []
    for c in classes:
        totals = matrix.student_totals(user.id, c.id)
        series = matrix.attendance_series(user.id, c.id)
        info = remaining_by_class[c.id]
        remaining = info.get('remaining', 0)

        if info.get('source') == 'unknown':
            scenarios.append({
                'class_id': c.id,
                'class_code': c.class_code,
                'status': 'unavailable',
                'reason': info.get('note'),
            })
            continue

        ewma_val = M.ewma(series)
        base = override if override is not None else (
            ewma_val if ewma_val is not None
            else ((totals['pct'] or 0.0) / 100.0)
        )

        scenarios.append({
            'class_id': c.id,
            'class_code': c.class_code,
            'status': 'ok',
            'current_pct': round(totals['pct'], 2) if totals['pct'] is not None else None,
            'present': totals['present'],
            'expected': totals['expected'],
            'remaining': info,
            'attend_rate_used': round(base, 4),
            'attend_rate_source': 'override' if override is not None else 'recent_weighted',
            'projected_pct': (
                round(M.projected_pct(totals['present'], totals['expected'], remaining, base), 2)
                if M.projected_pct(totals['present'], totals['expected'], remaining, base) is not None
                else None
            ),
            'projected_pct_if_perfect': (
                round(M.projected_pct(totals['present'], totals['expected'], remaining, 1.0), 2)
                if M.projected_pct(totals['present'], totals['expected'], remaining, 1.0) is not None
                else None
            ),
            'distribution': M.monte_carlo_forecast(
                totals['present'], totals['expected'], remaining, base, ctx.required_pct
            ),
            'can_miss': M.can_miss(
                totals['present'], totals['expected'], remaining, ctx.required_pct
            ),
            'point_of_no_return': F.point_of_no_return(
                totals['present'], totals['expected'], remaining, ctx.required_pct
            ),
        })

    return Response({
        'meta': ctx.meta(has_data=matrix.has_data),
        'scenarios': scenarios,
        'note': (
            'Simulations are seeded, so identical inputs always produce identical '
            'output. Where remaining sessions are inferred from observed cadence, '
            'the confidence field says so.'
        ),
    })

"""
Class Health Score — one number a teacher can act on, with its parts shown.

A mean attendance percentage is a bad summary: 82% could be a uniformly healthy
cohort or 90% of students at 95% masking 10% at 20%. The health score folds in
four independent dimensions so those two cases separate:

    coverage     0.40  what share of expected marks actually happened
    equity       0.25  how evenly attendance is distributed (1 - Gini)
    momentum     0.20  which way the cohort is moving right now
    consistency  0.15  how tightly students cluster around the mean

Components are always returned alongside the total. A score with no breakdown is
not actionable, and this dashboard's whole premise is that every number can be
challenged and traced.
"""
from typing import Dict, List, Optional

from . import metrics as M

WEIGHTS = {
    'coverage': 0.40,
    'equity': 0.25,
    'momentum': 0.20,
    'consistency': 0.15,
}

GRADES = (
    (85.0, 'A', 'Healthy'),
    (70.0, 'B', 'Stable'),
    (55.0, 'C', 'Needs attention'),
    (40.0, 'D', 'At risk'),
    (0.0, 'F', 'Critical'),
)

MIN_SESSIONS_FOR_SCORE = 3


def _grade(score: float):
    for floor, letter, label in GRADES:
        if score >= floor:
            return letter, label
    return 'F', 'Critical'


def _momentum_score(session_pcts: List[float]) -> tuple:
    """
    Cohort direction, mapped to 0..100 with 50 = flat.

    Slope is in percentage points per session; +/-2 pts/session is treated as the
    practical extreme, so a class improving 1 pt/session scores 75.
    """
    if len(session_pcts) < 2:
        return None, None
    slope = M.rolling_slope(session_pcts)
    if slope is None:
        return None, None
    scaled = 50.0 + (slope / 2.0) * 50.0
    return max(0.0, min(100.0, scaled)), slope


def compute_health(matrix, ctx, class_id: Optional[int] = None) -> dict:
    """
    Health score for one class (or the whole portfolio when class_id is None).

    Returns `status: insufficient_data` rather than a number when there is too
    little history to say anything honest.
    """
    cohort = matrix.cohort_totals(class_id)
    sessions = (
        matrix.sessions_by_class.get(class_id, [])
        if class_id is not None else
        sorted(matrix.sessions.values(), key=lambda s: s.start_time)
    )

    if len(sessions) < MIN_SESSIONS_FOR_SCORE:
        return {
            'status': 'insufficient_data',
            'required_n': MIN_SESSIONS_FOR_SCORE,
            'actual_n': len(sessions),
            'message': (
                f'{len(sessions)} session(s) recorded. A health score needs at least '
                f'{MIN_SESSIONS_FOR_SCORE} to avoid reading noise as signal.'
            ),
        }

    # --- coverage ---------------------------------------------------------
    coverage = cohort['pct']
    if coverage is None:
        return {
            'status': 'insufficient_data',
            'required_n': 1,
            'actual_n': 0,
            'message': 'No enrolled students with expected sessions in this window.',
        }

    # --- equity -----------------------------------------------------------
    per_student = list(matrix.per_student_pct(class_id).values())
    g = M.gini(per_student)
    equity = (1.0 - g) * 100.0 if g is not None else None

    # --- momentum ---------------------------------------------------------
    session_pcts = []
    for s in sessions:
        t = matrix.session_totals(s)
        if t['pct'] is not None:
            session_pcts.append(t['pct'])
    momentum, slope = _momentum_score(session_pcts)

    # --- consistency ------------------------------------------------------
    consistency = M.normalised_consistency(per_student)

    components = {
        'coverage': coverage,
        'equity': equity,
        'momentum': momentum,
        'consistency': consistency,
    }

    # Renormalise over available components so a missing dimension does not
    # silently drag the score down.
    available = {k: v for k, v in components.items() if v is not None}
    weight_sum = sum(WEIGHTS[k] for k in available) or 1.0
    total = sum(available[k] * WEIGHTS[k] for k in available) / weight_sum

    letter, label = _grade(total)

    return {
        'status': 'ok',
        'score': round(total, 1),
        'grade': letter,
        'grade_label': label,
        'components': {k: (round(v, 1) if v is not None else None) for k, v in components.items()},
        'weights': WEIGHTS,
        'component_meanings': {
            'coverage': 'Share of expected attendance marks that actually happened',
            'equity': 'How evenly attendance is spread across students (100 = perfectly even)',
            'momentum': 'Recent direction of cohort attendance (50 = flat)',
            'consistency': 'How tightly students cluster around the class average',
        },
        'gini': round(g, 4) if g is not None else None,
        'cohort_slope_pts_per_session': round(slope, 3) if slope else None,
        'students': cohort['students'],
        'sessions': len(sessions),
        'expected_marks': cohort['expected_marks'],
        'present_marks': cohort['present_marks'],
        'below_threshold_count': sum(1 for p in per_student if p < ctx.required_pct),
        'interpretation': _interpret(total, components, ctx.required_pct, per_student),
    }


def _interpret(total: float, components: dict, required: float, per_student: List[float]) -> str:
    """
    One sentence naming the binding constraint.

    Deliberately singular: telling a teacher four things at once tells them nothing.
    """
    below = sum(1 for p in per_student if p < required)
    n = len(per_student)
    equity = components.get('equity')
    momentum = components.get('momentum')
    coverage = components.get('coverage')

    if equity is not None and equity < 60 and below:
        return (
            f'Attendance is unevenly distributed — {below} of {n} students are below '
            f'{required:g}%, while the class average is held up by regular attenders. '
            f'Target the tail rather than the whole class.'
        )
    if momentum is not None and momentum < 35:
        return (
            'Cohort attendance is trending downward over recent sessions. '
            'The decline is recent, so the cause is likely recent too.'
        )
    if coverage is not None and coverage < required:
        return (
            f'Average attendance ({coverage:.1f}%) is below the {required:g}% requirement '
            f'across the whole cohort, not just a subset.'
        )
    if total >= 85:
        return 'Attendance is healthy and evenly distributed, with no concerning trend.'
    return (
        f'Overall attendance is acceptable; {below} of {n} students are below '
        f'{required:g}% and are the main lever for improvement.'
    )


def portfolio_comparison(matrix, ctx, classes) -> List[dict]:
    """
    Every class scored and z-ranked against the teacher's own portfolio.

    Absolute percentages across different subjects are not comparable; standing
    relative to the teacher's own classes is. This is what makes "which class
    needs me most this week" answerable.
    """
    rows = []
    for c in classes:
        h = compute_health(matrix, ctx, c.id)
        cohort = matrix.cohort_totals(c.id)
        rows.append({
            'class_id': c.id,
            'class_code': c.class_code,
            'class_name': c.class_name,
            'health': h,
            'attendance_pct': round(cohort['pct'], 2) if cohort['pct'] is not None else None,
            'students': cohort['students'],
            'sessions': cohort['sessions'],
        })

    scored = [r for r in rows if r['health'].get('status') == 'ok']
    if len(scored) >= 2:
        vals = [r['health']['score'] for r in scored]
        zs = M.z_scores(vals)
        for r, z in zip(scored, zs):
            r['portfolio_z'] = round(z, 2) if z is not None else None
            r['portfolio_standing'] = (
                'strongest' if z is not None and z > 1 else
                'weakest' if z is not None and z < -1 else
                'typical'
            )
    else:
        for r in rows:
            r['portfolio_z'] = None
            r['portfolio_standing'] = 'insufficient_classes'

    rows.sort(key=lambda r: r['health'].get('score', -1))
    return rows

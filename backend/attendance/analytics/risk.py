"""
Student risk scoring — the explainable core of the early-warning system.

Design constraints that drove this:

1. A single percentage cannot rank students. Two students at 74% are not equally
   at risk: one is climbing after illness, the other has missed the last five in
   a row. The old dashboard sorted by percentage and therefore surfaced the wrong
   students first.

2. Any score shown to a teacher must be defensible. A bare "risk: 82" invites
   "based on what?" So every score carries its component breakdown, and every
   component carries a plain-language reason string. Nothing is a black box.

3. Sparse data must not manufacture confidence. A student with two sessions on
   record gets a `confidence` of 'low' and is never presented as a firm prediction.

Components (weights sum to 1.0):
    deficit     0.35  distance below the required threshold
    trend       0.25  recent slope — is it getting worse right now
    recency     0.20  EWMA-weighted recent attendance
    streak      0.10  length of the current consecutive-absence run
    volatility  0.10  erratic attendance predicts future misses
"""
from typing import Dict, List, Optional

from . import metrics as M

WEIGHTS = {
    'deficit': 0.35,
    'trend': 0.25,
    'recency': 0.20,
    'streak': 0.10,
    'volatility': 0.10,
}

# Risk bands. Deliberately not "traffic light on percentage" — a student above
# threshold with a steep negative slope can still land in 'watch'.
BANDS = (
    (75.0, 'critical'),
    (55.0, 'high'),
    (35.0, 'watch'),
    (0.0, 'stable'),
)

# Below this many expected sessions we mark the score low-confidence.
CONFIDENCE_MIN_SESSIONS = 5


def _band(score: float) -> str:
    for floor, name in BANDS:
        if score >= floor:
            return name
    return 'stable'


def _deficit_component(pct: Optional[float], required: float) -> tuple:
    """How far below the requirement, scaled so `required` points below = 100."""
    if pct is None:
        return 0.0, None
    gap = required - pct
    if gap <= 0:
        return 0.0, None
    score = min(100.0, gap / required * 100.0)
    return score, f'{gap:.1f} points below the {required:g}% requirement'


def _trend_component(slope: Optional[float]) -> tuple:
    """
    Negative slope -> risk. -0.1/session (one extra miss every ten) maps to 100.
    """
    if slope is None:
        return 0.0, None
    if slope >= 0:
        return 0.0, None
    score = min(100.0, abs(slope) / 0.10 * 100.0)
    if score < 20:
        return score, None
    return score, f'attendance declining {abs(slope) * 100:.1f}% per session recently'


def _recency_component(ewma_val: Optional[float], required: float) -> tuple:
    """Recent-weighted attendance below requirement, ignoring older history."""
    if ewma_val is None:
        return 0.0, None
    recent_pct = ewma_val * 100.0
    gap = required - recent_pct
    if gap <= 0:
        return 0.0, None
    score = min(100.0, gap / required * 100.0)
    return score, f'recent attendance ~{recent_pct:.0f}%, weighted toward the latest sessions'


def _streak_component(absent_streak: int) -> tuple:
    """Consecutive absences. 4 in a row saturates the component."""
    if absent_streak <= 0:
        return 0.0, None
    score = min(100.0, absent_streak / 4.0 * 100.0)
    if absent_streak == 1:
        return score, None
    return score, f'{absent_streak} consecutive sessions missed'


def _volatility_component(vol: Optional[float]) -> tuple:
    """Erratic attendance is itself a warning sign, independent of the average."""
    if vol is None:
        return 0.0, None
    score = min(100.0, vol * 100.0)
    if score < 40:
        return score, None
    return score, 'irregular attendance pattern (frequently alternating)'


def score_student(
    matrix,
    student_id: int,
    required_pct: float,
    class_id: Optional[int] = None,
) -> dict:
    """
    Full explainable risk profile for one student.

    Every number returned is derived from the dense matrix, so a student with no
    records at all scores correctly instead of being skipped.
    """
    totals = matrix.student_totals(student_id, class_id)
    series = matrix.attendance_series(student_id, class_id)
    expected = totals['expected']

    pct = totals['pct']
    slope = M.rolling_slope(series)
    ewma_val = M.ewma(series)
    vol = M.volatility(series)
    st = M.streaks(series)

    components: Dict[str, float] = {}
    reasons: List[str] = []
    for key, (value, reason) in {
        'deficit': _deficit_component(pct, required_pct),
        'trend': _trend_component(slope),
        'recency': _recency_component(ewma_val, required_pct),
        'streak': _streak_component(st['current_absent']),
        'volatility': _volatility_component(vol),
    }.items():
        components[key] = round(value, 2)
        if reason:
            reasons.append(reason)

    total = sum(components[k] * w for k, w in WEIGHTS.items())

    if expected == 0:
        confidence = 'none'
    elif expected < CONFIDENCE_MIN_SESSIONS:
        confidence = 'low'
    elif expected < 2 * CONFIDENCE_MIN_SESSIONS:
        confidence = 'medium'
    else:
        confidence = 'high'

    username, full_name = matrix.student_names.get(student_id, ('', ''))

    return {
        'student_id': student_id,
        'username': username,
        'name': full_name,
        'attendance_pct': round(pct, 2) if pct is not None else None,
        'present': totals['present'],
        'expected': expected,
        'absent': totals['absent'],
        'risk_score': round(total, 2),
        'risk_band': _band(total),
        'components': components,
        'weights': WEIGHTS,
        'reasons': reasons or ['no risk indicators detected'],
        'confidence': confidence,
        'trend_slope_per_session': round(slope, 5) if slope is not None else None,
        'recent_weighted_pct': round(ewma_val * 100.0, 2) if ewma_val is not None else None,
        'volatility': round(vol, 3) if vol is not None else None,
        'current_absent_streak': st['current_absent'],
        'current_present_streak': st['current_present'],
        'longest_absent_streak': st['worst_absent'],
        'sparkline': [round(v, 3) for v in M.ewma_series(series)][-20:],
        'series': series[-20:],
    }


def rank_cohort(
    matrix,
    required_pct: float,
    class_id: Optional[int] = None,
    limit: Optional[int] = None,
) -> List[dict]:
    """All students scored and ordered by risk, highest first."""
    ids = matrix.students_in_class(class_id) if class_id is not None else matrix.student_ids
    out = [score_student(matrix, sid, required_pct, class_id) for sid in ids]
    out.sort(key=lambda r: (-r['risk_score'], r['attendance_pct'] if r['attendance_pct'] is not None else 0))
    return out[:limit] if limit else out


def band_distribution(scored: List[dict]) -> dict:
    """Counts per risk band, for the cohort summary strip."""
    dist = {'critical': 0, 'high': 0, 'watch': 0, 'stable': 0}
    for row in scored:
        dist[row['risk_band']] = dist.get(row['risk_band'], 0) + 1
    return dist


def newly_at_risk(scored: List[dict], required_pct: float) -> List[dict]:
    """
    Students still at or above the threshold but trending hard downward.

    This is the group a percentage-sorted list can never surface, and the group
    where intervention is cheapest — they have not failed yet. The slope cut-off
    of -0.02/session is roughly "one extra absence every fifty sessions and
    worsening"; combined with the band filter it stays a short, actionable list.
    """
    out = []
    for row in scored:
        pct = row['attendance_pct']
        slope = row['trend_slope_per_session']
        if pct is None or slope is None:
            continue
        if pct < required_pct:
            continue  # already failing — handled by the at-risk list, not this one
        if slope < -0.02 and row['risk_band'] != 'stable':
            out.append(row)
    out.sort(key=lambda r: r['trend_slope_per_session'])
    return out



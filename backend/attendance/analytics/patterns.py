"""
Temporal pattern analysis — when attendance fails, not just how much.

The old implementation produced a weekday x time-slot heatmap by generating
random-ish values from a base rate, and labelled cells "worst" purely on the
lowest number regardless of whether it came from one session or thirty. That is
worse than showing nothing: it invites a teacher to move a class based on noise.

Everything here is computed from real sessions, and every claim is gated by a
two-proportion z-test against the rest of the data. Cells that fail the test are
returned with `significant: False` so the UI can grey them out rather than
inviting a decision.
"""
from collections import defaultdict
from typing import Dict, List, Optional

from . import metrics as M

WEEKDAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']

# Time-of-day buckets. Coarse on purpose: hourly buckets across a term give cells
# with two sessions each, which no test can call significant.
TIME_SLOTS = [
    ('early_morning', 0, 9, 'Before 9am'),
    ('morning', 9, 12, '9am - 12pm'),
    ('afternoon', 12, 15, '12pm - 3pm'),
    ('late_afternoon', 15, 18, '3pm - 6pm'),
    ('evening', 18, 24, 'After 6pm'),
]

MIN_SESSIONS_PER_CELL = 3


def _slot_for_hour(hour: int) -> str:
    for key, lo, hi, _label in TIME_SLOTS:
        if lo <= hour < hi:
            return key
    return 'evening'


def _bucket(matrix, sessions, key_fn) -> Dict[object, dict]:
    """Aggregate present/expected marks and session count per bucket."""
    buckets: Dict[object, dict] = defaultdict(
        lambda: {'present': 0, 'expected': 0, 'sessions': 0, 'latencies': []}
    )
    for s in sessions:
        t = matrix.session_totals(s)
        if t['expected'] == 0:
            continue
        b = buckets[key_fn(s)]
        b['present'] += t['present']
        b['expected'] += t['expected']
        b['sessions'] += 1
        b['latencies'].extend(t['latencies'])
    return buckets


def _significance_vs_rest(buckets: Dict[object, dict], key) -> Optional[dict]:
    """Test one bucket's attendance rate against the pooled remainder."""
    cell = buckets[key]
    rest_present = sum(b['present'] for k, b in buckets.items() if k != key)
    rest_expected = sum(b['expected'] for k, b in buckets.items() if k != key)
    if rest_expected == 0 or cell['expected'] == 0:
        return None
    return M.two_proportion_z(cell['present'], cell['expected'], rest_present, rest_expected)


def weekday_analysis(matrix, sessions) -> dict:
    """Attendance by day of week, with significance and explicit sparse cells."""
    buckets = _bucket(matrix, sessions, lambda s: s.weekday)
    rows = []
    for wd in range(7):
        if wd not in buckets:
            continue
        b = buckets[wd]
        pct = M.safe_pct(b['present'], b['expected'])
        sig = _significance_vs_rest(buckets, wd) if b['sessions'] >= MIN_SESSIONS_PER_CELL else None
        rows.append({
            'weekday': wd,
            'label': WEEKDAY_NAMES[wd],
            'attendance_pct': round(pct, 2) if pct is not None else None,
            'sessions': b['sessions'],
            'expected_marks': b['expected'],
            'present_marks': b['present'],
            'median_latency_seconds': round(M.median(b['latencies']), 1) if b['latencies'] else None,
            'sufficient_data': b['sessions'] >= MIN_SESSIONS_PER_CELL,
            'significant': bool(sig and sig['significant']),
            'p_value': sig['p_value'] if sig else None,
            'delta_vs_rest_pct': sig['delta_pct'] if sig else None,
        })

    significant = [r for r in rows if r['significant'] and (r['delta_vs_rest_pct'] or 0) < 0]
    worst = min(significant, key=lambda r: r['attendance_pct']) if significant else None

    return {
        'rows': rows,
        'min_sessions_per_cell': MIN_SESSIONS_PER_CELL,
        'worst_significant_day': worst['label'] if worst else None,
        'finding': (
            f"{worst['label']} attendance is {abs(worst['delta_vs_rest_pct']):.1f} points below "
            f"other days (p={worst['p_value']}, {worst['sessions']} sessions) — a real effect, "
            f"not sampling noise."
            if worst else
            'No day of the week shows a statistically significant attendance difference.'
        ),
    }


def time_slot_analysis(matrix, sessions) -> dict:
    """Attendance by time of day, same significance gating as weekdays."""
    buckets = _bucket(matrix, sessions, lambda s: _slot_for_hour(s.hour))
    labels = {k: label for k, _lo, _hi, label in TIME_SLOTS}
    rows = []
    for key, _lo, _hi, label in TIME_SLOTS:
        if key not in buckets:
            continue
        b = buckets[key]
        pct = M.safe_pct(b['present'], b['expected'])
        sig = _significance_vs_rest(buckets, key) if b['sessions'] >= MIN_SESSIONS_PER_CELL else None
        rows.append({
            'slot': key,
            'label': label,
            'attendance_pct': round(pct, 2) if pct is not None else None,
            'sessions': b['sessions'],
            'expected_marks': b['expected'],
            'present_marks': b['present'],
            'median_latency_seconds': round(M.median(b['latencies']), 1) if b['latencies'] else None,
            'sufficient_data': b['sessions'] >= MIN_SESSIONS_PER_CELL,
            'significant': bool(sig and sig['significant']),
            'p_value': sig['p_value'] if sig else None,
            'delta_vs_rest_pct': sig['delta_pct'] if sig else None,
        })

    significant = [r for r in rows if r['significant'] and (r['delta_vs_rest_pct'] or 0) < 0]
    worst = min(significant, key=lambda r: r['attendance_pct']) if significant else None

    return {
        'rows': rows,
        'worst_significant_slot': worst['label'] if worst else None,
        'finding': (
            f"Sessions {worst['label'].lower()} run {abs(worst['delta_vs_rest_pct']):.1f} points "
            f"below other times (p={worst['p_value']})."
            if worst else
            'No time of day shows a statistically significant attendance difference.'
        ),
    }


def heatmap(matrix, sessions) -> dict:
    """
    Weekday x time-slot grid built from real sessions only.

    Cells with fewer than MIN_SESSIONS_PER_CELL sessions carry
    `sufficient_data: False` and a null percentage — the UI must render those as
    "no data", never as a low score. Empty cells are omitted entirely rather than
    filled with a plausible-looking number.
    """
    grid = defaultdict(lambda: {'present': 0, 'expected': 0, 'sessions': 0})
    for s in sessions:
        t = matrix.session_totals(s)
        if t['expected'] == 0:
            continue
        cell = grid[(s.weekday, _slot_for_hour(s.hour))]
        cell['present'] += t['present']
        cell['expected'] += t['expected']
        cell['sessions'] += 1

    cells = []
    for (wd, slot), c in grid.items():
        pct = M.safe_pct(c['present'], c['expected'])
        ok = c['sessions'] >= MIN_SESSIONS_PER_CELL
        cells.append({
            'weekday': wd,
            'weekday_label': WEEKDAY_NAMES[wd],
            'slot': slot,
            'attendance_pct': round(pct, 2) if (pct is not None and ok) else None,
            'raw_pct': round(pct, 2) if pct is not None else None,
            'sessions': c['sessions'],
            'expected_marks': c['expected'],
            'sufficient_data': ok,
        })

    cells.sort(key=lambda c: (c['weekday'], c['slot']))
    return {
        'cells': cells,
        'slots': [{'key': k, 'label': lbl} for k, _lo, _hi, lbl in TIME_SLOTS],
        'weekdays': [{'index': i, 'label': n} for i, n in enumerate(WEEKDAY_NAMES)],
        'min_sessions_per_cell': MIN_SESSIONS_PER_CELL,
        'note': (
            'Cells with fewer than '
            f'{MIN_SESSIONS_PER_CELL} sessions are shown as insufficient data rather '
            'than as a low score.'
        ),
    }


def session_timeline(matrix, sessions, limit: int = 60) -> List[dict]:
    """Per-session turnout series with CUSUM-detected level shifts marked."""
    ordered = sorted(sessions, key=lambda s: s.start_time)[-limit:]
    rows = []
    pcts = []
    for s in ordered:
        t = matrix.session_totals(s)
        if t['pct'] is None:
            continue
        pcts.append(t['pct'])
        rows.append({
            'session_id': s.id,
            'date': s.local_date.isoformat(),
            'class_code': s.class_code,
            'weekday': WEEKDAY_NAMES[s.weekday],
            'attendance_pct': round(t['pct'], 2),
            'present': t['present'],
            'expected': t['expected'],
            'median_latency_seconds': round(M.median(t['latencies']), 1) if t['latencies'] else None,
            'is_change_point': False,
        })

    for idx in M.cusum_change_points(pcts):
        if 0 <= idx < len(rows):
            rows[idx]['is_change_point'] = True
    return rows


def punctuality(matrix, sessions) -> dict:
    """
    How late students mark, distributionally.

    Median plus P90 rather than a mean: attendance latency is heavily right-skewed
    (a handful of very late marks would drag a mean into meaninglessness). A rising
    P90 with a flat median means a specific subgroup is drifting late, which is a
    different problem from the whole class arriving later.
    """
    all_lat: List[float] = []
    for s in sessions:
        all_lat.extend(matrix.session_totals(s)['latencies'])

    if len(all_lat) < M.SLOPE_WINDOW:
        return {
            'status': 'insufficient_data',
            'required_n': M.SLOPE_WINDOW,
            'actual_n': len(all_lat),
        }

    on_time = sum(1 for l in all_lat if l <= 300)      # within 5 minutes
    late = sum(1 for l in all_lat if 300 < l <= 900)   # 5-15 minutes
    very_late = sum(1 for l in all_lat if l > 900)     # beyond 15 minutes

    return {
        'status': 'ok',
        'median_seconds': round(M.median(all_lat), 1),
        'p90_seconds': round(M.percentile(all_lat, 90), 1),
        'p10_seconds': round(M.percentile(all_lat, 10), 1),
        'marks_analysed': len(all_lat),
        'buckets': [
            {'label': 'Within 5 min', 'count': on_time,
             'pct': round(on_time / len(all_lat) * 100, 1)},
            {'label': '5-15 min', 'count': late,
             'pct': round(late / len(all_lat) * 100, 1)},
            {'label': 'Over 15 min', 'count': very_late,
             'pct': round(very_late / len(all_lat) * 100, 1)},
        ],
        'finding': (
            f'Half of all marks land within {M.median(all_lat) / 60:.1f} minutes of session start; '
            f'the slowest 10% take over {M.percentile(all_lat, 90) / 60:.1f} minutes.'
        ),
    }


def student_temporal_profile(matrix, student_id: int) -> dict:
    """
    One student's own weekday pattern — "you miss Fridays" as a checkable claim.

    Uses the same significance gate as the cohort view, so a student is never told
    they have a Friday problem on the basis of two Fridays.
    """
    sessions = matrix.expected_sessions_for(student_id)
    buckets = defaultdict(lambda: {'present': 0, 'total': 0})
    for s in sessions:
        b = buckets[s.weekday]
        b['total'] += 1
        if matrix.is_present(student_id, s.id):
            b['present'] += 1

    rows = []
    for wd in sorted(buckets):
        b = buckets[wd]
        rest_p = sum(v['present'] for k, v in buckets.items() if k != wd)
        rest_t = sum(v['total'] for k, v in buckets.items() if k != wd)
        sig = (
            M.two_proportion_z(b['present'], b['total'], rest_p, rest_t)
            if b['total'] >= MIN_SESSIONS_PER_CELL and rest_t > 0 else None
        )
        rows.append({
            'weekday': wd,
            'label': WEEKDAY_NAMES[wd],
            'attendance_pct': round(M.safe_pct(b['present'], b['total']), 2) if b['total'] else None,
            'sessions': b['total'],
            'sufficient_data': b['total'] >= MIN_SESSIONS_PER_CELL,
            'significant': bool(sig and sig['significant']),
            'p_value': sig['p_value'] if sig else None,
        })

    weak = [r for r in rows if r['significant'] and r['attendance_pct'] is not None]
    weak.sort(key=lambda r: r['attendance_pct'])
    worst = weak[0] if weak else None

    return {
        'rows': rows,
        'finding': (
            f"{worst['label']} is this student's weakest day "
            f"({worst['attendance_pct']:.0f}% across {worst['sessions']} sessions, p={worst['p_value']})."
            if worst else
            'No single day stands out — absences are spread evenly across the week.'
        ),
    }

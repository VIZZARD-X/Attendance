"""
Attendance integrity detection.

Purpose: separate "this student did not attend" from "this mark may not be real".
Both look identical in a percentage, and only one of them is a discipline issue.

Every detector here follows the same three rules:

1. **Evidence, not verdicts.** Each flag carries an `evidence` dict containing the
   exact counts, timestamps and deltas that triggered it. A teacher must be able
   to disagree with the system and see why it fired.
2. **Relative thresholds, not absolute ones.** "Verification score below 0.5" is
   meaningless when one class runs at 0.9 and another at 0.55. Detectors compare
   against the class's own distribution (median / MAD, IQR) so a flag means
   "unusual *here*".
3. **Persisted and resolvable.** Flags are written to `AttendanceFlag` and
   deduplicated, so a dismissal survives the next dashboard load.

Nothing here modifies attendance records. Integrity findings never silently alter
a student's percentage — they surface for human judgement.
"""
from collections import defaultdict
from typing import Dict, List, Optional

from django.db.models import Q

from ..models import AttendanceFlag, AttendanceRecord
from . import metrics as M

# A cluster of marks inside this window, from distinct students, is suspicious:
# device-sharing and proxy marking produce tight bursts that natural arrival does not.
BURST_WINDOW_SECONDS = 20
BURST_MIN_STUDENTS = 4

# Robust outlier cut-off in median-absolute-deviations. 3.5 is the conventional
# modified-z threshold; unlike a standard-deviation rule it is not distorted by
# the very outliers it is looking for.
MAD_THRESHOLD = 3.5

# Verification scores this far below the class median are flagged.
VERIFICATION_MAD_THRESHOLD = 3.0

MIN_SAMPLES_FOR_OUTLIERS = 8


def _mad(values: List[float]) -> Optional[float]:
    """Median absolute deviation — a breakdown-resistant spread measure."""
    if not values:
        return None
    med = M.median(values)
    return M.median([abs(v - med) for v in values])


def _modified_z(value: float, med: float, mad: float) -> float:
    """0.6745 rescales MAD to be comparable with a standard deviation."""
    if mad == 0:
        return 0.0
    return 0.6745 * (value - med) / mad


def detect_burst_marking(matrix) -> List[dict]:
    """
    Clusters of distinct students marking within seconds of each other.

    A legitimate class trickles in over minutes. Four or more different students
    marking inside a 20-second window is the signature of one device being passed
    around — or one person marking for several.
    """
    by_session: Dict[int, List[tuple]] = defaultdict(list)
    for (student_id, session_id), mark in matrix.marks.items():
        if mark.marked_at is not None:
            by_session[session_id].append((mark.marked_at, student_id))

    findings = []
    for session_id, entries in by_session.items():
        entries.sort()
        n = len(entries)
        i = 0
        while i < n:
            j = i
            students = []
            while j < n and (entries[j][0] - entries[i][0]).total_seconds() <= BURST_WINDOW_SECONDS:
                students.append(entries[j][1])
                j += 1
            unique = set(students)
            if len(unique) >= BURST_MIN_STUDENTS:
                info = matrix.sessions.get(session_id)
                span = (entries[j - 1][0] - entries[i][0]).total_seconds()
                findings.append({
                    'flag_type': 'burst_marking',
                    'session_id': session_id,
                    'class_id': info.class_id if info else None,
                    'student_id': None,
                    'severity': 'critical' if len(unique) >= BURST_MIN_STUDENTS + 3 else 'warning',
                    # Scale confidence with cluster size; 10 students saturates it.
                    'score': min(1.0, len(unique) / 10.0),
                    'evidence': {
                        'student_count': len(unique),
                        'window_seconds': round(span, 1),
                        'threshold_window_seconds': BURST_WINDOW_SECONDS,
                        'threshold_students': BURST_MIN_STUDENTS,
                        'first_mark': entries[i][0].isoformat(),
                        'last_mark': entries[j - 1][0].isoformat(),
                        'student_ids': sorted(unique),
                    },
                    'explanation': (
                        f'{len(unique)} different students marked attendance within '
                        f'{span:.0f} seconds. Natural arrival is spread out; this pattern '
                        f'is consistent with a shared device or proxy marking.'
                    ),
                })
                i = j
            else:
                i += 1
    return findings


def detect_low_verification(matrix) -> List[dict]:
    """
    Verification scores that are outliers *for this class*.

    An absolute cut-off would flag an entire strict class and nothing in a lenient
    one. Comparing each mark against the class median via modified z-score makes
    the flag mean "unusual relative to how this class normally verifies".
    """
    by_class: Dict[int, List[tuple]] = defaultdict(list)
    for (student_id, session_id), mark in matrix.marks.items():
        if mark.verification_score is None:
            continue
        info = matrix.sessions.get(session_id)
        if info:
            by_class[info.class_id].append((mark.verification_score, student_id, session_id))

    findings = []
    for class_id, rows in by_class.items():
        scores = [r[0] for r in rows]
        if len(scores) < MIN_SAMPLES_FOR_OUTLIERS:
            continue
        med = M.median(scores)
        mad = _mad(scores)
        if not mad:
            continue
        for score, student_id, session_id in rows:
            z = _modified_z(score, med, mad)
            if z <= -VERIFICATION_MAD_THRESHOLD:
                findings.append({
                    'flag_type': 'low_verification',
                    'session_id': session_id,
                    'class_id': class_id,
                    'student_id': student_id,
                    'severity': 'warning',
                    'score': min(1.0, abs(z) / 6.0),
                    'evidence': {
                        'verification_score': round(score, 4),
                        'class_median': round(med, 4),
                        'class_mad': round(mad, 4),
                        'modified_z': round(z, 2),
                        'threshold_z': -VERIFICATION_MAD_THRESHOLD,
                        'sample_size': len(scores),
                    },
                    'explanation': (
                        f'Verification score {score:.2f} is well below this class\'s '
                        f'median of {med:.2f} (modified z = {z:.1f} across {len(scores)} marks).'
                    ),
                })
    return findings


def detect_post_session_marks(matrix) -> List[dict]:
    """
    Marks timestamped after the session ended.

    Unambiguous: either the clock is wrong or the mark was not made in the room.
    No statistics needed, so no threshold to argue about.
    """
    findings = []
    for (student_id, session_id), mark in matrix.marks.items():
        info = matrix.sessions.get(session_id)
        if not info or not info.end_time or mark.marked_at is None:
            continue
        overshoot = (mark.marked_at - info.end_time).total_seconds()
        if overshoot > 60:  # one minute of grace for clock skew
            findings.append({
                'flag_type': 'post_session_mark',
                'session_id': session_id,
                'class_id': info.class_id,
                'student_id': student_id,
                'severity': 'critical' if overshoot > 900 else 'warning',
                'score': min(1.0, overshoot / 1800.0),
                'evidence': {
                    'marked_at': mark.marked_at.isoformat(),
                    'session_end': info.end_time.isoformat(),
                    'seconds_after_end': round(overshoot, 1),
                    'grace_seconds': 60,
                },
                'explanation': (
                    f'Attendance was recorded {overshoot / 60:.1f} minutes after the '
                    f'session ended.'
                ),
            })
    return findings


def detect_session_collisions(matrix) -> List[dict]:
    """
    One student marked present at two overlapping sessions.

    Physically impossible, so it points at either a scheduling error or a proxy
    mark. Only concluded sessions are considered, and only actual presence.
    """
    by_student: Dict[int, List] = defaultdict(list)
    for (student_id, session_id), mark in matrix.marks.items():
        if not mark.is_present:
            continue
        info = matrix.sessions.get(session_id)
        if info and info.end_time:
            by_student[student_id].append(info)

    findings = []
    for student_id, sessions in by_student.items():
        sessions.sort(key=lambda s: s.start_time)
        for a, b in zip(sessions, sessions[1:]):
            if b.start_time < a.end_time and a.class_id != b.class_id:
                overlap = (min(a.end_time, b.end_time) - b.start_time).total_seconds()
                findings.append({
                    'flag_type': 'session_collision',
                    'session_id': b.id,
                    'class_id': b.class_id,
                    'student_id': student_id,
                    'severity': 'critical',
                    'score': 1.0,
                    'evidence': {
                        'session_a': {
                            'id': a.id, 'class_code': a.class_code,
                            'start': a.start_time.isoformat(), 'end': a.end_time.isoformat(),
                        },
                        'session_b': {
                            'id': b.id, 'class_code': b.class_code,
                            'start': b.start_time.isoformat(), 'end': b.end_time.isoformat(),
                        },
                        'overlap_seconds': round(overlap, 1),
                    },
                    'explanation': (
                        f'Marked present in both {a.class_code} and {b.class_code}, which '
                        f'overlap by {overlap / 60:.0f} minutes.'
                    ),
                })
    return findings


def detect_latency_outliers(matrix) -> List[dict]:
    """
    Marks far later than the class's own typical latency.

    Uses IQR fencing on the latency distribution: skewed data makes a mean-based
    rule fire constantly, whereas Q3 + 1.5*IQR adapts to how this class behaves.
    """
    by_class: Dict[int, List[tuple]] = defaultdict(list)
    for (student_id, session_id), mark in matrix.marks.items():
        if mark.latency_seconds is None:
            continue
        info = matrix.sessions.get(session_id)
        if info:
            by_class[info.class_id].append((mark.latency_seconds, student_id, session_id))

    findings = []
    for class_id, rows in by_class.items():
        lats = [r[0] for r in rows]
        if len(lats) < MIN_SAMPLES_FOR_OUTLIERS:
            continue
        q1 = M.percentile(lats, 25)
        q3 = M.percentile(lats, 75)
        iqr = q3 - q1
        if iqr <= 0:
            continue
        fence = q3 + 1.5 * iqr
        for lat, student_id, session_id in rows:
            if lat > fence:
                findings.append({
                    'flag_type': 'late_outlier',
                    'session_id': session_id,
                    'class_id': class_id,
                    'student_id': student_id,
                    'severity': 'info',
                    'score': min(1.0, (lat - fence) / max(fence, 1.0)),
                    'evidence': {
                        'latency_seconds': round(lat, 1),
                        'class_q1': round(q1, 1),
                        'class_q3': round(q3, 1),
                        'upper_fence': round(fence, 1),
                        'sample_size': len(lats),
                    },
                    'explanation': (
                        f'Marked {lat / 60:.1f} minutes into the session, beyond this '
                        f'class\'s usual range (upper fence {fence / 60:.1f} min).'
                    ),
                })
    return findings


def detect_cohort_drops(matrix) -> List[dict]:
    """
    Sessions where turnout shifted level, via CUSUM rather than a fixed cut-off.

    The previous "flag anything under 70%" rule fired constantly in a low-attendance
    class and never fired in a high one that had just collapsed from 98% to 80%.
    CUSUM flags *change*, which is what actually warrants a look.
    """
    findings = []
    for class_id, sessions in matrix.sessions_by_class.items():
        ordered = sorted(sessions, key=lambda s: s.start_time)
        pcts, keep = [], []
        for s in ordered:
            t = matrix.session_totals(s)
            if t['pct'] is not None:
                pcts.append(t['pct'])
                keep.append(s)
        if len(pcts) < 4:
            continue
        baseline = M.median(pcts)
        for idx in M.cusum_change_points(pcts):
            s = keep[idx]
            delta = pcts[idx] - baseline
            if delta >= 0:
                continue  # upward shifts are good news, not an integrity concern
            findings.append({
                'flag_type': 'cohort_drop',
                'session_id': s.id,
                'class_id': class_id,
                'student_id': None,
                'severity': 'warning' if delta > -20 else 'critical',
                'score': min(1.0, abs(delta) / 40.0),
                'evidence': {
                    'session_pct': round(pcts[idx], 2),
                    'class_median_pct': round(baseline, 2),
                    'delta_points': round(delta, 2),
                    'method': 'CUSUM change-point detection',
                    'sessions_analysed': len(pcts),
                },
                'explanation': (
                    f'Turnout on {s.local_date.isoformat()} was {pcts[idx]:.0f}%, '
                    f'{abs(delta):.0f} points below this class\'s median — a sustained '
                    f'level shift, not routine variation.'
                ),
            })
    return findings


DETECTORS = (
    detect_burst_marking,
    detect_low_verification,
    detect_post_session_marks,
    detect_session_collisions,
    detect_latency_outliers,
    detect_cohort_drops,
)


def run_detectors(matrix) -> List[dict]:
    out = []
    for fn in DETECTORS:
        try:
            out.extend(fn(matrix))
        except Exception:
            # One failing detector must not blank the whole Integrity tab.
            continue
    out.sort(key=lambda f: (-f['score'],))
    return out


def persist_flags(findings: List[dict]) -> dict:
    """
    Write findings to AttendanceFlag, skipping ones already recorded.

    Dedup key is (flag_type, session, student), so re-running analytics does not
    resurrect a dismissed flag or duplicate an open one.
    """
    created = skipped = 0
    for f in findings:
        exists = AttendanceFlag.objects.filter(
            flag_type=f['flag_type'],
            session_id=f['session_id'],
            student_id=f['student_id'],
        ).exists()
        if exists:
            skipped += 1
            continue
        AttendanceFlag.objects.create(
            flag_type=f['flag_type'],
            session_id=f['session_id'],
            class_obj_id=f['class_id'],
            student_id=f['student_id'],
            severity=f['severity'],
            score=f['score'],
            evidence={**f['evidence'], 'explanation': f['explanation']},
        )
        created += 1
    return {'created': created, 'already_known': skipped}


def integrity_summary(matrix, class_ids, persist: bool = True) -> dict:
    """
    Integrity view for the dashboard: fresh findings plus stored flag state.

    `persist=False` is available for read-only contexts (e.g. a student view)
    where writing flags would be a side effect of merely looking.
    """
    findings = run_detectors(matrix)
    write_result = persist_flags(findings) if persist else {'created': 0, 'already_known': 0}

    stored = (
        AttendanceFlag.objects
        .filter(Q(class_obj_id__in=class_ids) | Q(session__class_obj_id__in=class_ids))
        .select_related('student', 'session')
        .order_by('-score', '-created_at')[:100]
    )

    by_type = defaultdict(int)
    by_severity = defaultdict(int)
    open_rows = []
    for flag in stored:
        by_type[flag.flag_type] += 1
        by_severity[flag.severity] += 1
        if flag.status == 'open':
            open_rows.append({
                'id': flag.id,
                'flag_type': flag.flag_type,
                'flag_label': flag.get_flag_type_display(),
                'severity': flag.severity,
                'score': round(flag.score, 3),
                'student_id': flag.student_id,
                'student_name': (
                    flag.student.get_full_name() or flag.student.username
                    if flag.student_id else None
                ),
                'session_id': flag.session_id,
                'evidence': flag.evidence,
                'explanation': flag.evidence.get('explanation') if flag.evidence else None,
                'created_at': flag.created_at.isoformat(),
                'status': flag.status,
            })

    verification = matrix.verification_scores()
    return {
        'open_flags': open_rows,
        'open_count': len(open_rows),
        'by_type': dict(by_type),
        'by_severity': dict(by_severity),
        'newly_detected': write_result['created'],
        'previously_known': write_result['already_known'],
        'verification': {
            'median': round(M.median(verification), 4) if verification else None,
            'p10': round(M.percentile(verification, 10), 4) if verification else None,
            'sample_size': len(verification),
        } if verification else {'sample_size': 0},
        'detectors': [
            {'name': 'burst_marking',
             'description': f'{BURST_MIN_STUDENTS}+ distinct students marking within {BURST_WINDOW_SECONDS}s'},
            {'name': 'low_verification',
             'description': f'Verification score {VERIFICATION_MAD_THRESHOLD} MADs below the class median'},
            {'name': 'post_session_mark',
             'description': 'Mark timestamped after session end (60s grace)'},
            {'name': 'session_collision',
             'description': 'Present at two overlapping sessions simultaneously'},
            {'name': 'late_outlier',
             'description': 'Latency beyond the class IQR upper fence'},
            {'name': 'cohort_drop',
             'description': 'CUSUM-detected sustained drop in session turnout'},
        ],
        'note': (
            'Integrity flags never change attendance records or percentages. '
            'They are surfaced for review and can be resolved or dismissed.'
        ),
    }

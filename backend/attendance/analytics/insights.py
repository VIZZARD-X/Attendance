"""
Insight synthesis: turning computed statistics into a ranked, readable narrative.

The other analytics modules answer "what are the numbers?". This one answers the
question a teacher or student actually has: "what should I do about it?"

Design rules:

1. **Every insight cites its own evidence.** An insight carries the figures that
   produced it, so a reader can audit the claim instead of trusting it.
2. **Ranked by actionability, not by drama.** Priority combines severity with
   whether anything can still be done. A student who is mathematically unable to
   reach the threshold ranks below one who can still recover, because the latter
   is where action changes the outcome.
3. **Silence over fabrication.** If a statistic is missing or based on too little
   data, no insight is emitted. An empty list is a valid, honest answer.
4. **No duplicate framing.** The same underlying fact is not restated as three
   separate insights; detectors are checked in order of specificity.
"""
from typing import List, Optional

# Insight categories, used by the UI to pick an icon and colour.
CATEGORY_RISK = 'risk'
CATEGORY_PATTERN = 'pattern'
CATEGORY_INTEGRITY = 'integrity'
CATEGORY_TREND = 'trend'
CATEGORY_FORECAST = 'forecast'
CATEGORY_EQUITY = 'equity'
CATEGORY_POSITIVE = 'positive'

# Priority scale. Kept coarse deliberately: finer gradations would imply a
# precision the underlying estimates do not have.
P_CRITICAL = 100
P_HIGH = 75
P_MEDIUM = 50
P_LOW = 25


def _insight(
    category: str,
    priority: int,
    headline: str,
    detail: str,
    evidence: dict,
    action: Optional[str] = None,
) -> dict:
    return {
        'category': category,
        'priority': priority,
        'headline': headline,
        'detail': detail,
        'evidence': evidence,
        'action': action,
    }


# ---------------------------------------------------------------------------
# Teacher insights
# ---------------------------------------------------------------------------

def teacher_insights(
    *,
    health: dict,
    scored: List[dict],
    bands: dict,
    rising: List[dict],
    weekday: dict,
    slots: dict,
    punct: dict,
    integrity: dict,
    required_pct: float,
    total_students: int,
) -> List[dict]:
    """
    Insights for a teacher looking at one class or a portfolio.

    Ordered so that the most consequential and most fixable item is first.
    """
    out: List[dict] = []

    # --- Students who can still be saved -----------------------------------
    # Deliberately ahead of the already-failing list: this is the group where a
    # conversation this week changes the final outcome.
    if rising:
        worst = rising[0]
        out.append(_insight(
            CATEGORY_RISK, P_CRITICAL,
            f'{len(rising)} student(s) still passing but falling fast',
            (
                f'These students are at or above {required_pct:.0f}% today, so a '
                f'percentage-sorted list hides them entirely. Their recent trend is '
                f'downward — {worst["name"] or worst["username"]} is dropping fastest '
                f'at {abs(worst["trend_slope_per_session"]) * 100:.1f} points per session.'
            ),
            {
                'count': len(rising),
                'threshold_pct': required_pct,
                'students': [
                    {
                        'student_id': r['student_id'],
                        'name': r['name'] or r['username'],
                        'attendance_pct': r['attendance_pct'],
                        'slope_per_session': r['trend_slope_per_session'],
                        'risk_band': r['risk_band'],
                    }
                    for r in rising[:5]
                ],
            },
            'Reach out now — intervention is cheapest before the threshold is crossed.',
        ))

    # --- Already below threshold -------------------------------------------
    failing = [s for s in scored if s['attendance_pct'] is not None
               and s['attendance_pct'] < required_pct]
    if failing:
        critical = [s for s in failing if s['risk_band'] == 'critical']
        out.append(_insight(
            CATEGORY_RISK, P_HIGH if not critical else P_CRITICAL,
            f'{len(failing)} student(s) below the {required_pct:.0f}% requirement',
            (
                f'{len(critical)} of them are in the critical band, meaning low '
                f'attendance is compounded by a worsening trend, a long absence '
                f'streak, or erratic attendance rather than a single bad patch.'
            ),
            {
                'below_threshold': len(failing),
                'critical_band': len(critical),
                'total_students': total_students,
                'share_pct': round(len(failing) / total_students * 100, 1) if total_students else None,
                'students': [
                    {
                        'student_id': s['student_id'],
                        'name': s['name'] or s['username'],
                        'attendance_pct': s['attendance_pct'],
                        'risk_band': s['risk_band'],
                        'reasons': s['reasons'][:2],
                    }
                    for s in failing[:5]
                ],
            },
            'Review the at-risk list; each row lists the specific reasons it scored high.',
        ))

    # --- Integrity ---------------------------------------------------------
    if integrity.get('open_count'):
        by_sev = integrity.get('by_severity', {})
        crit = by_sev.get('critical', 0)
        out.append(_insight(
            CATEGORY_INTEGRITY, P_CRITICAL if crit else P_MEDIUM,
            f'{integrity["open_count"]} unresolved integrity flag(s)',
            (
                'These are marks whose circumstances look unusual — tight bursts of '
                'marking, timestamps after the session closed, or presence at two '
                'overlapping sessions. Attendance percentages are unaffected; each '
                'flag carries its own evidence and needs a human decision.'
            ),
            {
                'open_count': integrity['open_count'],
                'by_severity': by_sev,
                'by_type': integrity.get('by_type', {}),
                'newly_detected': integrity.get('newly_detected', 0),
            },
            'Open the Integrity tab to confirm or dismiss each flag.',
        ))

    # --- Systematic timing effects -----------------------------------------
    # Only significant, sufficiently-sampled findings qualify; a "bad Monday"
    # built from two sessions is noise, not a scheduling problem.
    wd_worst = next(
        (r for r in weekday.get('rows', [])
         if r.get('significant') and r.get('sufficient_data')
         and (r.get('delta_vs_rest_pct') or 0) < 0),
        None,
    )
    if wd_worst:
        out.append(_insight(
            CATEGORY_PATTERN, P_MEDIUM,
            f'{wd_worst["label"]} sessions underperform consistently',
            (
                f'{wd_worst["label"]} runs {abs(wd_worst["delta_vs_rest_pct"]):.1f} points '
                f'below other days across {wd_worst["sessions"]} sessions '
                f'(p = {wd_worst["p_value"]:.3f}). This is a scheduling signal, not a '
                f'student-motivation one — it is a property of the slot, not the cohort.'
            ),
            {
                'weekday': wd_worst['label'],
                'attendance_pct': wd_worst['attendance_pct'],
                'delta_vs_rest_pct': wd_worst['delta_vs_rest_pct'],
                'sessions': wd_worst['sessions'],
                'p_value': wd_worst['p_value'],
            },
            'Consider whether the slot itself, not the students, is the constraint.',
        ))

    slot_worst = next(
        (r for r in slots.get('rows', [])
         if r.get('significant') and r.get('sufficient_data')
         and (r.get('delta_vs_rest_pct') or 0) < 0),
        None,
    )
    if slot_worst:
        out.append(_insight(
            CATEGORY_PATTERN, P_LOW,
            f'{slot_worst["label"]} sessions attract fewer students',
            (
                f'Attendance in this time band sits {abs(slot_worst["delta_vs_rest_pct"]):.1f} '
                f'points below the rest, across {slot_worst["sessions"]} sessions '
                f'(p = {slot_worst["p_value"]:.3f}).'
            ),
            {
                'slot': slot_worst['label'],
                'attendance_pct': slot_worst['attendance_pct'],
                'delta_vs_rest_pct': slot_worst['delta_vs_rest_pct'],
                'sessions': slot_worst['sessions'],
                'p_value': slot_worst['p_value'],
            },
        ))

    # --- Equity ------------------------------------------------------------
    # A healthy average can hide a split cohort: half attend everything, half
    # attend nothing. Gini separates those two very different situations.
    if health.get('status') == 'ok':
        gini = health.get('gini')
        if gini is not None and gini > 0.25:
            out.append(_insight(
                CATEGORY_EQUITY, P_MEDIUM,
                'Attendance is concentrated in part of the cohort',
                (
                    f'The Gini coefficient of {gini:.2f} means attendance is unevenly '
                    f'distributed: the class average is being carried by a subset of '
                    f'students while others attend far less. The average alone would '
                    f'not reveal this.'
                ),
                {
                    'gini': gini,
                    'equity_component': health['components'].get('equity'),
                    'below_threshold_count': health.get('below_threshold_count'),
                    'students': health.get('students'),
                },
                'Target the lower group specifically; raising the average will not reach them.',
            ))

        # --- Cohort momentum ----------------------------------------------
        slope = health.get('cohort_slope_pts_per_session')
        if slope is not None and slope < -0.5:
            out.append(_insight(
                CATEGORY_TREND, P_HIGH,
                'Class attendance is trending downward',
                (
                    f'Session-over-session attendance is falling by about '
                    f'{abs(slope):.1f} percentage points per session across '
                    f'{health.get("sessions")} sessions. This is a cohort-wide drift '
                    f'rather than a few individuals.'
                ),
                {
                    'slope_pts_per_session': slope,
                    'sessions': health.get('sessions'),
                    'momentum_component': health['components'].get('momentum'),
                },
                'Look for a cause common to the whole class rather than chasing individuals.',
            ))
        elif slope is not None and slope > 0.5:
            out.append(_insight(
                CATEGORY_POSITIVE, P_LOW,
                'Class attendance is improving',
                (
                    f'Attendance is rising by about {slope:.1f} percentage points per '
                    f'session. Whatever changed recently is working.'
                ),
                {
                    'slope_pts_per_session': slope,
                    'sessions': health.get('sessions'),
                },
            ))

    # --- Punctuality -------------------------------------------------------
    if punct.get('status') == 'ok':
        very_late = next((b for b in punct['buckets'] if b['label'] == 'Over 15 min'), None)
        if very_late and very_late['pct'] >= 20:
            out.append(_insight(
                CATEGORY_PATTERN, P_LOW,
                f'{very_late["pct"]:.0f}% of marks arrive more than 15 minutes late',
                (
                    f'Median latency is {punct["median_seconds"] / 60:.1f} minutes across '
                    f'{punct["marks_analysed"]} marks. Late marking is recorded as present, '
                    f'so this cost is invisible in the attendance percentage.'
                ),
                {
                    'median_seconds': punct['median_seconds'],
                    'p90_seconds': punct['p90_seconds'],
                    'over_15_min_pct': very_late['pct'],
                    'marks_analysed': punct['marks_analysed'],
                },
            ))

    # --- Nothing wrong is itself worth saying ------------------------------
    if not out and health.get('status') == 'ok':
        out.append(_insight(
            CATEGORY_POSITIVE, P_LOW,
            'No significant issues detected',
            (
                f'Health score {health["score"]} ({health["grade"]}). No students are '
                f'trending toward the threshold, attendance is evenly distributed, and '
                f'no integrity flags are open.'
            ),
            {
                'health_score': health['score'],
                'grade': health['grade'],
                'students': health.get('students'),
                'sessions': health.get('sessions'),
            },
        ))

    out.sort(key=lambda i: -i['priority'])
    return out


# ---------------------------------------------------------------------------
# Student insights
# ---------------------------------------------------------------------------

def student_insights(
    *,
    per_class: List[dict],
    overall_pct: Optional[float],
    required_pct: float,
    temporal: dict,
    streaks: dict,
) -> List[dict]:
    """
    Insights for a student's own dashboard.

    Framed around what is still achievable. A student cannot act on a cohort
    statistic, so nothing here compares them to named peers.
    """
    out: List[dict] = []

    # --- Mathematically unreachable ----------------------------------------
    # Stated plainly rather than hidden: a false "you can still make it" is worse
    # than an early, honest warning that lets the student talk to someone.
    unreachable = [c for c in per_class
                   if c.get('forecast', {}).get('status') == 'unreachable']
    for c in unreachable:
        f = c['forecast']
        out.append(_insight(
            CATEGORY_FORECAST, P_CRITICAL,
            f'{c["class_code"]}: threshold no longer reachable',
            (
                f'Even attending every remaining session, the maximum you can reach is '
                f'{f["best_possible_pct"]:.1f}%, below the {required_pct:.0f}% requirement. '
                f'This is arithmetic, not a prediction.'
            ),
            {
                'class_code': c['class_code'],
                'attendance_pct': c['attendance_pct'],
                'best_possible_pct': f['best_possible_pct'],
                'required_pct': required_pct,
                'remaining_sessions': c.get('remaining', {}).get('remaining'),
            },
            'Speak to your teacher about options — waiting will not improve this.',
        ))

    # --- Tight but recoverable ---------------------------------------------
    tight = [
        c for c in per_class
        if c.get('forecast', {}).get('status') != 'unreachable'
        and c.get('forecast', {}).get('absences_affordable') is not None
        and c['forecast']['absences_affordable'] <= 1
        and c.get('attendance_pct') is not None
    ]
    for c in tight:
        f = c['forecast']
        affordable = f['absences_affordable']
        out.append(_insight(
            CATEGORY_FORECAST, P_HIGH,
            (
                f'{c["class_code"]}: no absences left'
                if affordable == 0 else
                f'{c["class_code"]}: one absence left'
            ),
            (
                f'You are at {c["attendance_pct"]:.1f}% against a {required_pct:.0f}% '
                f'requirement. You can afford {affordable} more absence(s) and still '
                f'finish above the line.'
            ),
            {
                'class_code': c['class_code'],
                'attendance_pct': c['attendance_pct'],
                'absences_affordable': affordable,
                'remaining_sessions': c.get('remaining', {}).get('remaining'),
                'remaining_confidence': c.get('remaining', {}).get('confidence'),
            },
            'Attend every remaining session in this class.',
        ))

    # --- Current absence streak --------------------------------------------
    if streaks.get('current_absent', 0) >= 3:
        out.append(_insight(
            CATEGORY_RISK, P_HIGH,
            f'{streaks["current_absent"]} sessions missed in a row',
            (
                'Consecutive absences drop a percentage faster than the same number of '
                'scattered ones, because there is no recovery in between.'
            ),
            {
                'current_absent_streak': streaks['current_absent'],
                'longest_absent_streak': streaks.get('worst_absent'),
                'overall_pct': overall_pct,
            },
            'Attending the next session stops the decline immediately.',
        ))
    elif streaks.get('current_present', 0) >= 5:
        out.append(_insight(
            CATEGORY_POSITIVE, P_LOW,
            f'{streaks["current_present"]} sessions attended in a row',
            'Your current streak is your longest recent run of consistent attendance.',
            {
                'current_present_streak': streaks['current_present'],
                'overall_pct': overall_pct,
            },
        ))

    # --- Personal weekday weakness -----------------------------------------
    wd = next(
        (r for r in temporal.get('rows', [])
         if r.get('significant') and r.get('sufficient_data')),
        None,
    )
    if wd and wd.get('attendance_pct') is not None and wd['attendance_pct'] < required_pct:
        out.append(_insight(
            CATEGORY_PATTERN, P_MEDIUM,
            f'{wd["label"]} is your weakest day',
            (
                f'You attend {wd["attendance_pct"]:.0f}% of {wd["label"]} sessions across '
                f'{wd["sessions"]} of them (p = {wd["p_value"]:.3f}), which is statistically '
                f'distinct from your other days rather than coincidence.'
            ),
            {
                'weekday': wd['label'],
                'attendance_pct': wd['attendance_pct'],
                'sessions': wd['sessions'],
                'p_value': wd['p_value'],
            },
            f'A recurring {wd["label"]} conflict is usually the cause — worth resolving once.',
        ))

    # --- Comfortable -------------------------------------------------------
    if not out and overall_pct is not None and overall_pct >= required_pct:
        margin = overall_pct - required_pct
        out.append(_insight(
            CATEGORY_POSITIVE, P_LOW,
            f'You are {margin:.1f} points above the requirement',
            (
                f'Overall attendance is {overall_pct:.1f}% against a {required_pct:.0f}% '
                f'requirement, with no downward trend or weak-day pattern detected.'
            ),
            {
                'overall_pct': overall_pct,
                'required_pct': required_pct,
                'margin_points': round(margin, 2),
            },
        ))

    out.sort(key=lambda i: -i['priority'])
    return out

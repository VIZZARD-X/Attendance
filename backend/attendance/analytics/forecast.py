"""
Remaining-session estimation.

The old code hardcoded `remaining_est = 18`, which made every projection and
every "you can miss N more" figure fiction. This module derives the number, and
always reports *how* it derived it so the client can show the provenance.

Strategy, in order of trust:
  1. `Class.expected_sessions_total` minus sessions already held  -> 'declared'
  2. `Class.sessions_per_week` x weeks left in the term           -> 'declared_cadence'
  3. observed cadence over the trailing 28 days x weeks left      -> 'inferred_cadence'
  4. nothing known                                                -> 'unknown' (0)
"""
import math
from datetime import timedelta
from typing import Dict, List, Optional

from django.utils import timezone

from ..models import AttendanceSession

OBSERVATION_WINDOW_DAYS = 28


def observed_cadence(class_id: int, as_of=None) -> Optional[float]:
    """Sessions per week over the trailing 4 weeks, or None if too little history."""
    as_of = as_of or timezone.now()
    since = as_of - timedelta(days=OBSERVATION_WINDOW_DAYS)
    held = (
        AttendanceSession.objects
        .filter(class_obj_id=class_id, start_time__gte=since, start_time__lte=as_of)
        .exclude(status='active')
        .count()
    )
    if held < 2:
        return None
    return held / (OBSERVATION_WINDOW_DAYS / 7.0)


def remaining_sessions(class_obj, sessions_held: int, ctx) -> dict:
    """
    Estimate sessions left in the term for one class.

    Returns {'remaining', 'source', 'confidence', 'note'} — never a bare number,
    because a forecast built on an inferred cadence deserves a visible caveat.
    """
    term = class_obj.term or ctx.term

    # 1. Declared total.
    if class_obj.expected_sessions_total:
        remaining = max(0, class_obj.expected_sessions_total - sessions_held)
        return {
            'remaining': remaining,
            'source': 'declared',
            'confidence': 'high',
            'note': f'{class_obj.expected_sessions_total} sessions planned for the term.',
        }

    weeks_left = term.weeks_remaining(ctx.now.date()) if term else None

    # 2. Declared weekly cadence.
    if class_obj.sessions_per_week and weeks_left is not None:
        remaining = int(round(class_obj.sessions_per_week * weeks_left))
        return {
            'remaining': max(0, remaining),
            'source': 'declared_cadence',
            'confidence': 'medium',
            'note': (
                f'{class_obj.sessions_per_week:g} sessions/week x '
                f'{weeks_left:.1f} weeks left in {term.name}.'
            ),
        }

    # 3. Cadence inferred from what actually happened.
    if weeks_left is not None:
        cadence = observed_cadence(class_obj.id, ctx.now)
        if cadence:
            remaining = int(round(cadence * weeks_left))
            return {
                'remaining': max(0, remaining),
                'source': 'inferred_cadence',
                'confidence': 'low',
                'note': (
                    f'Estimated from the last {OBSERVATION_WINDOW_DAYS} days '
                    f'({cadence:.1f} sessions/week) x {weeks_left:.1f} weeks left. '
                    f'Set an expected session total for an exact figure.'
                ),
            }

    # 4. Refuse to guess.
    return {
        'remaining': 0,
        'source': 'unknown',
        'confidence': 'none',
        'note': (
            'No academic term or planned session count is configured, so '
            'remaining sessions cannot be determined. Projections are omitted.'
        ),
    }


def remaining_by_class(classes, sessions_held_by_class: Dict[int, int], ctx) -> Dict[int, dict]:
    return {
        c.id: remaining_sessions(c, sessions_held_by_class.get(c.id, 0), ctx)
        for c in classes
    }


def point_of_no_return(
    present: int,
    expected: int,
    remaining: int,
    target_pct: float,
    upcoming_dates: Optional[List] = None,
) -> dict:
    """
    The moment the threshold stops being reachable.

    Even attending every remaining session, the best achievable final percentage
    is (present + remaining) / (expected + remaining). If that is already below
    target, the outcome is decided; otherwise we count how many further absences
    can be absorbed and, when a session calendar is available, name the date.

    "You have 9 days to become recoverable" moves people. "68%" does not.
    """
    total = expected + remaining
    if total == 0:
        return {'status': 'insufficient_data', 'required_n': 1, 'actual_n': 0}

    best_possible = (present + remaining) / total * 100.0
    if best_possible < target_pct:
        return {
            'status': 'unreachable',
            'best_possible_pct': round(best_possible, 2),
            'absences_affordable': 0,
            'deadline_date': None,
            'message': (
                f'Even with perfect attendance from here the maximum achievable is '
                f'{best_possible:.1f}%, below the {target_pct:g}% requirement.'
            ),
        }

    t = target_pct / 100.0
    affordable = int(math.floor((present + remaining) - t * total + 1e-9))
    affordable = max(0, min(affordable, remaining))

    deadline = None
    if upcoming_dates and affordable < len(upcoming_dates):
        deadline = upcoming_dates[affordable]

    if affordable == 0:
        message = (
            f'Every remaining session must be attended to hold {target_pct:g}%. '
            f'One more absence makes it impossible.'
        )
        status = 'critical'
    elif affordable <= 2:
        message = f'Only {affordable} more absence(s) can be absorbed before {target_pct:g}% is out of reach.'
        status = 'tight'
    else:
        message = f'{affordable} absences can still be absorbed while finishing at or above {target_pct:g}%.'
        status = 'recoverable'

    return {
        'status': status,
        'best_possible_pct': round(best_possible, 2),
        'absences_affordable': affordable,
        'deadline_date': deadline.isoformat() if hasattr(deadline, 'isoformat') else deadline,
        'message': message,
    }

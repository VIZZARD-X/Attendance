"""
Analytics scope & configuration resolution.

Everything downstream reads its term, threshold and date window from an
AnalyticsContext, so no metric module ever hardcodes 75.0 or a semester name.
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta, date, time
from typing import Optional, List

from django.utils import timezone

from ..models import AcademicTerm, Class

# Fallback used only when no AcademicTerm exists at all. Surfaced in the API
# `meta.threshold_source` so the client can tell a real policy from a default.
DEFAULT_REQUIRED_PCT = 75.0

# Minimum observations before a bucketed statistic is reported at all. Below
# this we emit an explicit insufficient_data marker instead of a number.
MIN_SAMPLE_SIZE = 3


@dataclass
class AnalyticsContext:
    """Resolved scope for one analytics computation."""
    term: Optional[AcademicTerm] = None
    required_pct: float = DEFAULT_REQUIRED_PCT
    threshold_source: str = 'default'      # 'term' | 'default' | 'override'
    start: Optional[datetime] = None       # inclusive window start (tz-aware)
    end: Optional[datetime] = None         # inclusive window end (tz-aware)
    class_ids: List[int] = field(default_factory=list)
    now: datetime = field(default_factory=timezone.now)

    @property
    def term_name(self) -> str:
        return self.term.name if self.term else 'All Time'

    @property
    def academic_year(self) -> str:
        return self.term.academic_year if self.term else ''

    @property
    def term_end_date(self) -> Optional[date]:
        return self.term.end_date if self.term else None

    def meta(self, **extra) -> dict:
        """Standard `meta` envelope block attached to every analytics response."""
        payload = {
            'computed_at': self.now.isoformat(),
            'term': self.term_name,
            'term_id': self.term.id if self.term else None,
            'academic_year': self.academic_year,
            'threshold_pct': round(self.required_pct, 2),
            'threshold_source': self.threshold_source,
            'window_start': self.start.isoformat() if self.start else None,
            'window_end': self.end.isoformat() if self.end else None,
            'min_sample_size': MIN_SAMPLE_SIZE,
        }
        payload.update(extra)
        return payload


def _aware(d: date, end_of_day: bool = False) -> datetime:
    t = time(23, 59, 59) if end_of_day else time(0, 0, 0)
    return timezone.make_aware(datetime.combine(d, t))


def build_context(request, class_ids: Optional[List[int]] = None) -> AnalyticsContext:
    """
    Resolve term, threshold and date window from query params.

    Params: term_id, threshold, from (YYYY-MM-DD), to (YYYY-MM-DD), days (int).
    Precedence for the window: explicit from/to > days > term bounds > all time.
    """
    q = request.query_params
    now = timezone.now()

    # --- term -------------------------------------------------------------
    # `term_id=all` is the explicit "ignore term boundaries, all time" request.
    # Anything non-numeric is treated as absent rather than passed to the ORM,
    # which would raise ValueError on the integer pk lookup.
    term = None
    term_id = q.get('term_id')
    all_time = str(term_id).lower() == 'all'
    if term_id and not all_time and str(term_id).isdigit():
        term = AcademicTerm.objects.filter(id=int(term_id)).first()
    if term is None and not all_time:
        term = AcademicTerm.current()


    # --- threshold --------------------------------------------------------
    if q.get('threshold'):
        try:
            required = max(1.0, min(100.0, float(q['threshold'])))
            source = 'override'
        except (TypeError, ValueError):
            required, source = DEFAULT_REQUIRED_PCT, 'default'
    elif term is not None:
        required, source = float(term.required_attendance_pct), 'term'
    else:
        required, source = DEFAULT_REQUIRED_PCT, 'default'

    # --- window -----------------------------------------------------------
    start = end = None
    frm, to = q.get('from'), q.get('to')
    if frm:
        try:
            start = _aware(datetime.strptime(frm, '%Y-%m-%d').date())
        except ValueError:
            start = None
    if to:
        try:
            end = _aware(datetime.strptime(to, '%Y-%m-%d').date(), end_of_day=True)
        except ValueError:
            end = None

    if start is None and end is None:
        days = q.get('days')
        if days:
            try:
                start = now - timedelta(days=max(1, int(days)))
                end = now
            except (TypeError, ValueError):
                pass

    if start is None and end is None and term is not None:
        start = _aware(term.start_date)
        end = min(_aware(term.end_date, end_of_day=True), now)

    return AnalyticsContext(
        term=term,
        required_pct=required,
        threshold_source=source,
        start=start,
        end=end,
        class_ids=list(class_ids or []),
        now=now,
    )


def resolve_teacher_classes(teacher, class_id=None) -> List[Class]:
    """Classes a teacher may analyse, optionally narrowed to one. Ownership enforced here."""
    qs = Class.objects.filter(teacher=teacher).select_related('term').order_by('class_code')
    if class_id not in (None, '', 'all'):
        qs = qs.filter(id=class_id)
    return list(qs)


def insufficient(actual: int, required: int = MIN_SAMPLE_SIZE) -> dict:
    """Explicit sparse-data marker. Never fabricate a value to fill a gap."""
    return {
        'status': 'insufficient_data',
        'required_n': required,
        'actual_n': actual,
    }

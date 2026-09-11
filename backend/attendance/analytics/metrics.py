"""
Pure statistical primitives.

No Django imports, no database access, no I/O — every function here takes plain
numbers and returns plain numbers. That makes each one unit-testable against
hand-computed values, which is the whole point: every figure the dashboard shows
must be traceable to a formula someone can check.
"""
import math
from typing import Dict, List, Optional, Sequence, Tuple

# Recency weight for the exponentially weighted attendance probability.
# 0.3 means the last ~6 sessions carry the bulk of the signal — responsive enough
# to catch a student who just started slipping, damped enough to ignore one blip.
EWMA_ALPHA = 0.3

# Rolling window for trend slope. 8 sessions ≈ 3 weeks at typical cadence.
SLOPE_WINDOW = 8

# Fewest observations that can support a *trend* claim. Two points always fit a
# line perfectly, so a 2-point "slope" of -1.0/session is an artefact of the
# arithmetic, not evidence of decline. Refuse to report one.
MIN_SLOPE_POINTS = 4



def safe_pct(numerator: float, denominator: float) -> Optional[float]:
    """Percentage, or None when there is genuinely nothing to divide by."""
    if not denominator:
        return None
    return numerator / denominator * 100.0


def mean(values: Sequence[float]) -> Optional[float]:
    return sum(values) / len(values) if values else None


def median(values: Sequence[float]) -> Optional[float]:
    if not values:
        return None
    s = sorted(values)
    n = len(s)
    mid = n // 2
    return s[mid] if n % 2 else (s[mid - 1] + s[mid]) / 2.0


def stdev(values: Sequence[float]) -> Optional[float]:
    """Population standard deviation."""
    if len(values) < 2:
        return 0.0 if values else None
    m = sum(values) / len(values)
    return math.sqrt(sum((v - m) ** 2 for v in values) / len(values))


def percentile(values: Sequence[float], p: float) -> Optional[float]:
    """Linear-interpolated percentile, p in 0..100."""
    if not values:
        return None
    s = sorted(values)
    if len(s) == 1:
        return s[0]
    k = (len(s) - 1) * (p / 100.0)
    lo, hi = math.floor(k), math.ceil(k)
    if lo == hi:
        return s[int(k)]
    return s[lo] + (s[hi] - s[lo]) * (k - lo)


def percentile_rank(values: Sequence[float], target: float) -> Optional[float]:
    """
    What share of `values` the target beats, 0..100.

    Used for privacy-safe peer benchmarking: a student learns their standing
    without ever learning another student's number.
    """
    if not values:
        return None
    below = sum(1 for v in values if v < target)
    equal = sum(1 for v in values if v == target)
    return (below + 0.5 * equal) / len(values) * 100.0


def ewma(series: Sequence[float], alpha: float = EWMA_ALPHA) -> Optional[float]:
    """
    Exponentially weighted mean, oldest→newest. Recent observations dominate.

    On a 1/0 attendance series this is a recency-weighted estimate of the
    probability the student shows up next — the input to the forecast.
    """
    if not series:
        return None
    acc = float(series[0])
    for v in series[1:]:
        acc = alpha * float(v) + (1 - alpha) * acc
    return acc


def ewma_series(series: Sequence[float], alpha: float = EWMA_ALPHA) -> List[float]:
    """Full smoothed curve, for sparklines."""
    if not series:
        return []
    out = [float(series[0])]
    for v in series[1:]:
        out.append(alpha * float(v) + (1 - alpha) * out[-1])
    return out


def ols_slope(series: Sequence[float]) -> Optional[float]:
    """
    Least-squares slope against index position.

    On a 1/0 series the units are "change in attendance probability per session":
    negative means the student is drifting away. This is the drift detector.
    """
    n = len(series)
    if n < 2:
        return None
    xs = list(range(n))
    mx = sum(xs) / n
    my = sum(series) / n
    denom = sum((x - mx) ** 2 for x in xs)
    if denom == 0:
        return 0.0
    num = sum((xs[i] - mx) * (series[i] - my) for i in range(n))
    return num / denom


def rolling_slope(series: Sequence[float], window: int = SLOPE_WINDOW) -> Optional[float]:
    """
    Slope over the trailing `window` observations only — recent trend, not lifetime.

    Returns None below MIN_SLOPE_POINTS: a trend claim needs enough points to be
    distinguishable from noise, and callers treat None as "no trend signal"
    rather than "flat".
    """
    if len(series) < MIN_SLOPE_POINTS:
        return None
    return ols_slope(series[-window:])



def volatility(series: Sequence[float]) -> Optional[float]:
    """
    Flip rate: share of consecutive pairs where attendance changed state.

    0 = perfectly regular (always there, or never there). 1 = alternating.
    Distinguishes a steady 60% attender from an erratic one, which a mean cannot.
    """
    if len(series) < 2:
        return None
    flips = sum(1 for i in range(1, len(series)) if series[i] != series[i - 1])
    return flips / (len(series) - 1)


def streaks(series: Sequence[int]) -> dict:
    """
    Streak stats over a chronologically ordered 1/0 series.

    `current_present` counts back from the newest observation, so it is 0 the
    moment a student misses. Derived absences are included, which the old
    record-only implementation could not see.
    """
    if not series:
        return {
            'current_present': 0, 'current_absent': 0,
            'best_present': 0, 'worst_absent': 0,
        }

    best = cur = 0
    worst = cur_abs = 0
    for v in series:
        if v:
            cur += 1
            best = max(best, cur)
            cur_abs = 0
        else:
            cur_abs += 1
            worst = max(worst, cur_abs)
            cur = 0

    trailing_present = 0
    for v in reversed(series):
        if v:
            trailing_present += 1
        else:
            break
    trailing_absent = 0
    for v in reversed(series):
        if not v:
            trailing_absent += 1
        else:
            break

    return {
        'current_present': trailing_present,
        'current_absent': trailing_absent,
        'best_present': best,
        'worst_absent': worst,
    }


def gini(values: Sequence[float]) -> Optional[float]:
    """
    Gini coefficient of attendance across a cohort, 0..1.

    0 = everyone attends equally. Higher = a small group carries the average
    while others are failing. This is the question a mean cannot answer: is 82%
    a healthy cohort, or 90% of students at 95% masking 10% at 20%?
    """
    if not values or len(values) < 2:
        return None
    s = sorted(values)
    n = len(s)
    total = sum(s)
    if total == 0:
        return 0.0
    cum = sum((i + 1) * v for i, v in enumerate(s))
    return (2 * cum) / (n * total) - (n + 1) / n


def lorenz_curve(values: Sequence[float], points: int = 20) -> List[dict]:
    """Cumulative share of attendance held by the bottom X% of students."""
    if not values:
        return []
    s = sorted(values)
    total = sum(s) or 1.0
    n = len(s)
    out = [{'population_pct': 0.0, 'attendance_share_pct': 0.0}]
    step = max(1, n // points)
    running = 0.0
    for i in range(0, n, step):
        running = sum(s[:i + 1])
        out.append({
            'population_pct': round((i + 1) / n * 100.0, 2),
            'attendance_share_pct': round(running / total * 100.0, 2),
        })
    if out[-1]['population_pct'] < 100.0:
        out.append({'population_pct': 100.0, 'attendance_share_pct': 100.0})
    return out


def two_proportion_z(p1_count: int, n1: int, p2_count: int, n2: int) -> Optional[dict]:
    """
    Two-proportion z-test.

    Guards every "Friday attendance is lower" style claim: without this a
    three-session sample looks identical to a thirty-session one. Only cells
    with p < 0.05 are allowed to be labelled significant.
    """
    if n1 < 1 or n2 < 1:
        return None
    p1 = p1_count / n1
    p2 = p2_count / n2
    pooled = (p1_count + p2_count) / (n1 + n2)
    if pooled in (0.0, 1.0):
        return {'z': 0.0, 'p_value': 1.0, 'significant': False, 'delta_pct': (p1 - p2) * 100.0}
    se = math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    if se == 0:
        return {'z': 0.0, 'p_value': 1.0, 'significant': False, 'delta_pct': (p1 - p2) * 100.0}
    z = (p1 - p2) / se
    p_value = 2 * (1 - _normal_cdf(abs(z)))
    return {
        'z': round(z, 3),
        'p_value': round(p_value, 4),
        'significant': p_value < 0.05,
        'delta_pct': round((p1 - p2) * 100.0, 2),
    }


def _normal_cdf(x: float) -> float:
    """Standard normal CDF via erf — avoids a scipy dependency."""
    return 0.5 * (1 + math.erf(x / math.sqrt(2)))


def z_scores(values: Sequence[float]) -> List[Optional[float]]:
    """Standardised values, for comparing a class against its own portfolio."""
    if len(values) < 2:
        return [None] * len(values)
    m = sum(values) / len(values)
    sd = stdev(values)
    if not sd:
        return [0.0] * len(values)
    return [(v - m) / sd for v in values]


def cusum_change_points(series: Sequence[float], threshold: float = 2.0) -> List[int]:
    """
    CUSUM change-point detection: indices where the level shifted materially.

    Replaces the old hardcoded "flag any day under 70%" rule, which fired on
    normal variation and missed genuine sustained drops in a high-attendance class.
    """
    n = len(series)
    if n < 4:
        return []
    m = sum(series) / n
    sd = stdev(series) or 0.0
    if sd == 0:
        return []
    k = 0.5 * sd
    pos = neg = 0.0
    out = []
    for i, v in enumerate(series):
        pos = max(0.0, pos + (v - m) - k)
        neg = max(0.0, neg - (v - m) - k)
        if neg > threshold * sd or pos > threshold * sd:
            out.append(i)
            pos = neg = 0.0
    return out


def min_sessions_needed(present: int, expected: int, target_pct: float) -> int:
    """
    Additional consecutive attendances required to reach `target_pct`.

    Solves (present + x) / (expected + x) >= t  for integer x:
        x >= (t*expected - present) / (1 - t)
    """
    t = target_pct / 100.0
    if expected == 0:
        return 0
    if present / expected >= t:
        return 0
    if t >= 1.0:
        return -1  # 100% is unreachable once anything has been missed
    x = (t * expected - present) / (1 - t)
    return max(0, math.ceil(x - 1e-9))


def can_miss(present: int, expected: int, remaining: int, target_pct: float) -> int:
    """
    How many of the remaining sessions may be skipped while still finishing at target.

    Solves (present + remaining - k) / (expected + remaining) >= t for integer k.
    Clamped at 0 so a failing student is never told they have room to spare.
    """
    t = target_pct / 100.0
    final_total = expected + remaining
    if final_total == 0:
        return 0
    k = (present + remaining) - t * final_total
    return max(0, int(math.floor(k + 1e-9)))


def projected_pct(present: int, expected: int, remaining: int, attend_prob: float) -> Optional[float]:
    """Expected end-of-term percentage if the student keeps attending at `attend_prob`."""
    total = expected + remaining
    if total == 0:
        return None
    return (present + remaining * attend_prob) / total * 100.0


def monte_carlo_forecast(
    present: int,
    expected: int,
    remaining: int,
    attend_prob: float,
    target_pct: float,
    trials: int = 2000,
    seed: int = 12345,
) -> dict:
    """
    Distribution of end-of-term attendance via Bernoulli simulation.

    Each trial draws `remaining` independent attendance outcomes at `attend_prob`
    (derived from the student's own EWMA), giving a full distribution rather than
    a single point guess. Reports P(finishing below threshold) plus a P10–P90 band.

    Seeded, so the same inputs always produce the same output — a requirement for
    anything shown to a student and defensible under audit.
    """
    total = expected + remaining
    if total == 0:
        return {'status': 'insufficient_data', 'required_n': 1, 'actual_n': 0}

    if remaining == 0:
        final = safe_pct(present, expected) or 0.0
        return {
            'p10': round(final, 2), 'p50': round(final, 2), 'p90': round(final, 2),
            'expected_pct': round(final, 2),
            'probability_below_target': 100.0 if final < target_pct else 0.0,
            'trials': 0,
            'attend_prob': round(attend_prob, 4),
            'remaining_sessions': 0,
        }

    import random
    rng = random.Random(seed)
    p = min(1.0, max(0.0, attend_prob))
    outcomes = []
    for _ in range(trials):
        attended = sum(1 for _ in range(remaining) if rng.random() < p)
        outcomes.append((present + attended) / total * 100.0)

    below = sum(1 for o in outcomes if o < target_pct)
    return {
        'p10': round(percentile(outcomes, 10), 2),
        'p50': round(percentile(outcomes, 50), 2),
        'p90': round(percentile(outcomes, 90), 2),
        'expected_pct': round(mean(outcomes), 2),
        'probability_below_target': round(below / trials * 100.0, 1),
        'trials': trials,
        'attend_prob': round(p, 4),
        'remaining_sessions': remaining,
    }


def normalised_consistency(per_student_pcts: Sequence[float]) -> Optional[float]:
    """
    Cohort evenness, 0..100.

    100 means every student attends at the same rate. Low means the average is
    hiding a failing tail. Feeds the Health Score's consistency component.
    """
    if len(per_student_pcts) < 2:
        return None
    sd = stdev(per_student_pcts)
    if sd is None:
        return None
    # 40 points of SD is treated as maximum practical dispersion.
    return max(0.0, min(100.0, 100.0 - (sd / 40.0) * 100.0))

"""
Analytics engine for attendance data.

Layering (each module depends only on those above it):

    context   - resolves the request into a term, threshold and date window
    matrix    - one bulk query -> an in-memory student x session presence matrix
    metrics   - pure statistics (slope, EWMA, Gini, median, significance tests)
    forecast  - remaining-session estimation and point-of-no-return arithmetic
    risk      - per-student weighted risk scoring with stated reasons
    health    - per-class composite score from coverage/equity/momentum/consistency
    patterns  - weekday, time-slot and punctuality structure
    integrity - anomaly detection on marking behaviour (never alters percentages)
    insights  - ranks the above into an actionable, evidence-carrying narrative

Two invariants hold throughout:

1. No value is invented. Where a sample is too small the module returns an
   explicit insufficient-data marker instead of a plausible-looking number.
2. Every derived figure can be traced back to the marks that produced it.
"""

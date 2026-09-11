import 'package:flutter/material.dart';

/// Design tokens for every analytics surface.
///
/// Nothing here invents meaning: the semantic colours map 1:1 onto the risk
/// bands and marks the backend actually returns, so a colour on screen can
/// always be traced back to a field in the API response.
class AnalyticsTheme {
  AnalyticsTheme._();

  // ---------------------------------------------------------------- surfaces
  /// Canvas/ink/teal values are taken verbatim from the app shell (drawer
  /// header, web sidebar) so analytics never looks like a bolted-on module.
  static const Color canvas = Color(0xFFF7FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFEEF3F5);
  static const Color border = Color(0xFFE1E8EC);
  static const Color borderStrong = Color(0xFFC7D3D9);
  static const Color ink = Color(0xFF1E1E2C);

  // -------------------------------------------------------------------- text
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9AA4B2);
  static const Color onAccent = Colors.white;

  // --------------------------------------------------------------- accents
  static const Color accent = Color(0xFF007C91);
  static const Color accentMid = Color(0xFF0097A7);
  static const Color accentBright = Color(0xFF14DCCA);
  static const Color accentSoft = Color(0xFFE2F1F4);

  /// The drawer-header gradient, reused for hero surfaces.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF007C91), Color(0xFF0097A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle teal wash used behind hero figures on light surfaces.
  static const LinearGradient accentWash = LinearGradient(
    colors: [Color(0x1A007C91), Color(0x0D0097A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ------------------------------------------------------- semantic (marks)
  static const Color present = Color(0xFF2F9E68);
  static const Color absent = Color(0xFFD64545);
  static const Color pendingReview = Color(0xFFE0932F);
  static const Color noData = Color(0xFFB6BDCA);

  // --------------------------------------------------- semantic (risk bands)
  static const Color riskCritical = Color(0xFFB3261E);
  static const Color riskHigh = Color(0xFFD64545);
  static const Color riskModerate = Color(0xFFE0932F);
  static const Color riskLow = Color(0xFF6AA84F);
  static const Color riskSafe = Color(0xFF2F9E68);

  /// Maps a backend risk band string onto its colour.
  ///
  /// Covers every band the scorer emits (`critical`, `high`, `watch`,
  /// `stable`), the flag severities (`critical`, `warning`, `info`) and the
  /// insight priorities, because all three are rendered through this one path.
  /// Unknown values fall back to [noData] rather than guessing a severity.
  static Color riskBandColor(String? band) {
    switch (band?.toLowerCase()) {
      case 'critical':
        return riskCritical;
      case 'high':
        return riskHigh;
      case 'warning':
      case 'watch':
      case 'moderate':
      case 'medium':
        return riskModerate;
      case 'low':
        return riskLow;
      case 'stable':
      case 'safe':
      case 'none':
        return riskSafe;
      case 'info':
        return accent;
      default:
        return noData;
    }
  }

  /// Colour for an [AttendanceFlag] severity (`info`/`warning`/`critical`).
  static Color severityColor(String? severity) =>
      riskBandColor(severity ?? 'info');

  /// Colour for an insight priority. The backend emits 100/75/50/25.
  static Color priorityColor(int? priority) {
    if (priority == null) return accent;
    if (priority >= 100) return riskCritical;
    if (priority >= 75) return riskHigh;
    if (priority >= 50) return riskModerate;
    return accent;
  }

  /// Health grade colour (A–F from `analytics/health.py`).
  static Color gradeColor(String? grade) {
    switch (grade?.toUpperCase()) {
      case 'A':
        return riskSafe;
      case 'B':
        return riskLow;
      case 'C':
        return riskModerate;
      case 'D':
        return riskHigh;
      case 'F':
        return riskCritical;
      default:
        return noData;
    }
  }

  /// Colour for an attendance percentage relative to the required threshold.
  /// Returns [noData] when [pct] is null so "unknown" never looks like "bad".
  static Color pctColor(double? pct, double requiredPct) {
    if (pct == null) return noData;
    final margin = pct - requiredPct;
    if (margin >= 10) return riskSafe;
    if (margin >= 0) return riskLow;
    if (margin >= -10) return riskModerate;
    if (margin >= -25) return riskHigh;
    return riskCritical;
  }

  /// Colour for a per-session/per-class trend slope.
  static Color slopeColor(double? slope) {
    if (slope == null) return noData;
    if (slope > 0.002) return riskSafe;
    if (slope < -0.002) return riskHigh;
    return textTertiary;
  }

  static IconData slopeIcon(double? slope) {
    if (slope == null) return Icons.remove;
    if (slope > 0.002) return Icons.trending_up;
    if (slope < -0.002) return Icons.trending_down;
    return Icons.trending_flat;
  }

  // ------------------------------------------------------------ typography
  static const TextStyle heroNumber = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w800,
    color: onAccent,
    height: 1.0,
    letterSpacing: -1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle displayNumber = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.05,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: textSecondary,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: textTertiary,
    height: 1.4,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 12,
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    color: textPrimary,
  );

  // ---------------------------------------------------------------- spacing
  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 12;
  static const double gapLg = 16;
  static const double gapXl = 24;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 22;

  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets pagePadding = EdgeInsets.all(16);

  // ------------------------------------------------------------------ motion
  /// Three durations only, so every surface moves at the same cadence.
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 250);
  static const Duration motionSlow = Duration(milliseconds: 400);

  /// Delay between successive items in a staggered entrance.
  static const Duration motionStagger = Duration(milliseconds: 60);

  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeInCubic;

  /// Honours the platform "reduce motion" setting. Every animated widget in
  /// the analytics stack checks this and renders its end state instantly when
  /// animations are disabled, so no information lives only in a transition.
  static bool motionEnabled(BuildContext context) =>
      !MediaQuery.of(context).disableAnimations;

  // ------------------------------------------------------------ decoration
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0F1E1E2C),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x141E1E2C),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x1F1E1E2C),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static BoxDecoration card({Color? accentBorder, bool elevated = false}) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: accentBorder ?? border),
        boxShadow: elevated ? shadowLg : shadowSm,
      );

  static BoxDecoration hero() => BoxDecoration(
        gradient: heroGradient,
        borderRadius: BorderRadius.circular(radiusXl),
        boxShadow: shadowMd,
      );

  static BoxDecoration chip(Color color) => BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      );

  /// Breakpoint used consistently across analytics screens.
  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  static int gridColumns(double width) {
    if (width >= 1280) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}

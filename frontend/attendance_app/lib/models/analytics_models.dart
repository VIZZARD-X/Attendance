/// Typed models mirroring the analytics API contract.
///
/// Design rule: the backend uses `null` to mean "not computable from the data
/// we actually have". These models preserve that distinction instead of
/// collapsing nulls to zero, so the UI can render "—" rather than a wrong 0%.
library;

// ---------------------------------------------------------------- primitives

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int asInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool? asBoolOrNull(dynamic v) => v is bool ? v : null;

String? asStringOrNull(dynamic v) => v?.toString();

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

Map<String, dynamic>? asMapOrNull(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> asMapList(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

/// Extracts a row list from a payload that may be either a bare list or a
/// wrapper object.
///
/// Several analytics modules return `{'rows': [...], 'finding': '...'}` (and
/// the heatmap returns `{'cells': [...]}` ) rather than a naked list, because
/// the narrative sentence is computed alongside the rows. Reading those through
/// [asMapList] silently yields an empty list and the panel renders as "no
/// data", which is a lie. This helper accepts both shapes.
List<Map<String, dynamic>> rowsOf(dynamic v) {
  if (v is List) return asMapList(v);
  if (v is Map) {
    for (final key in const ['rows', 'cells', 'buckets', 'items']) {
      if (v[key] is List) return asMapList(v[key]);
    }
  }
  return const [];
}

/// The narrative sentence a pattern block carries next to its rows. Rendered
/// verbatim; the UI never composes its own claim from the numbers.
String? findingOf(dynamic v) =>
    v is Map ? asStringOrNull(v['finding'] ?? v['note']) : null;

/// Converts a `{band: count}` map (or a list of `{band, count}` rows) into
/// ordered counts. `risk.band_distribution` returns the former.
List<Map<String, dynamic>> bandRowsOf(dynamic v, List<String> order) {
  if (v is List) return asMapList(v);
  if (v is Map) {
    final out = <Map<String, dynamic>>[];
    for (final band in order) {
      if (v.containsKey(band)) {
        out.add({'band': band, 'count': asInt(v[band])});
      }
    }
    // Preserve any band the backend adds later without dropping it.
    for (final entry in v.entries) {
      final key = entry.key.toString();
      if (!order.contains(key) && entry.value is num) {
        out.add({'band': key, 'count': asInt(entry.value)});
      }
    }
    return out;
  }
  return const [];
}

List<double> asDoubleList(dynamic v) => v is List
    ? v.map(asDouble).whereType<double>().toList()
    : const [];

List<String> asStringList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/// Formats a nullable percentage. Never fabricates a value.
String fmtPct(double? pct, {int decimals = 1, String dash = '—'}) =>
    pct == null ? dash : '${pct.toStringAsFixed(decimals)}%';

String fmtNum(num? v, {String dash = '—'}) => v == null ? dash : '$v';

String fmtSigned(double? v, {int decimals = 1, String dash = '—'}) {
  if (v == null) return dash;
  final s = v.toStringAsFixed(decimals);
  return v > 0 ? '+$s' : s;
}

// --------------------------------------------------------------------- meta

/// Scope/provenance envelope returned by every analytics endpoint.
///
/// Field names follow `AnalyticsContext.meta()` in `analytics/context.py`:
/// `threshold_pct`, `term`, `computed_at`. The older aliases are still read so
/// a cached response from a previous build still parses.
class AnalyticsMeta {
  final bool hasData;
  final double requiredPct;
  final String? thresholdSource;
  final String? termId;
  final String? termName;
  final String? academicYear;
  final String? scope;
  final int? classesInScope;
  final String? generatedAt;
  final String? windowStart;
  final String? windowEnd;
  final int? minSampleSize;
  final String? timezone;
  final Map<String, dynamic> raw;

  const AnalyticsMeta({
    required this.hasData,
    required this.requiredPct,
    this.thresholdSource,
    this.termId,
    this.termName,
    this.academicYear,
    this.scope,
    this.classesInScope,
    this.generatedAt,
    this.windowStart,
    this.windowEnd,
    this.minSampleSize,
    this.timezone,
    this.raw = const {},
  });

  factory AnalyticsMeta.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return AnalyticsMeta(
      hasData: j['has_data'] == true,
      // The backend key is `threshold_pct`; 75 is only a last-resort default
      // for a response that predates the envelope.
      requiredPct:
          asDouble(j['threshold_pct'] ?? j['required_pct']) ?? 75.0,
      thresholdSource: asStringOrNull(j['threshold_source']),
      termId: asStringOrNull(j['term_id']),
      termName: asStringOrNull(j['term'] ?? j['term_name']),
      academicYear: asStringOrNull(j['academic_year']),
      scope: asStringOrNull(j['scope']),
      classesInScope: asIntOrNull(j['classes_in_scope']),
      generatedAt: asStringOrNull(j['computed_at'] ?? j['generated_at']),
      windowStart: asStringOrNull(j['window_start']),
      windowEnd: asStringOrNull(j['window_end']),
      minSampleSize: asIntOrNull(j['min_sample_size']),
      timezone: asStringOrNull(j['timezone']),
      raw: j,
    );
  }

  static const AnalyticsMeta empty =
      AnalyticsMeta(hasData: false, requiredPct: 75.0);

  /// Human label for where the requirement came from, so a teacher can tell a
  /// term-configured threshold from the system default.
  String? get thresholdSourceLabel {
    switch (thresholdSource) {
      case 'term':
        return 'set by the term';
      case 'override':
        return 'overridden for this view';
      case 'default':
        return 'system default';
      default:
        return null;
    }
  }
}

// ------------------------------------------------------------ shared pieces

/// Mark totals shared by cohort/class/student summaries.
class MarkTotals {
  final int present;
  final int absent;
  final int pendingReview;
  final int expected;

  const MarkTotals({
    this.present = 0,
    this.absent = 0,
    this.pendingReview = 0,
    this.expected = 0,
  });

  factory MarkTotals.fromJson(Map<String, dynamic> j) => MarkTotals(
        present: asInt(j['present'] ?? j['present_marks']),
        absent: asInt(j['absent'] ?? j['absent_marks']),
        pendingReview:
            asInt(j['pending_review'] ?? j['pending_review_marks']),
        expected: asInt(j['expected'] ?? j['expected_marks']),
      );

  int get unrecorded {
    final diff = expected - present - absent - pendingReview;
    return diff > 0 ? diff : 0;
  }
}

/// Count of students in one risk band.
///
/// `risk.band_distribution()` returns a `{critical, high, watch, stable}` dict.
/// [bandOrder] fixes the severity order so the stacked bar always reads the
/// same way regardless of Python dict ordering.
class RiskBandCount {
  final String band;
  final int count;

  const RiskBandCount({required this.band, required this.count});

  static const List<String> bandOrder = ['critical', 'high', 'watch', 'stable'];

  factory RiskBandCount.fromJson(Map<String, dynamic> j) => RiskBandCount(
        band: asStringOrNull(j['band']) ?? 'unknown',
        count: asInt(j['count'] ?? j['students']),
      );

  /// Human label for a band. The backend's own vocabulary, expanded only where
  /// the bare word would be ambiguous on screen.
  String get label {
    switch (band) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'watch':
        return 'Watch';
      case 'stable':
        return 'Stable';
      default:
        return band;
    }
  }
}

class DistributionBand {
  final String band;
  final int students;
  final double? sharePct;

  const DistributionBand({
    required this.band,
    required this.students,
    this.sharePct,
  });

  factory DistributionBand.fromJson(Map<String, dynamic> j) =>
      DistributionBand(
        band: asStringOrNull(j['band']) ?? '—',
        students: asInt(j['students']),
        sharePct: asDouble(j['share_pct']),
      );
}

/// One point on the Lorenz curve from `metrics.lorenz_curve`.
class LorenzPoint {
  final double populationPct;
  final double attendanceSharePct;

  const LorenzPoint({
    required this.populationPct,
    required this.attendanceSharePct,
  });

  factory LorenzPoint.fromJson(Map<String, dynamic> j) => LorenzPoint(
        populationPct: asDouble(j['population_pct']) ?? 0,
        attendanceSharePct: asDouble(j['attendance_share_pct']) ?? 0,
      );

  /// Tolerates a bare numeric list as well as the `{population_pct, ...}`
  /// rows the backend actually sends.
  static List<LorenzPoint> listFrom(dynamic v) {
    if (v is! List || v.isEmpty) return const [];
    if (v.first is Map) {
      return asMapList(v).map(LorenzPoint.fromJson).toList();
    }
    final shares = asDoubleList(v);
    if (shares.length < 2) return const [];
    return [
      for (var i = 0; i < shares.length; i++)
        LorenzPoint(
          populationPct: (i + 1) / shares.length * 100.0,
          attendanceSharePct: shares[i],
        ),
    ];
  }
}

class Distribution {
  final List<DistributionBand> bands;
  final int totalStudents;
  final int belowThreshold;
  final int atOrAboveThreshold;
  final double? thresholdPct;
  final double? gini;
  final List<LorenzPoint> lorenz;
  final double? medianPct;
  final double? p10Pct;
  final double? p90Pct;

  const Distribution({
    this.bands = const [],
    this.totalStudents = 0,
    this.belowThreshold = 0,
    this.atOrAboveThreshold = 0,
    this.thresholdPct,
    this.gini,
    this.lorenz = const [],
    this.medianPct,
    this.p10Pct,
    this.p90Pct,
  });

  factory Distribution.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return Distribution(
      bands: asMapList(j['bands']).map(DistributionBand.fromJson).toList(),
      totalStudents: asInt(j['total_students']),
      belowThreshold: asInt(j['below_threshold']),
      atOrAboveThreshold: asInt(j['at_or_above_threshold']),
      thresholdPct: asDouble(j['threshold_pct']),
      gini: asDouble(j['gini']),
      lorenz: LorenzPoint.listFrom(j['lorenz']),
      medianPct: asDouble(j['median_pct']),
      p10Pct: asDouble(j['p10_pct']),
      p90Pct: asDouble(j['p90_pct']),
    );
  }

  bool get isEmpty => bands.isEmpty && totalStudents == 0;

  /// Plain-language reading of the Gini coefficient. Kept here so the teacher
  /// and student views describe the same number identically.
  String? get giniReading {
    if (gini == null) return null;
    final g = gini!;
    if (g < 0.10) return 'Attendance is spread very evenly across students.';
    if (g < 0.20) return 'Attendance is fairly evenly spread.';
    if (g < 0.35) {
      return 'Absence is concentrated in a subset of students.';
    }
    return 'Absence is heavily concentrated in a small group of students.';
  }
}

/// One point on the cohort timeline (`patterns.session_timeline`).
class TrendPoint {
  final int? sessionId;
  final String? date;
  final String? classCode;
  final String? weekday;
  final double? pct;
  final int present;
  final int expected;
  final double? medianLatencySeconds;
  final bool isChangePoint;

  const TrendPoint({
    this.sessionId,
    this.date,
    this.classCode,
    this.weekday,
    this.pct,
    this.present = 0,
    this.expected = 0,
    this.medianLatencySeconds,
    this.isChangePoint = false,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
        sessionId: asIntOrNull(j['session_id']),
        date: asStringOrNull(j['date'] ?? j['local_date']),
        classCode: asStringOrNull(j['class_code']),
        weekday: asStringOrNull(j['weekday']),
        pct: asDouble(j['attendance_pct'] ?? j['pct']),
        present: asInt(j['present']),
        expected: asInt(j['expected']),
        medianLatencySeconds: asDouble(j['median_latency_seconds']),
        isChangePoint: j['is_change_point'] == true,
      );
}

class TrendSeries {
  final List<TrendPoint> sessions;
  final double? cohortSlopePtsPerSession;
  final List<int> changePoints;

  const TrendSeries({
    this.sessions = const [],
    this.cohortSlopePtsPerSession,
    this.changePoints = const [],
  });

  factory TrendSeries.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return TrendSeries(
      sessions: asMapList(j['sessions']).map(TrendPoint.fromJson).toList(),
      cohortSlopePtsPerSession: asDouble(j['cohort_slope_pts_per_session']),
      changePoints:
          (j['change_points'] is List)
              ? (j['change_points'] as List).map(asIntOrNull).whereType<int>().toList()
              : const [],
    );
  }

  bool get isEmpty => sessions.isEmpty;
}

class StreakInfo {
  final int currentPresent;
  final int currentAbsent;
  final int longestPresent;
  final int longestAbsent;

  const StreakInfo({
    this.currentPresent = 0,
    this.currentAbsent = 0,
    this.longestPresent = 0,
    this.longestAbsent = 0,
  });

  /// `metrics.streaks()` emits `best_present`/`worst_absent`; `risk.py` emits
  /// `longest_absent_streak`. Both spellings are read so the "longest" figures
  /// are not silently reported as zero.
  factory StreakInfo.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return StreakInfo(
      currentPresent:
          asInt(j['current_present'] ?? j['current_present_streak']),
      currentAbsent: asInt(j['current_absent'] ?? j['current_absent_streak']),
      longestPresent: asInt(
        j['best_present'] ?? j['longest_present'] ?? j['longest_present_streak'],
      ),
      longestAbsent: asInt(
        j['worst_absent'] ?? j['longest_absent'] ?? j['longest_absent_streak'],
      ),
    );
  }

  bool get isEmpty =>
      currentPresent == 0 &&
      currentAbsent == 0 &&
      longestPresent == 0 &&
      longestAbsent == 0;
}

/// Remaining-session estimate, including its provenance.
///
/// `forecast.remaining_sessions` reports `source` (`declared`,
/// `declared_cadence`, `inferred_cadence`, `unknown`) and a matching
/// `confidence`. Both are surfaced so a projection built on an inferred cadence
/// is never presented as firmly as one built on a declared session count.
class RemainingInfo {
  final int? remaining;
  final String? source;
  final String? confidence;
  final String? note;

  const RemainingInfo({
    this.remaining,
    this.source,
    this.confidence,
    this.note,
  });

  factory RemainingInfo.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return RemainingInfo(
      remaining: asIntOrNull(j['remaining']),
      source: asStringOrNull(j['source']),
      confidence: asStringOrNull(j['confidence']),
      note: asStringOrNull(j['note']),
    );
  }

  bool get isKnown => source != null && source != 'unknown' && remaining != null;

  /// Plain label for the estimate's provenance.
  String get sourceLabel {
    switch (source) {
      case 'declared':
        return 'planned session count';
      case 'declared_cadence':
        return 'declared weekly cadence';
      case 'inferred_cadence':
        return 'cadence inferred from held sessions';
      case 'unknown':
        return 'unknown';
      default:
        return source ?? 'unknown';
    }
  }
}

/// Monte-Carlo forecast distribution from `metrics.monte_carlo_forecast`.
///
/// The backend reports the probability of finishing **below** target, already
/// expressed in percent (0–100). Both are exposed here in the same unit so no
/// caller has to guess whether to multiply by 100.
class ForecastDistribution {
  final String status;
  final String? reason;
  final double? probabilityBelowTargetPct;
  final double? expectedPct;
  final double? p10;
  final double? p50;
  final double? p90;
  final int? trials;
  final double? attendProb;
  final int? remainingSessions;
  final int? requiredN;
  final int? actualN;
  final Map<String, dynamic> raw;

  const ForecastDistribution({
    this.status = 'ok',
    this.reason,
    this.probabilityBelowTargetPct,
    this.expectedPct,
    this.p10,
    this.p50,
    this.p90,
    this.trials,
    this.attendProb,
    this.remainingSessions,
    this.requiredN,
    this.actualN,
    this.raw = const {},
  });

  factory ForecastDistribution.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return ForecastDistribution(
      status: asStringOrNull(j['status']) ?? (j.isEmpty ? 'missing' : 'ok'),
      reason: asStringOrNull(j['reason']),
      probabilityBelowTargetPct: asDouble(j['probability_below_target']),
      expectedPct: asDouble(j['expected_pct']),
      p10: asDouble(j['p10']),
      p50: asDouble(j['p50'] ?? j['median']),
      p90: asDouble(j['p90']),
      trials: asIntOrNull(j['trials']),
      attendProb: asDouble(j['attend_prob']),
      remainingSessions: asIntOrNull(j['remaining_sessions']),
      requiredN: asIntOrNull(j['required_n']),
      actualN: asIntOrNull(j['actual_n']),
      raw: j,
    );
  }

  bool get isAvailable =>
      status != 'insufficient_data' &&
      status != 'missing' &&
      status != 'unavailable';

  /// Percentage chance of finishing at or above the requirement (0–100).
  double? get probabilityMeetingPct => probabilityBelowTargetPct == null
      ? null
      : (100.0 - probabilityBelowTargetPct!).clamp(0.0, 100.0);

  bool get hasBand => p10 != null && p90 != null;

  /// Why no projection is available, in the backend's own words where it gave
  /// one (the student view sends `{status: 'unavailable', reason: ...}`).
  String get unavailableReason =>
      reason ??
      (requiredN == null
          ? 'A projection needs a known number of remaining sessions.'
          : 'Needs $requiredN recorded sessions; ${actualN ?? 0} so far.');
}

/// `forecast.point_of_no_return` result.
///
/// The backend reports a `status` string (`unreachable`, `critical`, `tight`,
/// `recoverable`, `insufficient_data`) plus a `message`. Reading a non-existent
/// `reachable` boolean is why the "can no longer be reached" warning never
/// fired.
class PointOfNoReturn {
  final String status;
  final double? bestPossiblePct;
  final int? absencesAffordable;
  final String? deadlineDate;
  final String? message;
  final int? requiredN;
  final int? actualN;
  final Map<String, dynamic> raw;

  const PointOfNoReturn({
    this.status = 'unknown',
    this.bestPossiblePct,
    this.absencesAffordable,
    this.deadlineDate,
    this.message,
    this.requiredN,
    this.actualN,
    this.raw = const {},
  });

  factory PointOfNoReturn.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return PointOfNoReturn(
      status: asStringOrNull(j['status']) ?? 'unknown',
      bestPossiblePct: asDouble(j['best_possible_pct']),
      absencesAffordable:
          asIntOrNull(j['absences_affordable'] ?? j['sessions_until']),
      deadlineDate: asStringOrNull(j['deadline_date']),
      message: asStringOrNull(j['message'] ?? j['note'] ?? j['explanation']),
      requiredN: asIntOrNull(j['required_n']),
      actualN: asIntOrNull(j['actual_n']),
      raw: j,
    );
  }

  /// True when the requirement is mathematically out of reach.
  bool get isUnreachable => status == 'unreachable';

  /// True when one more absence decides the outcome.
  bool get isCritical => status == 'critical';

  /// Worth surfacing prominently — the student has little or no slack left.
  bool get needsAttention =>
      status == 'unreachable' || status == 'critical' || status == 'tight';

  bool get hasVerdict => status != 'unknown' && status != 'insufficient_data';
}

class CanMissInfo {
  final int? canMiss;
  final String? note;

  const CanMissInfo({this.canMiss, this.note});

  factory CanMissInfo.fromJson(dynamic v) {
    if (v is num) return CanMissInfo(canMiss: v.toInt());
    final j = asMapOrNull(v);
    if (j == null) return const CanMissInfo();
    return CanMissInfo(
      canMiss: asIntOrNull(j['can_miss'] ?? j['sessions']),
      note: asStringOrNull(j['note']),
    );
  }
}

class CohortPosition {
  final double? percentileRank;
  final double? cohortMedianPct;
  final int? cohortSize;

  const CohortPosition({
    this.percentileRank,
    this.cohortMedianPct,
    this.cohortSize,
  });

  factory CohortPosition.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CohortPosition();
    return CohortPosition(
      percentileRank: asDouble(json['percentile_rank']),
      cohortMedianPct: asDouble(json['cohort_median_pct']),
      cohortSize: asIntOrNull(json['cohort_size']),
    );
  }
}

/// A narrative finding from `analytics/insights.py`.
///
/// The backend emits `category`, `priority` (100/75/50/25), `headline`,
/// `detail`, `evidence` and an optional `action`. Reading `body`/`severity`
/// is why insight bodies rendered blank.
class Insight {
  final String? title;
  final String body;
  final String? category;
  final int? priority;
  final String? action;
  final Map<String, dynamic> evidence;
  final Map<String, dynamic> raw;

  const Insight({
    this.title,
    required this.body,
    this.category,
    this.priority,
    this.action,
    this.evidence = const {},
    this.raw = const {},
  });

  factory Insight.fromJson(dynamic v) {
    if (v is String) return Insight(body: v);
    final j = asMap(v);
    return Insight(
      title: asStringOrNull(j['headline'] ?? j['title']),
      body: asStringOrNull(
            j['detail'] ?? j['body'] ?? j['message'] ?? j['text'],
          ) ??
          '',
      category: asStringOrNull(j['category'] ?? j['kind'] ?? j['type']),
      priority: asIntOrNull(j['priority']),
      action: asStringOrNull(j['action']),
      evidence: asMap(j['evidence']),
      raw: j,
    );
  }

  static List<Insight> listFrom(dynamic v) =>
      v is List ? v.map(Insight.fromJson).toList() : const [];

  /// Label derived from the backend's own category, not from the wording.
  String get categoryLabel => (category ?? 'insight').replaceAll('_', ' ');
}

/// One row of a pattern breakdown (weekday, time slot, or a student's own
/// weekday profile) from `analytics/patterns.py`.
///
/// `sufficientData` and `significant` are carried through deliberately: a
/// bucket below the sample floor must render as "not enough data", never as a
/// low score, and a difference that failed the two-proportion test must not be
/// presented as a finding.
class PatternRow {
  final String label;
  final String? key;
  final double? attendancePct;
  final int sessions;
  final int expectedMarks;
  final int presentMarks;
  final double? medianLatencySeconds;
  final bool sufficientData;
  final bool significant;
  final double? pValue;
  final double? deltaVsRestPct;

  const PatternRow({
    this.label = '—',
    this.key,
    this.attendancePct,
    this.sessions = 0,
    this.expectedMarks = 0,
    this.presentMarks = 0,
    this.medianLatencySeconds,
    this.sufficientData = false,
    this.significant = false,
    this.pValue,
    this.deltaVsRestPct,
  });

  factory PatternRow.fromJson(Map<String, dynamic> j) => PatternRow(
        label: asStringOrNull(j['label']) ??
            asStringOrNull(j['slot']) ??
            asStringOrNull(j['weekday']) ??
            '—',
        key: asStringOrNull(j['slot'] ?? j['weekday']),
        attendancePct: asDouble(j['attendance_pct']),
        sessions: asInt(j['sessions']),
        expectedMarks: asInt(j['expected_marks']),
        presentMarks: asInt(j['present_marks']),
        medianLatencySeconds: asDouble(j['median_latency_seconds']),
        sufficientData: j['sufficient_data'] != false,
        significant: j['significant'] == true,
        pValue: asDouble(j['p_value']),
        deltaVsRestPct: asDouble(j['delta_vs_rest_pct']),
      );

  static List<PatternRow> listFrom(dynamic v) =>
      rowsOf(v).map(PatternRow.fromJson).toList();
}

/// A pattern block: its rows plus the sentence the backend wrote about them.
class PatternBlock {
  final List<PatternRow> rows;
  final String? finding;
  final int? minSessionsPerCell;
  final String? worstLabel;

  const PatternBlock({
    this.rows = const [],
    this.finding,
    this.minSessionsPerCell,
    this.worstLabel,
  });

  factory PatternBlock.fromJson(dynamic v) {
    final j = asMap(v);
    return PatternBlock(
      rows: PatternRow.listFrom(v),
      finding: findingOf(v),
      minSessionsPerCell: asIntOrNull(j['min_sessions_per_cell']),
      worstLabel: asStringOrNull(
        j['worst_significant_day'] ?? j['worst_significant_slot'],
      ),
    );
  }

  bool get isEmpty => rows.isEmpty;
}

/// One weekday x time-slot cell of `patterns.heatmap`.
class HeatmapCell {
  final int weekday;
  final String weekdayLabel;
  final String slot;
  final double? attendancePct;
  final double? rawPct;
  final int sessions;
  final int expectedMarks;
  final bool sufficientData;

  const HeatmapCell({
    this.weekday = 0,
    this.weekdayLabel = '',
    this.slot = '',
    this.attendancePct,
    this.rawPct,
    this.sessions = 0,
    this.expectedMarks = 0,
    this.sufficientData = false,
  });

  factory HeatmapCell.fromJson(Map<String, dynamic> j) => HeatmapCell(
        weekday: asInt(j['weekday']),
        weekdayLabel: asStringOrNull(j['weekday_label']) ?? '',
        slot: asStringOrNull(j['slot']) ?? '',
        attendancePct: asDouble(j['attendance_pct']),
        rawPct: asDouble(j['raw_pct']),
        sessions: asInt(j['sessions']),
        expectedMarks: asInt(j['expected_marks']),
        sufficientData: j['sufficient_data'] == true,
      );
}

/// The weekday x time-slot grid, including its axis labels so the UI never
/// invents an axis the data does not have.
class HeatmapData {
  final List<HeatmapCell> cells;
  final List<HeatmapAxis> slots;
  final List<HeatmapAxis> weekdays;
  final int? minSessionsPerCell;
  final String? note;

  const HeatmapData({
    this.cells = const [],
    this.slots = const [],
    this.weekdays = const [],
    this.minSessionsPerCell,
    this.note,
  });

  factory HeatmapData.fromJson(dynamic v) {
    final j = asMap(v);
    return HeatmapData(
      cells: rowsOf(v).map(HeatmapCell.fromJson).toList(),
      slots: [
        for (final s in asMapList(j['slots']))
          HeatmapAxis(
            key: asStringOrNull(s['key']) ?? '',
            label: asStringOrNull(s['label']) ?? '',
          ),
      ],
      weekdays: [
        for (final w in asMapList(j['weekdays']))
          HeatmapAxis(
            key: asStringOrNull(w['index']) ?? '',
            label: asStringOrNull(w['label']) ?? '',
          ),
      ],
      minSessionsPerCell: asIntOrNull(j['min_sessions_per_cell']),
      note: asStringOrNull(j['note']),
    );
  }

  bool get isEmpty => cells.isEmpty;

  /// Only weekdays that actually have cells, so an empty Saturday column is not
  /// drawn as a row of grey boxes.
  List<HeatmapAxis> get activeWeekdays {
    final present = cells.map((c) => c.weekday).toSet().toList()..sort();
    return [
      for (final i in present)
        HeatmapAxis(
          key: '$i',
          label: weekdays
                  .firstWhere(
                    (w) => w.key == '$i',
                    orElse: () => const HeatmapAxis(key: '', label: ''),
                  )
                  .label
                  .isNotEmpty
              ? weekdays.firstWhere((w) => w.key == '$i').label
              : cells.firstWhere((c) => c.weekday == i).weekdayLabel,
        ),
    ];
  }

  /// Only slots that actually have cells, in the backend's declared order.
  List<HeatmapAxis> get activeSlots {
    final present = cells.map((c) => c.slot).toSet();
    final ordered = slots.where((s) => present.contains(s.key)).toList();
    if (ordered.isNotEmpty) return ordered;
    final fallback = present.toList()..sort();
    return [
      for (final k in fallback)
        HeatmapAxis(key: k, label: k.replaceAll('_', ' ')),
    ];
  }

  HeatmapCell? cellAt(int weekday, String slot) {
    for (final c in cells) {
      if (c.weekday == weekday && c.slot == slot) return c;
    }
    return null;
  }
}

/// A labelled axis entry for the heatmap grid.
class HeatmapAxis {
  final String key;
  final String label;

  const HeatmapAxis({required this.key, required this.label});
}

/// One latency bucket of `patterns.punctuality`.
class PunctualityBucket {
  final String label;
  final int count;
  final double? pct;

  const PunctualityBucket({this.label = '', this.count = 0, this.pct});

  factory PunctualityBucket.fromJson(Map<String, dynamic> j) =>
      PunctualityBucket(
        label: asStringOrNull(j['label']) ?? '',
        count: asInt(j['count']),
        pct: asDouble(j['pct']),
      );
}

/// How late students mark, distributionally (`patterns.punctuality`).
///
/// Median plus P90 rather than a mean, because latency is right-skewed. The
/// `insufficient_data` status is preserved so the panel says why it is empty.
class Punctuality {
  final String status;
  final double? medianSeconds;
  final double? p10Seconds;
  final double? p90Seconds;
  final int marksAnalysed;
  final List<PunctualityBucket> buckets;
  final String? finding;
  final int? requiredN;
  final int? actualN;

  const Punctuality({
    this.status = 'missing',
    this.medianSeconds,
    this.p10Seconds,
    this.p90Seconds,
    this.marksAnalysed = 0,
    this.buckets = const [],
    this.finding,
    this.requiredN,
    this.actualN,
  });

  factory Punctuality.fromJson(dynamic v) {
    final j = asMap(v);
    return Punctuality(
      status: asStringOrNull(j['status']) ?? (j.isEmpty ? 'missing' : 'ok'),
      medianSeconds: asDouble(j['median_seconds']),
      p10Seconds: asDouble(j['p10_seconds']),
      p90Seconds: asDouble(j['p90_seconds']),
      marksAnalysed: asInt(j['marks_analysed']),
      buckets:
          asMapList(j['buckets']).map(PunctualityBucket.fromJson).toList(),
      finding: asStringOrNull(j['finding']),
      requiredN: asIntOrNull(j['required_n']),
      actualN: asIntOrNull(j['actual_n']),
    );
  }

  bool get isAvailable => status == 'ok';

  String get insufficientReason => requiredN == null
      ? 'Not enough marks with a recorded arrival time yet.'
      : 'Needs $requiredN marks with a recorded arrival time; '
          '${actualN ?? 0} recorded so far.';
}

/// Weighted cohort health score from `analytics/health.py`.
///
/// The screen previously read this off the top-level `health` map by hand and
/// dropped everything but the score, so the grade, the four weighted components
/// and the interpretation sentence were never shown.
class CohortHealth {
  final String status;
  final double? score;
  final String? grade;
  final String? gradeLabel;
  final Map<String, double?> components;
  final Map<String, double> weights;
  final Map<String, String> componentMeanings;
  final double? gini;
  final double? cohortSlopePtsPerSession;
  final int students;
  final int sessions;
  final int expectedMarks;
  final int presentMarks;
  final int belowThresholdCount;
  final String? interpretation;
  final String? message;
  final int? requiredN;
  final int? actualN;

  const CohortHealth({
    this.status = 'missing',
    this.score,
    this.grade,
    this.gradeLabel,
    this.components = const {},
    this.weights = const {},
    this.componentMeanings = const {},
    this.gini,
    this.cohortSlopePtsPerSession,
    this.students = 0,
    this.sessions = 0,
    this.expectedMarks = 0,
    this.presentMarks = 0,
    this.belowThresholdCount = 0,
    this.interpretation,
    this.message,
    this.requiredN,
    this.actualN,
  });

  factory CohortHealth.fromJson(dynamic v) {
    final j = asMap(v);
    return CohortHealth(
      status: asStringOrNull(j['status']) ?? (j.isEmpty ? 'missing' : 'ok'),
      score: asDouble(j['score']),
      grade: asStringOrNull(j['grade']),
      gradeLabel: asStringOrNull(j['grade_label']),
      components: {
        for (final e in asMap(j['components']).entries)
          e.key: asDouble(e.value),
      },
      weights: {
        for (final e in asMap(j['weights']).entries)
          if (asDouble(e.value) != null) e.key: asDouble(e.value)!,
      },
      componentMeanings: {
        for (final e in asMap(j['component_meanings']).entries)
          e.key: e.value.toString(),
      },
      gini: asDouble(j['gini']),
      cohortSlopePtsPerSession: asDouble(j['cohort_slope_pts_per_session']),
      students: asInt(j['students']),
      sessions: asInt(j['sessions']),
      expectedMarks: asInt(j['expected_marks']),
      presentMarks: asInt(j['present_marks']),
      belowThresholdCount: asInt(j['below_threshold_count']),
      interpretation: asStringOrNull(j['interpretation']),
      message: asStringOrNull(j['message']),
      requiredN: asIntOrNull(j['required_n']),
      actualN: asIntOrNull(j['actual_n']),
    );
  }

  bool get isAvailable => status == 'ok' && score != null;

  /// Components in the backend's declared weight order, heaviest first.
  List<({String key, double? value, double? weight, String? meaning})>
      get orderedComponents {
    final keys = components.keys.toList()
      ..sort((a, b) => (weights[b] ?? 0).compareTo(weights[a] ?? 0));
    return [
      for (final k in keys)
        (
          key: k,
          value: components[k],
          weight: weights[k],
          meaning: componentMeanings[k],
        ),
    ];
  }

  String get unavailableReason =>
      message ??
      (requiredN == null
          ? 'Not enough recorded sessions to score cohort health.'
          : 'Needs $requiredN sessions to score; ${actualN ?? 0} so far.');
}

// -------------------------------------------------------------- teacher: overview

class TeacherSummary {
  final double? attendancePct;
  final int students;
  final int sessions;
  final MarkTotals totals;
  final int belowThresholdStudents;
  final List<RiskBandCount> riskBands;
  final int risingRiskCount;
  final int openIntegrityFlags;
  final String? denominatorNote;

  const TeacherSummary({
    this.attendancePct,
    this.students = 0,
    this.sessions = 0,
    this.totals = const MarkTotals(),
    this.belowThresholdStudents = 0,
    this.riskBands = const [],
    this.risingRiskCount = 0,
    this.openIntegrityFlags = 0,
    this.denominatorNote,
  });

  factory TeacherSummary.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return TeacherSummary(
      attendancePct: asDouble(j['attendance_pct']),
      students: asInt(j['students']),
      sessions: asInt(j['sessions']),
      totals: MarkTotals.fromJson(j),
      belowThresholdStudents: asInt(j['below_threshold_students']),
      // `risk.band_distribution` returns a {band: count} dict, not a list.
      riskBands: bandRowsOf(j['risk_bands'], RiskBandCount.bandOrder)
          .map(RiskBandCount.fromJson)
          .toList(),
      risingRiskCount: asInt(j['rising_risk_count']),
      openIntegrityFlags: asInt(j['open_integrity_flags']),
      denominatorNote: asStringOrNull(j['denominator_note']),
    );
  }
}

/// One class in the teacher's portfolio (`health.portfolio_comparison`).
///
/// The score, grade and trend live under a nested `health` object, and the
/// z-standing lives at the top level. Reading `health_score`/`slope` off the
/// top level is why every class card showed no band and "0 below requirement".
class ClassHealthRow {
  final int? classId;
  final String classCode;
  final String className;
  final double? attendancePct;
  final int students;
  final int sessions;
  final CohortHealth health;
  final double? portfolioZ;
  final String? portfolioStanding;
  final Map<String, dynamic> raw;

  const ClassHealthRow({
    this.classId,
    this.classCode = '—',
    this.className = '',
    this.attendancePct,
    this.students = 0,
    this.sessions = 0,
    this.health = const CohortHealth(),
    this.portfolioZ,
    this.portfolioStanding,
    this.raw = const {},
  });

  factory ClassHealthRow.fromJson(Map<String, dynamic> j) {
    final health = CohortHealth.fromJson(j['health']);
    return ClassHealthRow(
      classId: asIntOrNull(j['class_id']),
      classCode: asStringOrNull(j['class_code']) ?? '—',
      className: asStringOrNull(j['class_name']) ?? '',
      attendancePct: asDouble(j['attendance_pct']),
      students: asInt(j['students']),
      sessions: asInt(j['sessions'] ?? j['sessions_held']),
      health: health,
      portfolioZ: asDouble(j['portfolio_z']),
      portfolioStanding: asStringOrNull(j['portfolio_standing']),
      raw: j,
    );
  }

  double? get healthScore => health.score;
  String? get healthGrade => health.grade;

  /// Trend comes from the nested health block, which is the only place the
  /// backend computes it per class.
  double? get slopePtsPerSession => health.cohortSlopePtsPerSession;

  double? get gini => health.gini;

  int get belowThreshold => health.belowThresholdCount;

  /// A band string the shared colour helpers understand, derived from the
  /// letter grade rather than invented.
  String? get healthBand {
    switch (health.grade?.toUpperCase()) {
      case 'A':
        return 'stable';
      case 'B':
        return 'low';
      case 'C':
        return 'watch';
      case 'D':
        return 'high';
      case 'F':
        return 'critical';
      default:
        return null;
    }
  }

  String? get standingLabel {
    switch (portfolioStanding) {
      case 'strongest':
        return 'Strongest in your portfolio';
      case 'weakest':
        return 'Weakest in your portfolio';
      case 'typical':
        return 'Typical for your portfolio';
      case 'insufficient_classes':
        return null;
      default:
        return null;
    }
  }
}

/// Temporal breakdowns from the teacher overview's `temporal` block.
///
/// Each sub-block arrives as `{rows: [...], finding: '...'}` (and the heatmap as
/// `{cells: [...], slots: [...], weekdays: [...]}`), which is why reading them
/// as bare lists produced three permanently empty panels.
class TemporalPatterns {
  final PatternBlock weekday;
  final PatternBlock timeSlots;
  final HeatmapData heatmap;
  final Punctuality punctuality;

  const TemporalPatterns({
    this.weekday = const PatternBlock(),
    this.timeSlots = const PatternBlock(),
    this.heatmap = const HeatmapData(),
    this.punctuality = const Punctuality(),
  });

  factory TemporalPatterns.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return TemporalPatterns(
      weekday: PatternBlock.fromJson(j['weekday']),
      timeSlots: PatternBlock.fromJson(j['time_slots']),
      heatmap: HeatmapData.fromJson(j['heatmap']),
      punctuality: Punctuality.fromJson(j['punctuality']),
    );
  }

  bool get isEmpty =>
      weekday.isEmpty &&
      timeSlots.isEmpty &&
      heatmap.isEmpty &&
      !punctuality.isAvailable;
}

/// Cohort-level integrity summary (`integrity.integrity_summary`).
///
/// Carries the counts by type/severity, the verification-score distribution and
/// the detector catalogue, all of which the backend computes and the UI
/// previously discarded.
class IntegritySummary {
  final List<IntegrityFlag> openFlags;
  final int openCount;
  final Map<String, int> byType;
  final Map<String, int> bySeverity;
  final int newlyDetected;
  final int previouslyKnown;
  final double? verificationMedian;
  final double? verificationP10;
  final int verificationSampleSize;
  final List<({String name, String description})> detectors;
  final String? note;

  const IntegritySummary({
    this.openFlags = const [],
    this.openCount = 0,
    this.byType = const {},
    this.bySeverity = const {},
    this.newlyDetected = 0,
    this.previouslyKnown = 0,
    this.verificationMedian,
    this.verificationP10,
    this.verificationSampleSize = 0,
    this.detectors = const [],
    this.note,
  });

  factory IntegritySummary.fromJson(dynamic v) {
    final j = asMap(v);
    final verification = asMap(j['verification']);
    return IntegritySummary(
      openFlags:
          asMapList(j['open_flags']).map(IntegrityFlag.fromJson).toList(),
      openCount: asInt(j['open_count']),
      byType: {
        for (final e in asMap(j['by_type']).entries) e.key: asInt(e.value),
      },
      bySeverity: {
        for (final e in asMap(j['by_severity']).entries) e.key: asInt(e.value),
      },
      newlyDetected: asInt(j['newly_detected']),
      previouslyKnown: asInt(j['previously_known']),
      verificationMedian: asDouble(verification['median']),
      verificationP10: asDouble(verification['p10']),
      verificationSampleSize: asInt(verification['sample_size']),
      detectors: [
        for (final d in asMapList(j['detectors']))
          (
            name: asStringOrNull(d['name']) ?? '',
            description: asStringOrNull(d['description']) ?? '',
          ),
      ],
      note: asStringOrNull(j['note']),
    );
  }

  bool get isEmpty => openCount == 0 && byType.isEmpty;

  bool get hasVerification => verificationSampleSize > 0;

  /// Severity counts in escalating order, skipping severities with no flags.
  List<({String severity, int count})> get orderedSeverities {
    const order = ['critical', 'warning', 'info'];
    return [
      for (final s in order)
        if ((bySeverity[s] ?? 0) > 0) (severity: s, count: bySeverity[s]!),
    ];
  }

  /// Flag types ordered by count, so the most common signal reads first.
  List<({String type, int count})> get orderedTypes {
    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) (type: e.key, count: e.value)];
  }
}

class TeacherOverview {
  final AnalyticsMeta meta;
  final String? reason;
  final TeacherSummary? summary;
  final CohortHealth health;
  final List<ClassHealthRow> classes;
  final Distribution distribution;
  final TrendSeries trend;
  final TemporalPatterns temporal;
  final IntegritySummary integrity;
  final List<Insight> insights;

  const TeacherOverview({
    required this.meta,
    this.reason,
    this.summary,
    this.health = const CohortHealth(),
    this.classes = const [],
    this.distribution = const Distribution(),
    this.trend = const TrendSeries(),
    this.temporal = const TemporalPatterns(),
    this.integrity = const IntegritySummary(),
    this.insights = const [],
  });

  factory TeacherOverview.fromJson(Map<String, dynamic> j) => TeacherOverview(
        meta: AnalyticsMeta.fromJson(asMapOrNull(j['meta'])),
        reason: asStringOrNull(j['reason']),
        summary: j['summary'] == null
            ? null
            : TeacherSummary.fromJson(asMapOrNull(j['summary'])),
        health: CohortHealth.fromJson(j['health']),
        classes: asMapList(j['classes']).map(ClassHealthRow.fromJson).toList(),
        distribution: Distribution.fromJson(asMapOrNull(j['distribution'])),
        trend: TrendSeries.fromJson(asMapOrNull(j['trend'])),
        temporal: TemporalPatterns.fromJson(asMapOrNull(j['temporal'])),
        integrity: IntegritySummary.fromJson(j['integrity']),
        insights: Insight.listFrom(j['insights']),
      );

  static TeacherOverview get empty =>
      const TeacherOverview(meta: AnalyticsMeta.empty);

  double? get cohortSlope =>
      trend.cohortSlopePtsPerSession ?? health.cohortSlopePtsPerSession;
}

// --------------------------------------------------------- teacher: at-risk

/// One risk-scored student (`risk.score_student`).
///
/// Carries the component scores, their weights and the backend's own reason
/// strings, so a score shown on screen can always be explained.
class AtRiskStudent {
  final int? studentId;
  final String name;
  final String? username;
  final double? riskScore;
  final String? band;
  final double? attendancePct;
  final int present;
  final int expected;
  final int absent;
  final double? slope;
  final double? recentWeightedPct;
  final double? volatility;
  final int currentAbsentStreak;
  final int currentPresentStreak;
  final int longestAbsentStreak;
  final String? confidence;
  final List<String> drivers;
  final Map<String, double> components;
  final Map<String, double> weights;
  final List<double> sparkline;
  final List<double> series;
  final Map<String, dynamic> raw;

  const AtRiskStudent({
    this.studentId,
    this.name = '—',
    this.username,
    this.riskScore,
    this.band,
    this.attendancePct,
    this.present = 0,
    this.expected = 0,
    this.absent = 0,
    this.slope,
    this.recentWeightedPct,
    this.volatility,
    this.currentAbsentStreak = 0,
    this.currentPresentStreak = 0,
    this.longestAbsentStreak = 0,
    this.confidence,
    this.drivers = const [],
    this.components = const {},
    this.weights = const {},
    this.sparkline = const [],
    this.series = const [],
    this.raw = const {},
  });

  factory AtRiskStudent.fromJson(Map<String, dynamic> j) => AtRiskStudent(
        studentId: asIntOrNull(j['student_id']),
        name: () {
          final full = asStringOrNull(j['name'] ?? j['student_name']);
          if (full != null && full.trim().isNotEmpty) return full;
          return asStringOrNull(j['username']) ?? '—';
        }(),
        username: asStringOrNull(j['username']),
        riskScore: asDouble(j['risk_score'] ?? j['score']),
        band: asStringOrNull(j['risk_band'] ?? j['band']),
        attendancePct: asDouble(j['attendance_pct']),
        present: asInt(j['present']),
        expected: asInt(j['expected']),
        absent: asInt(j['absent']),
        slope: asDouble(j['trend_slope_per_session'] ?? j['slope']),
        recentWeightedPct: asDouble(j['recent_weighted_pct']),
        volatility: asDouble(j['volatility']),
        currentAbsentStreak: asInt(j['current_absent_streak']),
        currentPresentStreak: asInt(j['current_present_streak']),
        longestAbsentStreak: asInt(j['longest_absent_streak']),
        confidence: asStringOrNull(j['confidence']),
        drivers: asStringList(j['reasons'] ?? j['drivers']),
        components: {
          for (final e in asMap(j['components']).entries)
            if (asDouble(e.value) != null) e.key: asDouble(e.value)!,
        },
        weights: {
          for (final e in asMap(j['weights']).entries)
            if (asDouble(e.value) != null) e.key: asDouble(e.value)!,
        },
        sparkline: asDoubleList(j['sparkline']),
        series: asDoubleList(j['series']),
        raw: j,
      );

  /// Points below the requirement. Derived from the returned percentage rather
  /// than read from a field the backend does not send.
  double? deficitPoints(double requiredPct) {
    if (attendancePct == null) return null;
    final gap = requiredPct - attendancePct!;
    return gap > 0 ? gap : null;
  }

  /// Present marks needed, at perfect attendance, to reach [requiredPct].
  /// Mirrors `metrics.min_sessions_needed`, computed locally because the
  /// at-risk endpoint does not include it.
  int? sessionsNeededToRecover(double requiredPct) {
    if (expected == 0 || attendancePct == null) return null;
    if (attendancePct! >= requiredPct) return 0;
    final t = requiredPct / 100.0;
    if (t >= 1.0) return null;
    final needed = (t * expected - present) / (1 - t);
    return needed <= 0 ? 0 : needed.ceil();
  }

  /// Components sorted by their contribution (value x weight), heaviest first —
  /// the order that answers "why is this student flagged".
  List<({String key, double value, double weight, double contribution})>
      get rankedComponents {
    final rows = [
      for (final e in components.entries)
        (
          key: e.key,
          value: e.value,
          weight: weights[e.key] ?? 0,
          contribution: e.value * (weights[e.key] ?? 0),
        ),
    ]..sort((a, b) => b.contribution.compareTo(a.contribution));
    return rows;
  }

  bool get isLowConfidence => confidence == 'low' || confidence == 'none';
}

class TeacherAtRisk {
  final AnalyticsMeta meta;
  final List<RiskBandCount> bands;
  final Map<String, double> weights;
  final String? scoringNote;
  final List<AtRiskStudent> students;
  final List<AtRiskStudent> risingRisk;
  final int total;

  const TeacherAtRisk({
    required this.meta,
    this.bands = const [],
    this.weights = const {},
    this.scoringNote,
    this.students = const [],
    this.risingRisk = const [],
    this.total = 0,
  });

  factory TeacherAtRisk.fromJson(Map<String, dynamic> j) => TeacherAtRisk(
        meta: AnalyticsMeta.fromJson(asMapOrNull(j['meta'])),
        // `bands` is a {band: count} dict from `risk.band_distribution`.
        bands: bandRowsOf(j['bands'], RiskBandCount.bandOrder)
            .map(RiskBandCount.fromJson)
            .toList(),
        weights: {
          for (final e in asMap(j['weights']).entries)
            if (asDouble(e.value) != null) e.key: asDouble(e.value)!,
        },
        scoringNote: asStringOrNull(j['scoring_note']),
        students: asMapList(j['students']).map(AtRiskStudent.fromJson).toList(),
        risingRisk:
            asMapList(j['rising_risk']).map(AtRiskStudent.fromJson).toList(),
        total: asInt(j['total']),
      );

  static TeacherAtRisk get empty =>
      const TeacherAtRisk(meta: AnalyticsMeta.empty);

  /// Students whose band is above "stable" — the actionable triage list.
  List<AtRiskStudent> get actionable =>
      students.where((s) => s.band != null && s.band != 'stable').toList();
}

// --------------------------------------------------- teacher: student detail

/// Per-student drill-down for a student in the teacher's classes.
class TeacherStudentDetail {
  final AnalyticsMeta meta;
  final int? studentId;
  final String name;
  final String? username;
  final double? overallPct;
  final MarkTotals overall;
  final AtRiskStudent risk;
  final List<ClassAnalyticsRow> perClass;
  final PatternBlock temporal;

  const TeacherStudentDetail({
    required this.meta,
    this.studentId,
    this.name = '—',
    this.username,
    this.overallPct,
    this.overall = const MarkTotals(),
    this.risk = const AtRiskStudent(),
    this.perClass = const [],
    this.temporal = const PatternBlock(),
  });

  factory TeacherStudentDetail.fromJson(Map<String, dynamic> j) {
    final student = asMap(j['student']);
    final overall = asMap(j['overall']);
    final fullName = asStringOrNull(student['name']);
    return TeacherStudentDetail(
      meta: AnalyticsMeta.fromJson(asMapOrNull(j['meta'])),
      studentId: asIntOrNull(student['student_id']),
      name: (fullName != null && fullName.trim().isNotEmpty)
          ? fullName
          : (asStringOrNull(student['username']) ?? '—'),
      username: asStringOrNull(student['username']),
      overallPct: asDouble(overall['attendance_pct']),
      overall: MarkTotals.fromJson(overall),
      risk: AtRiskStudent.fromJson(asMap(j['risk'])),
      perClass:
          asMapList(j['per_class']).map(ClassAnalyticsRow.fromJson).toList(),
      temporal: PatternBlock.fromJson(j['temporal']),
    );
  }
}

// ------------------------------------------------------- teacher: integrity

class IntegrityFlag {
  final int id;
  final String flagType;
  final String flagLabel;
  final String severity;
  final double? score;
  final String status;
  final int? studentId;
  final String? studentName;
  final int? sessionId;
  final int? classId;
  final Map<String, dynamic> evidence;
  final String? explanation;
  final String? createdAt;
  final String? resolutionNote;
  final String? resolvedAt;

  const IntegrityFlag({
    required this.id,
    this.flagType = '',
    this.flagLabel = '',
    this.severity = 'info',
    this.score,
    this.status = 'open',
    this.studentId,
    this.studentName,
    this.sessionId,
    this.classId,
    this.evidence = const {},
    this.explanation,
    this.createdAt,
    this.resolutionNote,
    this.resolvedAt,
  });

  factory IntegrityFlag.fromJson(Map<String, dynamic> j) => IntegrityFlag(
        id: asInt(j['id']),
        flagType: asStringOrNull(j['flag_type']) ?? '',
        flagLabel: asStringOrNull(j['flag_label']) ??
            asStringOrNull(j['flag_type']) ??
            '',
        severity: asStringOrNull(j['severity']) ?? 'info',
        score: asDouble(j['score']),
        status: asStringOrNull(j['status']) ?? 'open',
        studentId: asIntOrNull(j['student_id']),
        studentName: asStringOrNull(j['student_name']),
        sessionId: asIntOrNull(j['session_id']),
        classId: asIntOrNull(j['class_id']),
        evidence: asMap(j['evidence']),
        explanation: asStringOrNull(j['explanation']),
        createdAt: asStringOrNull(j['created_at']),
        resolutionNote: asStringOrNull(j['resolution_note']),
        resolvedAt: asStringOrNull(j['resolved_at']),
      );

  bool get isOpen => status == 'open';
}

class IntegrityFlagPage {
  final AnalyticsMeta meta;
  final List<IntegrityFlag> flags;
  final int count;
  final String? note;

  const IntegrityFlagPage({
    required this.meta,
    this.flags = const [],
    this.count = 0,
    this.note,
  });

  factory IntegrityFlagPage.fromJson(Map<String, dynamic> j) =>
      IntegrityFlagPage(
        meta: AnalyticsMeta.fromJson(asMapOrNull(j['meta'])),
        flags: asMapList(j['flags']).map(IntegrityFlag.fromJson).toList(),
        count: asInt(j['count']),
        note: asStringOrNull(j['note']),
      );

  static IntegrityFlagPage get empty =>
      const IntegrityFlagPage(meta: AnalyticsMeta.empty);
}

// -------------------------------------------------------- student: overview

/// One class row on a student dashboard, including forecast provenance.
class ClassAnalyticsRow {
  final int? classId;
  final String classCode;
  final String className;
  final double? attendancePct;
  final MarkTotals totals;
  final int sessionsHeld;
  final bool? meetsThreshold;
  final double? trendSlopePerSession;
  final double? recentWeightedPct;
  final double? volatility;
  final StreakInfo streaks;
  final List<double> sparkline;
  final List<double> series;
  final RemainingInfo remaining;
  final PointOfNoReturn forecast;
  final int? sessionsNeededToRecover;
  final CanMissInfo canMiss;
  final ForecastDistribution projection;
  final double? projectedPctIfPerfect;
  final CohortPosition cohort;
  final Map<String, dynamic> raw;

  const ClassAnalyticsRow({
    this.classId,
    this.classCode = '—',
    this.className = '',
    this.attendancePct,
    this.totals = const MarkTotals(),
    this.sessionsHeld = 0,
    this.meetsThreshold,
    this.trendSlopePerSession,
    this.recentWeightedPct,
    this.volatility,
    this.streaks = const StreakInfo(),
    this.sparkline = const [],
    this.series = const [],
    this.remaining = const RemainingInfo(),
    this.forecast = const PointOfNoReturn(),
    this.sessionsNeededToRecover,
    this.canMiss = const CanMissInfo(),
    this.projection = const ForecastDistribution(status: 'missing'),
    this.projectedPctIfPerfect,
    this.cohort = const CohortPosition(),
    this.raw = const {},
  });

  factory ClassAnalyticsRow.fromJson(Map<String, dynamic> j) =>
      ClassAnalyticsRow(
        classId: asIntOrNull(j['class_id']),
        classCode: asStringOrNull(j['class_code']) ?? '—',
        className: asStringOrNull(j['class_name']) ?? '',
        attendancePct: asDouble(j['attendance_pct']),
        totals: MarkTotals.fromJson(j),
        sessionsHeld: asInt(j['sessions_held']),
        meetsThreshold: asBoolOrNull(j['meets_threshold']),
        trendSlopePerSession: asDouble(j['trend_slope_per_session']),
        recentWeightedPct: asDouble(j['recent_weighted_pct']),
        volatility: asDouble(j['volatility']),
        streaks: StreakInfo.fromJson(asMapOrNull(j['streaks'])),
        sparkline: asDoubleList(j['sparkline']),
        series: asDoubleList(j['series']),
        remaining: RemainingInfo.fromJson(asMapOrNull(j['remaining'])),
        forecast: PointOfNoReturn.fromJson(asMapOrNull(j['forecast'])),
        sessionsNeededToRecover:
            asIntOrNull(j['sessions_needed_to_recover']),
        canMiss: CanMissInfo.fromJson(j['can_miss']),
        projection: ForecastDistribution.fromJson(asMapOrNull(j['projection'])),
        projectedPctIfPerfect: asDouble(j['projected_pct_if_perfect']),
        cohort: CohortPosition.fromJson(asMapOrNull(j['cohort'])),
        raw: j,
      );

  bool get projectionAvailable => projection.isAvailable;
}

class StudentOverall {
  final double? attendancePct;
  final MarkTotals totals;
  final bool? meetsThreshold;
  final double? marginPoints;
  final StreakInfo streaks;
  final double? recentWeightedPct;
  final double? trendSlopePerSession;
  final List<double> sparkline;
  final int classesBelowThreshold;
  final int? remainingSessionsEstimated;

  const StudentOverall({
    this.attendancePct,
    this.totals = const MarkTotals(),
    this.meetsThreshold,
    this.marginPoints,
    this.streaks = const StreakInfo(),
    this.recentWeightedPct,
    this.trendSlopePerSession,
    this.sparkline = const [],
    this.classesBelowThreshold = 0,
    this.remainingSessionsEstimated,
  });

  factory StudentOverall.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return StudentOverall(
      attendancePct: asDouble(j['attendance_pct']),
      totals: MarkTotals.fromJson(j),
      meetsThreshold: asBoolOrNull(j['meets_threshold']),
      marginPoints: asDouble(j['margin_points']),
      streaks: StreakInfo.fromJson(asMapOrNull(j['streaks'])),
      recentWeightedPct: asDouble(j['recent_weighted_pct']),
      trendSlopePerSession: asDouble(j['trend_slope_per_session']),
      sparkline: asDoubleList(j['sparkline']),
      classesBelowThreshold: asInt(j['classes_below_threshold']),
      remainingSessionsEstimated:
          asIntOrNull(j['remaining_sessions_estimated']),
    );
  }
}

class StudentOverview {
  final AnalyticsMeta meta;
  final String? reason;
  final StudentOverall? overall;
  final List<ClassAnalyticsRow> perClass;
  final PatternBlock temporal;
  final List<Insight> insights;

  const StudentOverview({
    required this.meta,
    this.reason,
    this.overall,
    this.perClass = const [],
    this.temporal = const PatternBlock(),
    this.insights = const [],
  });

  factory StudentOverview.fromJson(Map<String, dynamic> j) => StudentOverview(
        meta: AnalyticsMeta.fromJson(asMapOrNull(j['meta'])),
        reason: asStringOrNull(j['reason']),
        overall: j['overall'] == null
            ? null
            : StudentOverall.fromJson(asMapOrNull(j['overall'])),
        perClass:
            asMapList(j['per_class']).map(ClassAnalyticsRow.fromJson).toList(),
        temporal: PatternBlock.fromJson(j['temporal']),
        insights: Insight.listFrom(j['insights']),
      );

  static StudentOverview get empty =>
      const StudentOverview(meta: AnalyticsMeta.empty);

  /// Classes where the requirement can no longer be reached, or where one more
  /// absence decides it. Sorted worst first.
  List<ClassAnalyticsRow> get classesNeedingAttention {
    final rows =
        perClass.where((c) => c.forecast.needsAttention).toList();
    rows.sort((a, b) {
      final order = {'unreachable': 0, 'critical': 1, 'tight': 2};
      return (order[a.forecast.status] ?? 3)
          .compareTo(order[b.forecast.status] ?? 3);
    });
    return rows;
  }
}

// -------------------------------------------------------- student: calendar

class CalendarSession {
  final int? sessionId;
  final int? classId;
  final String classCode;
  final String className;
  final String? startTime;
  final int? durationMinutes;
  final String status;
  final double? latencySeconds;
  final double? verificationScore;

  const CalendarSession({
    this.sessionId,
    this.classId,
    this.classCode = '—',
    this.className = '',
    this.startTime,
    this.durationMinutes,
    this.status = 'unrecorded',
    this.latencySeconds,
    this.verificationScore,
  });

  factory CalendarSession.fromJson(Map<String, dynamic> j) => CalendarSession(
        sessionId: asIntOrNull(j['session_id']),
        classId: asIntOrNull(j['class_id']),
        classCode: asStringOrNull(j['class_code']) ?? '—',
        className: asStringOrNull(j['class_name']) ?? '',
        startTime: asStringOrNull(j['start_time']),
        durationMinutes: asIntOrNull(j['duration_minutes']),
        status: asStringOrNull(j['status']) ?? 'unrecorded',
        latencySeconds: asDouble(j['latency_seconds']),
        verificationScore: asDouble(j['verification_score']),
      );
}

class CalendarDay {
  final String date;
  final int present;
  final int total;
  final double? attendancePct;
  final String? dayStatus;
  final List<CalendarSession> sessions;

  const CalendarDay({
    required this.date,
    this.present = 0,
    this.total = 0,
    this.attendancePct,
    this.dayStatus,
    this.sessions = const [],
  });

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
        date: asStringOrNull(j['date']) ?? '',
        present: asInt(j['present']),
        total: asInt(j['total']),
        attendancePct: asDouble(j['attendance_pct']),
        dayStatus: asStringOrNull(j['day_status']),
        sessions:
            asMapList(j['sessions']).map(CalendarSession.fromJson).toList(),
      );

  /// Day-level state. Prefers the backend's own `day_status`, falling back to
  /// the counts rather than inventing a third rule.
  String get state {
    if (dayStatus != null) return dayStatus!;
    if (total == 0) return 'none';
    if (present == total) return 'present';
    if (present == 0) return 'absent';
    return 'partial';
  }

  int? get dayNumber {
    if (date.length < 10) return null;
    return int.tryParse(date.substring(8, 10));
  }
}

class StudentCalendar {
  final AnalyticsMeta meta;
  final List<CalendarDay> days;
  final double? attendancePct;
  final MarkTotals totals;
  final int daysRecorded;

  const StudentCalendar({
    required this.meta,
    this.days = const [],
    this.attendancePct,
    this.totals = const MarkTotals(),
    this.daysRecorded = 0,
  });

  factory StudentCalendar.fromJson(Map<String, dynamic> j) {
    final t = asMap(j['totals']);
    return StudentCalendar(
      meta: AnalyticsMeta.fromJson(asMapOrNull(j['meta'])),
      days: asMapList(j['days']).map(CalendarDay.fromJson).toList(),
      attendancePct: asDouble(t['attendance_pct']),
      totals: MarkTotals.fromJson(t),
      daysRecorded: asInt(t['days_recorded']),
    );
  }

  static StudentCalendar get empty =>
      const StudentCalendar(meta: AnalyticsMeta.empty);

  Map<String, CalendarDay> get byDate =>
      {for (final d in days) d.date: d};
}

// ------------------------------------------------------- student: simulator

/// One class's forecast scenario from `/analytics/student/simulate/`.
///
/// `attendRateUsed` is a rate in 0..1 (the backend rounds `attend_prob`), while
/// the request parameter is a percentage — the mismatch is handled in the
/// service layer, not here.
class ForecastScenario {
  final int? classId;
  final String classCode;
  final String status;
  final String? reason;
  final double? currentPct;
  final int present;
  final int expected;
  final RemainingInfo remaining;
  final double? attendRateUsed;
  final String? attendRateSource;
  final double? projectedPct;
  final double? projectedPctIfPerfect;
  final ForecastDistribution distribution;
  final CanMissInfo canMiss;
  final PointOfNoReturn pointOfNoReturn;

  const ForecastScenario({
    this.classId,
    this.classCode = '—',
    this.status = 'ok',
    this.reason,
    this.currentPct,
    this.present = 0,
    this.expected = 0,
    this.remaining = const RemainingInfo(),
    this.attendRateUsed,
    this.attendRateSource,
    this.projectedPct,
    this.projectedPctIfPerfect,
    this.distribution = const ForecastDistribution(status: 'missing'),
    this.canMiss = const CanMissInfo(),
    this.pointOfNoReturn = const PointOfNoReturn(),
  });

  factory ForecastScenario.fromJson(Map<String, dynamic> j) => ForecastScenario(
        classId: asIntOrNull(j['class_id']),
        classCode: asStringOrNull(j['class_code']) ?? '—',
        status: asStringOrNull(j['status']) ?? 'ok',
        reason: asStringOrNull(j['reason']),
        currentPct: asDouble(j['current_pct']),
        present: asInt(j['present']),
        expected: asInt(j['expected']),
        remaining: RemainingInfo.fromJson(asMapOrNull(j['remaining'])),
        attendRateUsed: asDouble(j['attend_rate_used']),
        attendRateSource: asStringOrNull(j['attend_rate_source']),
        projectedPct: asDouble(j['projected_pct']),
        projectedPctIfPerfect: asDouble(j['projected_pct_if_perfect']),
        distribution:
            ForecastDistribution.fromJson(asMapOrNull(j['distribution'])),
        canMiss: CanMissInfo.fromJson(j['can_miss']),
        pointOfNoReturn:
            PointOfNoReturn.fromJson(asMapOrNull(j['point_of_no_return'])),
      );

  bool get isAvailable => status == 'ok';

  /// Assumed future attendance as a percentage, for display.
  double? get attendPctUsed =>
      attendRateUsed == null ? null : attendRateUsed! * 100.0;

  bool get isOverride => attendRateSource == 'override';
}

class SimulatorResult {
  final AnalyticsMeta meta;
  final List<ForecastScenario> scenarios;
  final String? note;

  const SimulatorResult({
    required this.meta,
    this.scenarios = const [],
    this.note,
  });

  factory SimulatorResult.fromJson(Map<String, dynamic> j) => SimulatorResult(
        meta: AnalyticsMeta.fromJson(asMapOrNull(j['meta'])),
        scenarios:
            asMapList(j['scenarios']).map(ForecastScenario.fromJson).toList(),
        note: asStringOrNull(j['note']),
      );

  static SimulatorResult get empty =>
      const SimulatorResult(meta: AnalyticsMeta.empty);
}


import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/analytics_models.dart';
import 'storage_service.dart';

/// Raised when an analytics endpoint fails. Screens surface [message] instead
/// of silently rendering an empty state, so a network/permission failure is
/// never mistaken for "you have no attendance data".
class AnalyticsException implements Exception {
  final String message;
  final int? statusCode;

  AnalyticsException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thin typed wrapper over the `/analytics/*` endpoints.
///
/// Every method either returns a fully parsed model or throws
/// [AnalyticsException]. It never invents data to fill a gap.
class AnalyticsService {
  final Dio _dio = ApiClient().dio;

  Future<Options> _authOptions() async {
    final token = await StorageService.read(key: 'access_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: _clean(query),
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AnalyticsException(
        'Unexpected response shape from $path',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw AnalyticsException(_describe(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: body ?? const {},
        options: await _authOptions(),
      );
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AnalyticsException(
        'Unexpected response shape from $path',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw AnalyticsException(_describe(e), statusCode: e.response?.statusCode);
    }
  }

  /// Drops null/empty params so we never send `class_id=` and change the scope
  /// the backend resolves.
  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out.isEmpty ? null : out;
  }

  String _describe(DioException e) {
    final res = e.response;
    if (res != null) {
      final data = res.data;
      if (data is Map) {
        final msg = data['error'] ?? data['detail'] ?? data['message'];
        if (msg != null) return msg.toString();
      }
      switch (res.statusCode) {
        case 401:
          return 'Your session has expired. Please sign in again.';
        case 403:
          return 'You do not have permission to view this analytics view.';
        case 404:
          return 'That analytics resource no longer exists.';
        default:
          return 'Server error (${res.statusCode}).';
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The request timed out. Check your connection and retry.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Check your connection and retry.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return 'Network error: ${e.message ?? 'unknown'}';
    }
  }

  // ------------------------------------------------------------------ teacher

  /// Cohort overview. [classId] narrows scope to a single class; [termId] may
  /// be a term primary key or the literal `'all'`.
  Future<TeacherOverview> teacherOverview({
    String? classId,
    String? termId,
  }) async {
    final json = await _get(
      '/analytics/teacher/overview/',
      query: {'class_id': classId, 'term_id': termId},
    );
    return TeacherOverview.fromJson(json);
  }

  /// Risk-ranked triage list.
  Future<TeacherAtRisk> teacherAtRisk({
    String? classId,
    String? termId,
    double? threshold,
    int? limit,
  }) async {
    final json = await _get(
      '/analytics/teacher/at-risk/',
      query: {
        'class_id': classId,
        'term_id': termId,
        'threshold': threshold,
        'limit': limit,
      },
    );
    return TeacherAtRisk.fromJson(json);
  }

  /// Per-student drill-down for a student in the teacher's classes.
  Future<TeacherStudentDetail> teacherStudentDetail(
    int studentId, {
    String? classId,
    String? termId,
  }) async {
    final json = await _get(
      '/analytics/teacher/student/$studentId/',
      query: {'class_id': classId, 'term_id': termId},
    );
    return TeacherStudentDetail.fromJson(json);
  }

  /// Advisory integrity flags. [status] accepts `open`, `resolved`,
  /// `dismissed`, or `all`.
  Future<IntegrityFlagPage> integrityFlags({
    String status = 'open',
    String? classId,
    String? termId,
  }) async {
    final json = await _get(
      '/analytics/teacher/flags/',
      query: {'status': status, 'class_id': classId, 'term_id': termId},
    );
    return IntegrityFlagPage.fromJson(json);
  }

  /// Resolve or dismiss a flag. Flags are advisory; this never edits marks.
  Future<void> resolveIntegrityFlag(
    int flagId, {
    required String status,
    String? note,
  }) async {
    await _post(
      '/analytics/teacher/flags/$flagId/resolve/',
      body: {
        'status': status,
        if (note != null && note.isNotEmpty) 'resolution_note': note,
      },
    );
  }

  // ------------------------------------------------------------------ student

  Future<StudentOverview> studentOverview({String? termId}) async {
    final json = await _get(
      '/analytics/student/overview/',
      query: {'term_id': termId},
    );
    return StudentOverview.fromJson(json);
  }

  /// Calendar of recorded sessions for one month.
  ///
  /// The endpoint filters by `from`/`to`/`days`, not by `year`/`month` — sending
  /// year/month was silently ignored, which is why the month arrows did nothing.
  /// Month bounds are converted here so callers keep a calendar-shaped API.
  Future<StudentCalendar> studentCalendar({
    int? year,
    int? month,
    String? classId,
    String? termId,
  }) async {
    String? from;
    String? to;
    if (year != null && month != null) {
      final first = DateTime(year, month, 1);
      final last = DateTime(year, month + 1, 0);
      from = _isoDate(first);
      to = _isoDate(last);
    }
    final json = await _get(
      '/analytics/student/calendar/',
      query: {
        'from': from,
        'to': to,
        'class_id': classId,
        'term_id': termId,
      },
    );
    return StudentCalendar.fromJson(json);
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Forecast simulator.
  ///
  /// [attendPct] is a percentage (0–100) because that is the parameter the
  /// endpoint reads (`attend_pct`, divided by 100 server-side). Sending
  /// `attend_rate` meant every slider position was discarded.
  Future<SimulatorResult> studentSimulate({
    double? attendPct,
    String? classId,
    String? termId,
  }) async {
    final json = await _get(
      '/analytics/student/simulate/',
      query: {
        'attend_pct': attendPct,
        'class_id': classId,
        'term_id': termId,
      },
    );
    return SimulatorResult.fromJson(json);
  }
}

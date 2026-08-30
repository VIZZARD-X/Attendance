import 'dart:convert';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'storage_service.dart';
import '../core/api_client.dart';

class AnnouncementService {
  final Dio _dio = ApiClient().dio;
  final String baseUrl = ApiConfig.baseUrl;

  AnnouncementService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = ApiConfig.connectionTimeout;
    _dio.options.receiveTimeout = ApiConfig.receiveTimeout;
  }

  Future<String?> _getToken() async {
    return await StorageService.read(key: 'access_token');
  }

  /// Get announcements for the current user
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '/announcements/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('Get announcements error: ${e.message}');
      return [];
    }
  }

  /// Create announcement
  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    required String targetType,
    int? targetClassId,
    int? targetStudentId,
    int? minAttendanceThreshold,
    required bool isUrgent,
  }) async {
    try {
      final token = await _getToken();
      final Map<String, dynamic> data = {
        'title': title,
        'content': content,
        'target_type': targetType,
        'is_urgent': isUrgent,
      };

      if (targetClassId != null) {
        data['target_class'] = targetClassId;
      }
      if (targetStudentId != null) {
        data['target_student_id'] = targetStudentId;
      }
      if (minAttendanceThreshold != null) {
        data['min_attendance_threshold'] = minAttendanceThreshold;
      }

      final response = await _dio.post(
        '/announcements/',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'announcement': response.data};
      }
      return {'success': false, 'message': 'Failed to create announcement'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to create announcement';
      if (e.response != null && e.response!.data is Map) {
        final data = e.response!.data;
        if (data.containsKey('error')) {
          errorMessage = data['error'];
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }
}

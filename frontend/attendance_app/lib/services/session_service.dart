import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'storage_service.dart';

class SessionService {
  final String baseUrl = ApiConfig.baseUrl; 
  final Dio _dio = Dio();
  

  SessionService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = ApiConfig.connectionTimeout;
    _dio.options.receiveTimeout = ApiConfig.receiveTimeout;
  }

  Future<String?> _getToken() async {
    return await StorageService.read(key: 'access_token');
  }

  /// Create a new attendance session
  Future<Map<String, dynamic>> createSession({
    required int classId,
    required int durationMinutes,
    String classType = 'online',
  }) async {
    try {
      final token = await _getToken();
      
      final response = await _dio.post(
        '/sessions/create/',
        data: {
          'class_id': classId,
          'duration_minutes': durationMinutes,
          'class_type': classType,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'session': response.data['session'],
        };
      }
      
      return {'success': false, 'message': 'Failed to create session'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to create session';
      if (e.response?.data is Map<String, dynamic>) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Get active sessions
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    try {
      final token = await _getToken();
      
      final response = await _dio.get(
        '/sessions/active/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['sessions']);
      }
      
      return [];
    } catch (e) {
      print('Error fetching active sessions: $e');
      return [];
    }
  }

  /// Get student active sessions
  Future<List<Map<String, dynamic>>> getStudentActiveSessions() async {
    try {
      final token = await _getToken();
      
      final response = await _dio.get(
        '/sessions/student-active/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['sessions']);
      }
      
      return [];
    } catch (e) {
      print('Error fetching student active sessions: $e');
      return [];
    }
  }

  /// Get session details
  Future<Map<String, dynamic>?> getSessionDetails(String sessionId) async {
    try {
      final token = await _getToken();
      
      final response = await _dio.get(
        '/sessions/$sessionId/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200) {
        return response.data;
      }
      
      return null;
    } catch (e) {
      print('Error fetching session details: $e');
      return null;
    }
  }

  /// End session and get statistics
  Future<Map<String, dynamic>> endSession(String sessionId) async {
    try {
      final token = await _getToken();
      
      final response = await _dio.post(
        '/sessions/$sessionId/end/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Session ended successfully',
          'statistics': response.data['statistics'] ?? {},
          'session': response.data['session'],
        };
      }
      
      return {
        'success': false,
        'message': 'Failed to end session'
      };
    } on DioException catch (e) {
      String errorMessage = 'Error ending session';
      if (e.response?.data is Map<String, dynamic>) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      print('Error ending session: $e');
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  /// Mark attendance (for students)
  Future<Map<String, dynamic>> markAttendance(String sessionId) async {
    try {
      final token = await _getToken();
      
      final response = await _dio.post(
        '/sessions/$sessionId/mark/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': response.data['message'],
        };
      }
      
      return {'success': false, 'message': 'Failed to mark attendance'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to mark attendance';
      if (e.response?.data is Map<String, dynamic>) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Get session attendance details with student list
  Future<Map<String, dynamic>?> getSessionAttendance(String sessionId) async {
    try {
      final token = await _getToken();
      
      final response = await _dio.get(
        '/sessions/$sessionId/attendance/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'session': response.data['session'],
          'students': List<Map<String, dynamic>>.from(
            response.data['students'] ?? []
          ),
          'statistics': response.data['statistics'] ?? {},
        };
      }
      
      return {'success': false};
    } catch (e) {
      print('Error fetching session attendance: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Teacher manually marks attendance for a student
  Future<Map<String, dynamic>> manualMarkAttendance({
    required String sessionId,
    required int studentId,
    required String status, // "present" or "absent"
  }) async {
    try {
      final token = await _getToken();
      
      final response = await _dio.post(
        '/sessions/$sessionId/mark-student/',
        data: {
          'student_id': studentId,
          'status': status,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'],
          'record': response.data['record'],
        };
      }
      
      return {'success': false, 'message': 'Failed to mark attendance'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to mark attendance';
      if (e.response?.data is Map<String, dynamic>) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Upload reference image for offline session
  Future<Map<String, dynamic>> uploadReferenceImage(String sessionId, String imagePath) async {
    try {
      final token = await _getToken();
      
      final formData = FormData.fromMap({
        'reference_image': await MultipartFile.fromFile(imagePath),
      });

      final response = await _dio.post(
        '/sessions/$sessionId/upload-reference/',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Reference image uploaded successfully'};
      }
      
      return {'success': false, 'message': 'Failed to upload image'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to upload image';
      if (e.response?.data is Map<String, dynamic>) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }
}
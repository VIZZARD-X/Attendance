import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import 'offline_verification_screen.dart';

class OfflineSessionsScreen extends StatefulWidget {
  const OfflineSessionsScreen({super.key});

  @override
  State<OfflineSessionsScreen> createState() => _OfflineSessionsScreenState();
}

class _OfflineSessionsScreenState extends State<OfflineSessionsScreen> {
  final SessionService _sessionService = SessionService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _offlineSessions = [];

  @override
  void initState() {
    super.initState();
    _fetchOfflineSessions();
  }

  Future<void> _fetchOfflineSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _sessionService.getStudentActiveSessions();
      setState(() {
        _offlineSessions = sessions.where((s) => s['class_type'] == 'offline').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sessions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Attendance'),
        backgroundColor: const Color(0xFF007C91),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _offlineSessions.isEmpty
              ? const Center(
                  child: Text(
                    'No active offline sessions found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _offlineSessions.length,
                  itemBuilder: (context, index) {
                    final session = _offlineSessions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007C91).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.class_rounded, color: Color(0xFF007C91)),
                        ),
                        title: Text(
                          session['class_code'] ?? 'Unknown Class',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Teacher: ${session['teacher_name'] ?? 'Unknown'}'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OfflineVerificationScreen(
                                sessionId: session['session_id'],
                                classCode: session['class_code'] ?? '',
                              ),
                            ),
                          ).then((_) => _fetchOfflineSessions());
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import 'package:intl/intl.dart';

class SessionEditScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;

  const SessionEditScreen({super.key, required this.sessionData});

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  final SessionService _sessionService = SessionService();
  bool isLoading = true;
  bool isSaving = false;

  late TextEditingController _durationController;
  DateTime? _selectedStartTime;
  List<Map<String, dynamic>> _students = [];
  Map<int, String> _studentStatuses = {}; // student_id -> status ('present', 'absent')

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
        text: widget.sessionData['duration_minutes']?.toString() ?? '45');
    
    final startTimeStr = widget.sessionData['start_time_ist'] ?? widget.sessionData['start_time'];
    if (startTimeStr != null) {
      try {
        _selectedStartTime = DateTime.parse(startTimeStr);
        if (!startTimeStr.contains('+') && !startTimeStr.contains('Z')) {
          _selectedStartTime = DateTime.parse(startTimeStr).toUtc().toLocal();
        }
      } catch (e) {
        _selectedStartTime = DateTime.now();
      }
    }

    _fetchSessionDetails();
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _fetchSessionDetails() async {
    setState(() => isLoading = true);
    try {
      final result = await _sessionService.getSessionAttendance(widget.sessionData['session_id']);
      if (result != null && result['success'] == true) {
        if (mounted) {
          setState(() {
            _students = List<Map<String, dynamic>>.from(result['students'] ?? []);
            _studentStatuses.clear();
            for (var student in _students) {
              _studentStatuses[student['student_id']] = student['status'];
            }
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => isLoading = false);
          _showErrorSnackBar('Failed to load session details');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Error loading details: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedStartTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF007C91)),
          ),
          child: child!,
        );
      },
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedStartTime ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF007C91)),
            ),
            child: child!,
          );
        },
      );
      if (time != null && mounted) {
        setState(() {
          _selectedStartTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      _showErrorSnackBar('Please enter a valid duration');
      return;
    }

    setState(() => isSaving = true);

    try {
      // 1. Edit session details
      final editResult = await _sessionService.editSession(
        sessionId: widget.sessionData['session_id'],
        startTime: _selectedStartTime?.toUtc().toIso8601String(),
        durationMinutes: duration,
      );

      if (editResult['success'] != true) {
        throw Exception(editResult['message'] ?? 'Failed to update session');
      }

      // 2. Update bulk attendance
      final updates = _studentStatuses.entries
          .map((e) => {'student_id': e.key, 'status': e.value})
          .toList();

      if (updates.isNotEmpty) {
        final bulkResult = await _sessionService.updateBulkAttendance(
          sessionId: widget.sessionData['session_id'],
          updates: updates,
        );
        if (bulkResult['success'] != true) {
          throw Exception(bulkResult['message'] ?? 'Failed to update attendance');
        }
      }

      if (mounted) {
        _showSuccessSnackBar('Session updated successfully');
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      appBar: AppBar(
        title: const Text('Edit Session', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (!isSaving)
            TextButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save, color: Color(0xFF007C91)),
              label: const Text('Save', style: TextStyle(color: Color(0xFF007C91), fontWeight: FontWeight.bold)),
            ),
          if (isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Session Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Date Time Picker
                  InkWell(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFF007C91)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Time', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedStartTime != null
                                      ? DateFormat('MMM dd, yyyy - hh:mm a').format(_selectedStartTime!)
                                      : 'Select Time',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Duration Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: Color(0xFF007C91)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration (minutes)',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Students List
                  if (_students.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No students enrolled in this class.', style: TextStyle(color: Colors.grey)),
                    ))
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _students.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          final studentId = student['student_id'];
                          final status = _studentStatuses[studentId] ?? 'absent';
                          final isPresent = status == 'present';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF007C91).withOpacity(0.1),
                              child: Text(
                                student['name'][0].toUpperCase(),
                                style: const TextStyle(color: Color(0xFF007C91), fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(student['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(student['email'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            trailing: Switch(
                              value: isPresent,
                              activeColor: Colors.green,
                              onChanged: (val) {
                                setState(() {
                                  _studentStatuses[studentId] = val ? 'present' : 'absent';
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }
}

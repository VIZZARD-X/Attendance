import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import 'add_students_screen.dart';
import '../../widgets/teacher_web_layout.dart';
import '../../services/class_service.dart';
import '../../widgets/teacher_drawer.dart';
import '../../widgets/hover_wrapper.dart';
import 'package:share_plus/share_plus.dart';

class MyClassesScreen extends StatefulWidget {
  const MyClassesScreen({super.key});

  @override
  State<MyClassesScreen> createState() => _MyClassesScreenState();
}

class _MyClassesScreenState extends State<MyClassesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool isLoading = false;
  bool isSidebarExpanded = false;

  final ClassService _classService = ClassService();
  List<Map<String, dynamic>> classes = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _loadClasses();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() => isLoading = true);

    try {
      final loadedClasses = await _classService.getMyClasses();

      if (mounted) {
        // ✨ EXACT DASHBOARD COLOR PALETTE
        final colorPalette = [
          Colors.cyan, // Class Insights
          Colors.green, // My Classes
          Colors.orange, // Create Session
          Colors.purple, // Announcements
          Colors.indigo, // Reports Export
          Colors.teal, // Attendance
          Colors.deepOrange, // Resources
          Colors.blueGrey, // Settings
        ];

        setState(() {
          classes = loadedClasses.asMap().entries.map((entry) {
            final index = entry.key;
            final c = entry.value;

            return {
              'id': c['id'],
              'code': c['class_code'],
              'name': c['class_name'],
              'semester': c['semester'].toString().length == 1
                  ? 'Semester ${c['semester']}'
                  : c['semester'],
              'students': c['student_count'] ?? 0,
              'color': colorPalette[index % colorPalette.length],
            };
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading classes: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Failed to load classes: $e');
      }
    }
  }

  void _showCreateClassDialog() {
    final nameController = TextEditingController();
    String selectedSemester = '1';
    final List<String> semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007C91), Color(0xFF0097A7)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Create New Class',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  controller: nameController,
                  label: 'Class Name *',
                  hint: 'e.g., Computer Science',
                  icon: Icons.book_rounded,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSemester,
                  items: semesters.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text('Semester $value'),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedSemester = newValue;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Semester *',
                    prefixIcon: const Icon(
                      Icons.calendar_today_rounded,
                      color: Color(0xFF007C91),
                      size: 22,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF007C91),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007C91), Color(0xFF0097A7)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007C91).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _navigateToAddStudents(
                      nameController.text,
                      selectedSemester,
                    );
                  } else {
                    _showErrorSnackBar('Please fill in all required fields');
                  }
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Next: Add Students'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF007C91), size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF007C91), width: 2),
        ),
      ),
    );
  }

  void _navigateToAddStudents(String name, String semester) async {
    setState(() => isLoading = true);

    try {
      final result = await _classService.createClass(
        name: name,
        semester: semester,
        students: [],
      );

      setState(() => isLoading = false);

      if (result['success'] == true) {
        final classData = result['class'];
        final classId = classData['id'];

        final studentsAdded = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddStudentsScreen(classId: classId),
          ),
        );

        if (studentsAdded == true) {
          await _loadClasses();
          _showSuccessSnackBar(
            'Class created and students added successfully!',
          );
        } else {
          await _loadClasses();
        }
      } else {
        _showErrorSnackBar(result['message'] ?? 'Failed to create class');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error creating class: $e');
    }
  }

  void _deleteClass(int index) async {
    final classData = classes[index];
    final className = classData['name'];
    final classId = classData['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Class',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$className"? This action cannot be undone.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _classService.deleteClass(classId);
      if (success) {
        await _loadClasses();
        _showSuccessSnackBar('Class "$className" deleted');
      } else {
        _showErrorSnackBar('Failed to delete class');
      }
    }
  }

  void _showClassDetails(Map<String, dynamic> classData) async {
    // Load students first
    setState(() => isLoading = true);

    final students = await _classService.getClassStudents(classData['id']);

    setState(() => isLoading = false);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header with class info
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          classData['color'].withOpacity(0.88),
                          classData['color'],
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          classData['name'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tab Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelColor: classData['color'],
                            unselectedLabelColor: Colors.white,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(
                                icon: Icon(Icons.info_outline),
                                text: 'Overview',
                              ),
                              Tab(
                                icon: Icon(Icons.people_outline),
                                text: 'Students',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // },

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Overview Tab
                        _buildOverviewTab(classData),

                        // Students Tab
                        _buildStudentsTab(classData, students, setModalState),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Overview Tab (existing functionality)
  Widget _buildOverviewTab(Map<String, dynamic> classData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            Icons.calendar_today_rounded,
            'Semester',
            classData['semester'],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(
            Icons.people_rounded,
            'Enrolled Students',
            '${classData['students']} students',
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007C91), Color(0xFF0097A7)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007C91).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddStudentsScreen(classId: classData['id']),
                    ),
                  ).then((_) => _loadClasses());
                },
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: const Text(
                  'Add Students',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Students Tab (NEW)
  Widget _buildStudentsTab(
    Map<String, dynamic> classData,
    List<Map<String, dynamic>> students,
    StateSetter setModalState,
  ) {
    return Column(
      children: [
        // Student count and add button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${students.length} Students Enrolled',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddStudentsScreen(classId: classData['id']),
                    ),
                  ).then((value) async {
                    await _loadClasses();
                    if (value == true) {
                      // Reload students in modal
                      _showClassDetails(classData);
                    }
                  });
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007C91),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Students list
        Expanded(
          child: students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No students enrolled yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddStudentsScreen(classId: classData['id']),
                            ),
                          ).then((_) => _loadClasses());
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Students'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007C91),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return _buildStudentCard(
                      student,
                      classData['id'],
                      setModalState,
                      () async {
                        // Reload students after delete
                        final updatedStudents = await _classService
                            .getClassStudents(classData['id']);
                        setModalState(() {
                          students.clear();
                          students.addAll(updatedStudents);
                        });
                        await _loadClasses();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Student Card Widget (NEW)
  Widget _buildStudentCard(
    Map<String, dynamic> student,
    int classId,
    StateSetter setModalState,
    VoidCallback onDelete,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF007C91),
          radius: 24,
          child: Text(
            student['username']?.substring(0, 1).toUpperCase() ?? 'S',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          student['username'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    student['email'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Remove'),
                ],
              ),
              onTap: () {
                Future.delayed(Duration.zero, () {
                  _confirmDeleteStudent(student, classId, onDelete);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // Confirm Delete Student (NEW)
  void _confirmDeleteStudent(
    Map<String, dynamic> student,
    int classId,
    VoidCallback onDelete,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber,
                color: Colors.red.shade700,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Remove Student',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Remove ${student['username']} from this class?\n\nThis will not delete the student account.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await _classService.removeStudentFromClass(
                classId,
                student['id'],
              );

              if (success) {
                onDelete();
                _showSuccessSnackBar('Student removed from class');
              } else {
                _showErrorSnackBar('Failed to remove student');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF007C91).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF007C91), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF007C91),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;
    final isTablet = screenW >= 600 && screenW < 1024;

    final crossAxisCount = isMobile
        ? 1
        : (isTablet ? 2 : (screenW < 1400 ? 3 : 4));
    final cardPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 20.0);
    final gridSpacing = isMobile ? 12.0 : (isTablet ? 16.0 : 18.0);
    final cardAspectRatio = isMobile ? 1.4 : (isTablet ? 1.15 : 1.25);

    Widget mainContent = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF007C91), Color(0xFF0097A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _buildAppBar(isMobile),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                : classes.isEmpty
                ? _buildEmptyState()
                : _buildClassesGrid(
                    crossAxisCount,
                    cardPadding,
                    gridSpacing,
                    cardAspectRatio,
                  ),
          ),
        ],
      ),
    );

    Widget mobileChild = Scaffold(
      drawer: isMobile ? const TeacherDrawer(currentRoute: 'My Classes') : null,
      body: SafeArea(child: mainContent),
    );

    return mobileChild;
  }

  Widget _buildAppBar(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF007C91), Color(0xFF0097A7)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
            ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Classes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                if (!isMobile)
                  const Text(
                    'Manage your classes and students',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: _showCreateClassDialog,
              tooltip: 'Create Class',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 100,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Classes Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first class to get started',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateClassDialog,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text(
                'Create Class',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF007C91),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesGrid(
    int crossAxisCount,
    double padding,
    double spacing,
    double aspectRatio,
  ) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GridView.builder(
        padding: EdgeInsets.all(padding),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final classData = classes[index];
          return _buildClassCard(classData, index);
        },
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData, int index) {
    return HoverWrapper(
      child: InkWell(
        onTap: () => _showClassDetails(classData),
        borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [classData['color'].withOpacity(0.88), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: classData['color'].withOpacity(0.36),
              blurRadius: 10,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: classData['color'].withOpacity(0.9),
            width: 0.8,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.school_outlined,
                size: 120,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          classData['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.grey[700],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_add_rounded,
                                  color: const Color(0xFF007C91),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text('Add Students'),
                              ],
                            ),
                            onTap: () {
                              Future.delayed(Duration.zero, () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddStudentsScreen(
                                      classId: classData['id'],
                                    ),
                                  ),
                                ).then((_) => _loadClasses());
                              });
                            },
                          ),
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.share_rounded,
                                  color: Colors.green.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text('Share Link'),
                              ],
                            ),
                            onTap: () {
                              final appUrl =
                                  'https://presence-cne6ezafcncnduf3.indiasouthcentral-01.azurewebsites.net';
                              final shareText =
                                  "Join my class '${classData['name']}' on Attendance App!\nClick here to join: $appUrl/#/join/${classData['code']}";
                              Share.share(shareText);
                            },
                          ),
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_rounded,
                                  color: Colors.red.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text('Delete'),
                              ],
                            ),
                            onTap: () => _deleteClass(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Semester ${classData['semester']}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_rounded,
                          color: Colors.black87,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${classData['students']} students',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title, {
    bool isMobile = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: (isSidebarExpanded || isMobile)
          ? Text(title, style: const TextStyle(color: Colors.white))
          : null,
      onTap: () {
        if (isMobile) Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title clicked'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      },
    );
  }
}

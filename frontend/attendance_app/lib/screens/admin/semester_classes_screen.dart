import 'package:flutter/material.dart';
import '../../services/class_service.dart';

class SemesterClassesScreen extends StatefulWidget {
  final String semesterLabel;
  final String semesterDisplay;

  const SemesterClassesScreen({
    super.key,
    required this.semesterLabel,
    required this.semesterDisplay,
  });

  @override
  State<SemesterClassesScreen> createState() => _SemesterClassesScreenState();
}

class _SemesterClassesScreenState extends State<SemesterClassesScreen> {
  final ClassService _classService = ClassService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _students = [];
  int _totalStudents = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    final q = _searchQuery.toLowerCase();
    return _students.where((s) {
      final name = (s['username'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final rollNo = (s['roll_no'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || rollNo.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);

    try {
      final data = await _classService.getSemesterStudents(widget.semesterLabel);

      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(data['students'] ?? []);
          _totalStudents = data['total_students'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading students: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF007C91), Color(0xFF0097A7)],
                ),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.semesterDisplay,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$_totalStudents students',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0097A7)),
              ),
            )
          : _students.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSearchBar(),
                    Expanded(child: _buildStudentList()),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No students in this semester',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search by name, email or roll no',
            hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF007C91)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF007C91)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    final filtered = _filteredStudents;
    if (filtered.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No students in this semester' : 'No students match your search',
          style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildStudentCard(filtered[index]),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final classes = List<Map<String, dynamic>>.from(student['classes'] ?? []);

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF007C91),
              radius: 24,
              child: Text(
                (student['username'] as String?)?.substring(0, 1).toUpperCase() ?? 'S',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['username'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          student['email'] ?? '',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Roll: ${student['roll_no'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (classes.isNotEmpty)
                        Expanded(
                          child: Text(
                            'Classes: ${classes.map((c) => c['class_code']).join(', ')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF007C91).withOpacity(0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF007C91), size: 20),
              onPressed: () => _showEditDialog(student),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              onPressed: () => _showRemoveStudentDialog(student),
              tooltip: 'Remove from class',
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> student) {
    final nameController = TextEditingController(text: student['username'] ?? '');
    final emailController = TextEditingController(text: student['email'] ?? '');
    final rollNoController = TextEditingController(text: student['roll_no'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Edit Student',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rollNoController,
                      decoration: InputDecoration(
                        labelText: 'Roll No',
                        prefixIcon: const Icon(Icons.numbers, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final result = await _classService.updateStudentDetails(
                            studentId: student['id'],
                            username: nameController.text.trim(),
                            email: emailController.text.trim(),
                            rollNo: rollNoController.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (result['error'] != null) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(result['error']),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Student updated successfully'),
                                backgroundColor: Color(0xFF007C91),
                              ),
                            );
                            _loadStudents();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007C91),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRemoveStudentDialog(Map<String, dynamic> student) {
    final classes = List<Map<String, dynamic>>.from(student['classes'] ?? []);
    final studentName = student['username'] ?? 'Unknown';

    if (classes.isEmpty) return;

    if (classes.length == 1) {
      final cls = classes.first;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Remove Student', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Remove $studentName from ${cls['class_code']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await _classService.adminRemoveStudentFromClass(
                  cls['id'],
                  student['id'],
                );
                if (!mounted) return;
                if (success) {
                  _loadStudents();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$studentName removed from ${cls['class_code']}'),
                      backgroundColor: const Color(0xFF007C91),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to remove student'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      return;
    }

    final selectedClasses = <int>{};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Remove from Classes', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select classes to remove $studentName from:',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  ...classes.map((cls) {
                    final classId = cls['id'] as int;
                    final isSelected = selectedClasses.contains(classId);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(cls['class_code'] ?? ''),
                      subtitle: Text(cls['class_code'] ?? ''),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selectedClasses.add(classId);
                          } else {
                            selectedClasses.remove(classId);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedClasses.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          for (final classId in selectedClasses) {
                            await _classService.adminRemoveStudentFromClass(
                              classId,
                              student['id'],
                            );
                          }
                          if (!mounted) return;
                          _loadStudents();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Student removed from selected classes'),
                              backgroundColor: Color(0xFF007C91),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

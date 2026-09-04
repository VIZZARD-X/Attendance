import 'package:flutter/material.dart';
import '../../services/class_service.dart';
import '../../widgets/admin_web_layout.dart';
import 'semester_classes_screen.dart';
import 'widgets/add_student_dialog.dart';

abstract class _AppColors {
  static const tealDark = Color(0xFF007C91);
  static const teal = Color(0xFF0097A7);
  static const textPrimary = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
}

class _SemesterCard {
  final String semesterDisplay;
  final String semesterLabel;
  final int studentCount;
  final Color color;
  final List<Color> gradient;

  const _SemesterCard({
    required this.semesterDisplay,
    required this.semesterLabel,
    required this.studentCount,
    required this.color,
    required this.gradient,
  });
}

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  final ClassService _classService = ClassService();
  List<_SemesterCard> _semesters = [];
  List<Map<String, dynamic>> _unassignedStudents = [];

  @override
  void initState() {
    super.initState();
    _loadSemesters();
  }

  Future<void> _loadSemesters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summaryFuture = _classService.getAdminClassesSummary();
      final unassignedFuture = _classService.getAdminUnassignedStudents();
      final results = await Future.wait([summaryFuture, unassignedFuture]);
      final summary = results[0] as List<Map<String, dynamic>>;
      final unassignedData = results[1] as Map<String, dynamic>;

      if (mounted) {
        const colorPalette = [
          Color(0xFFD34C53),
          Color(0xFFE4B40B),
          Color(0xFFA83FD9),
          Color(0xFF4FBDD6),
          Color(0xFF66BB6A),
          Color(0xFF46CDD5),
        ];

        const gradientPalette = [
          [Color(0xFFF2658B), Colors.white],
          [Color(0xFFE4BD3C), Colors.white],
          [Color(0xFFBA6CF5), Colors.white],
          [Color(0xFF3AB0E6), Colors.white],
          [Color(0xFF81C784), Colors.white],
          [Color(0xFF5FD4D4), Colors.white],
        ];

        setState(() {
          _semesters = summary.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final semesterStr = data['semester']?.toString() ?? '';
            return _SemesterCard(
              semesterDisplay: _semesterDisplay(semesterStr),
              semesterLabel: semesterStr,
              studentCount:
                  int.tryParse(data['student_count']?.toString() ?? '') ?? 0,
              color: colorPalette[index % colorPalette.length],
              gradient: gradientPalette[index % gradientPalette.length],
            );
          }).toList();
          _unassignedStudents = List<Map<String, dynamic>>.from(
            unassignedData['students'] ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading semesters: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load class summaries. Please try again.';
        });
      }
    }
  }

  String _semesterDisplay(String raw) {
    final trimmed = raw.trim();
    return int.tryParse(trimmed) != null ? 'Semester $trimmed' : trimmed;
  }

  String _initialOf(dynamic raw) {
    final name = raw?.toString() ?? '';
    return name.isEmpty ? 'S' : name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return AdminWebLayout(
      currentRoute: 'Manage Students',
      mobileChild: _buildMobileBody(isMobile),
      desktopBody: _buildDesktopBody(),
    );
  }

  Widget _buildMobileBody(bool isMobile) {
    final crossAxisCount = isMobile ? 1 : 2;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(isMobile),
              const SizedBox(height: 24),
              if (!_isLoading && _errorMessage == null)
                _buildNewlyAddedSection(isMobile),
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal),
                        ),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _semesters.isEmpty
                          ? _buildEmptyState()
                          : _buildSemesterGrid(crossAxisCount, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDesktopHeader(),
            const SizedBox(height: 24),
            if (!_isLoading && _errorMessage == null)
              _buildNewlyAddedSection(false),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal),
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : _semesters.isEmpty
                        ? _buildEmptyState()
                        : _buildSemesterGrid(3, false),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            // BUG FIX: was BorderRadius.circular(63.5) on a 76x76 box, which
            // doesn't correspond to any meaningful dimension. Using
            // BoxShape.circle is correct regardless of the box size.
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_AppColors.tealDark, _AppColors.teal],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manage Students',
                style: TextStyle(
                  color: _AppColors.tealDark,
                  fontSize: 38,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'View and manage students by semester',
                style: TextStyle(
                  fontSize: 16,
                  color: _AppColors.textMuted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showAddStudentDialog,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text('Add Student'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _AppColors.tealDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ],
    );
  }

  Widget _buildHeaderSection(bool isMobile) {
    return Row(
      children: [
        if (isMobile)
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        const Icon(Icons.people_alt_rounded, color: _AppColors.tealDark, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Manage Students',
            style: TextStyle(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.w700,
              color: _AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.person_add_alt_1_rounded, color: _AppColors.tealDark, size: 26),
          onPressed: _showAddStudentDialog,
          tooltip: 'Add Student',
        ),
      ],
    );
  }

  Widget _buildNewlyAddedSection(bool isMobile) {
    if (_unassignedStudents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Newly Added',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w700,
            color: _AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Students whom you have added but are not yet enrolled in any class',
          style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        ..._unassignedStudents.map((s) {
          final initial = _initialOf(s['username']);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFD1ECF1),
                  radius: isMobile ? 18 : 20,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF007C91),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['username'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        s['email'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7FA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _semesterDisplay((s['semester'] ?? '').toString()),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007C91),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSemesterGrid(int crossAxisCount, bool isMobile) {
    final isCompact = crossAxisCount < 3;

    // BUG FIX: previous ratios (1.35 / 1.45 / 1.6) made single- and
    // two-column cards nearly as tall as they were wide - big oversized
    // square-ish tiles for what is really just one row of content (an
    // icon, two short text lines, and an arrow). These are tuned to give
    // compact, row-like cards on mobile/tablet and a slightly taller,
    // more spacious tile on the 3-column desktop grid.
    final childAspectRatio = crossAxisCount == 1
        ? 2.6
        : (crossAxisCount == 2 ? 1.7 : 1.6);

    return GridView.builder(
      itemCount: _semesters.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        // BUG FIX: cross spacing was larger than main-axis spacing on the
        // desktop grid (42 vs 55), which reads as an unbalanced/uneven
        // rhythm compared to the compact case. Keep spacing consistent.
        mainAxisSpacing: isCompact ? 16 : 32,
        crossAxisSpacing: isCompact ? 16 : 32,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, idx) => _buildSemesterCard(_semesters[idx], isCompact),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 72, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: _AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadSemesters,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.tealDark,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No classes found',
            style: TextStyle(
              fontSize: 18,
              color: _AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create classes to see semester summaries',
            style: TextStyle(
              fontSize: 14,
              color: _AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    AddStudentDialog.show(
      context: context,
      classService: _classService,
      onStudentCreated: _loadSemesters,
    );
  }

  Widget _buildSemesterCard(_SemesterCard semester, bool isCompact) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SemesterClassesScreen(
              semesterLabel: semester.semesterLabel,
              semesterDisplay: semester.semesterDisplay,
              totalEnrollments: semester.studentCount,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20 : 32,
          vertical: isCompact ? 18 : 24,
        ),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: semester.gradient,
          ),
          shape: RoundedRectangleBorder(
            // BUG FIX: 43px radius was disproportionately large for these
            // card sizes (especially the shorter compact cards), making
            // them look like pills and clipping content into the curved
            // corners. 24px keeps the same soft-rounded style at a scale
            // that fits the card dimensions.
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: isCompact ? 52 : 68,
              height: isCompact ? 52 : 68,
              padding: EdgeInsets.all(isCompact ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                border: Border.all(
                  color: semester.color.withOpacity(0.70),
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_rounded,
                color: semester.color,
                size: isCompact ? 22 : 30,
              ),
            ),
            SizedBox(width: isCompact ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    semester.semesterDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${semester.studentCount} Students',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: semester.color,
              size: isCompact ? 16 : 20,
            ),
          ],
        ),
      ),
    );
  }
}
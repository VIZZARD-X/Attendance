import 'package:flutter/material.dart';
import '../../services/class_service.dart';
import 'semester_classes_screen.dart';
import '../../widgets/admin_web_layout.dart';

abstract class _AppColors {
  static const tealDark = Color(0xFF007C91);
  static const teal = Color(0xFF0097A7);
  static const tealLight = Color(0xFF0288A3);
  static const background = Color(0xFFF7FAFC);
  static const darkBg = Color(0xFF1E1E2D);
  static const textPrimary = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
}

class _SemesterCard {
  final int semester;
  final String semesterLabel;
  final int studentCount;
  final Color color;
  final List<Color> gradient;

  const _SemesterCard({
    required this.semester,
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
  bool _isSidebarExpanded = false;
  bool _isLoading = false;
  final ClassService _classService = ClassService();
  List<_SemesterCard> _semesters = [];

  @override
  void initState() {
    super.initState();
    _loadSemesters();
  }

  Future<void> _loadSemesters() async {
    setState(() => _isLoading = true);

    try {
      final summary = await _classService.getAdminClassesSummary();

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
              semester: int.tryParse(semesterStr) ?? index + 1,
              semesterLabel: semesterStr,
              studentCount: data['student_count'] ?? 0,
              color: colorPalette[index % colorPalette.length],
              gradient: gradientPalette[index % gradientPalette.length],
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading semesters: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;
    final isDesktop = screenW >= 1024;
    final crossAxisCount = isMobile ? 1 : 2;

    Widget mainContent = isDesktop
        ? SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_AppColors.tealDark, _AppColors.teal], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          borderRadius: BorderRadius.circular(63.5),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 38),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Manage Students', style: TextStyle(color: _AppColors.tealDark, fontSize: 38, fontFamily: 'Inter', fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            const Text('View and manage students by semester', style: TextStyle(fontSize: 16, color: _AppColors.textMuted, fontFamily: 'Inter')),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _AppColors.textPrimary), onPressed: () => Navigator.pop(context), tooltip: 'Back'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.only(top: 60), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal))))
                      : _semesters.isEmpty
                          ? _buildEmptyState()
                          : _buildSemesterGrid(3, false),
                ],
              ),
            ),
          )
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(isMobile),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(child: Padding(padding: EdgeInsets.only(top: 60), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal))))
                      : _semesters.isEmpty
                          ? _buildEmptyState()
                          : _buildSemesterGrid(crossAxisCount, isMobile),
                ],
              ),
            ),
          );

    Widget mobileChild = Scaffold(
      backgroundColor: _AppColors.background,
      appBar: _buildTopBar(isMobile),
      drawer: _buildMobileDrawer(),
      body: Stack(
        children: [
          SafeArea(child: mainContent),
        ],
      ),
    );

    return AdminWebLayout(
      currentRoute: 'Manage Students',
      mobileChild: mobileChild,
      desktopBody: mainContent,
    );
  }

  PreferredSizeWidget _buildTopBar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: _AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_AppColors.tealDark, _AppColors.teal]),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Manage Students',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(color: _AppColors.darkBg),
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_AppColors.tealDark, _AppColors.teal],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.people_alt_rounded,
                      size: 35,
                      color: _AppColors.tealDark,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Manage Students',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_rounded, color: Colors.white70),
              title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushReplacementNamed(context, '/admin'),
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded, color: Colors.white70),
              title: const Text('Students', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
              title: const Text('Back', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
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
        Text(
          'Manage Students',
          style: TextStyle(
            fontSize: isMobile ? 22 : 28,
            fontWeight: FontWeight.w700,
            color: _AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterGrid(int crossAxisCount, bool isMobile) {
    final isCompact = crossAxisCount < 3;
    final childAspectRatio = crossAxisCount == 1
        ? 1.35
        : (crossAxisCount == 2 ? 1.45 : 1.6);

    return GridView.builder(
      itemCount: _semesters.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: isCompact ? 20 : 42,
        crossAxisSpacing: isCompact ? 16 : 55,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, idx) => _buildSemesterCard(_semesters[idx], isCompact),
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

  Widget _buildSemesterCard(_SemesterCard semester, bool isCompact) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SemesterClassesScreen(
              semesterLabel: semester.semesterLabel,
              semesterDisplay: 'Semester ${semester.semester}',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(43),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20 : 32,
          vertical: isCompact ? 18 : 24,
        ),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.05, -0.07),
            end: const Alignment(1.18, 1.28),
            colors: semester.gradient,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(43),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
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
                        'Semester ${semester.semester}',
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
          ],
        ),
      ),
    );
  }
}

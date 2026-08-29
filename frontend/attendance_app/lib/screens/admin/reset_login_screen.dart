import 'package:flutter/material.dart';
import '../../services/class_service.dart';
import 'teacher_list_screen.dart';
import 'student_list_screen.dart';

abstract class _AppColors {
  static const tealDark = Color(0xFF007C91);
  static const teal = Color(0xFF0097A7);
  static const tealLight = Color(0xFF0288A3);
  static const background = Color(0xFFF7FAFC);
  static const darkBg = Color(0xFF1E1E2D);
  static const textPrimary = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
}

class ResetLoginScreen extends StatefulWidget {
  const ResetLoginScreen({super.key});

  @override
  State<ResetLoginScreen> createState() => _ResetLoginScreenState();
}

class _ResetLoginScreenState extends State<ResetLoginScreen> {
  final ClassService _classService = ClassService();
  bool _isSidebarExpanded = false;
  bool _isLoading = false;
  int _teacherCount = 0;
  int _studentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _classService.getAdminStats();

      if (mounted) {
        setState(() {
          _teacherCount = stats['teachers_count'] ?? 0;
          _studentCount = stats['students_count'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
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

    if (isDesktop) return _buildDesktopLayout();

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: _buildTopBar(isMobile),
      drawer: _buildMobileDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(isMobile),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal),
                      ),
                    ),
                  )
                else
                  _buildCards(isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            _buildDesktopSidebar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDesktopHeader(),
                      const SizedBox(height: 32),
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal),
                            ),
                          ),
                        )
                      else
                        _buildCards(false),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
              gradient: LinearGradient(
                colors: [_AppColors.tealDark, _AppColors.teal],
              ),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Login Reset',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_AppColors.tealDark, _AppColors.teal],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(63.5),
          ),
          child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Login Reset',
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
                'Reset Login Access',
                style: TextStyle(
                  fontSize: 16,
                  color: _AppColors.textMuted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarExpanded ? 220 : 72,
      decoration: const BoxDecoration(color: _AppColors.darkBg),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_AppColors.tealDark, _AppColors.teal],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 26),
          ),
          IconButton(
            icon: Icon(
              _isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white70,
            ),
            onPressed: () =>
                setState(() => _isSidebarExpanded = !_isSidebarExpanded),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarItem(Icons.dashboard_rounded, 'Dashboard'),
                _buildSidebarItem(Icons.lock_reset_rounded, 'Reset Login'),
              ],
            ),
          ),
          _buildSidebarItem(Icons.arrow_back_rounded, 'Back'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title, {
    bool isMobile = false,
  }) {
    final showLabel = _isSidebarExpanded || isMobile;
    return Tooltip(
      message: showLabel ? '' : title,
      child: ListTile(
        leading: Icon(icon, color: Colors.white70, size: isMobile ? 24 : 20),
        title: showLabel
            ? Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 14))
            : null,
        onTap: () {
          if (title == 'Back' || title == 'Dashboard') {
            Navigator.pop(context);
          }
        },
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
                      Icons.lock_reset_rounded,
                      size: 35,
                      color: _AppColors.tealDark,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Login Reset',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _buildSidebarItem(Icons.dashboard_rounded, 'Dashboard', isMobile: true),
            _buildSidebarItem(Icons.lock_reset_rounded, 'Reset Login', isMobile: true),
            const Divider(color: Colors.white24),
            _buildSidebarItem(Icons.arrow_back_rounded, 'Back', isMobile: true),
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
        const Icon(Icons.lock_reset_rounded, color: _AppColors.tealDark, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Login Reset',
                style: TextStyle(
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w700,
                  color: _AppColors.textPrimary,
                ),
              ),
              Text(
                '${_teacherCount + _studentCount} total users',
                style: const TextStyle(
                  fontSize: 13,
                  color: _AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCards(bool isMobile) {
    return Column(
      children: [
        _buildResetCard(
          title: 'Teachers',
          count: _teacherCount,
          icon: Icons.person_rounded,
          isCompact: isMobile,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeacherListScreen()),
          ),
        ),
        const SizedBox(height: 24),
        _buildResetCard(
          title: 'Students',
          count: _studentCount,
          icon: Icons.people_alt_rounded,
          isCompact: isMobile,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentListScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildResetCard({
    required String title,
    required int count,
    required IconData icon,
    required bool isCompact,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(33),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 22 : 40),
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment(0.41, 0.46),
            end: Alignment(0.88, 0.97),
            colors: [_AppColors.teal, _AppColors.tealLight],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(33),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 32 : 64,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: isCompact ? 16 : 24),
            Center(
              child: Container(
                width: isCompact ? 160 : 334,
                height: isCompact ? 160 : 334,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isCompact ? 78 : 160,
                ),
              ),
            ),
            SizedBox(height: isCompact ? 16 : 24),
            Row(
              children: [
                Container(
                  width: isCompact ? 44 : 69,
                  height: isCompact ? 44 : 69,
                  decoration: const ShapeDecoration(
                    color: Color(0xFF0288A3),
                    shape: OvalBorder(),
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 20 : 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Reset Access',
                  style: TextStyle(
                    color: _AppColors.tealDark,
                    fontSize: isCompact ? 15 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

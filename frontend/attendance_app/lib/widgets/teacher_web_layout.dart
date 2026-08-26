import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/auth_service.dart';
import '../services/class_service.dart';

import '../screens/dashboard/teacher_dashboard_web.dart';
import '../screens/teacher/my_classes_screen.dart';
import '../screens/teacher/session_create_screen.dart';
import '../screens/teacher/teacher_attendance_history_screen.dart';
import '../screens/teacher/teacher_profile_screen.dart';

class _AppColors {
  static const darkBg = Color(0xFF1E1E2C);
  static const tealLight = Color(0xFF14DCCA);
  static const tealDark = Color(0xFF007C91);
}

class DashboardCardData {
  final String title;
  final IconData icon;

  const DashboardCardData({required this.title, required this.icon});
}

class TeacherWebLayout extends StatefulWidget {
  final Widget mobileChild;
  final Widget desktopBody;
  final String currentRoute;

  const TeacherWebLayout({
    super.key,
    required this.mobileChild,
    required this.desktopBody,
    required this.currentRoute,
  });

  @override
  State<TeacherWebLayout> createState() => _TeacherWebLayoutState();
}

class _TeacherWebLayoutState extends State<TeacherWebLayout> {
  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  final AuthService _authService = AuthService();
  final ClassService _classService = ClassService();

  static bool _isSidebarExpanded = false;

  static const _cards = <DashboardCardData>[
    DashboardCardData(title: 'Dashboard', icon: Icons.dashboard_rounded),
    DashboardCardData(title: 'My Classes', icon: Icons.people_alt_rounded),
    DashboardCardData(title: 'Create Session', icon: Icons.timer_rounded),
    DashboardCardData(
      title: 'Attendance History',
      icon: Icons.check_circle_rounded,
    ),
    DashboardCardData(title: 'Profile', icon: Icons.person_rounded),
  ];

  Future<void> _handleCardTap(String title) async {
    if (title == widget.currentRoute) return;

    switch (title) {
      case 'Dashboard':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const TeacherDashboardWeb()),
        );
        break;
      case 'My Classes':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const MyClassesScreen()),
        );
        break;
      case 'Create Session':
        await _navigateToCreateSession();
        break;
      case 'Attendance History':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const TeacherAttendanceHistoryScreen()),
        );
        break;
      case 'Profile':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const TeacherProfileScreen()),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _navigateToCreateSession() async {
    try {
      final classes = await _classService.getMyClasses();

      if (!mounted) return;
      if (classes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No classes found. Please create a class first.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final subjects = classes
          .map(
            (c) => {
              'id': c['id'].toString(),
              'code': c['class_code'] as String,
              'name': c['class_name'] as String,
              'semester': c['semester'] as String,
            },
          )
          .toList();

      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        _fadeRoute(SessionPage(subjects: subjects)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading classes: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _buildSidebarItem(IconData icon, String title) {
    final isSelected = widget.currentRoute == title;
    final showLabel = _isSidebarExpanded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Tooltip(
        message: showLabel ? '' : title,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  title == 'Logout' ? _logout() : _handleCardTap(title),
              child: Container(
                height: 48,
                padding: EdgeInsets.symmetric(
                  horizontal: showLabel ? 12.0 : 0.0,
                ),
                child: Row(
                  mainAxisAlignment: showLabel
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? _AppColors.tealDark : Colors.white70,
                      size: 24,
                    ),
                    if (showLabel) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected
                                ? _AppColors.tealDark
                                : Colors.white70,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSidebarExpanded ? 220 : 72,
      decoration: const BoxDecoration(
        color: _AppColors.darkBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: Colors.white70,
                size: 28,
              ),
              onPressed: () =>
                  setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _cards
                  .map((c) => _buildSidebarItem(c.icon, c.title))
                  .toList(),
            ),
          ),
          _buildSidebarItem(Icons.logout, 'Logout'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 1024;

    if (kIsWeb && isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 72.0),
                child: widget.desktopBody,
              ),
            ),
            SafeArea(child: _buildDesktopSidebar()),
          ],
        ),
      );
    }

    return widget.mobileChild;
  }
}

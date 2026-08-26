import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/auth_service.dart';

import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/manage_students_screen.dart';
import '../screens/admin/manage_teachers_screen.dart';
import '../screens/admin/reset_login_screen.dart';
import '../screens/admin/admin_profile_screen.dart';

class _AppColors {
  static const darkBg = Color(0xFF1E1E2C);
  static const tealDark = Color(0xFF007C91);
}

class AdminSidebarData {
  final String title;
  final IconData icon;

  const AdminSidebarData({required this.title, required this.icon});
}

class AdminWebLayout extends StatefulWidget {
  final Widget mobileChild;
  final Widget desktopBody;
  final String currentRoute;

  const AdminWebLayout({
    super.key,
    required this.mobileChild,
    required this.desktopBody,
    required this.currentRoute,
  });

  @override
  State<AdminWebLayout> createState() => _AdminWebLayoutState();
}

class _AdminWebLayoutState extends State<AdminWebLayout> {
  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    );
  }

  final AuthService _authService = AuthService();

  static bool _isSidebarExpanded = false;

  static const _cards = <AdminSidebarData>[
    AdminSidebarData(title: 'Dashboard', icon: Icons.dashboard_rounded),
    AdminSidebarData(title: 'Manage Students', icon: Icons.people_alt_rounded),
    AdminSidebarData(title: 'Manage Teachers', icon: Icons.person_rounded),
    AdminSidebarData(title: 'Reset Login', icon: Icons.lock_reset_rounded),
    AdminSidebarData(title: 'Profile', icon: Icons.person_outline_rounded),
  ];

  Future<void> _handleCardTap(String title) async {
    if (title == widget.currentRoute) return;

    switch (title) {
      case 'Dashboard':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const AdminDashboardPage()),
        );
        break;
      case 'Manage Students':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const ManageStudentsScreen()),
        );
        break;
      case 'Manage Teachers':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const ManageTeachersScreen()),
        );
        break;
      case 'Reset Login':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const ResetLoginScreen()),
        );
        break;
      case 'Profile':
        await Navigator.pushReplacement(
          context,
          _fadeRoute(const AdminProfileScreen()),
        );
        break;
      default:
        break;
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
    return GestureDetector(
      onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
      child: AnimatedContainer(
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

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'admin_profile_screen.dart';
import 'manage_students_screen.dart';
import 'manage_teachers_screen.dart';
import 'reset_login_screen.dart';
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

class _DashboardCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AuthService _authService = AuthService();

  bool _isSidebarExpanded = false;
  bool _isLoading = false;
  String _username = 'Admin';

  static const _cards = <_DashboardCard>[
    _DashboardCard(
      title: 'Manage Students',
      subtitle: 'View or Edit Student Details',
      icon: Icons.people_alt_rounded,
      color: Color(0xFFF59E0B),
      gradient: [Color(0xFFF59E0B), Colors.white],
    ),
    _DashboardCard(
      title: 'Manage Teachers',
      subtitle: 'View and Edit Teacher Details',
      icon: Icons.person_rounded,
      color: Color(0xFF0FA797),
      gradient: [Color(0xFF14B8A6), Colors.white],
    ),
    _DashboardCard(
      title: 'Reset Login',
      subtitle: 'Provide Login Access to a Device',
      icon: Icons.lock_reset_rounded,
      color: Color(0xFFCC4899),
      gradient: [Color(0xFFDE6ACB), Colors.white],
    ),
    _DashboardCard(
      title: 'Profile',
      subtitle: 'View your Profile',
      icon: Icons.person_outline_rounded,
      color: Color(0xFF8F8E95),
      gradient: [Color(0xFFACACB4), Colors.white],
    ),
  ];

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

  Future<void> _handleCardTap(String title) async {
    switch (title) {
      case 'Manage Students':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageStudentsScreen()),
        );
      case 'Manage Teachers':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageTeachersScreen()),
        );
      case 'Reset Login':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResetLoginScreen()),
        );
      case 'Profile':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
        );
      default:
        _showSnackBar('$title – Coming Soon!', Colors.blue);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
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
                  _buildDesktopHeader(),
                  const SizedBox(height: 48),
                  _buildSectionHeader(),
                  const SizedBox(height: 24),
                  _buildDashboardGrid(3, false),
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
                  _buildSectionHeader(),
                  const SizedBox(height: 16),
                  _buildDashboardGrid(crossAxisCount, isMobile),
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
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );

    return AdminWebLayout(
      currentRoute: 'Dashboard',
      mobileChild: mobileChild,
      desktopBody: Stack(
        children: [
          mainContent,
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() => Container(
        color: Colors.black26,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontSize: 26,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(width: 30, height: 4, decoration: BoxDecoration(color: _AppColors.tealDark, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, color: _AppColors.textMuted, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardGrid(int crossAxisCount, bool isMobile) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isMobile ? 16 : 24,
        mainAxisSpacing: isMobile ? 16 : 24,
        childAspectRatio: isMobile ? 1.2 : 1.4,
      ),
      itemBuilder: (context, index) {
        final card = _cards[index];
        return InkWell(
          onTap: () => _handleCardTap(card.title),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: card.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: card.color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Icon(card.icon, size: 100, color: Colors.white.withOpacity(0.15)),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                        child: Icon(card.icon, color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      Text(
                        card.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black, fontSize: 14, fontFamily: 'Inter'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildTopBar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_AppColors.tealDark, _AppColors.teal]),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Welcome, $_username',
              style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _AppColors.textPrimary),
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
          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $_username',
                style: const TextStyle(color: _AppColors.tealDark, fontSize: 38, fontFamily: 'Inter', fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'Admin Panel',
                style: TextStyle(fontSize: 16, color: _AppColors.textMuted, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: _AppColors.textPrimary),
          onPressed: _logout,
        ),
      ],
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
                gradient: LinearGradient(colors: [_AppColors.tealDark, _AppColors.teal]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings_rounded, size: 35, color: _AppColors.tealDark),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _username,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text('Logout', style: TextStyle(color: Colors.white)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

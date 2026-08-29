import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'admin_profile_screen.dart';
import 'manage_students_screen.dart';
import 'manage_teachers_screen.dart';
import 'reset_login_screen.dart';

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

    if (isDesktop) return _buildDesktopLayout();

    final crossAxisCount = isMobile ? 1 : 2;

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: _buildTopBar(isMobile),
      drawer: _buildMobileDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
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
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: _AppColors.background,
      body: Stack(
        children: [
          SafeArea(
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
                          const SizedBox(height: 48),
                          _buildSectionHeader(),
                          const SizedBox(height: 24),
                          _buildDashboardGrid(3, false),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
            Container(
              width: 12,
              height: 43,
              decoration: ShapeDecoration(
                color: _AppColors.tealLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 33,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardGrid(int crossAxisCount, bool isMobile) {
    final childAspectRatio =
        crossAxisCount == 1 ? 1.5 : (crossAxisCount == 2 ? 1.3 : 1.6);

    return GridView.builder(
      itemCount: _cards.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 42,
        crossAxisSpacing: 55,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, idx) => _buildActionCard(_cards[idx], isMobile),
    );
  }

  Widget _buildActionCard(_DashboardCard card, bool isMobile) {
    return InkWell(
      onTap: () => _handleCardTap(card.title),
      borderRadius: BorderRadius.circular(43),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.05, -0.07),
            end: const Alignment(1.18, 1.28),
            colors: card.gradient,
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
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    border: Border.all(
                      color: card.color.withOpacity(0.70),
                      width: 1.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(card.icon, color: card.color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Welcome, $_username',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: _AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: _AppColors.textPrimary),
          onPressed: _logout,
        ),
      ],
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
                style: const TextStyle(
                  color: _AppColors.tealDark,
                  fontSize: 38,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'Admin Panel',
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
          icon: const Icon(Icons.logout, color: _AppColors.textPrimary),
          onPressed: _logout,
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
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 26),
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
        onTap: () =>
            title == 'Logout' ? _logout() : _handleCardTap(title),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 35,
                      color: _AppColors.tealDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ..._cards.map(
              (c) => _buildSidebarItem(c.icon, c.title, isMobile: true),
            ),
            const Divider(color: Colors.white24),
            _buildSidebarItem(Icons.logout, 'Logout', isMobile: true),
          ],
        ),
      ),
    );
  }
}

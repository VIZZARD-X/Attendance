import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/class_service.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/enhanced_dashboard_card.dart';
import '../../widgets/offline_indicator.dart';
import 'admin_navigation.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AuthService _authService = AuthService();
  final ClassService _classService = ClassService();

  bool isSidebarExpanded = false;
  String adminName = "Loading...";
  String username = "";
  bool isLoading = true;
  int studentCount = 0;
  int teacherCount = 0;

  Map<String, dynamic>? _cachedUserData;
  DateTime? _lastFetch;

  final List<Map<String, dynamic>> dashboardCards = [
    {
      'title': 'Manage Students',
      'subtitle': 'View or Edit Student Details',
      'icon': Icons.people_alt_rounded,
      'gradientColors': [const Color(0xFFFDBB49), const Color(0xFFFEF3DE)],
    },
    {
      'title': 'Manage Teachers',
      'subtitle': 'View and Edit Teacher Details',
      'icon': Icons.person_rounded,
      'gradientColors': [const Color(0xFF2DC1A5), const Color(0xFFCBF0E8)],
    },
    {
      'title': 'Manage Classes',
      'subtitle': 'Browse Classes and Students',
      'icon': Icons.class_rounded,
      'gradientColors': [const Color(0xFF9C8BFF), const Color(0xFFE0E7FF)],
    },
    {
      'title': 'Profile',
      'subtitle': 'View your Profile',
      'icon': Icons.person_outline_rounded,
      'gradientColors': [const Color(0xFF8F939A), const Color(0xFFE2E4E7)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted && !isLoading) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedUserData != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 5)) {
      setState(() {
        adminName = _cachedUserData!['first_name'] ?? 'Admin';
        username = _cachedUserData!['username'] ?? '';
        isLoading = false;
      });
      return;
    }

    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        _authService.getCurrentUser(),
        _classService.getAdminStats(),
      ]);

      if (!mounted) return;

      final userData = results[0];
      final stats = results[1]!;

      setState(() {
        _cachedUserData = userData;
        _lastFetch = DateTime.now();

        adminName = userData?['first_name'] ?? 'Admin';
        username = userData?['username'] ?? '';
        studentCount = int.tryParse(stats['students_count']?.toString() ?? '') ?? 0;
        teacherCount = int.tryParse(stats['teachers_count']?.toString() ?? '') ?? 0;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        adminName = 'Error loading';
        username = '';
        isLoading = false;
      });
      debugPrint('Error loading admin dashboard data: $e');
    }
  }

  void _handleCardTap(String title) async {
    await navigateToAdminScreen(context, title);
    _loadUserData(forceRefresh: true);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _cachedUserData = null;
        _lastFetch = null;
      });

      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;
    final isTablet = screenW >= 600 && screenW < 1024;
    final isDesktop = screenW >= 1024;

    int crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      appBar: isMobile || isTablet ? _buildTopBar(isMobile) : null,
      drawer: isMobile || isTablet ? const AdminDrawer(currentRoute: 'Dashboard') : null,
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
                if (isDesktop) _buildDesktopSidebar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isDesktop) _buildTopBar(false),
                          if (isDesktop) const SizedBox(height: 24),
                          _buildStatsSection(isMobile),
                          const SizedBox(height: 24),
                          _buildSectionHeader(isMobile),
                          const SizedBox(height: 16),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1100),
                              child: _buildDashboardGrid(crossAxisCount, isMobile),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
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
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: isMobile
          ? null
          : IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF1F2937)),
              onPressed: () => setState(() => isSidebarExpanded = !isSidebarExpanded),
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
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $adminName',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile)
                  Text(
                    '@$username',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const OfflineIndicator(),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF1F2937)),
          onPressed: () => _loadUserData(forceRefresh: true),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFF1F2937)),
          onPressed: _logout,
        ),
      ],
    );
  }

  Widget _buildStatsSection(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Students',
            studentCount.toString(),
            Icons.people_rounded,
            [const Color(0xFF66E9E1), Colors.white],
            const Color(0xFF0097A7),
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Teachers',
            teacherCount.toString(),
            Icons.person_rounded,
            [const Color(0xFFA8E6A7), Colors.white],
            const Color(0xFF1EBA57),
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    List<Color> gradientColors,
    Color borderColor,
    bool isMobile,
  ) {
    return Container(
      height: isMobile ? 100 : 120,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: borderColor, size: isMobile ? 24 : 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.black54,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007C91), Color(0xFF0097A7)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardGrid(int crossAxisCount, bool isMobile) {
    return GridView.builder(
      itemCount: dashboardCards.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: isMobile ? 0.96 : 1.22,
      ),
      itemBuilder: (context, idx) {
        final card = dashboardCards[idx];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: EnhancedDashboardCard(
              title: card['title'] as String,
              subtitle: card['subtitle'] as String,
              icon: card['icon'] as IconData,
              gradientColors: card['gradientColors'] as List<Color>,
              onTap: () => _handleCardTap(card['title'] as String),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isSidebarExpanded ? 220 : 70,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: kAdminNavItems.length,
              itemBuilder: (context, index) {
                final item = kAdminNavItems[index];
                return _buildSidebarItem(
                  item.icon,
                  item.title,
                );
              },
            ),
          ),
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
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: isMobile ? 24 : 20),
      title: isSidebarExpanded || isMobile
          ? Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            )
          : null,
      onTap: () => _handleCardTap(title),
    );
  }
}
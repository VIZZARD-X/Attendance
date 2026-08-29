import 'package:flutter/material.dart';
import '../../services/class_service.dart';

abstract class _AppColors {
  static const tealDark = Color(0xFF007C91);
  static const teal = Color(0xFF0097A7);
  static const tealLight = Color(0xFF0288A3);
  static const background = Color(0xFFF7FAFC);
  static const darkBg = Color(0xFF1E1E2D);
  static const textPrimary = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
}

class TeacherListScreen extends StatefulWidget {
  const TeacherListScreen({super.key});

  @override
  State<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends State<TeacherListScreen> {
  final ClassService _classService = ClassService();
  bool _isSidebarExpanded = false;
  bool _isLoading = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _teachers = [];

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;
    final q = _searchQuery.toLowerCase();
    return _teachers.where((t) {
      final name = (t['full_name'] ?? '').toString().toLowerCase();
      final email = (t['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoading = true);

    try {
      final data = await _classService.getUsersByRole('teachers');
      final users = data['teachers'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _teachers = users.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading teachers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAccess(Map<String, dynamic> teacher) async {
    final userId = teacher['id'] as int;
    final result = await _classService.toggleUserAccess(userId);

    if (result.isNotEmpty) {
      await _loadTeachers();
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
        child: Column(
          children: [
            _buildHeaderSection(isMobile),
            if (!isMobile) const SizedBox(height: 16),
            _buildSearchBar(isMobile),
            const SizedBox(height: 12),
            Expanded(child: _buildContent(isMobile)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal),
        ),
      );
    }

    return _buildTable(isMobile);
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            _buildDesktopSidebar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDesktopHeader(),
                    const SizedBox(height: 24),
                    _buildSearchBar(false),
                    const SizedBox(height: 16),
                    Expanded(child: _buildContent(false)),
                  ],
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
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Teachers',
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
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teachers',
                style: TextStyle(
                  color: _AppColors.tealDark,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage teacher login access',
                style: TextStyle(
                  fontSize: 16,
                  color: _AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.person_add_alt_1_rounded, color: _AppColors.tealDark),
          onPressed: _showAddTeacherDialog,
          tooltip: 'Add Teacher',
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
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
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
                _buildSidebarItem(Icons.person_rounded, 'Teachers'),
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
                      Icons.person_rounded,
                      size: 35,
                      color: _AppColors.tealDark,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Teachers',
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
            _buildSidebarItem(Icons.person_rounded, 'Teachers', isMobile: true),
            const Divider(color: Colors.white24),
            _buildSidebarItem(Icons.arrow_back_rounded, 'Back', isMobile: true),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 24, 8, isMobile ? 8 : 24, 0),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          const Icon(Icons.person_rounded, color: _AppColors.tealDark, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Teachers',
              style: TextStyle(
                fontSize: isMobile ? 22 : 28,
                fontWeight: FontWeight.w700,
                color: _AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: _AppColors.tealDark),
            onPressed: _showAddTeacherDialog,
            tooltip: 'Add Teacher',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 0),
      child: SizedBox(
        height: isMobile ? 44 : 50,
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Enter Name or Mail',
            hintStyle: TextStyle(
              color: Colors.black.withValues(alpha: 0.3),
              fontSize: isMobile ? 14 : 20,
            ),
            prefixIcon: const Icon(Icons.search, color: _AppColors.tealDark),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _AppColors.tealDark),
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

  Widget _buildTable(bool isMobile) {
    final filtered = _filteredTeachers;

    if (filtered.isEmpty && !_isLoading) {
      return const Center(child: Text('No teachers found'));
    }

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _buildTeacherCard(filtered[index], index + 1),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth < 1100;
        final tableMinWidth = isTablet ? 880.0 : 1040.0;

        final table = Container(
          decoration: ShapeDecoration(
            color: const Color(0xFFF8F8F8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Column(
            children: [
              _buildTableHeader(isTablet),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildTableRow(
                    filtered[index],
                    index + 1,
                    isTablet,
                  ),
                ),
              ),
            ],
          ),
        );

        if (isTablet) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableMinWidth),
              child: table,
            ),
          );
        }

        return table;
      },
    );
  }

  Widget _buildTableHeader(bool isCompact) {
    return Container(
      height: isCompact ? 56 : 65,
      decoration: const BoxDecoration(color: Color(0xFF0097A7)),
      child: Row(
        children: [
          Container(
            width: 58,
            alignment: Alignment.center,
            child: const Text(
              'Sl. No',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Teacher Name',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 20 : 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Teacher Mail',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 20 : 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 90,
            child: Center(
              child: Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> teacher, int index, bool isMobile) {
    final name = teacher['full_name'] ?? 'Unknown';
    final email = teacher['email'] ?? '';
    final hasAccess = teacher['is_active'] == true;

    return Container(
      height: isMobile ? 64 : 72,
      decoration: BoxDecoration(
        color: index.isOdd ? const Color(0xFFE5E4E4) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isMobile ? 12 : 24),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isMobile ? 12 : 24),
              child: Text(
                email,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          SizedBox(
            width: isMobile ? 60 : 100,
            child: Center(
              child: Container(
                width: isMobile ? 34 : 42,
                height: isMobile ? 34 : 42,
                decoration: ShapeDecoration(
                  color: hasAccess
                      ? const Color(0xFF1D8E2E)
                      : const Color(0xFFF60000),
                  shape: OvalBorder(),
                ),
                child: hasAccess
                    ? Icon(Icons.check, color: Colors.white, size: isMobile ? 18 : 22)
                    : Icon(Icons.close, color: Colors.white, size: isMobile ? 18 : 22),
              ),
            ),
          ),
          if (!isMobile) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              onPressed: () => _showDeleteTeacherDialog(teacher),
              tooltip: 'Delete teacher',
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: _AppColors.textMuted),
              onPressed: () => _showAccessDialog(teacher),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index) {
    final name = teacher['full_name'] ?? 'Unknown';
    final email = teacher['email'] ?? '';
    final hasAccess = teacher['is_active'] == true;

    return InkWell(
      onTap: () => _showAccessDialog(teacher),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF7FA),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  color: _AppColors.tealDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: hasAccess
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          hasAccess ? 'Access granted' : 'No access',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasAccess
                                ? const Color(0xFF1D8E2E)
                                : const Color(0xFFF60000),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _showDeleteTeacherDialog(teacher),
                        tooltip: 'Delete teacher',
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_vert, color: _AppColors.textMuted),
                        onPressed: () => _showAccessDialog(teacher),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccessDialog(Map<String, dynamic> teacher) {
    final name = teacher['full_name'] ?? 'Unknown';
    final hasAccess = teacher['is_active'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(hasAccess ? 'Revoke Access' : 'Grant Access'),
        content: Text(
          '${hasAccess ? 'Revoke' : 'Grant'} login access for $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleAccess(teacher);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hasAccess ? Colors.red : Colors.green,
            ),
            child: Text(hasAccess ? 'Revoke' : 'Grant'),
          ),
        ],
      ),
    );
  }

  void _showAddTeacherDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Teacher', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password (min 6 chars)',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
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
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final password = passwordController.text;

                          if (name.isEmpty || email.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Name, email, and password are required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final result = await _classService.adminCreateUser(
                            username: name,
                            email: email,
                            password: password,
                            role: 'teacher',
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
                                content: Text('Teacher created successfully'),
                                backgroundColor: _AppColors.tealDark,
                              ),
                            );
                            _loadTeachers();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.tealDark,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteTeacherDialog(Map<String, dynamic> teacher) {
    final name = teacher['full_name'] ?? teacher['username'] ?? 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Teacher', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Permanently delete $name?\n\nAll their data will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await _classService.adminDeleteUser(teacher['id']);
              if (!mounted) return;
              if (result['error'] != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['error']),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Teacher deleted'),
                    backgroundColor: _AppColors.tealDark,
                  ),
                );
                _loadTeachers();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

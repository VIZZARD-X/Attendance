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

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final ClassService _classService = ClassService();
  bool _isSidebarExpanded = false;
  bool _isLoading = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _students = [];
  String? _sortColumn;
  bool _sortAscending = true;
  String? _errorMessage;

  List<Map<String, dynamic>> get _filteredStudents {
    var result = _students;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        final name = (s['full_name'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    if (_sortColumn != null) {
      result.sort((a, b) {
        final aVal = _sortValue(a);
        final bVal = _sortValue(b);
        return _sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
      });
    }

    return result;
  }

  String _sortValue(Map<String, dynamic> s) {
    switch (_sortColumn) {
      case 'name':
        return (s['full_name'] ?? '').toString().toLowerCase();
      case 'email':
        return (s['email'] ?? '').toString().toLowerCase();
      case 'access':
        return s['is_active'] == true ? '1' : '0';
      default:
        return '';
    }
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _classService.getUsersByRole('students');
      final users = data['students'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _students = users.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading students: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load students. Check your connection.';
        });
      }
    }
  }

  Future<void> _toggleAccess(Map<String, dynamic> student) async {
    final userId = student['id'] as int;
    final result = await _classService.toggleUserAccess(userId);

    if (result.isNotEmpty) {
      await _loadStudents();
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal),
                ),
              )
            : Column(
                children: [
                  _buildHeaderSection(isMobile),
                  _buildMobileSearch(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildContent(isMobile)),
                ],
              ),
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isLoading) {
      if (isMobile) {
        return ListView.builder(
          itemCount: 5,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _ShimmerCard(),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: _AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: _AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadStudents,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.tealDark,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No students match your search'
                  : 'No students yet',
              style: const TextStyle(
                fontSize: 18,
                color: _AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStudents,
      color: _AppColors.tealDark,
      child: _buildTable(isMobile),
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
              child: Column(
                children: [
                  _buildDesktopTopBar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(38, 20, 38, 38),
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _AppColors.teal,
                                ),
                              ),
                            )
                          : _buildContent(false),
                    ),
                  ),
                ],
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
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: _AppColors.textPrimary,
        ),
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
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Students',
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

  Widget _buildDesktopTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: ShapeDecoration(
              gradient: const LinearGradient(
                colors: [_AppColors.tealDark, _AppColors.teal],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Manage Students',
              style: TextStyle(
                color: _AppColors.tealDark,
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 26,
            ),
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
                _buildSidebarItem(Icons.people_alt_rounded, 'Students'),
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
            ? Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
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
            _buildSidebarItem(
              Icons.dashboard_rounded,
              'Dashboard',
              isMobile: true,
            ),
            _buildSidebarItem(
              Icons.people_alt_rounded,
              'Students',
              isMobile: true,
            ),
            const Divider(color: Colors.white24),
            _buildSidebarItem(Icons.arrow_back_rounded, 'Back', isMobile: true),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 6 : 12,
        isMobile ? 16 : 24,
        0,
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: _AppColors.textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          const Icon(
            Icons.people_alt_rounded,
            color: _AppColors.tealDark,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Students',
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.w700,
                    color: _AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_students.length} students',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: _AppColors.tealDark,
            ),
            onPressed: _showAddStudentDialog,
            tooltip: 'Add Student',
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search by name, email or roll no',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(
            Icons.search,
            color: _AppColors.teal,
            size: 22,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _AppColors.teal, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(bool isMobile) {
    final filtered = _filteredStudents;

    if (filtered.isEmpty && !_isLoading) {
      return const Center(child: Text('No students found'));
    }

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _buildStudentCard(filtered[index], index + 1),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth < 1100;
        final tableMinWidth = isTablet ? 880.0 : 1040.0;

        final table = Container(
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Column(
            children: [
              _buildTableTopBar(isTablet),
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildTableRow(filtered[index], index + 1, isTablet),
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

  Widget _buildTableTopBar(bool isCompact) {
    return Container(
      height: isCompact ? 72 : 92,
      decoration: const ShapeDecoration(
        gradient: LinearGradient(
          colors: [_AppColors.tealDark, _AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          Padding(
            padding: EdgeInsets.only(right: isCompact ? 16 : 24),
            child: SizedBox(
              width: isCompact ? 220 : 320,
              height: isCompact ? 38 : 42,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, email or roll no',
                  hintStyle: TextStyle(
                    color: Colors.black.withValues(alpha: 0.3),
                    fontSize: isCompact ? 14 : 18,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: _AppColors.tealLight,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 20,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(color: _AppColors.teal),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: InkWell(
              onTap: () => _toggleSort('name'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '#',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _sortColumn == 'name'
                        ? (_sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                        : Icons.unfold_more,
                    size: 14,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _toggleSort('name'),
              child: Row(
                children: [
                  const Text(
                    'Student Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _sortColumn == 'name'
                        ? (_sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                        : Icons.unfold_more,
                    size: 14,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _toggleSort('email'),
              child: Row(
                children: [
                  const Text(
                    'Student Mail',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _sortColumn == 'email'
                        ? (_sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                        : Icons.unfold_more,
                    size: 14,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () => _toggleSort('access'),
              child: Row(
                children: [
                  const Text(
                    'Access',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _sortColumn == 'access'
                        ? (_sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                        : Icons.unfold_more,
                    size: 14,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 100),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    Map<String, dynamic> student,
    int index,
    bool isCompact,
  ) {
    final name = student['full_name'] ?? 'Unknown';
    final email = student['email'] ?? '';
    final hasAccess = student['is_active'] == true;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: index.isOdd ? const Color(0xFFF5F5F5) : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                email,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: hasAccess,
                  activeTrackColor: const Color(0xFF1D8E2E),
                  onChanged: (_) => _toggleAccess(student),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _showDeleteStudentDialog(student),
                  tooltip: 'Delete student',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: _AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => _showAccessDialog(student),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final name = student['full_name'] ?? 'Unknown';
    final email = student['email'] ?? '';
    final hasAccess = student['is_active'] == true;

    return Dismissible(
      key: ValueKey(student['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 32),
      ),
      confirmDismiss: (_) async {
        _showDeleteStudentDialog(student);
        return false;
      },
      child: InkWell(
        onTap: () => _showAccessDialog(student),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
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
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 22,
                          ),
                          onPressed: () => _showDeleteStudentDialog(student),
                          tooltip: 'Delete student',
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(
                            Icons.more_vert,
                            color: _AppColors.textMuted,
                          ),
                          onPressed: () => _showAccessDialog(student),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccessDialog(Map<String, dynamic> student) {
    final name = student['full_name'] ?? 'Unknown';
    final hasAccess = student['is_active'] == true;

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
              _toggleAccess(student);
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

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameFocus = FocusNode();
    final emailFocus = FocusNode();
    final passwordFocus = FocusNode();

    bool isSaving = false;
    String? nameError;
    String? emailError;
    String? passwordError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Add Student',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      focusNode: nameFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => emailFocus.requestFocus(),
                      onChanged: (_) => setDialogState(() => nameError = null),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        errorText: nameError,
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      focusNode: emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => passwordFocus.requestFocus(),
                      onChanged: (_) => setDialogState(() => emailError = null),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: emailError,
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      focusNode: passwordFocus,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) =>
                          setDialogState(() => passwordError = null),
                      decoration: InputDecoration(
                        labelText: 'Password (min 6 chars)',
                        errorText: passwordError,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
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

                          bool hasError = false;

                          if (name.isEmpty) {
                            setDialogState(
                              () => nameError = 'Name is required',
                            );
                            hasError = true;
                          }
                          if (email.isEmpty) {
                            setDialogState(
                              () => emailError = 'Email is required',
                            );
                            hasError = true;
                          } else if (!email.contains('@')) {
                            setDialogState(
                              () => emailError = 'Enter a valid email',
                            );
                            hasError = true;
                          }
                          if (password.isEmpty) {
                            setDialogState(
                              () => passwordError = 'Password is required',
                            );
                            hasError = true;
                          } else if (password.length < 6) {
                            setDialogState(
                              () => passwordError = 'At least 6 characters',
                            );
                            hasError = true;
                          }

                          if (hasError) return;

                          setDialogState(() => isSaving = true);
                          final result = await _classService.adminCreateUser(
                            username: name,
                            email: email,
                            password: password,
                            role: 'student',
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
                                content: Text('Student created successfully'),
                                backgroundColor: _AppColors.tealDark,
                              ),
                            );
                            _loadStudents();
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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

  void _showDeleteStudentDialog(Map<String, dynamic> student) {
    final name = student['full_name'] ?? student['username'] ?? 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Student',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Permanently delete $name?\n\nAll their data (enrollments, attendance records, profile) will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await _classService.adminDeleteUser(student['id']);
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
                    content: Text(result['message'] ?? 'Student deleted'),
                    backgroundColor: _AppColors.tealDark,
                  ),
                );
                _loadStudents();
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

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Alignment> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = AlignmentTween(begin: Alignment(-1, 0), end: Alignment(1, 0))
        .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _shimmerGradient(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerLine(height: 18, width: 180),
                const SizedBox(height: 8),
                _buildShimmerLine(height: 14, width: 240),
                const SizedBox(height: 6),
                _buildShimmerLine(height: 13, width: 100),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildShimmerLine(height: 24, width: 100, radius: 999),
                    const Spacer(),
                    _buildShimmerLine(height: 24, width: 24, radius: 12),
                    const SizedBox(width: 8),
                    _buildShimmerLine(height: 24, width: 24, radius: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLine({
    required double height,
    required double width,
    double radius = 6,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: _shimmerGradient(),
          ),
        );
      },
    );
  }

  LinearGradient _shimmerGradient() {
    return LinearGradient(
      begin: _animation.value,
      end: Alignment(-_animation.value.x, _animation.value.y),
      colors: [
        Colors.grey.shade200,
        Colors.grey.shade100,
        Colors.grey.shade200,
      ],
    );
  }
}

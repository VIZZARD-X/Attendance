import 'package:flutter/material.dart';
import '../../services/class_service.dart';
import '../../widgets/admin_web_layout.dart';
import 'admin_class_detail_screen.dart';

abstract class _AppColors {
  static const tealDark = Color(0xFF007C91);
  static const teal = Color(0xFF0097A7);
  static const tealLight = Color(0xFF0288A3);
  static const textPrimary = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
}

class ManageTeachersScreen extends StatefulWidget {
  const ManageTeachersScreen({super.key});

  @override
  State<ManageTeachersScreen> createState() => _ManageTeachersScreenState();
}

class _ManageTeachersScreenState extends State<ManageTeachersScreen> {
  final ClassService _classService = ClassService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _teachers = [];
  final Set<int> _expandedTeacherIds = {};

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;
    final q = _searchQuery.toLowerCase();
    return _teachers.where((t) =>
      (t['username']?.toString().toLowerCase() ?? '').contains(q) ||
      (t['email']?.toString().toLowerCase() ?? '').contains(q)
    ).toList();
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

  /// Safely parses a teacher id that may arrive as int, String, or null
  /// depending on the backend/JSON serialization path.
  int? _teacherIdOf(Map<String, dynamic> teacher) {
    final raw = teacher['id'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _classService.getTeachers();

      if (mounted) {
        setState(() {
          _teachers = List<Map<String, dynamic>>.from(data['teachers'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teachers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load teachers. Please check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    return AdminWebLayout(
      currentRoute: 'Manage Teachers',
      mobileChild: _buildMobileBody(isMobile),
      desktopBody: _buildDesktopBody(),
    );
  }

  Widget _buildMobileBody(bool isMobile) {
    return SafeArea(
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
                Expanded(
                  child: RefreshIndicator(
                    color: _AppColors.teal,
                    onRefresh: _loadTeachers,
                    child: _buildContent(isMobile),
                  ),
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
          hintText: 'Search by name or email',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search, color: _AppColors.teal, size: 22),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildDesktopBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 20, 38, 38),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
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
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Manage Teachers',
                  style: TextStyle(
                    color: _AppColors.tealDark,
                    fontSize: 36,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
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
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_AppColors.teal),
                    ),
                  )
                : _buildContent(false),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 6 : 12, isMobile ? 16 : 24, 0),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Teachers',
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.w700,
                    color: _AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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

  /// Central place that decides between the error state, empty state,
  /// and the actual teacher list/table.
  Widget _buildContent(bool isMobile) {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final filtered = _filteredTeachers;

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) =>
            _buildTeacherCard(filtered[index], index + 1),
      );
    }

    return _buildTable(filtered);
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
            onPressed: _loadTeachers,
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
          Icon(Icons.person_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No teachers match your search' : 'No teachers found',
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

  Widget _buildTable(List<Map<String, dynamic>> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth < 1100;
        final tableMinWidth = isTablet ? 860.0 : 1040.0;

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
                  hintText: 'Search by name or email',
                  hintStyle: TextStyle(
                    color: Colors.black.withValues(alpha: 0.3),
                    fontSize: isCompact ? 14 : 18,
                  ),
                  prefixIcon: const Icon(Icons.search, color: _AppColors.tealLight, size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      child: const Row(
        children: [
          SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              'Sl. No',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Teacher Name',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Teacher Email',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Classes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> teacher, int displayIndex, bool isCompact) {
    final classes = List<Map<String, dynamic>>.from(teacher['classes'] ?? []);
    final teacherId = _teacherIdOf(teacher);
    final hasClasses = classes.isNotEmpty;
    final isExpanded = teacherId != null && _expandedTeacherIds.contains(teacherId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: displayIndex.isOdd ? const Color(0xFFF5F5F5) : Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(
                  '$displayIndex',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    teacher['username'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    teacher['email'] ?? '',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Text(
                        '${teacher['class_count'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasClasses && teacherId != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedTeacherIds.remove(teacherId);
                              } else {
                                _expandedTeacherIds.add(teacherId);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _AppColors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isExpanded ? 'Hide' : 'View',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _AppColors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  size: 16,
                                  color: _AppColors.teal,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: _AppColors.tealDark, size: 20),
                onPressed: () => _showEditTeacherDialog(teacher),
                tooltip: 'Edit teacher',
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            padding: const EdgeInsets.fromLTRB(76, 8, 48, 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: _ClassListSection(
              classes: classes,
              dense: true,
              onTapClass: _openClassDetail,
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, int displayIndex) {
    final classes = List<Map<String, dynamic>>.from(teacher['classes'] ?? []);
    final teacherId = _teacherIdOf(teacher);
    final isExpanded = teacherId != null && _expandedTeacherIds.contains(teacherId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: teacherId == null
                ? null
                : () {
                    setState(() {
                      if (isExpanded) {
                        _expandedTeacherIds.remove(teacherId);
                      } else {
                        _expandedTeacherIds.add(teacherId);
                      }
                    });
                  },
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
                      '$displayIndex',
                      style: const TextStyle(
                        color: _AppColors.tealDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                teacher['username'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            if (classes.isNotEmpty)
                              Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: _AppColors.teal,
                                size: 24,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          teacher['email'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: _AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${teacher['class_count'] ?? 0} classes',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _AppColors.tealDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: _AppColors.tealDark, size: 20),
                    onPressed: () => _showEditTeacherDialog(teacher),
                    tooltip: 'Edit teacher',
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                border: Border(
                  left: BorderSide(color: Colors.grey.shade200),
                  right: BorderSide(color: Colors.grey.shade200),
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: _ClassListSection(
                classes: classes,
                dense: false,
                onTapClass: _openClassDetail,
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _openClassDetail(Map<String, dynamic> cls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminClassDetailScreen(
          classId: cls['id'],
          classCode: cls['class_code'] ?? '',
          className: cls['class_name'] ?? '',
        ),
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
                            ScaffoldMessenger.of(ctx).showSnackBar(
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
                                backgroundColor: Color(0xFF007C91),
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
    ).whenComplete(() {
      nameController.dispose();
      emailController.dispose();
      passwordController.dispose();
    });
  }

  void _showEditTeacherDialog(Map<String, dynamic> teacher) {
    final nameController = TextEditingController(text: teacher['username'] ?? '');
    final emailController = TextEditingController(text: teacher['email'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Teacher', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
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

                          if (name.isEmpty || email.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Name and email cannot be empty'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final result = await _classService.updateTeacherDetails(
                            teacherId: teacher['id'],
                            username: name,
                            email: email,
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
                                content: Text('Teacher updated successfully'),
                                backgroundColor: Color(0xFF007C91),
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
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      emailController.dispose();
    });
  }
}

/// Shared "Classes:" expandable section used by both the desktop table row
/// and the mobile card, so styling/behaviour only needs to live in one place.
class _ClassListSection extends StatelessWidget {
  const _ClassListSection({
    required this.classes,
    required this.onTapClass,
    this.dense = false,
  });

  final List<Map<String, dynamic>> classes;
  final void Function(Map<String, dynamic> cls) onTapClass;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Classes:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _AppColors.tealDark,
          ),
        ),
        SizedBox(height: dense ? 6 : 8),
        if (classes.isEmpty)
          Text(
            'No classes assigned',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          )
        else
          ...classes.map((cls) => Padding(
            padding: EdgeInsets.only(bottom: dense ? 4 : 6),
            child: InkWell(
              onTap: () => onTapClass(cls),
              borderRadius: BorderRadius.circular(dense ? 8 : 10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 4 : 8,
                  vertical: dense ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(dense ? 8 : 10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: dense ? 8 : 10,
                        vertical: dense ? 2 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: _AppColors.teal.withValues(alpha: dense ? 0.08 : 0.08),
                        borderRadius: BorderRadius.circular(dense ? 6 : 8),
                      ),
                      child: Text(
                        cls['class_code'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _AppColors.tealDark,
                        ),
                      ),
                    ),
                    SizedBox(width: dense ? 8 : 10),
                    Expanded(
                      child: Text(
                        cls['class_name'] ?? '',
                        style: TextStyle(fontSize: dense ? 13 : 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${cls['student_count'] ?? 0} students',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          )),
      ],
    );
  }
}
import 'package:flutter/material.dart';

import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../theme/analytics_theme.dart';
import '../../widgets/analytics/analytics_animations.dart';
import '../../widgets/analytics/analytics_panels.dart';
import '../../widgets/analytics/analytics_primitives.dart';
import '../../widgets/teacher_drawer.dart';
import '../../widgets/teacher_web_layout.dart';

/// Teacher-facing analytics: cohort health, per-class portfolio, risk triage,
/// and advisory integrity flags.
///
/// Loading rules: overview and at-risk load together because the summary tiles
/// reference risk counts. Integrity flags load lazily on first visit to that tab
/// so the initial render is not blocked by a panel most sessions never open.
/// The per-student drill-down loads only when a row is tapped.
class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _service = AnalyticsService();
  late final TabController _tabs;

  bool _loading = true;
  String? _error;

  TeacherOverview _overview = TeacherOverview.empty;
  TeacherAtRisk _atRisk = TeacherAtRisk.empty;

  IntegrityFlagPage? _flags;
  bool _flagsLoading = false;
  String? _flagsError;
  String _flagStatus = 'open';

  /// null = all classes the teacher owns.
  String? _classId;

  static const _tabLabels = ['Overview', 'Classes', 'At risk', 'Integrity'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.index == 3 && _flags == null && !_flagsLoading) {
      _loadFlags();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.teacherOverview(classId: _classId),
        _service.teacherAtRisk(classId: _classId),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as TeacherOverview;
        _atRisk = results[1] as TeacherAtRisk;
        _loading = false;
      });
    } on AnalyticsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadFlags() async {
    setState(() {
      _flagsLoading = true;
      _flagsError = null;
    });
    try {
      final page = await _service.integrityFlags(
        status: _flagStatus,
        classId: _classId,
      );
      if (!mounted) return;
      setState(() {
        _flags = page;
        _flagsLoading = false;
      });
    } on AnalyticsException catch (e) {
      if (!mounted) return;
      setState(() {
        _flagsError = e.message;
        _flagsLoading = false;
      });
    }
  }

  Future<void> _resolveFlag(IntegrityFlag flag, String status) async {
    try {
      await _service.resolveIntegrityFlag(flag.id, status: status);
      await _loadFlags();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flag marked $status.')),
      );
    } on AnalyticsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  double get _required => _overview.meta.requiredPct;

  /// Opens the drill-down for one student. The request is made inside the sheet
  /// so the list stays interactive while it loads.
  void _openStudent(AtRiskStudent student) {
    final id = student.studentId;
    if (id == null) return;
    StudentDrillDownSheet.show(
      context,
      requiredPct: _required,
      load: () => _service.teacherStudentDetail(id, classId: _classId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final content = Column(
      children: [
        _header(isMobile),
        Expanded(
          child: _loading
              ? _loadingBody()
              : _error != null
                  ? AnalyticsErrorState(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _overviewTab(),
                        _classesTab(),
                        _atRiskTab(),
                        _integrityTab(),
                      ],
                    ),
        ),
      ],
    );

    final body = Container(
      color: AnalyticsTheme.canvas,
      child: SafeArea(child: content),
    );

    return TeacherWebLayout(
      currentRoute: 'Analytics',
      mobileChild: Scaffold(
        backgroundColor: AnalyticsTheme.canvas,
        drawer:
            isMobile ? const TeacherDrawer(currentRoute: 'Analytics') : null,
        body: body,
      ),
      desktopBody: body,
    );
  }

  /// Gradient header carrying the title, scope filter and tab bar, matching the
  /// other teacher screens' app-bar treatment.
  Widget _header(bool isMobile) {
    final s = _overview.summary;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AnalyticsTheme.heroGradient,
        boxShadow: AnalyticsTheme.shadowMd,
      ),
      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 20, 10, isMobile ? 8 : 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isMobile)
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                )
              else
                const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 19 : 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (!_loading && _error == null)
                      Text(
                        s == null
                            ? 'No recorded attendance in this scope'
                            : '${s.students} students · ${s.sessions} sessions · '
                                '${_overview.classes.length} class(es)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loading ? null : _load,
              ),
            ],
          ),
          if (!_loading && _error == null && _overview.classes.isNotEmpty)
            _classFilter(),
          TabBar(
            controller: _tabs,
            isScrollable: isMobile,
            tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
            tabs: [for (final t in _tabLabels) Tab(text: t)],
          ),
        ],
      ),
    );
  }

  /// Skeletons matching the eventual layout, so the page does not jump when the
  /// data lands.
  Widget _loadingBody() => ListView(
        padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
        children: [
          const ShimmerSkeleton(height: 132),
          const SizedBox(height: AnalyticsTheme.gapLg),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AnalyticsTheme.gapMd),
                const Expanded(child: ShimmerSkeleton(height: 96)),
              ],
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapLg),
          ShimmerSkeleton.panel(height: 180),
          const SizedBox(height: AnalyticsTheme.gapLg),
          ShimmerSkeleton.panel(height: 120),
        ],
      );

  /// Common scroll wrapper for a tab body. Sections fade in with a stagger.
  Widget _wrap(List<Widget> children) => RefreshIndicator(
        onRefresh: _load,
        color: AnalyticsTheme.accent,
        child: ListView(
          padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
          children: [
            ScopeBanner(meta: _overview.meta),
            const SizedBox(height: AnalyticsTheme.gapLg),
            ...staggered(children),
            const SizedBox(height: AnalyticsTheme.gapXl),
          ],
        ),
      );

  /// Filter options come from the overview payload, so the picker can never
  /// offer a class the current scope does not contain.
  Widget _classFilter() {
    final classes = _overview.classes;
    if (classes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('All classes', null),
            for (final c in classes)
              if (c.classId != null)
                _filterChip(c.classCode, c.classId.toString()),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? id) {
    final selected = _classId == id;
    return Padding(
      padding: const EdgeInsets.only(right: AnalyticsTheme.gapSm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        selectedColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: selected ? 1.0 : 0.6)),
        labelStyle: TextStyle(
          color: selected ? AnalyticsTheme.accent : Colors.white,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12.5,
        ),
        onSelected: (_) {
          if (selected) return;
          setState(() {
            _classId = id;
            // Flags are scope-specific; drop the cached page so the tab
            // re-fetches rather than showing another class's flags.
            _flags = null;
          });
          _load();
        },
      ),
    );
  }

  // ------------------------------------------------------------------ tabs

  Widget _overviewTab() {
    final meta = _overview.meta;
    if (!meta.hasData) {
      return _wrap([
        AnalyticsEmptyState(
          message: _overview.reason ??
              'No attendance has been recorded in this scope yet.',
          detail: 'Hold a session and mark attendance to populate analytics.',
        ),
      ]);
    }

    final s = _overview.summary;
    final health = _overview.health;
    return _wrap([
      HeroPctHeader(
        title: 'Cohort attendance',
        pct: s?.attendancePct,
        requiredPct: _required,
        subtitle: s?.denominatorNote,
        slope: _overview.cohortSlope,
        sparkline: _overview.trend.sessions
            .map((p) => p.pct)
            .whereType<double>()
            .toList(),
        chips: [
          if (health.grade != null) HeroChip(label: 'Health ${health.grade}'),
          if ((s?.belowThresholdStudents ?? 0) > 0)
            HeroChip(
              label: '${s!.belowThresholdStudents} below requirement',
              icon: Icons.trending_down,
            ),
          if ((s?.openIntegrityFlags ?? 0) > 0)
            HeroChip(
              label: '${s!.openIntegrityFlags} open flag(s)',
              icon: Icons.flag_outlined,
            ),
        ],
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      MetricGrid(
        tiles: [
          MetricTile(
            label: 'Students',
            value: fmtNum(s?.students),
            countTo: s?.students.toDouble(),
            icon: Icons.people_outline,
          ),
          MetricTile(
            label: 'Sessions held',
            value: fmtNum(s?.sessions),
            countTo: s?.sessions.toDouble(),
            icon: Icons.event_available_outlined,
          ),
          MetricTile(
            label: 'Below requirement',
            value: fmtNum(s?.belowThresholdStudents),
            countTo: s?.belowThresholdStudents.toDouble(),
            sublabel: 'under ${_required.toStringAsFixed(0)}%',
            valueColor: (s?.belowThresholdStudents ?? 0) > 0
                ? AnalyticsTheme.absent
                : AnalyticsTheme.present,
            icon: Icons.trending_down,
            onTap: () => _tabs.animateTo(2),
          ),
          MetricTile(
            label: 'Rising risk',
            value: fmtNum(s?.risingRiskCount),
            countTo: s?.risingRiskCount.toDouble(),
            sublabel: 'above the line but declining',
            icon: Icons.priority_high,
            onTap: () => _tabs.animateTo(2),
          ),
          MetricTile(
            label: 'Open flags',
            value: fmtNum(s?.openIntegrityFlags),
            countTo: s?.openIntegrityFlags.toDouble(),
            sublabel: 'advisory only',
            icon: Icons.flag_outlined,
            onTap: () => _tabs.animateTo(3),
          ),
          MetricTile(
            label: 'Median student',
            value: fmtPct(_overview.distribution.medianPct),
            countTo: _overview.distribution.medianPct,
            countFormatter: (v) => '${v.toStringAsFixed(1)}%',
            sublabel: _overview.distribution.p10Pct == null
                ? null
                : 'bottom 10% at ${fmtPct(_overview.distribution.p10Pct, decimals: 0)}',
            icon: Icons.straighten,
          ),
        ],
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      CohortHealthPanel(health: health, requiredPct: _required),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'Attendance over time',
        subtitle: 'Each point is one session; highlighted points are shifts in '
            'the underlying rate, detected by CUSUM.',
        icon: Icons.show_chart,
        child: TrendLineChart(
          points: _overview.trend.sessions,
          requiredPct: _required,
        ),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'Mark composition',
        icon: Icons.donut_small_outlined,
        child: MarkCompositionBar(totals: s?.totals ?? const MarkTotals()),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'Risk mix',
        subtitle: _atRisk.scoringNote,
        icon: Icons.warning_amber_outlined,
        child: RiskBandBar(
          bands: (s?.riskBands.isNotEmpty ?? false)
              ? s!.riskBands
              : _atRisk.bands,
        ),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'What stands out',
        subtitle: 'Ordered by priority. Wording comes from the analysis, '
            'not from this screen.',
        icon: Icons.lightbulb_outline,
        child: InsightList(insights: _overview.insights),
      ),
    ]);
  }

  Widget _classesTab() {
    final classes = _overview.classes;
    if (classes.isEmpty) {
      return _wrap([
        const AnalyticsEmptyState(
          message: 'No classes with recorded sessions in this scope.',
          icon: Icons.class_outlined,
        ),
      ]);
    }
    return _wrap([
      Text('Per-class health', style: AnalyticsTheme.sectionTitle),
      const SizedBox(height: AnalyticsTheme.gapMd),
      MetricGrid(
        tileHeight: 178,
        stagger: false,
        tiles: [
          for (final c in classes)
            ClassHealthTile(
              row: c,
              requiredPct: _required,
              onTap: c.classId == null
                  ? null
                  : () {
                      setState(() {
                        _classId = c.classId.toString();
                        _flags = null;
                      });
                      _load();
                    },
            ),
        ],
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'Distribution of students',
        subtitle: 'How attendance is spread across the cohort.',
        icon: Icons.bar_chart,
        child: BandDistributionChart(
          bands: _overview.distribution.bands,
          total: _overview.distribution.totalStudents,
        ),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'Who absence falls on',
        subtitle: 'Concentration of attendance across students.',
        icon: Icons.pie_chart_outline,
        child: EquityCurvePanel(distribution: _overview.distribution),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'Weekday pattern',
        subtitle: 'Starred days differ significantly from the rest of the week.',
        icon: Icons.calendar_view_week,
        child: PatternBars(
          block: _overview.temporal.weekday,
          requiredPct: _required,
        ),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'Time-of-day pattern',
        icon: Icons.schedule,
        child: PatternBars(
          block: _overview.temporal.timeSlots,
          requiredPct: _required,
        ),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'Weekday × time grid',
        subtitle: 'Tap a cell for its sample size.',
        icon: Icons.grid_on,
        child: AttendanceHeatmap(
          data: _overview.temporal.heatmap,
          requiredPct: _required,
        ),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      AnalyticsCard(
        title: 'How late students mark',
        subtitle: 'Median and P90 rather than a mean: arrival times are '
            'right-skewed.',
        icon: Icons.timer_outlined,
        child: PunctualityPanel(punctuality: _overview.temporal.punctuality),
      ),
    ]);
  }

  Widget _atRiskTab() {
    return _wrap([
      AnalyticsCard(
        title: 'Risk mix',
        subtitle: _atRisk.scoringNote,
        icon: Icons.warning_amber_outlined,
        child: RiskBandBar(bands: _atRisk.bands),
      ),
      const SizedBox(height: AnalyticsTheme.gapLg),
      Row(
        children: [
          Expanded(
            child: Text('Triage list', style: AnalyticsTheme.sectionTitle),
          ),
          Text('${_atRisk.total} scored', style: AnalyticsTheme.caption),
        ],
      ),
      const SizedBox(height: AnalyticsTheme.gapXs),
      Text(
        'Tap a student for the classes and weekdays behind the score.',
        style: AnalyticsTheme.caption,
      ),
      const SizedBox(height: AnalyticsTheme.gapMd),
      AtRiskList(
        students: _atRisk.actionable,
        requiredPct: _required,
        onTap: _openStudent,
        emptyMessage: 'No student is above the "stable" band in this scope.',
      ),
      if (_atRisk.risingRisk.isNotEmpty) ...[
        const SizedBox(height: AnalyticsTheme.gapLg),
        Text('Declining but not yet below the line',
            style: AnalyticsTheme.sectionTitle),
        const SizedBox(height: AnalyticsTheme.gapXs),
        Text(
          'Still at or above the requirement, but trending down — the group a '
          'percentage-sorted list never surfaces.',
          style: AnalyticsTheme.caption,
        ),
        const SizedBox(height: AnalyticsTheme.gapMd),
        AtRiskList(
          students: _atRisk.risingRisk,
          requiredPct: _required,
          onTap: _openStudent,
        ),
      ],
    ]);
  }

  Widget _integrityTab() {
    if (_flagsLoading && _flags == null) {
      return ListView(
        padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
        children: [
          ShimmerSkeleton.panel(height: 110),
          const SizedBox(height: AnalyticsTheme.gapMd),
          ShimmerSkeleton.panel(height: 90),
          const SizedBox(height: AnalyticsTheme.gapMd),
          ShimmerSkeleton.panel(height: 90),
        ],
      );
    }
    if (_flagsError != null) {
      return AnalyticsErrorState(message: _flagsError!, onRetry: _loadFlags);
    }
    final page = _flags;
    return RefreshIndicator(
      onRefresh: _loadFlags,
      color: AnalyticsTheme.accent,
      child: ListView(
        padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
        children: [
          FadeSlideIn(
            child: AnalyticsCard(
              title: 'Integrity signals',
              subtitle: 'Detectors run on every load. Nothing here changes a '
                  'mark.',
              icon: Icons.verified_user_outlined,
              child: IntegritySummaryStrip(summary: _overview.integrity),
            ),
          ),
          const SizedBox(height: AnalyticsTheme.gapLg),
          Wrap(
            spacing: AnalyticsTheme.gapSm,
            children: [
              for (final s in const ['open', 'resolved', 'dismissed', 'all'])
                ChoiceChip(
                  label: Text(s),
                  selected: _flagStatus == s,
                  showCheckmark: false,
                  onSelected: (_) {
                    if (_flagStatus == s) return;
                    setState(() => _flagStatus = s);
                    _loadFlags();
                  },
                ),
              if (_flagsLoading)
                const Padding(
                  padding: EdgeInsets.all(AnalyticsTheme.gapSm),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapLg),
          if (page == null || page.flags.isEmpty)
            AnalyticsEmptyState(
              message: 'No $_flagStatus flags in this scope.',
              detail: page?.note ??
                  'Flags are advisory signals for review, not accusations.',
              icon: Icons.verified_user_outlined,
            )
          else
            for (var i = 0; i < page.flags.length; i++)
              FadeSlideIn(
                index: i,
                offsetY: 10,
                child: IntegrityFlagTile(
                  flag: page.flags[i],
                  onResolve: (status) => _resolveFlag(page.flags[i], status),
                ),
              ),
          const SizedBox(height: AnalyticsTheme.gapXl),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../theme/analytics_theme.dart';
import '../../widgets/analytics/analytics_animations.dart';
import '../../widgets/analytics/analytics_panels.dart';
import '../../widgets/analytics/analytics_primitives.dart';
import '../../widgets/student_drawer.dart';

/// Student-facing analytics: standing per class, session history, and a
/// forecast the student can interrogate.
///
/// Loading rules: overview loads first because it drives the headline. Calendar
/// and simulator load lazily on first tab visit; the simulator re-fetches when
/// the assumed attendance rate changes, debounced so dragging the slider does
/// not spam the endpoint.
class StudentAnalyticsScreen extends StatefulWidget {
  const StudentAnalyticsScreen({super.key});

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _service = AnalyticsService();
  late final TabController _tabs;

  bool _loading = true;
  String? _error;
  StudentOverview _overview = StudentOverview.empty;

  StudentCalendar? _calendar;
  bool _calendarLoading = false;
  String? _calendarError;
  late DateTime _month;

  SimulatorResult? _sim;
  bool _simLoading = false;
  String? _simError;

  /// Assumed future attendance as a percentage (0–100), matching the endpoint's
  /// `attend_pct` parameter. Null means "use my recent weighted rate".
  double? _attendPct;
  Timer? _simDebounce;

  static const _tabLabels = ['Standing', 'History', 'Forecast'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _tabs = TabController(length: _tabLabels.length, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _simDebounce?.cancel();
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.index == 1 && _calendar == null && !_calendarLoading) {
      _loadCalendar();
    }
    if (_tabs.index == 2 && _sim == null && !_simLoading) {
      _loadSimulator();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await _service.studentOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
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

  Future<void> _loadCalendar([DateTime? month]) async {
    final target = month ?? _month;
    setState(() {
      _calendarLoading = true;
      _calendarError = null;
      _month = target;
    });
    try {
      final cal = await _service.studentCalendar(
        year: target.year,
        month: target.month,
      );
      if (!mounted) return;
      setState(() {
        _calendar = cal;
        _calendarLoading = false;
      });
    } on AnalyticsException catch (e) {
      if (!mounted) return;
      setState(() {
        _calendarError = e.message;
        _calendarLoading = false;
      });
    }
  }

  Future<void> _loadSimulator() async {
    setState(() {
      _simLoading = true;
      _simError = null;
    });
    try {
      final sim = await _service.studentSimulate(attendPct: _attendPct);
      if (!mounted) return;
      setState(() {
        _sim = sim;
        _simLoading = false;
      });
    } on AnalyticsException catch (e) {
      if (!mounted) return;
      setState(() {
        _simError = e.message;
        _simLoading = false;
      });
    }
  }

  /// Debounced so dragging the slider issues one request, not twenty.
  void _onRateChanged(double pct) {
    setState(() => _attendPct = pct);
    _simDebounce?.cancel();
    _simDebounce = Timer(const Duration(milliseconds: 350), _loadSimulator);
  }

  void _resetRate() {
    setState(() => _attendPct = null);
    _simDebounce?.cancel();
    _loadSimulator();
  }

  double get _required => _overview.meta.requiredPct;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnalyticsTheme.canvas,
      drawer: const StudentDrawer(currentRoute: 'Analytics'),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _loading
                  ? _loadingBody()
                  : _error != null
                      ? AnalyticsErrorState(message: _error!, onRetry: _load)
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _standingTab(),
                            _historyTab(),
                            _forecastTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gradient header matching the drawer and the rest of the student shell.
  Widget _header() {
    final o = _overview.overall;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AnalyticsTheme.heroGradient,
        boxShadow: AnalyticsTheme.shadowMd,
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My attendance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (!_loading && _error == null)
                      Text(
                        o == null
                            ? 'No attendance recorded yet'
                            : '${_overview.perClass.length} class(es) · '
                                '${o.totals.present}/${o.totals.expected} marks',
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
          TabBar(
            controller: _tabs,
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

  Widget _loadingBody() => ListView(
        padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
        children: [
          const ShimmerSkeleton(height: 150),
          const SizedBox(height: AnalyticsTheme.gapLg),
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: AnalyticsTheme.gapMd),
                const Expanded(child: ShimmerSkeleton(height: 96)),
              ],
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapLg),
          ShimmerSkeleton.panel(height: 130),
        ],
      );

  // -------------------------------------------------------------- standing

  Widget _standingTab() {
    if (!_overview.meta.hasData) {
      return ListView(
        padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
        children: [
          AnalyticsEmptyState(
            message: _overview.reason ??
                'No attendance has been recorded for you yet.',
            detail: 'Your first marked session will populate this page.',
          ),
        ],
      );
    }

    final o = _overview.overall;
    final attention = _overview.classesNeedingAttention;
    return RefreshIndicator(
      onRefresh: _load,
      color: AnalyticsTheme.accent,
      child: ListView(
        padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
        children: [
          ScopeBanner(meta: _overview.meta),
          const SizedBox(height: AnalyticsTheme.gapLg),
          ...staggered([
            HeroPctHeader(
              title: 'Overall attendance',
              pct: o?.attendancePct,
              requiredPct: _required,
              subtitle: o == null
                  ? null
                  : '${o.totals.present} present of ${o.totals.expected} '
                      'expected marks',
              slope: o?.trendSlopePerSession,
              sparkline: o?.sparkline ?? const [],
              chips: [
                if (o?.recentWeightedPct != null)
                  HeroChip(
                    label:
                        'Recent form ${fmtPct(o!.recentWeightedPct, decimals: 0)}',
                    icon: Icons.speed,
                  ),
                if ((o?.classesBelowThreshold ?? 0) > 0)
                  HeroChip(
                    label: '${o!.classesBelowThreshold} class(es) below',
                    icon: Icons.class_outlined,
                  ),
                if ((o?.remainingSessionsEstimated ?? 0) > 0)
                  HeroChip(
                    label: '${o!.remainingSessionsEstimated} sessions left',
                    icon: Icons.event_outlined,
                  ),
              ],
            ),
            const SizedBox(height: AnalyticsTheme.gapLg),
            if (attention.isNotEmpty) _attentionCard(attention),
            if (attention.isNotEmpty)
              const SizedBox(height: AnalyticsTheme.gapLg),
            _metricGrid(o),
            const SizedBox(height: AnalyticsTheme.gapLg),
            AnalyticsCard(
              title: 'Mark composition',
              icon: Icons.donut_small_outlined,
              child:
                  MarkCompositionBar(totals: o?.totals ?? const MarkTotals()),
            ),
            const SizedBox(height: AnalyticsTheme.gapLg),
            AnalyticsCard(
              title: 'Your week',
              subtitle:
                  'Starred days differ significantly from your other days.',
              icon: Icons.calendar_view_week,
              child: PatternBars(
                block: _overview.temporal,
                requiredPct: _required,
                emptyMessage:
                    'Not enough sessions yet to describe your weekly pattern.',
              ),
            ),
            const SizedBox(height: AnalyticsTheme.gapLg),
            Text('Per class', style: AnalyticsTheme.sectionTitle),
            const SizedBox(height: AnalyticsTheme.gapMd),
            if (_overview.perClass.isEmpty)
              const AnalyticsEmptyState(
                message:
                    'You are not enrolled in any class with recorded sessions.',
                icon: Icons.class_outlined,
              )
            else
              for (final c in _overview.perClass)
                StudentClassCard(row: c, requiredPct: _required),
            const SizedBox(height: AnalyticsTheme.gapLg),
            AnalyticsCard(
              title: 'What this means',
              icon: Icons.lightbulb_outline,
              child: InsightList(insights: _overview.insights),
            ),
          ]),
          const SizedBox(height: AnalyticsTheme.gapXl),
        ],
      ),
    );
  }

  Widget _attentionCard(List<ClassAnalyticsRow> classes) {
    return AnalyticsCard(
      title: 'Action needed',
      subtitle: '${classes.length} class(es) have critical attendance standing',
      icon: Icons.warning_amber_rounded,
      accentBorder: AnalyticsTheme.riskCritical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in classes) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${c.classCode} ${c.className}'.trim(),
                      style: AnalyticsTheme.cardTitle,
                    ),
                  ),
                  Text(
                    c.forecast.message ?? c.forecast.status,
                    style: TextStyle(
                      color: c.forecast.isUnreachable
                          ? AnalyticsTheme.riskCritical
                          : AnalyticsTheme.riskHigh,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricGrid(StudentOverall? o) {
    final margin = o?.marginPoints;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AnalyticsTheme.gapMd,
          mainAxisSpacing: AnalyticsTheme.gapMd,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: [
            MetricTile(
              label: 'Present streak',
              value: '${o?.streaks.currentPresent ?? 0}',
              sublabel: 'Longest: ${o?.streaks.longestPresent ?? 0}',
              icon: Icons.local_fire_department_outlined,
            ),
            MetricTile(
              label: 'Absent streak',
              value: '${o?.streaks.currentAbsent ?? 0}',
              sublabel: 'Worst: ${o?.streaks.longestAbsent ?? 0}',
              icon: Icons.bedtime_outlined,
            ),
            MetricTile(
              label: 'Margin vs Req',
              value: margin == null
                  ? '—'
                  : '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)} pts',
              sublabel: o?.meetsThreshold == true
                  ? 'Above requirement'
                  : 'Below requirement',
              valueColor: (margin ?? 0) >= 0
                  ? AnalyticsTheme.present
                  : AnalyticsTheme.absent,
              icon: Icons.compare_arrows,
            ),
            MetricTile(
              label: 'Recent Weight',
              value: fmtPct(o?.recentWeightedPct),
              sublabel: 'Recent form score',
              icon: Icons.speed,
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------- history

  Widget _historyTab() {
    if (_calendarLoading && _calendar == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_calendarError != null) {
      return AnalyticsErrorState(
        message: _calendarError!,
        onRetry: () => _loadCalendar(),
      );
    }
    final cal = _calendar;
    if (cal == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
      children: [
        ScopeBanner(
          meta: cal.meta,
          extra: '${cal.daysRecorded} days with sessions',
        ),
        const SizedBox(height: AnalyticsTheme.gapLg),
        AnalyticsCard(
          title: 'Session history',
          subtitle: cal.attendancePct == null
              ? 'No percentage for this month — no sessions were held.'
              : '${fmtPct(cal.attendancePct)} in this month',
          child: SessionCalendar(
            calendar: cal,
            month: _month,
            onMonthChanged: (y, m) => _loadCalendar(DateTime(y, m)),
            onDayTap: _showDay,
          ),
        ),
        const SizedBox(height: AnalyticsTheme.gapXl),
      ],
    );
  }

  void _showDay(CalendarDay day) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.date, style: AnalyticsTheme.sectionTitle),
            const SizedBox(height: AnalyticsTheme.gapXs),
            Text('${day.present} present of ${day.total} sessions',
                style: AnalyticsTheme.caption),
            const SizedBox(height: AnalyticsTheme.gapLg),
            for (final s in day.sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: AnalyticsTheme.gapMd),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.status == 'present'
                            ? AnalyticsTheme.present
                            : s.status == 'pending_review'
                                ? AnalyticsTheme.pendingReview
                                : AnalyticsTheme.absent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AnalyticsTheme.gapMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.classCode, style: AnalyticsTheme.cardTitle),
                          Text(
                            [
                              s.status.replaceAll('_', ' '),
                              if (s.startTime != null) s.startTime!,
                              if (s.latencySeconds != null)
                                'marked ${s.latencySeconds!.toStringAsFixed(0)}s in',
                            ].join(' · '),
                            style: AnalyticsTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (day.sessions.isEmpty)
              const Text('No sessions were held on this day.'),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- forecast

  Widget _forecastTab() {
    if (_simLoading && _sim == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_simError != null) {
      return AnalyticsErrorState(message: _simError!, onRetry: _loadSimulator);
    }
    final sim = _sim;
    if (sim == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
      children: [
        ScopeBanner(meta: sim.meta),
        const SizedBox(height: AnalyticsTheme.gapLg),
        AnalyticsCard(
          title: 'Try a scenario',
          subtitle: 'Change the rate you expect to attend from here onward.',
          trailing: _simLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          child: AttendRateSlider(
            value: _attendPct == null ? null : _attendPct! / 100.0,
            onChanged: (rate) => _onRateChanged(rate * 100.0),
            onReset: _resetRate,
          ),
        ),
        const SizedBox(height: AnalyticsTheme.gapLg),
        if (sim.scenarios.isEmpty)
          AnalyticsEmptyState(
            message: sim.note ??
                'No class has enough recorded history to project a result.',
            detail: 'Projections need at least one held session and a known '
                'number of remaining sessions.',
            icon: Icons.timeline,
          )
        else
          for (final s in sim.scenarios)
            ForecastScenarioCard(scenario: s, requiredPct: _required),
        const SizedBox(height: AnalyticsTheme.gapXl),
      ],
    );
  }
}

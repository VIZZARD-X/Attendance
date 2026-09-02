import 'package:flutter/material.dart';

import '../../models/analytics_models.dart';
import '../../theme/analytics_theme.dart';
import 'analytics_animations.dart';
import 'analytics_primitives.dart';

/// Domain panels composed from [analytics_primitives].
///
/// These render backend-supplied fields only. Where a value is null the panel
/// states the reason the backend gave rather than substituting a placeholder
/// number.

// ------------------------------------------------------------- teacher panels

/// Portfolio row for one class in the teacher overview.
///
/// Shows the class's health grade and its standing relative to the teacher's
/// own portfolio, because an absolute percentage across different subjects is
/// not comparable — the z-standing is what answers "which class needs me most".
class ClassHealthTile extends StatelessWidget {
  final ClassHealthRow row;
  final double requiredPct;
  final VoidCallback? onTap;

  const ClassHealthTile({
    super.key,
    required this.row,
    required this.requiredPct,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AnalyticsTheme.pctColor(row.attendancePct, requiredPct);
    return HoverLift(
      onTap: onTap,
      child: Container(
        decoration: AnalyticsTheme.card(),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.classCode, style: AnalyticsTheme.cardTitle),
                      if (row.className.isNotEmpty)
                        Text(
                          row.className,
                          style: AnalyticsTheme.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (row.healthGrade != null)
                  SeverityChip(
                    label: 'GRADE ${row.healthGrade}',
                    color: AnalyticsTheme.gradeColor(row.healthGrade),
                  ),
              ],
            ),
            const SizedBox(height: AnalyticsTheme.gapMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedCountUp(
                  value: row.attendancePct,
                  formatter: (v) => '${v.toStringAsFixed(1)}%',
                  style: AnalyticsTheme.metricNumber.copyWith(color: color),
                ),
                const SizedBox(width: AnalyticsTheme.gapSm),
                Icon(
                  AnalyticsTheme.slopeIcon(row.slopePtsPerSession),
                  size: 15,
                  color: AnalyticsTheme.slopeColor(row.slopePtsPerSession),
                ),
                if (row.healthScore != null) ...[
                  const Spacer(),
                  Text(
                    'health ${row.healthScore!.toStringAsFixed(0)}',
                    style: AnalyticsTheme.caption,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AnalyticsTheme.gapSm),
            ThresholdBar(
              pct: row.attendancePct,
              requiredPct: requiredPct,
              height: 7,
            ),
            const SizedBox(height: AnalyticsTheme.gapSm),
            Text(
              '${row.students} students · ${row.sessions} sessions · '
              '${row.belowThreshold} below requirement',
              style: AnalyticsTheme.caption,
            ),
            if (row.standingLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  row.portfolioZ == null
                      ? row.standingLabel!
                      : '${row.standingLabel!} (z=${fmtSigned(row.portfolioZ, decimals: 2)})',
                  style: AnalyticsTheme.caption.copyWith(
                    color: row.portfolioStanding == 'weakest'
                        ? AnalyticsTheme.absent
                        : row.portfolioStanding == 'strongest'
                            ? AnalyticsTheme.present
                            : AnalyticsTheme.textTertiary,
                  ),
                ),
              )
            else if (!row.health.isAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  row.health.unavailableReason,
                  style: AnalyticsTheme.caption,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Risk-ranked student list. Each row shows the drivers behind its score.
class AtRiskList extends StatelessWidget {
  final List<AtRiskStudent> students;
  final double requiredPct;
  final void Function(AtRiskStudent)? onTap;
  final String emptyMessage;

  const AtRiskList({
    super.key,
    required this.students,
    required this.requiredPct,
    this.onTap,
    this.emptyMessage = 'No students are currently at risk in this scope.',
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return AnalyticsEmptyState(
        message: emptyMessage,
        detail: 'Risk is scored only for students with recorded sessions.',
        icon: Icons.verified_outlined,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < students.length; i++)
          FadeSlideIn(
            index: i,
            offsetY: 10,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AnalyticsTheme.gapSm),
              child: AtRiskRow(
                student: students[i],
                requiredPct: requiredPct,
                onTap: onTap == null ? null : () => onTap!(students[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class AtRiskRow extends StatelessWidget {
  final AtRiskStudent student;
  final double requiredPct;
  final VoidCallback? onTap;

  const AtRiskRow({
    super.key,
    required this.student,
    required this.requiredPct,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bandColor = AnalyticsTheme.riskBandColor(student.band);
    final deficit = student.deficitPoints(requiredPct);
    final needed = student.sessionsNeededToRecover(requiredPct);
    return HoverLift(
      onTap: onTap,
      scale: 1.008,
      borderRadius: BorderRadius.circular(AnalyticsTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AnalyticsTheme.gapMd),
        decoration: BoxDecoration(
          color: AnalyticsTheme.surface,
          borderRadius: BorderRadius.circular(AnalyticsTheme.radiusMd),
          border: Border.all(color: AnalyticsTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AnalyticsTheme.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: AnalyticsTheme.cardTitle),
                      Text(
                        [
                          'Attendance ${fmtPct(student.attendancePct)}',
                          if (deficit != null)
                            'deficit ${deficit.toStringAsFixed(1)} pts',
                          if (student.expected > 0)
                            '${student.present}/${student.expected} marks',
                        ].join(' · '),
                        style: AnalyticsTheme.caption,
                      ),
                    ],
                  ),
                ),
                if (student.sparkline.length > 1)
                  SizedBox(
                    width: 62,
                    height: 26,
                    child: Sparkline(
                      values: student.sparkline,
                      color: bandColor,
                      strokeWidth: 1.6,
                    ),
                  ),
                const SizedBox(width: AnalyticsTheme.gapMd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedCountUp(
                      value: student.riskScore,
                      formatter: (v) => v.toStringAsFixed(0),
                      style:
                          AnalyticsTheme.cardTitle.copyWith(color: bandColor),
                    ),
                    SeverityChip(
                      label: (student.band ?? 'unknown').toUpperCase(),
                      color: bandColor,
                    ),
                  ],
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AnalyticsTheme.textTertiary),
                ],
              ],
            ),
            if (student.drivers.isNotEmpty) ...[
              const SizedBox(height: AnalyticsTheme.gapSm),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final d in student.drivers)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AnalyticsTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(d, style: AnalyticsTheme.caption),
                    ),
                ],
              ),
            ],
            if (needed != null && needed > 0) ...[
              const SizedBox(height: AnalyticsTheme.gapXs),
              Text(
                'Needs $needed consecutive present marks to '
                'reach ${requiredPct.toStringAsFixed(0)}%.',
                style: AnalyticsTheme.caption,
              ),
            ],
            if (student.isLowConfidence)
              Padding(
                padding: const EdgeInsets.only(top: AnalyticsTheme.gapXs),
                child: Text(
                  'Low confidence — only ${student.expected} expected marks so far.',
                  style: AnalyticsTheme.caption.copyWith(
                    color: AnalyticsTheme.pendingReview,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Advisory integrity flag with its evidence and resolve actions.
class IntegrityFlagTile extends StatelessWidget {
  final IntegrityFlag flag;
  final void Function(String status)? onResolve;

  const IntegrityFlagTile({super.key, required this.flag, this.onResolve});

  @override
  Widget build(BuildContext context) {
    final color = AnalyticsTheme.severityColor(flag.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: AnalyticsTheme.gapSm),
      padding: const EdgeInsets.all(AnalyticsTheme.gapMd),
      decoration: BoxDecoration(
        color: AnalyticsTheme.surface,
        borderRadius: BorderRadius.circular(AnalyticsTheme.radiusMd),
        border: Border.all(color: AnalyticsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(flag.flagLabel, style: AnalyticsTheme.cardTitle),
              ),
              SeverityChip(
                label: flag.severity.toUpperCase(),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapSm),
          Text(
            [
              if (flag.studentName != null) flag.studentName!,
              if (flag.sessionId != null) 'session #${flag.sessionId}',
              if (flag.score != null) 'score ${flag.score!.toStringAsFixed(2)}',
              if (flag.createdAt != null) flag.createdAt!.split('T').first,
            ].join(' · '),
            style: AnalyticsTheme.caption,
          ),
          if (flag.explanation != null) ...[
            const SizedBox(height: AnalyticsTheme.gapSm),
            Text(flag.explanation!, style: AnalyticsTheme.body),
          ],
          if (flag.evidence.isNotEmpty) ...[
            const SizedBox(height: AnalyticsTheme.gapSm),
            _EvidenceDetails(evidence: flag.evidence),
          ],
          if (!flag.isOpen) ...[
            const SizedBox(height: AnalyticsTheme.gapSm),
            Text(
              '${flag.status} '
              '${flag.resolutionNote == null ? '' : '— ${flag.resolutionNote}'}',
              style: AnalyticsTheme.caption,
            ),
          ],
          if (flag.isOpen && onResolve != null) ...[
            const SizedBox(height: AnalyticsTheme.gapMd),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => onResolve!('dismissed'),
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: AnalyticsTheme.gapSm),
                FilledButton(
                  onPressed: () => onResolve!('resolved'),
                  child: const Text('Mark reviewed'),
                ),
              ],
            ),
          ],
          const MethodologyNote(
            'Advisory only — resolving a flag never changes attendance marks.',
          ),
        ],
      ),
    );
  }
}

/// Collapsible raw evidence for one flag.
///
/// The evidence map is what makes a flag checkable, so it is shown in full
/// rather than summarised. Nested maps are rendered as compact JSON-ish text.
class _EvidenceDetails extends StatelessWidget {
  final Map<String, dynamic> evidence;

  const _EvidenceDetails({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final rows = evidence.entries
        .where((e) => e.key != 'explanation')
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Theme(
      // ExpansionTile draws its own dividers; the card already has a border.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AnalyticsTheme.gapSm),
        title: Text('Evidence (${rows.length})', style: AnalyticsTheme.label),
        children: [
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      e.key.replaceAll('_', ' '),
                      style: AnalyticsTheme.caption,
                    ),
                  ),
                  Expanded(
                    child: Text('${e.value}', style: AnalyticsTheme.mono),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- student panels

/// Per-class card on the student dashboard, including forecast provenance.
///
/// Surfaces the point-of-no-return verdict (`forecast.status`) directly, since
/// "the requirement can no longer be reached" is the single most consequential
/// thing this screen can tell a student.
class StudentClassCard extends StatelessWidget {
  final ClassAnalyticsRow row;
  final double requiredPct;

  const StudentClassCard({
    super.key,
    required this.row,
    required this.requiredPct,
  });

  @override
  Widget build(BuildContext context) {
    final color = AnalyticsTheme.pctColor(row.attendancePct, requiredPct);
    final pnr = row.forecast;
    return Container(
      margin: const EdgeInsets.only(bottom: AnalyticsTheme.gapMd),
      decoration: AnalyticsTheme.card(
        accentBorder: pnr.isUnreachable
            ? AnalyticsTheme.absent.withValues(alpha: 0.45)
            : null,
      ),
      padding: AnalyticsTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.classCode, style: AnalyticsTheme.cardTitle),
                    if (row.className.isNotEmpty)
                      Text(row.className, style: AnalyticsTheme.caption),
                  ],
                ),
              ),
              AnimatedCountUp(
                value: row.attendancePct,
                formatter: (v) => '${v.toStringAsFixed(1)}%',
                style: AnalyticsTheme.metricNumber.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapMd),
          ThresholdBar(pct: row.attendancePct, requiredPct: requiredPct),
          const SizedBox(height: AnalyticsTheme.gapMd),
          Wrap(
            spacing: AnalyticsTheme.gapLg,
            runSpacing: AnalyticsTheme.gapSm,
            children: [
              _stat('Present', '${row.totals.present}/${row.totals.expected}'),
              _stat('Sessions held', '${row.sessionsHeld}'),
              if (row.totals.pendingReview > 0)
                _stat('Pending review', '${row.totals.pendingReview}'),
              _stat('Recent weighted', fmtPct(row.recentWeightedPct)),
              if (row.cohort.percentileRank != null)
                _stat(
                  'Cohort rank',
                  'p${row.cohort.percentileRank!.toStringAsFixed(0)}',
                ),
              if (row.streaks.longestAbsent > 0)
                _stat('Worst absent run', '${row.streaks.longestAbsent}'),
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapMd),
          _forecastLine(),
          if (pnr.hasVerdict && pnr.message != null)
            Padding(
              padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
              child: _VerdictBanner(pnr: pnr),
            ),
          if (row.projectionAvailable &&
              row.projection.probabilityMeetingPct != null)
            Padding(
              padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
              child: Text(
                'Chance of finishing at or above ${requiredPct.toStringAsFixed(0)}%: '
                '${row.projection.probabilityMeetingPct!.toStringAsFixed(0)}%'
                '${row.projection.hasBand ? ' · likely range ${fmtPct(row.projection.p10)}–${fmtPct(row.projection.p90)}' : ''}',
                style: AnalyticsTheme.body,
              ),
            )
          else if (!row.projectionAvailable)
            Padding(
              padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
              child: Text(
                row.projection.unavailableReason,
                style: AnalyticsTheme.caption,
              ),
            ),
          if (row.streaks.currentAbsent > 0 || row.streaks.currentPresent > 0)
            Padding(
              padding: const EdgeInsets.only(top: AnalyticsTheme.gapXs),
              child: Text(
                row.streaks.currentAbsent > 0
                    ? 'Current streak: ${row.streaks.currentAbsent} absent'
                    : 'Current streak: ${row.streaks.currentPresent} present',
                style: AnalyticsTheme.caption,
              ),
            ),
          if (row.sparkline.length > 1) ...[
            const SizedBox(height: AnalyticsTheme.gapMd),
            SizedBox(
              height: 34,
              child: Sparkline(values: row.sparkline, color: color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _forecastLine() {
    if (!row.remaining.isKnown) {
      return Text(
        row.remaining.note ??
            'Remaining sessions are unknown, so no projection is shown.',
        style: AnalyticsTheme.caption,
      );
    }
    final canMiss = row.canMiss.canMiss;
    final needed = row.sessionsNeededToRecover;
    final parts = <String>[
      '${row.remaining.remaining} sessions remaining '
          '(${row.remaining.sourceLabel})',
      if (canMiss != null) 'can miss $canMiss more',
      if (needed != null && needed > 0) 'needs $needed present to recover',
    ];
    return Text(parts.join(' · '), style: AnalyticsTheme.body);
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AnalyticsTheme.label.copyWith(fontSize: 10)),
          Text(value, style: AnalyticsTheme.cardTitle),
        ],
      );
}

/// Point-of-no-return verdict, rendered in the backend's own words.
///
/// Colour is driven by `status`, not by re-deriving a judgement from the
/// numbers: `unreachable` and `critical` are red, `tight` amber, `recoverable`
/// green.
class _VerdictBanner extends StatelessWidget {
  final PointOfNoReturn pnr;

  const _VerdictBanner({required this.pnr});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (pnr.status) {
      'unreachable' => (AnalyticsTheme.riskCritical, Icons.block),
      'critical' => (AnalyticsTheme.absent, Icons.priority_high),
      'tight' => (AnalyticsTheme.pendingReview, Icons.warning_amber_outlined),
      'recoverable' => (AnalyticsTheme.present, Icons.check_circle_outline),
      _ => (AnalyticsTheme.textTertiary, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.all(AnalyticsTheme.gapMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AnalyticsTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AnalyticsTheme.gapSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pnr.message!,
                  style: AnalyticsTheme.body.copyWith(
                    color: AnalyticsTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pnr.deadlineDate != null)
                  Text(
                    'Decisive by ${pnr.deadlineDate}',
                    style: AnalyticsTheme.caption,
                  ),
                if (pnr.bestPossiblePct != null && pnr.isUnreachable)
                  Text(
                    'Best achievable: ${fmtPct(pnr.bestPossiblePct)}',
                    style: AnalyticsTheme.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Month grid of recorded sessions. Days with no sessions are visibly neutral,
/// distinct from days marked absent.
class SessionCalendar extends StatelessWidget {
  final StudentCalendar calendar;
  final DateTime month;
  final void Function(int year, int month)? onMonthChanged;
  final void Function(CalendarDay)? onDayTap;

  const SessionCalendar({
    super.key,
    required this.calendar,
    required this.month,
    this.onMonthChanged,
    this.onDayTap,
  });

  static const _weekLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final byDate = calendar.byDate;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-first grid.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onMonthChanged == null
                  ? null
                  : () {
                      final prev = DateTime(month.year, month.month - 1);
                      onMonthChanged!(prev.year, prev.month);
                    },
            ),
            Expanded(
              child: Text(
                '${_monthName(month.month)} ${month.year}',
                textAlign: TextAlign.center,
                style: AnalyticsTheme.cardTitle,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onMonthChanged == null
                  ? null
                  : () {
                      final next = DateTime(month.year, month.month + 1);
                      onMonthChanged!(next.year, next.month);
                    },
            ),
          ],
        ),
        Row(
          children: [
            for (final l in _weekLabels)
              Expanded(
                child: Center(
                  child: Text(l, style: AnalyticsTheme.caption),
                ),
              ),
          ],
        ),
        const SizedBox(height: AnalyticsTheme.gapSm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (context, i) {
            if (i < leading) return const SizedBox.shrink();
            final dayNum = i - leading + 1;
            final iso = '${month.year.toString().padLeft(4, '0')}-'
                '${month.month.toString().padLeft(2, '0')}-'
                '${dayNum.toString().padLeft(2, '0')}';
            final day = byDate[iso];
            return _DayCell(
              dayNum: dayNum,
              day: day,
              onTap: day == null || onDayTap == null
                  ? null
                  : () => onDayTap!(day),
            );
          },
        ),
        const SizedBox(height: AnalyticsTheme.gapMd),
        Wrap(
          spacing: AnalyticsTheme.gapMd,
          runSpacing: AnalyticsTheme.gapSm,
          children: const [
            _Legend('Present', AnalyticsTheme.present),
            _Legend('Absent', AnalyticsTheme.absent),
            _Legend('Partial', AnalyticsTheme.pendingReview),
            _Legend('No session', AnalyticsTheme.noData),
          ],
        ),
        const MethodologyNote(
          'Only sessions that were actually held appear here; blank days had no '
          'scheduled session.',
        ),
      ],
    );
  }

  String _monthName(int m) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][m - 1];
}

class _DayCell extends StatelessWidget {
  final int dayNum;
  final CalendarDay? day;
  final VoidCallback? onTap;

  const _DayCell({required this.dayNum, this.day, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg = AnalyticsTheme.surfaceMuted;
    Color fg = AnalyticsTheme.textTertiary;
    if (day != null) {
      switch (day!.state) {
        case 'present':
          bg = AnalyticsTheme.present;
          fg = Colors.white;
          break;
        case 'absent':
          bg = AnalyticsTheme.absent;
          fg = Colors.white;
          break;
        case 'partial':
          bg = AnalyticsTheme.pendingReview;
          fg = Colors.white;
          break;
        default:
          bg = AnalyticsTheme.surfaceMuted;
      }
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AnalyticsTheme.radiusSm),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AnalyticsTheme.radiusSm),
          border: Border.all(color: AnalyticsTheme.border),
        ),
        child: Center(
          child: Text(
            '$dayNum',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;

  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: AnalyticsTheme.caption),
      ],
    );
  }
}

/// Forecast card for one class, driven by the simulator endpoint.
class ForecastScenarioCard extends StatelessWidget {
  final ForecastScenario scenario;
  final double requiredPct;

  const ForecastScenarioCard({
    super.key,
    required this.scenario,
    required this.requiredPct,
  });

  @override
  Widget build(BuildContext context) {
    if (!scenario.isAvailable) {
      return Container(
        margin: const EdgeInsets.only(bottom: AnalyticsTheme.gapMd),
        decoration: AnalyticsTheme.card(),
        padding: AnalyticsTheme.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scenario.classCode, style: AnalyticsTheme.cardTitle),
            const SizedBox(height: AnalyticsTheme.gapSm),
            Text(
              scenario.reason ??
                  'A projection is not available for this class yet.',
              style: AnalyticsTheme.body,
            ),
          ],
        ),
      );
    }

    final projected = scenario.projectedPct;
    final color = AnalyticsTheme.pctColor(projected, requiredPct);
    final dist = scenario.distribution;

    return Container(
      margin: const EdgeInsets.only(bottom: AnalyticsTheme.gapMd),
      decoration: AnalyticsTheme.card(),
      padding: AnalyticsTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(scenario.classCode,
                    style: AnalyticsTheme.cardTitle),
              ),
              Text(
                'now ${fmtPct(scenario.currentPct)}',
                style: AnalyticsTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCountUp(
                value: projected,
                formatter: (v) => '${v.toStringAsFixed(1)}%',
                style: AnalyticsTheme.metricNumber.copyWith(color: color),
              ),
              const SizedBox(width: AnalyticsTheme.gapSm),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('projected at term end',
                    style: AnalyticsTheme.caption),
              ),
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapSm),
          ThresholdBar(pct: projected, requiredPct: requiredPct),
          const SizedBox(height: AnalyticsTheme.gapMd),
          Wrap(
            spacing: AnalyticsTheme.gapLg,
            runSpacing: AnalyticsTheme.gapSm,
            children: [
              _kv('If perfect from now',
                  fmtPct(scenario.projectedPctIfPerfect)),
              _kv(
                'Chance of meeting requirement',
                dist.probabilityMeetingPct == null
                    ? '—'
                    : '${dist.probabilityMeetingPct!.toStringAsFixed(0)}%',
              ),
              _kv('Can still miss',
                  scenario.canMiss.canMiss == null
                      ? '—'
                      : '${scenario.canMiss.canMiss}'),
              _kv(
                'Remaining sessions',
                scenario.remaining.remaining == null
                    ? '—'
                    : '${scenario.remaining.remaining}',
              ),
            ],
          ),
          if (dist.hasBand) ...[
            const SizedBox(height: AnalyticsTheme.gapSm),
            Text(
              'Likely range ${fmtPct(dist.p10)} – ${fmtPct(dist.p90)} '
              '(median ${fmtPct(dist.p50)}'
              '${dist.trials == null || dist.trials == 0 ? '' : ', ${dist.trials} simulated runs'})',
              style: AnalyticsTheme.body,
            ),
          ] else if (!dist.isAvailable)
            Padding(
              padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
              child: Text(
                dist.unavailableReason,
                style: AnalyticsTheme.caption,
              ),
            ),
          if (scenario.pointOfNoReturn.hasVerdict &&
              scenario.pointOfNoReturn.message != null)
            Padding(
              padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
              child: _VerdictBanner(pnr: scenario.pointOfNoReturn),
            ),
          MethodologyNote(
            'Assumes a ${(scenario.attendPctUsed ?? 0).toStringAsFixed(0)}% '
            'attendance rate for remaining sessions '
            '(${scenario.attendRateSource ?? 'recent weighted'}); '
            'remaining count from ${scenario.remaining.source ?? 'unknown'}'
            '${scenario.remaining.confidence == null ? '' : ', ${scenario.remaining.confidence} confidence'}.',
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AnalyticsTheme.label.copyWith(fontSize: 10)),
          Text(value, style: AnalyticsTheme.cardTitle),
        ],
      );
}

/// Slider controlling the assumed future attendance rate.
class AttendRateSlider extends StatelessWidget {
  final double? value;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  const AttendRateSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                value == null
                    ? 'Using your recent weighted attendance rate'
                    : 'Assuming ${(value! * 100).toStringAsFixed(0)}% attendance from here',
                style: AnalyticsTheme.body,
              ),
            ),
            if (value != null)
              TextButton(onPressed: onReset, child: const Text('Reset')),
          ],
        ),
        Slider(
          value: value ?? 1.0,
          min: 0,
          max: 1,
          divisions: 20,
          label: '${((value ?? 1.0) * 100).toStringAsFixed(0)}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- new panels

/// Cohort health score with its four weighted components.
///
/// The score is a weighted composite (coverage 40, equity 25, momentum 20,
/// consistency 15), so the components are shown alongside it — a single number
/// without its parts cannot be acted on. When the backend reports
/// `insufficient_data` the panel says so and shows nothing else.
class CohortHealthPanel extends StatelessWidget {
  final CohortHealth health;
  final double requiredPct;

  const CohortHealthPanel({
    super.key,
    required this.health,
    required this.requiredPct,
  });

  @override
  Widget build(BuildContext context) {
    if (!health.isAvailable) {
      return AnalyticsCard(
        title: 'Cohort health',
        icon: Icons.favorite_outline,
        child: AnalyticsEmptyState(
          message: health.unavailableReason,
          detail: 'Health is scored only once enough sessions exist to be '
              'meaningful.',
          icon: Icons.monitor_heart_outlined,
        ),
      );
    }

    final color = AnalyticsTheme.gradeColor(health.grade);
    return AnalyticsCard(
      title: 'Cohort health',
      subtitle: health.gradeLabel,
      icon: Icons.favorite_outline,
      trailing: SeverityChip(
        label: 'GRADE ${health.grade ?? '—'}',
        color: color,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 520;
          final gauge = RadialGauge(
            score: health.score,
            centerLabel: 'HEALTH',
            centerSublabel: health.grade == null ? null : 'grade ${health.grade}',
            color: color,
            size: stacked ? 118 : 136,
          );
          final components = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final comp in health.orderedComponents)
                WeightedComponentRow(
                  label: comp.key,
                  value: comp.value,
                  weight: comp.weight,
                  meaning: comp.meaning,
                  color: color,
                ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked)
                Column(
                  children: [
                    Center(child: gauge),
                    const SizedBox(height: AnalyticsTheme.gapLg),
                    components,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    gauge,
                    const SizedBox(width: AnalyticsTheme.gapXl),
                    Expanded(child: components),
                  ],
                ),
              const SizedBox(height: AnalyticsTheme.gapMd),
              Wrap(
                spacing: AnalyticsTheme.gapLg,
                runSpacing: AnalyticsTheme.gapSm,
                children: [
                  _fact('Students', '${health.students}'),
                  _fact('Sessions', '${health.sessions}'),
                  _fact(
                    'Below ${requiredPct.toStringAsFixed(0)}%',
                    '${health.belowThresholdCount}',
                  ),
                  if (health.gini != null)
                    _fact('Gini', health.gini!.toStringAsFixed(3)),
                  if (health.cohortSlopePtsPerSession != null)
                    _fact(
                      'Trend',
                      '${fmtSigned(health.cohortSlopePtsPerSession, decimals: 3)} pts/session',
                    ),
                ],
              ),
              if (health.interpretation != null)
                MethodologyNote(health.interpretation!),
            ],
          );
        },
      ),
    );
  }

  Widget _fact(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AnalyticsTheme.label.copyWith(fontSize: 10)),
          Text(value, style: AnalyticsTheme.cardTitle),
        ],
      );
}


/// Weekday x time-slot attendance heatmap.
///
/// Cells below the backend's `min_sessions_per_cell` floor are hatched, not
/// coloured: a two-session cell at 50% is noise, and shading it red would
/// invent a pattern. Combinations with no sessions at all are left blank.
class AttendanceHeatmap extends StatefulWidget {
  final HeatmapData data;
  final double requiredPct;

  const AttendanceHeatmap({
    super.key,
    required this.data,
    required this.requiredPct,
  });

  @override
  State<AttendanceHeatmap> createState() => _AttendanceHeatmapState();
}

class _AttendanceHeatmapState extends State<AttendanceHeatmap> {
  HeatmapCell? _selected;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return AnalyticsEmptyState(
        message: 'No sessions to place on a weekday/time grid yet.',
        detail: widget.data.note,
        icon: Icons.grid_on,
      );
    }

    final weekdays = widget.data.activeWeekdays;
    final slots = widget.data.activeSlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 78),
                  for (final s in slots)
                    SizedBox(
                      width: 78,
                      child: Text(
                        s.label,
                        style: AnalyticsTheme.caption,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (final w in weekdays)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text(w.label, style: AnalyticsTheme.caption),
                      ),
                      for (final s in slots)
                        _HeatCell(
                          cell: widget.data
                              .cellAt(int.tryParse(w.key) ?? -1, s.key),
                          requiredPct: widget.requiredPct,
                          selected: _selected,
                          onTap: (cell) => setState(
                            () => _selected = _selected == cell ? null : cell,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AnalyticsTheme.gapMd),
        const _HeatLegend(),
        if (_selected != null)
          Padding(
            padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
            child: Text(_describe(_selected!), style: AnalyticsTheme.body),
          ),
        if (widget.data.note != null) MethodologyNote(widget.data.note!),
      ],
    );
  }

  String _describe(HeatmapCell c) {
    final where = '${c.weekdayLabel} ${c.slot.replaceAll('_', ' ')}';
    if (c.sufficientData) {
      return '$where: ${fmtPct(c.attendancePct)} across ${c.sessions} sessions '
          '(${c.expectedMarks} expected marks)';
    }
    return '$where: only ${c.sessions} session(s) — too few to score'
        '${c.rawPct == null ? '' : ' (raw ${fmtPct(c.rawPct)})'}';
  }
}


/// One cell of [AttendanceHeatmap].
class _HeatCell extends StatelessWidget {
  final HeatmapCell? cell;
  final double requiredPct;
  final HeatmapCell? selected;
  final void Function(HeatmapCell) onTap;

  const _HeatCell({
    required this.cell,
    required this.requiredPct,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = cell;
    if (c == null) {
      // No session was ever held in this weekday/slot combination.
      return const SizedBox(width: 78, height: 42);
    }
    final isSelected = selected == c;

    if (!c.sufficientData) {
      return SizedBox(
        width: 78,
        height: 42,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: GestureDetector(
            onTap: () => onTap(c),
            child: Tooltip(
              message: 'Only ${c.sessions} session(s) — insufficient data',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AnalyticsTheme.radiusSm),
                  border: Border.all(
                    color: isSelected
                        ? AnalyticsTheme.accent
                        : AnalyticsTheme.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: CustomPaint(
                  painter: _CellHatchPainter(),
                  child: Center(
                    child: Text(
                      'n=${c.sessions}',
                      style: AnalyticsTheme.caption.copyWith(fontSize: 9.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final color = AnalyticsTheme.pctColor(c.attendancePct, requiredPct);
    return SizedBox(
      width: 78,
      height: 42,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: GestureDetector(
          onTap: () => onTap(c),
          child: AnimatedContainer(
            duration: AnalyticsTheme.motionFast,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AnalyticsTheme.radiusSm),
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.35),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtPct(c.attendancePct, decimals: 0),
                    style: AnalyticsTheme.cardTitle
                        .copyWith(color: color, fontSize: 13),
                  ),
                  Text(
                    'n=${c.sessions}',
                    style: AnalyticsTheme.caption.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diagonal hatching, used to mark "not enough data" without implying a value.
class _CellHatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AnalyticsTheme.noData.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CellHatchPainter old) => false;
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AnalyticsTheme.gapMd,
      runSpacing: AnalyticsTheme.gapSm,
      children: [
        _swatch('At or above requirement', AnalyticsTheme.riskSafe),
        _swatch('Just below', AnalyticsTheme.riskModerate),
        _swatch('Well below', AnalyticsTheme.riskHigh),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 10,
              child: CustomPaint(painter: _CellHatchPainter()),
            ),
            const SizedBox(width: 5),
            Text('Insufficient data', style: AnalyticsTheme.caption),
          ],
        ),
      ],
    );
  }

  Widget _swatch(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: AnalyticsTheme.caption),
        ],
      );
}


/// Arrival-time distribution.
///
/// Median plus P90, matching the backend's own choice: latency is right-skewed,
/// so a mean would be dragged around by a handful of very late marks. A rising
/// P90 against a flat median means a subgroup is drifting late, which is a
/// different problem from the whole class arriving later.
class PunctualityPanel extends StatelessWidget {
  final Punctuality punctuality;

  const PunctualityPanel({super.key, required this.punctuality});

  @override
  Widget build(BuildContext context) {
    if (!punctuality.isAvailable) {
      return AnalyticsEmptyState(
        message: punctuality.insufficientReason,
        detail: 'Arrival times come from the timestamp on each present mark.',
        icon: Icons.timer_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AnalyticsTheme.gapXl,
          runSpacing: AnalyticsTheme.gapSm,
          children: [
            _stat('Median arrival', punctuality.medianSeconds),
            _stat('Fastest 10%', punctuality.p10Seconds),
            _stat('Slowest 10%', punctuality.p90Seconds),
          ],
        ),
        const SizedBox(height: AnalyticsTheme.gapLg),
        for (var i = 0; i < punctuality.buckets.length; i++)
          FadeSlideIn(
            index: i,
            offsetY: 6,
            child: _bucketRow(punctuality.buckets[i], i),
          ),
        if (punctuality.finding != null)
          MethodologyNote(punctuality.finding!),
        MethodologyNote(
          '${punctuality.marksAnalysed} present marks with a recorded arrival '
          'time.',
        ),
      ],
    );
  }

  Widget _stat(String label, double? seconds) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AnalyticsTheme.label.copyWith(fontSize: 10)),
          AnimatedCountUp(
            value: seconds == null ? null : seconds / 60,
            formatter: (v) => '${v.toStringAsFixed(1)} min',
            style: AnalyticsTheme.cardTitle,
          ),
        ],
      );

  Widget _bucketRow(PunctualityBucket b, int index) {
    // Colour by lateness, matching the mark semantics used elsewhere.
    final color = index == 0
        ? AnalyticsTheme.present
        : index == 1
            ? AnalyticsTheme.pendingReview
            : AnalyticsTheme.absent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(b.label, style: AnalyticsTheme.caption),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AnalyticsTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  AnimatedBarFill(
                    fraction: ((b.pct ?? 0) / 100).clamp(0.0, 1.0),
                    builder: (context, t) => Container(
                      height: 10,
                      width: c.maxWidth * t,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.7), color],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AnalyticsTheme.gapSm),
          SizedBox(
            width: 92,
            child: Text(
              '${fmtPct(b.pct, decimals: 0)} · ${b.count}',
              style: AnalyticsTheme.caption,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}


/// Lorenz curve of attendance concentration, with the Gini coefficient.
///
/// Answers a question an average cannot: is absence spread thinly across the
/// cohort, or concentrated in a few students? The diagonal is perfect equality;
/// the gap between it and the curve is the inequality the Gini number measures.
class EquityCurvePanel extends StatelessWidget {
  final Distribution distribution;

  const EquityCurvePanel({super.key, required this.distribution});

  @override
  Widget build(BuildContext context) {
    if (distribution.lorenz.length < 2) {
      return const AnalyticsEmptyState(
        message: 'Not enough students to measure how evenly attendance is '
            'spread.',
        detail: 'A concentration curve needs at least two students with '
            'recorded marks.',
        icon: Icons.pie_chart_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GINI',
                      style: AnalyticsTheme.label.copyWith(fontSize: 10)),
                  AnimatedCountUp(
                    value: distribution.gini,
                    formatter: (v) => v.toStringAsFixed(3),
                    style: AnalyticsTheme.metricNumber,
                  ),
                ],
              ),
            ),
            if (distribution.medianPct != null)
              _stat('Median student', fmtPct(distribution.medianPct)),
            const SizedBox(width: AnalyticsTheme.gapLg),
            if (distribution.p10Pct != null)
              _stat('Bottom 10%', fmtPct(distribution.p10Pct)),
          ],
        ),
        const SizedBox(height: AnalyticsTheme.gapLg),
        SizedBox(
          height: 190,
          child: DrawOnBuilder(
            builder: (context, t) => CustomPaint(
              painter: _LorenzPainter(distribution.lorenz, t),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: AnalyticsTheme.gapSm),
        Text(
          'Horizontal: students, weakest first. Vertical: share of all present '
          'marks they account for.',
          style: AnalyticsTheme.caption,
        ),
        if (distribution.giniReading != null)
          MethodologyNote(distribution.giniReading!),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AnalyticsTheme.label.copyWith(fontSize: 10)),
          Text(value, style: AnalyticsTheme.cardTitle),
        ],
      );
}

class _LorenzPainter extends CustomPainter {
  final List<LorenzPoint> points;
  final double t;

  _LorenzPainter(this.points, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 26.0;
    final w = size.width - pad;
    final h = size.height - pad;
    if (w <= 0 || h <= 0) return;

    final frame = Paint()
      ..color = AnalyticsTheme.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(pad, 0), Offset(pad, h), frame);
    canvas.drawLine(Offset(pad, h), Offset(size.width, h), frame);

    // Line of perfect equality.
    final equality = Paint()
      ..color = AnalyticsTheme.textTertiary
      ..strokeWidth = 1.2;
    for (double x = 0; x < w; x += 8) {
      canvas.drawLine(
        Offset(pad + x, h - (x / w) * h),
        Offset(pad + (x + 4).clamp(0, w), h - ((x + 4).clamp(0, w) / w) * h),
        equality,
      );
    }

    Offset at(LorenzPoint p) => Offset(
          pad + (p.populationPct / 100).clamp(0.0, 1.0) * w,
          h - (p.attendanceSharePct / 100).clamp(0.0, 1.0) * h,
        );

    final path = Path()..moveTo(pad, h);
    for (final p in points) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }

    final fill = Path.from(path)
      ..lineTo(at(points.last).dx, h)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, pad + w * t, size.height));
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AnalyticsTheme.accent.withValues(alpha: 0.22),
            AnalyticsTheme.accent.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(pad, 0, w, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AnalyticsTheme.accent
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    _text(canvas, '100%', Offset(0, -2));
    _text(canvas, '0%', Offset(0, h - 12));
    _text(canvas, 'students →', Offset(pad + 2, h + 4));
  }

  void _text(Canvas canvas, String s, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: AnalyticsTheme.caption),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_LorenzPainter old) =>
      old.points != points || old.t != t;
}


/// Compact integrity strip: counts by severity and type, plus the verification
/// distribution and the detector catalogue.
///
/// Everything here is advisory. The wording avoids accusation because a flag is
/// a signal to look, not a finding of wrongdoing.
class IntegritySummaryStrip extends StatelessWidget {
  final IntegritySummary summary;
  final VoidCallback? onSeeAll;

  const IntegritySummaryStrip({
    super.key,
    required this.summary,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty && !summary.hasVerification) {
      return const AnalyticsEmptyState(
        message: 'No integrity signals in this scope.',
        detail: 'Detectors run on every load; nothing crossed a threshold.',
        icon: Icons.verified_user_outlined,
        minHeight: 90,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AnalyticsTheme.gapSm,
          runSpacing: AnalyticsTheme.gapSm,
          children: [
            for (final s in summary.orderedSeverities)
              SeverityChip(
                label: '${s.severity.toUpperCase()} · ${s.count}',
                color: AnalyticsTheme.severityColor(s.severity),
                icon: Icons.flag_outlined,
              ),
            if (summary.orderedSeverities.isEmpty)
              SeverityChip(
                label: 'NO OPEN FLAGS',
                color: AnalyticsTheme.present,
                icon: Icons.check,
              ),
          ],
        ),
        const SizedBox(height: AnalyticsTheme.gapMd),
        Wrap(
          spacing: AnalyticsTheme.gapXl,
          runSpacing: AnalyticsTheme.gapSm,
          children: [
            _stat('Open', '${summary.openCount}'),
            _stat('New this load', '${summary.newlyDetected}'),
            _stat('Already known', '${summary.previouslyKnown}'),
            if (summary.hasVerification)
              _stat(
                'Median verification',
                summary.verificationMedian == null
                    ? '—'
                    : summary.verificationMedian!.toStringAsFixed(3),
              ),
            if (summary.hasVerification)
              _stat(
                'Weakest 10%',
                summary.verificationP10 == null
                    ? '—'
                    : summary.verificationP10!.toStringAsFixed(3),
              ),
          ],
        ),
        if (summary.orderedTypes.isNotEmpty) ...[
          const SizedBox(height: AnalyticsTheme.gapMd),
          Text('BY TYPE', style: AnalyticsTheme.label.copyWith(fontSize: 10)),
          const SizedBox(height: AnalyticsTheme.gapXs),
          for (final t in summary.orderedTypes)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.type.replaceAll('_', ' '),
                      style: AnalyticsTheme.caption,
                    ),
                  ),
                  Text('${t.count}', style: AnalyticsTheme.caption),
                ],
              ),
            ),
        ],
        if (summary.detectors.isNotEmpty) ...[
          const SizedBox(height: AnalyticsTheme.gapSm),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'What is being checked (${summary.detectors.length})',
                style: AnalyticsTheme.label,
              ),
              children: [
                for (final d in summary.detectors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.radar,
                            size: 13, color: AnalyticsTheme.textTertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: AnalyticsTheme.caption,
                              children: [
                                TextSpan(
                                  text: '${d.name.replaceAll('_', ' ')}: ',
                                  style: AnalyticsTheme.caption.copyWith(
                                    color: AnalyticsTheme.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: d.description),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (onSeeAll != null && summary.openCount > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onSeeAll,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Review flags'),
            ),
          ),
        MethodologyNote(
          summary.note ??
              'Flags never change attendance records or the percentages '
                  'computed from them.',
        ),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AnalyticsTheme.label.copyWith(fontSize: 10)),
          Text(value, style: AnalyticsTheme.cardTitle),
        ],
      );
}


/// Bottom sheet showing one student's drill-down, fetched on demand.
///
/// This is the teacher-side counterpart to the student's own dashboard, and the
/// reason the at-risk list is tappable: a risk score is only actionable once you
/// can see which classes and which weekdays drive it.
class StudentDrillDownSheet extends StatelessWidget {
  final TeacherStudentDetail detail;
  final double requiredPct;

  const StudentDrillDownSheet({
    super.key,
    required this.detail,
    required this.requiredPct,
  });

  /// Shows a sheet that loads its own data, so callers only pass a loader.
  static Future<void> show(
    BuildContext context, {
    required Future<TeacherStudentDetail> Function() load,
    required double requiredPct,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AnalyticsTheme.surface,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => FutureBuilder<TeacherStudentDetail>(
          future: load(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
                children: [
                  const ShimmerSkeleton(width: 180, height: 18),
                  const SizedBox(height: AnalyticsTheme.gapLg),
                  ShimmerSkeleton.panel(height: 90),
                  const SizedBox(height: AnalyticsTheme.gapMd),
                  ShimmerSkeleton.panel(height: 120),
                ],
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
                child: AnalyticsErrorState(message: '${snap.error}'),
              );
            }
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(AnalyticsTheme.gapLg),
              children: [
                StudentDrillDownSheet(
                  detail: snap.data!,
                  requiredPct: requiredPct,
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final risk = detail.risk;
    final bandColor = AnalyticsTheme.riskBandColor(risk.band);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.name, style: AnalyticsTheme.sectionTitle),
                  if (detail.username != null)
                    Text('@${detail.username}', style: AnalyticsTheme.caption),
                ],
              ),
            ),
            if (risk.band != null)
              SeverityChip(
                label: '${risk.band!.toUpperCase()} · '
                    '${risk.riskScore?.toStringAsFixed(0) ?? '—'}',
                color: bandColor,
              ),
          ],
        ),
        const SizedBox(height: AnalyticsTheme.gapLg),
        HeadlinePctTile(
          pct: detail.overallPct,
          requiredPct: requiredPct,
          label: 'Overall attendance',
          sublabel: '${detail.overall.present} present of '
              '${detail.overall.expected} expected marks',
          slope: risk.slope,
          sparkline: risk.sparkline,
        ),
        if (risk.rankedComponents.isNotEmpty) ...[
          const SizedBox(height: AnalyticsTheme.gapLg),
          AnalyticsCard(
            title: 'Why this score',
            subtitle: 'Each component scaled 0–100, then weighted.',
            icon: Icons.calculate_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final comp in risk.rankedComponents)
                  WeightedComponentRow(
                    label: comp.key,
                    value: comp.value,
                    weight: comp.weight,
                    color: bandColor,
                  ),
                if (risk.drivers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final d in risk.drivers)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: AnalyticsTheme.caption),
                              Expanded(
                                child: Text(d, style: AnalyticsTheme.caption),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AnalyticsTheme.gapLg),
        Text('Per class', style: AnalyticsTheme.sectionTitle),
        const SizedBox(height: AnalyticsTheme.gapMd),
        if (detail.perClass.isEmpty)
          const AnalyticsEmptyState(
            message: 'No class rows for this student in the current scope.',
            icon: Icons.class_outlined,
          )
        else
          for (final row in detail.perClass)
            StudentClassCard(row: row, requiredPct: requiredPct),
        const SizedBox(height: AnalyticsTheme.gapLg),
        AnalyticsCard(
          title: 'Weekday profile',
          subtitle: 'Only days with enough sessions are scored.',
          icon: Icons.calendar_view_week,
          child: PatternBars(
            block: detail.temporal,
            requiredPct: requiredPct,
            emptyMessage: 'Not enough sessions to describe a weekly pattern '
                'for this student.',
          ),
        ),
        const SizedBox(height: AnalyticsTheme.gapXl),
      ],
    );
  }
}


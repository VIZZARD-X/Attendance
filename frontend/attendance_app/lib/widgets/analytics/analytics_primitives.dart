import 'package:flutter/material.dart';

import '../../models/analytics_models.dart';
import '../../theme/analytics_theme.dart';
import 'analytics_animations.dart';

/// Shared, data-honest building blocks for analytics screens.
///
/// Every widget here has an explicit "we don't have this" rendering path, so a
/// missing metric shows as an em dash or a stated reason rather than a zero.
/// Motion is decorative only: each animated widget renders its final state
/// immediately when the platform asks for reduced motion.

// ------------------------------------------------------------------ scaffolding

class AnalyticsCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Color? accentBorder;
  final EdgeInsets padding;
  final IconData? icon;

  const AnalyticsCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.accentBorder,
    this.padding = AnalyticsTheme.cardPadding,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AnalyticsTheme.card(accentBorder: accentBorder),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AnalyticsTheme.accentSoft,
                      borderRadius:
                          BorderRadius.circular(AnalyticsTheme.radiusSm),
                    ),
                    child: Icon(icon, size: 15, color: AnalyticsTheme.accent),
                  ),
                  const SizedBox(width: AnalyticsTheme.gapMd),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: AnalyticsTheme.sectionTitle),
                      if (subtitle != null) ...[
                        const SizedBox(height: AnalyticsTheme.gapXs),
                        Text(subtitle!, style: AnalyticsTheme.caption),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          if (title != null) const SizedBox(height: AnalyticsTheme.gapLg),
          child,
        ],
      ),
    );
  }
}

/// Explains *why* a panel is empty. Never renders a bare "No data".
class AnalyticsEmptyState extends StatelessWidget {
  final String message;
  final String? detail;
  final IconData icon;
  final double minHeight;

  const AnalyticsEmptyState({
    super.key,
    required this.message,
    this.detail,
    this.icon = Icons.insights_outlined,
    this.minHeight = 120,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AnalyticsTheme.gapLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: AnalyticsTheme.noData),
              const SizedBox(height: AnalyticsTheme.gapSm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AnalyticsTheme.body,
              ),
              if (detail != null) ...[
                const SizedBox(height: AnalyticsTheme.gapXs),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: AnalyticsTheme.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AnalyticsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AnalyticsErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AnalyticsTheme.gapXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AnalyticsTheme.absent),
            const SizedBox(height: AnalyticsTheme.gapMd),
            Text(
              'Could not load analytics',
              style: AnalyticsTheme.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AnalyticsTheme.gapSm),
            Text(message, style: AnalyticsTheme.body, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AnalyticsTheme.gapLg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows the scope the numbers were computed under: term, threshold, when.
///
/// Every part comes from `meta`; nothing is inferred. Where the term name is
/// absent the banner says "All terms" only when the caller actually asked for
/// all terms, rather than implying a scope the response did not confirm.
class ScopeBanner extends StatelessWidget {
  final AnalyticsMeta meta;
  final String? extra;

  const ScopeBanner({super.key, required this.meta, this.extra});

  @override
  Widget build(BuildContext context) {
    final threshold = 'Requirement ${meta.requiredPct.toStringAsFixed(0)}%'
        '${meta.thresholdSourceLabel == null ? '' : ' (${meta.thresholdSourceLabel})'}';
    final parts = <String>[
      if (meta.termName != null)
        meta.termName!
      else if (meta.termId == 'all')
        'All terms',
      if (meta.academicYear != null) meta.academicYear!,
      threshold,
      if (meta.classesInScope != null) '${meta.classesInScope} class(es)',
      if (extra != null) extra!,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AnalyticsTheme.gapMd,
        vertical: AnalyticsTheme.gapSm,
      ),
      decoration: BoxDecoration(
        color: AnalyticsTheme.accentSoft,
        borderRadius: BorderRadius.circular(AnalyticsTheme.radiusMd),
        border: Border.all(
          color: AnalyticsTheme.accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined,
              size: 15, color: AnalyticsTheme.accent),
          const SizedBox(width: AnalyticsTheme.gapSm),
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: AnalyticsTheme.caption.copyWith(
                color: AnalyticsTheme.textSecondary,
              ),
            ),
          ),
          if (meta.windowStart != null && meta.windowEnd != null)
            Tooltip(
              message: 'Window ${_day(meta.windowStart!)} → '
                  '${_day(meta.windowEnd!)}'
                  '${meta.generatedAt == null ? '' : '\nComputed ${_stamp(meta.generatedAt!)}'}',
              child: const Icon(Icons.schedule,
                  size: 14, color: AnalyticsTheme.textTertiary),
            ),
        ],
      ),
    );
  }

  static String _day(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;

  static String _stamp(String iso) =>
      iso.length >= 16 ? iso.substring(0, 16).replaceFirst('T', ' ') : iso;
}

/// A short note explaining how a number was derived (denominators, provenance).
class MethodologyNote extends StatelessWidget {
  final String text;

  const MethodologyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 13, color: AnalyticsTheme.textTertiary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AnalyticsTheme.caption)),
        ],
      ),
    );
  }
}

class SeverityChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const SeverityChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory SeverityChip.riskBand(String? band) => SeverityChip(
        label: (band ?? 'unknown').toUpperCase(),
        color: AnalyticsTheme.riskBandColor(band),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: AnalyticsTheme.chip(color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- metric tiles

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sublabel;
  final Color? valueColor;
  final IconData? icon;
  final VoidCallback? onTap;

  /// When set, the numeric part counts up instead of appearing instantly.
  /// [value] is still used verbatim whenever [countTo] is null, so an em dash
  /// or a formatted string is never overwritten by a number.
  final double? countTo;
  final String Function(double)? countFormatter;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.sublabel,
    this.valueColor,
    this.icon,
    this.onTap,
    this.countTo,
    this.countFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle =
        AnalyticsTheme.metricNumber.copyWith(color: valueColor);
    final content = Container(
      decoration: AnalyticsTheme.card(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AnalyticsTheme.label.copyWith(fontSize: 10.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Icon(icon, size: 15, color: AnalyticsTheme.accent),
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapSm),
          if (countTo == null)
            Text(value, style: valueStyle)
          else
            AnimatedCountUp(
              value: countTo,
              formatter: countFormatter ??
                  ((v) => v.toStringAsFixed(0)),
              style: valueStyle,
            ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: AnalyticsTheme.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return HoverLift(onTap: onTap, child: content);
  }
}

/// Large hero figure with threshold context, used at the top of dashboards.
///
/// Kept as a white card (rather than the gradient hero) because it appears
/// inside scrolling content next to other cards; [HeroPctHeader] is the
/// full-width gradient variant.
class HeadlinePctTile extends StatelessWidget {
  final double? pct;
  final double requiredPct;
  final String label;
  final String? sublabel;
  final double? slope;
  final List<double> sparkline;

  const HeadlinePctTile({
    super.key,
    required this.pct,
    required this.requiredPct,
    this.label = 'Attendance',
    this.sublabel,
    this.slope,
    this.sparkline = const [],
  });

  @override
  Widget build(BuildContext context) {
    final color = AnalyticsTheme.pctColor(pct, requiredPct);
    final margin = pct == null ? null : pct! - requiredPct;

    return AnalyticsCard(
      accentBorder: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AnalyticsTheme.label),
          const SizedBox(height: AnalyticsTheme.gapSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCountUp(
                value: pct,
                formatter: (v) => v.toStringAsFixed(1),
                style: AnalyticsTheme.displayNumber.copyWith(color: color),
              ),
              if (pct != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text('%',
                      style: AnalyticsTheme.sectionTitle.copyWith(color: color)),
                ),
              const Spacer(),
              if (slope != null)
                SeverityChip(
                  label: slope! > 0 ? 'Improving' : (slope! < 0 ? 'Declining' : 'Flat'),
                  color: AnalyticsTheme.slopeColor(slope),
                  icon: AnalyticsTheme.slopeIcon(slope),
                ),
            ],
          ),
          const SizedBox(height: AnalyticsTheme.gapSm),
          ThresholdBar(pct: pct, requiredPct: requiredPct),
          const SizedBox(height: AnalyticsTheme.gapSm),
          Text(
            margin == null
                ? 'Not enough recorded sessions to compute a percentage.'
                : margin >= 0
                    ? '${margin.toStringAsFixed(1)} points above the ${requiredPct.toStringAsFixed(0)}% requirement'
                    : '${margin.abs().toStringAsFixed(1)} points below the ${requiredPct.toStringAsFixed(0)}% requirement',
            style: AnalyticsTheme.body,
          ),
          if (sublabel != null) ...[
            const SizedBox(height: AnalyticsTheme.gapXs),
            Text(sublabel!, style: AnalyticsTheme.caption),
          ],
          if (sparkline.length > 1) ...[
            const SizedBox(height: AnalyticsTheme.gapMd),
            SizedBox(
              height: 40,
              child: Sparkline(values: sparkline, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal bar showing achieved pct against the required threshold marker.
///
/// The fill grows on first paint; the requirement marker is drawn on top so the
/// comparison is always readable, including at 0% and 100%.
class ThresholdBar extends StatelessWidget {
  final double? pct;
  final double requiredPct;
  final double height;

  const ThresholdBar({
    super.key,
    required this.pct,
    required this.requiredPct,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = AnalyticsTheme.pctColor(pct, requiredPct);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final target = ((pct ?? 0) / 100).clamp(0.0, 1.0);
        final marker = (requiredPct / 100).clamp(0.0, 1.0) * w;
        return SizedBox(
          height: height + 6,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: AnalyticsTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              if (pct != null)
                AnimatedBarFill(
                  fraction: target,
                  builder: (context, value) => Container(
                    height: height,
                    width: value * w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.75), color],
                      ),
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              Positioned(
                left: marker - 1,
                top: -3,
                child: Container(
                  width: 2,
                  height: height + 6,
                  decoration: BoxDecoration(
                    color: AnalyticsTheme.ink.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-width gradient hero header for the top of an analytics screen.
///
/// Uses the drawer-header gradient verbatim so the analytics screens read as
/// part of the same app. The ring shows an empty track when the percentage is
/// unknown, never a zero-scored dial.
class HeroPctHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double? pct;
  final double requiredPct;
  final double? slope;
  final List<double> sparkline;
  final List<Widget> chips;
  final Widget? trailing;

  const HeroPctHeader({
    super.key,
    required this.title,
    required this.pct,
    required this.requiredPct,
    this.subtitle,
    this.slope,
    this.sparkline = const [],
    this.chips = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final margin = pct == null ? null : pct! - requiredPct;
    final meets = margin != null && margin >= 0;

    return Container(
      width: double.infinity,
      decoration: AnalyticsTheme.hero(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: AnalyticsTheme.label.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: AnalyticsTheme.gapSm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedCountUp(
                          value: pct,
                          formatter: (v) => v.toStringAsFixed(1),
                          style: AnalyticsTheme.heroNumber,
                        ),
                        if (pct != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 3),
                            child: Text(
                              '%',
                              style: AnalyticsTheme.sectionTitle
                                  .copyWith(color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AnalyticsTheme.gapXs),
                    Text(
                      margin == null
                          ? 'Not enough recorded sessions to compute a percentage.'
                          : meets
                              ? '${margin.toStringAsFixed(1)} points above the '
                                  '${requiredPct.toStringAsFixed(0)}% requirement'
                              : '${margin.abs().toStringAsFixed(1)} points below the '
                                  '${requiredPct.toStringAsFixed(0)}% requirement',
                      style: AnalyticsTheme.body.copyWith(color: Colors.white),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AnalyticsTheme.gapXs),
                      Text(
                        subtitle!,
                        style: AnalyticsTheme.caption
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AnalyticsTheme.gapLg),
              trailing ?? _HeroRing(pct: pct, meets: meets),
            ],
          ),
          if (slope != null || chips.isNotEmpty) ...[
            const SizedBox(height: AnalyticsTheme.gapLg),
            Wrap(
              spacing: AnalyticsTheme.gapSm,
              runSpacing: AnalyticsTheme.gapSm,
              children: [
                if (slope != null)
                  HeroChip(
                    label: slope! > 0
                        ? 'Improving'
                        : (slope! < 0 ? 'Declining' : 'Flat'),
                    icon: AnalyticsTheme.slopeIcon(slope),
                  ),
                ...chips,
              ],
            ),
          ],
          if (sparkline.length > 1) ...[
            const SizedBox(height: AnalyticsTheme.gapLg),
            SizedBox(
              height: 38,
              child: Sparkline(
                values: sparkline,
                color: Colors.white,
                strokeWidth: 2.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status ring shown inside [HeroPctHeader].
class _HeroRing extends StatelessWidget {
  final double? pct;
  final bool meets;

  const _HeroRing({required this.pct, required this.meets});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: AnimatedArc(
        progress: pct == null ? null : (pct! / 100).clamp(0.0, 1.0),
        color: Colors.white,
        trackColor: Colors.white24,
        strokeWidth: 9,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pct == null
                  ? Icons.help_outline
                  : meets
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(height: 2),
            Text(
              pct == null
                  ? 'No data'
                  : meets
                      ? 'On track'
                      : 'Below',
              style:
                  AnalyticsTheme.caption.copyWith(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip styled for the gradient hero surface.
class HeroChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const HeroChip({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular gauge for a 0..100 composite score.
///
/// Distinct from [ThresholdBar] on purpose: a gauge suits an index like the
/// health score, where there is no single threshold line to compare against.
/// A null score draws an empty track and an em dash.
class RadialGauge extends StatelessWidget {
  final double? score;
  final String? centerLabel;
  final String? centerSublabel;
  final Color color;
  final double size;
  final double strokeWidth;

  const RadialGauge({
    super.key,
    required this.score,
    this.centerLabel,
    this.centerSublabel,
    this.color = AnalyticsTheme.accent,
    this.size = 132,
    this.strokeWidth = 13,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedArc(
        progress: score == null ? null : (score! / 100).clamp(0.0, 1.0),
        color: color,
        strokeWidth: strokeWidth,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedCountUp(
              value: score,
              formatter: (v) => v.toStringAsFixed(0),
              style: AnalyticsTheme.displayNumber.copyWith(
                color: score == null ? AnalyticsTheme.textTertiary : color,
                fontSize: size * 0.24,
              ),
            ),
            if (centerLabel != null)
              Text(
                centerLabel!,
                style: AnalyticsTheme.label.copyWith(
                  color: score == null ? AnalyticsTheme.textTertiary : color,
                  fontSize: 11,
                ),
              ),
            if (centerSublabel != null)
              Text(
                centerSublabel!,
                style: AnalyticsTheme.caption.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- charts

/// Minimal sparkline. Values may be percentages (0-100) or rates (0-1);
/// it normalises against its own range and draws itself in on first paint.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double strokeWidth;
  final bool animate;

  const Sparkline({
    super.key,
    required this.values,
    this.color = AnalyticsTheme.accent,
    this.strokeWidth = 2,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox.shrink();
    }
    if (!animate) {
      return CustomPaint(
        painter: _SparklinePainter(values, color, strokeWidth, 1),
        size: Size.infinite,
      );
    }
    return DrawOnBuilder(
      builder: (context, t) => CustomPaint(
        painter: _SparklinePainter(values, color, strokeWidth, t),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double strokeWidth;

  /// 0..1 draw-on progress. At 1 the output is identical to a static render.
  final double t;

  _SparklinePainter(this.values, this.color, this.strokeWidth, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    Offset at(int i) => Offset(
          size.width * (i / (values.length - 1)),
          size.height - ((values[i] - minV) / range) * size.height,
        );

    // Reveal by clipping to the swept width, so the curve is never distorted
    // mid-animation — an animated chart must not imply values it does not have.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));

    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final p = at(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        fill.moveTo(p.dx, size.height);
        fill.lineTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
        fill.lineTo(p.dx, p.dy);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.24),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color || old.t != t;
}

/// Session-by-session cohort trend, with the threshold line and change points.
///
/// Tapping a point pins a tooltip carrying that session's own numbers (date,
/// percentage, present/expected, class code and median latency) so a reader can
/// check the chart against the record rather than eyeballing the curve.
class TrendLineChart extends StatefulWidget {
  final List<TrendPoint> points;
  final double requiredPct;
  final double height;

  const TrendLineChart({
    super.key,
    required this.points,
    required this.requiredPct,
    this.height = 220,
  });

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  int? _selected;

  @override
  void didUpdateWidget(TrendLineChart old) {
    super.didUpdateWidget(old);
    // A new series invalidates the pinned index; keeping it would label a point
    // with another session's numbers.
    if (old.points != widget.points) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final usable = widget.points.where((p) => p.pct != null).toList();
    if (usable.length < 2) {
      return AnalyticsEmptyState(
        message: usable.isEmpty
            ? 'No sessions with recorded attendance yet.'
            : 'Only one session recorded — a trend needs at least two.',
        detail: 'The chart appears once more sessions have marks.',
        icon: Icons.show_chart,
        minHeight: widget.height,
      );
    }
    final selected =
        (_selected != null && _selected! < usable.length) ? _selected : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _select(d.localPosition.dx, c.maxWidth, usable),
              onHorizontalDragUpdate: (d) =>
                  _select(d.localPosition.dx, c.maxWidth, usable),
              child: DrawOnBuilder(
                builder: (context, t) => CustomPaint(
                  painter: _TrendPainter(
                    usable,
                    widget.requiredPct,
                    t,
                    selected,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AnalyticsTheme.gapSm),
        _TrendReadout(
          point: selected == null ? null : usable[selected],
          count: usable.length,
        ),
      ],
    );
  }

  void _select(double dx, double width, List<TrendPoint> usable) {
    const leftPad = _TrendPainter.leftPad;
    final plotW = width - leftPad;
    if (plotW <= 0) return;
    final frac = ((dx - leftPad) / plotW).clamp(0.0, 1.0);
    final index = (frac * (usable.length - 1)).round();
    if (index != _selected) setState(() => _selected = index);
  }
}

/// Text readout beneath [TrendLineChart]. Shows the pinned session's own
/// figures, or an instruction when nothing is pinned.
class _TrendReadout extends StatelessWidget {
  final TrendPoint? point;
  final int count;

  const _TrendReadout({required this.point, required this.count});

  @override
  Widget build(BuildContext context) {
    if (point == null) {
      return Text(
        'Tap or drag the chart to read a session. $count sessions plotted.',
        style: AnalyticsTheme.caption,
      );
    }
    final p = point!;
    final parts = <String>[
      if (p.date != null) p.date!,
      if (p.classCode != null) p.classCode!,
      if (p.weekday != null) p.weekday!,
      '${p.present}/${p.expected} present',
      if (p.medianLatencySeconds != null)
        'median arrival ${(p.medianLatencySeconds! / 60).toStringAsFixed(1)} min',
      if (p.isChangePoint) 'sustained shift detected here',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fmtPct(p.pct),
          style: AnalyticsTheme.cardTitle.copyWith(
            color: AnalyticsTheme.accent,
          ),
        ),
        const SizedBox(width: AnalyticsTheme.gapSm),
        Expanded(
          child: Text(parts.join(' · '), style: AnalyticsTheme.caption),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> points;
  final double requiredPct;

  /// 0..1 draw-on progress.
  final double t;

  /// Index of the pinned point, if any.
  final int? selected;

  _TrendPainter(this.points, this.requiredPct, this.t, this.selected);

  static const double leftPad = 34;
  static const double bottomPad = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - leftPad;
    final plotH = size.height - bottomPad;
    if (plotW <= 0 || plotH <= 0) return;

    final gridPaint = Paint()
      ..color = AnalyticsTheme.border
      ..strokeWidth = 1;
    final labelStyle = AnalyticsTheme.caption;

    // Y axis: fixed 0-100 so slopes are never visually exaggerated.
    for (final v in [0, 25, 50, 75, 100]) {
      final y = plotH - (v / 100) * plotH;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      _text(canvas, '$v', Offset(0, y - 6), labelStyle);
    }

    // Requirement line, dashed and labelled.
    final ty = plotH - (requiredPct / 100) * plotH;
    final dash = Paint()
      ..color = AnalyticsTheme.absent.withValues(alpha: 0.75)
      ..strokeWidth = 1.5;
    for (double x = leftPad; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, ty), Offset(x + 4, ty), dash);
    }

    Offset at(int i) {
      final x = points.length == 1
          ? leftPad + plotW / 2
          : leftPad + plotW * (i / (points.length - 1));
      final y = plotH - (points[i].pct!.clamp(0, 100) / 100) * plotH;
      return Offset(x, y);
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }

    final fill = Path.from(path)
      ..lineTo(at(points.length - 1).dx, plotH)
      ..lineTo(at(0).dx, plotH)
      ..close();

    // Reveal left-to-right by clipping, never by rescaling the curve.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, leftPad + plotW * t, size.height));

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AnalyticsTheme.accent.withValues(alpha: 0.26),
            AnalyticsTheme.accent.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(leftPad, 0, plotW, plotH)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [AnalyticsTheme.accent, AnalyticsTheme.accentMid],
        ).createShader(Rect.fromLTWH(leftPad, 0, plotW, plotH))
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final o = at(i);
      final isChange = p.isChangePoint;
      canvas.drawCircle(
        o,
        isChange ? 4.5 : 2.6,
        Paint()
          ..color =
              isChange ? AnalyticsTheme.pendingReview : AnalyticsTheme.accent,
      );
      if (isChange) {
        canvas.drawCircle(
          o,
          4.5,
          Paint()
            ..color = AnalyticsTheme.surface
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
    canvas.restore();

    // Selection marker sits outside the reveal clip so a pinned point stays
    // visible even mid-animation.
    if (selected != null && selected! < points.length) {
      final o = at(selected!);
      canvas.drawLine(
        Offset(o.dx, 0),
        Offset(o.dx, plotH),
        Paint()
          ..color = AnalyticsTheme.accent.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        o,
        6,
        Paint()
          ..color = AnalyticsTheme.surface
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        o,
        6,
        Paint()
          ..color = AnalyticsTheme.accent
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke,
      );
    }

    // X axis: first and last dates only, to avoid unreadable clutter.
    final firstDate = points.first.date;
    final lastDate = points.last.date;
    if (firstDate != null) {
      _text(canvas, _short(firstDate), Offset(leftPad, plotH + 4), labelStyle);
    }
    if (lastDate != null && points.length > 1) {
      _text(
        canvas,
        _short(lastDate),
        Offset(size.width - 52, plotH + 4),
        labelStyle,
      );
    }
    _text(
      canvas,
      '${requiredPct.toStringAsFixed(0)}% required',
      Offset(leftPad + 4, ty - 13),
      labelStyle.copyWith(color: AnalyticsTheme.absent),
    );
  }

  String _short(String iso) => iso.length >= 10 ? iso.substring(5, 10) : iso;

  void _text(Canvas canvas, String s, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points ||
      old.requiredPct != requiredPct ||
      old.t != t ||
      old.selected != selected;
}

/// Horizontal band distribution (students per attendance band).
class BandDistributionChart extends StatelessWidget {
  final List<DistributionBand> bands;
  final int total;

  const BandDistributionChart({
    super.key,
    required this.bands,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) {
      return const AnalyticsEmptyState(
        message: 'No students with recorded marks in this scope.',
        icon: Icons.bar_chart,
      );
    }
    final maxCount = bands.fold<int>(0, (m, b) => b.students > m ? b.students : m);
    return Column(
      children: [
        for (final b in bands) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  child: Text(b.band, style: AnalyticsTheme.caption),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final frac = maxCount == 0 ? 0.0 : b.students / maxCount;
                      return Stack(
                        children: [
                          Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: AnalyticsTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          AnimatedBarFill(
                            fraction: frac,
                            builder: (context, value) => Container(
                              height: 18,
                              width: c.maxWidth * value,
                              decoration: BoxDecoration(
                                color: _bandColor(b.band),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: AnalyticsTheme.gapSm),
                SizedBox(
                  width: 62,
                  child: Text(
                    b.sharePct == null
                        ? '${b.students}'
                        : '${b.students} · ${b.sharePct!.toStringAsFixed(0)}%',
                    style: AnalyticsTheme.caption,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (total > 0)
          Padding(
            padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
            child: Text('$total students in scope',
                style: AnalyticsTheme.caption),
          ),
      ],
    );
  }

  /// Bands arrive as human labels like "0-25%" — derive colour from the lower
  /// bound so the mapping stays consistent with the rest of the UI.
  Color _bandColor(String band) {
    final m = RegExp(r'(\d+)').firstMatch(band);
    final low = m == null ? null : int.tryParse(m.group(1)!);
    if (low == null) return AnalyticsTheme.noData;
    if (low >= 90) return AnalyticsTheme.riskSafe;
    if (low >= 75) return AnalyticsTheme.riskLow;
    if (low >= 50) return AnalyticsTheme.riskModerate;
    if (low >= 25) return AnalyticsTheme.riskHigh;
    return AnalyticsTheme.riskCritical;
  }
}

/// Single stacked bar breaking a cohort into risk bands.
class RiskBandBar extends StatelessWidget {
  final List<RiskBandCount> bands;

  const RiskBandBar({super.key, required this.bands});

  @override
  Widget build(BuildContext context) {
    final total = bands.fold<int>(0, (s, b) => s + b.count);
    if (total == 0) {
      return const AnalyticsEmptyState(
        message: 'No risk scores yet — risk needs at least one recorded session.',
        icon: Icons.warning_amber_outlined,
        minHeight: 80,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBarFill(
          fraction: 1,
          builder: (context, t) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  for (final b in bands)
                    if (b.count > 0)
                      Expanded(
                        flex: b.count,
                        child: Container(
                          color: AnalyticsTheme.riskBandColor(b.band),
                        ),
                      ),
                  // Reveal from the left by holding back the remaining width.
                  if (t < 1)
                    Expanded(
                      flex: ((1 - t) * total * 4).round().clamp(0, 1 << 20),
                      child: const ColoredBox(
                        color: AnalyticsTheme.surfaceMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AnalyticsTheme.gapMd),
        Wrap(
          spacing: AnalyticsTheme.gapMd,
          runSpacing: AnalyticsTheme.gapSm,
          children: [
            for (final b in bands)
              if (b.count > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AnalyticsTheme.riskBandColor(b.band),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('${b.label} · ${b.count}',
                        style: AnalyticsTheme.caption),
                  ],
                ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: AnalyticsTheme.gapSm),
          child: Text(
            '$total students scored',
            style: AnalyticsTheme.caption,
          ),
        ),
      ],
    );
  }
}

/// Weekday / time-slot pattern bars.
///
/// Three data-honesty rules, all driven by fields the backend already sends:
///  * a bucket with `sufficient_data: false` is hatched and labelled "n too
///    small", never coloured as a low score;
///  * a difference that failed the two-proportion test carries no marker, so a
///    visually low bar is not mistaken for a finding;
///  * the sentence under the bars is the backend's own `finding`, verbatim.
class PatternBars extends StatelessWidget {
  final PatternBlock block;
  final double requiredPct;
  final String emptyMessage;

  const PatternBars({
    super.key,
    required this.block,
    required this.requiredPct,
    this.emptyMessage = 'Not enough sessions to break this down.',
  });

  @override
  Widget build(BuildContext context) {
    if (block.isEmpty) {
      return AnalyticsEmptyState(
        message: emptyMessage,
        detail: block.finding,
        icon: Icons.schedule,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < block.rows.length; i++)
          FadeSlideIn(
            index: i,
            offsetY: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _PatternRowBar(
                row: block.rows[i],
                requiredPct: requiredPct,
              ),
            ),
          ),
        if (block.finding != null) MethodologyNote(block.finding!),
        if (block.minSessionsPerCell != null)
          MethodologyNote(
            'Buckets with fewer than ${block.minSessionsPerCell} sessions are '
            'marked as insufficient data rather than scored.',
          ),
      ],
    );
  }
}

class _PatternRowBar extends StatelessWidget {
  final PatternRow row;
  final double requiredPct;

  const _PatternRowBar({required this.row, required this.requiredPct});

  @override
  Widget build(BuildContext context) {
    final usable = row.sufficientData && row.attendancePct != null;
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: AnalyticsTheme.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (row.significant)
                Tooltip(
                  message: 'Statistically significant difference'
                      '${row.pValue == null ? '' : ' (p=${row.pValue})'}',
                  child: const Icon(
                    Icons.star,
                    size: 11,
                    color: AnalyticsTheme.accent,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AnalyticsTheme.gapSm),
        Expanded(
          child: usable
              ? ThresholdBar(
                  pct: row.attendancePct,
                  requiredPct: requiredPct,
                  height: 9,
                )
              : const _InsufficientBar(),
        ),
        const SizedBox(width: AnalyticsTheme.gapSm),
        SizedBox(
          width: 92,
          child: Text(
            _detail(),
            style: AnalyticsTheme.caption,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _detail() {
    if (!row.sufficientData) return 'n=${row.sessions} · too few';
    if (row.attendancePct == null) return 'n=${row.sessions}';
    final delta = row.deltaVsRestPct;
    final base = '${fmtPct(row.attendancePct, decimals: 0)} · n=${row.sessions}';
    if (delta == null || !row.significant) return base;
    return '$base · ${fmtSigned(delta, decimals: 1)}pt';
  }
}

/// Hatched track shown where the sample is below the backend's floor.
class _InsufficientBar extends StatelessWidget {
  const _InsufficientBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 15,
      child: CustomPaint(
        painter: _HatchPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 3, size.width, size.height - 6),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = AnalyticsTheme.surfaceMuted,
    );
    canvas.save();
    canvas.clipRRect(rect);
    final line = Paint()
      ..color = AnalyticsTheme.noData.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        line,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter old) => false;
}

/// Insight list.
///
/// Headline, body and action all come from the backend verbatim; the UI adds no
/// claims of its own. The left rail colour encodes the backend's `priority`, and
/// the category is shown so a reader can tell a risk finding from an equity one.
class InsightList extends StatelessWidget {
  final List<Insight> insights;
  final int? maxItems;

  const InsightList({super.key, required this.insights, this.maxItems});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const AnalyticsEmptyState(
        message: 'No findings strong enough to report yet.',
        detail: 'Insights only appear when the data supports them.',
        icon: Icons.lightbulb_outline,
        minHeight: 80,
      );
    }
    final shown = maxItems == null || insights.length <= maxItems!
        ? insights
        : insights.sublist(0, maxItems!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var idx = 0; idx < shown.length; idx++)
          FadeSlideIn(
            index: idx,
            offsetY: 8,
            child: _InsightRow(insight: shown[idx]),
          ),
        if (maxItems != null && insights.length > maxItems!)
          Text(
            '${insights.length - maxItems!} more finding(s) not shown.',
            style: AnalyticsTheme.caption,
          ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final Insight insight;

  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = AnalyticsTheme.priorityColor(insight.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: AnalyticsTheme.gapMd),
      padding: const EdgeInsets.only(left: AnalyticsTheme.gapMd),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  insight.title ?? insight.categoryLabel,
                  style: AnalyticsTheme.cardTitle,
                ),
              ),
              if (insight.category != null)
                Padding(
                  padding: const EdgeInsets.only(left: AnalyticsTheme.gapSm),
                  child: SeverityChip(
                    label: insight.categoryLabel.toUpperCase(),
                    color: color,
                  ),
                ),
            ],
          ),
          if (insight.body.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(insight.body, style: AnalyticsTheme.body),
          ],
          if (insight.action != null) ...[
            const SizedBox(height: AnalyticsTheme.gapSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_forward, size: 13, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight.action!,
                    style: AnalyticsTheme.body.copyWith(
                      color: AnalyticsTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Mark composition bar: present / absent / pending / unrecorded.
class MarkCompositionBar extends StatelessWidget {
  final MarkTotals totals;

  const MarkCompositionBar({super.key, required this.totals});

  @override
  Widget build(BuildContext context) {
    if (totals.expected == 0) {
      return const AnalyticsEmptyState(
        message: 'No expected marks in this scope yet.',
        icon: Icons.pie_chart_outline,
        minHeight: 80,
      );
    }
    final segments = <(String, int, Color)>[
      ('Present', totals.present, AnalyticsTheme.present),
      ('Absent', totals.absent, AnalyticsTheme.absent),
      ('Pending review', totals.pendingReview, AnalyticsTheme.pendingReview),
      ('Unrecorded', totals.unrecorded, AnalyticsTheme.noData),
    ].where((s) => s.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBarFill(
          fraction: 1,
          builder: (context, t) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  for (final s in segments)
                    Expanded(flex: s.$2, child: ColoredBox(color: s.$3)),
                  if (t < 1)
                    Expanded(
                      flex: ((1 - t) * totals.expected * 4)
                          .round()
                          .clamp(0, 1 << 20),
                      child: const ColoredBox(
                        color: AnalyticsTheme.surfaceMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AnalyticsTheme.gapMd),
        Wrap(
          spacing: AnalyticsTheme.gapMd,
          runSpacing: AnalyticsTheme.gapSm,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: s.$3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('${s.$1} · ${s.$2}', style: AnalyticsTheme.caption),
                ],
              ),
          ],
        ),
        MethodologyNote(
          '${totals.expected} expected marks = one per enrolled student per '
          'session held.',
        ),
      ],
    );
  }
}

/// Responsive metric grid. Tiles enter with a stagger so the eye lands on the
/// first figure rather than the whole block at once.
class MetricGrid extends StatelessWidget {
  final List<Widget> tiles;
  final double tileHeight;
  final bool stagger;

  const MetricGrid({
    super.key,
    required this.tiles,
    this.tileHeight = 108,
    this.stagger = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = AnalyticsTheme.gridColumns(c.maxWidth);
        const spacing = AnalyticsTheme.gapMd;
        final tileWidth = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < tiles.length; i++)
              SizedBox(
                width: tileWidth,
                height: tileHeight,
                child: stagger
                    ? FadeSlideIn(index: i, offsetY: 10, child: tiles[i])
                    : tiles[i],
              ),
          ],
        );
      },
    );
  }
}

/// A labelled progress row used for weighted components (health, risk).
///
/// The weight is displayed alongside the value because a component's
/// contribution is the product of the two — showing only the value would
/// overstate a lightly weighted signal.
class WeightedComponentRow extends StatelessWidget {
  final String label;
  final double? value;
  final double? weight;
  final String? meaning;
  final Color color;

  const WeightedComponentRow({
    super.key,
    required this.label,
    required this.value,
    this.weight,
    this.meaning,
    this.color = AnalyticsTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.replaceAll('_', ' '),
                  style: AnalyticsTheme.label,
                ),
              ),
              if (weight != null)
                Text(
                  'weight ${(weight! * 100).toStringAsFixed(0)}%',
                  style: AnalyticsTheme.caption,
                ),
              const SizedBox(width: AnalyticsTheme.gapSm),
              SizedBox(
                width: 38,
                child: AnimatedCountUp(
                  value: value,
                  formatter: (v) => v.toStringAsFixed(0),
                  style: AnalyticsTheme.cardTitle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: AnalyticsTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                if (value != null)
                  AnimatedBarFill(
                    fraction: (value! / 100).clamp(0.0, 1.0),
                    builder: (context, t) => Container(
                      height: 7,
                      width: c.maxWidth * t,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.7), color],
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (meaning != null) ...[
            const SizedBox(height: 3),
            Text(meaning!, style: AnalyticsTheme.caption),
          ],
        ],
      ),
    );
  }
}

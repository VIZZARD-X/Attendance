import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../theme/analytics_theme.dart';

/// Motion primitives shared by every analytics surface.
///
/// Three rules apply throughout, enforced here rather than left to call sites:
///
/// 1. **Nothing is only visible while animating.** Every widget renders its
///    final state when `MediaQuery.disableAnimations` is set, so a
///    reduced-motion user sees exactly the same numbers.
/// 2. **Nothing animates in the background.** Repeating controllers stop when
///    the app is paused or inactive, following the pattern already used by
///    `MagicalDashboardCard`.
/// 3. **No new dependencies.** Everything is `AnimationController`,
///    `TweenAnimationBuilder` and `CustomPainter`.

// ---------------------------------------------------------------- entrances

/// Fades and lifts its child into place once, optionally staggered by [index].
///
/// The child is always laid out — only opacity and offset animate — so the
/// widget tree is complete from the first frame for tests and screen readers.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration stagger;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = AnalyticsTheme.motionBase,
    this.stagger = AnalyticsTheme.motionStagger,
    this.offsetY = 14,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: AnalyticsTheme.curveEnter,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!AnalyticsTheme.motionEnabled(context)) {
      _controller.value = 1;
      return;
    }
    // Cap the cumulative delay: a long list must not leave its last card
    // invisible for seconds.
    final delayMs =
        (widget.stagger.inMilliseconds * widget.index).clamp(0, 480);
    if (delayMs == 0) {
      _controller.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Applies [FadeSlideIn] to a list of children, preserving their order.
List<Widget> staggered(List<Widget> children, {int startIndex = 0}) => [
      for (var i = 0; i < children.length; i++)
        FadeSlideIn(index: startIndex + i, child: children[i]),
    ];

// ------------------------------------------------------------------ numbers

/// Counts a numeric value up from zero, or from its previous value on change.
///
/// The formatter receives the interpolated value, so callers keep control of
/// units and precision. A null [value] renders [placeholder] and never
/// animates — "unknown" must not look like a number rolling toward zero.
class AnimatedCountUp extends StatefulWidget {
  final double? value;
  final String Function(double value) formatter;
  final TextStyle? style;
  final String placeholder;
  final Duration duration;
  final TextAlign? textAlign;

  const AnimatedCountUp({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.placeholder = '—',
    this.duration = AnalyticsTheme.motionSlow,
    this.textAlign,
  });

  @override
  State<AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<AnimatedCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _from = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = _tween(widget.value ?? 0);
  }

  Animation<double> _tween(double to) =>
      Tween<double>(begin: _from, end: to).animate(
        CurvedAnimation(parent: _controller, curve: AnalyticsTheme.curveEnter),
      );

  void _run() {
    if (widget.value == null || !AnalyticsTheme.motionEnabled(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  @override
  void didUpdateWidget(AnimatedCountUp old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    _from = old.value == null ? 0 : _animation.value;
    _animation = _tween(widget.value ?? 0);
    _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value == null) {
      return Text(
        widget.placeholder,
        style: widget.style,
        textAlign: widget.textAlign,
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Text(
        widget.formatter(_animation.value),
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }
}

// ---------------------------------------------------------------- skeletons

/// Placeholder block shown while a panel's data is in flight.
///
/// A shimmering block of roughly the right shape says "loading here" better
/// than a centred spinner, and stops the layout jumping when data lands.
class ShimmerSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  /// A stack of lines approximating a text paragraph.
  static Widget lines({int count = 3, double spacing = 8}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            ShimmerSkeleton(
              height: 12,
              width: i.isEven ? null : 180,
            ),
          ],
        ],
      );

  /// A card-shaped placeholder standing in for a whole panel.
  static Widget panel({double height = 140}) => Container(
        decoration: AnalyticsTheme.card(),
        padding: AnalyticsTheme.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerSkeleton(width: 140, height: 14),
            const SizedBox(height: AnalyticsTheme.gapLg),
            ShimmerSkeleton(height: height),
          ],
        ),
      );

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AnalyticsTheme.motionEnabled(context) && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed &&
        mounted &&
        AnalyticsTheme.motionEnabled(context) &&
        !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AnalyticsTheme.radiusSm);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - _controller.value), 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: const [
                AnalyticsTheme.surfaceMuted,
                Color(0xFFF7FBFC),
                AnalyticsTheme.surfaceMuted,
              ],
              stops: const [0.15, 0.5, 0.85],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- interaction

/// Lifts and shadows its child on pointer hover.
///
/// Desktop/web only: on touch platforms hover never fires and a scale change
/// would only fight with scrolling. Mirrors the dashboard cards' interaction so
/// the two surfaces feel like one app.
class HoverLift extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  const HoverLift({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.015,
    this.borderRadius,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AnalyticsTheme.radiusLg);
    final pointerDevice = kIsWeb || MediaQuery.of(context).size.width >= 900;
    final animate = pointerDevice && AnalyticsTheme.motionEnabled(context);

    Widget content = widget.child;

    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        child: content,
      );
    }

    if (animate) {
      content = AnimatedScale(
        scale: _hover ? widget.scale : 1.0,
        duration: AnalyticsTheme.motionFast,
        curve: AnalyticsTheme.curveEnter,
        child: AnimatedPhysicalModel(
          duration: AnalyticsTheme.motionFast,
          elevation: _hover ? 8 : 0,
          color: Colors.transparent,
          shadowColor: AnalyticsTheme.ink.withValues(alpha: 0.25),
          borderRadius: radius,
          shape: BoxShape.rectangle,
          child: content,
        ),
      );
    }

    if (!pointerDevice) return content;
    return MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: content,
    );
  }
}

// ------------------------------------------------------------------- shapes

/// Animated arc, used by gauges and rings.
///
/// [progress] is 0..1 and drives the sweep. A null value draws only the track,
/// so an unknown metric reads as an empty ring rather than a zero score.
class AnimatedArc extends StatelessWidget {
  final double? progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double startAngle;
  final double sweepAngle;
  final Widget? center;
  final Duration duration;

  /// 135° start with a 270° sweep: a dial with its gap at the bottom.
  static const double dialStart = 2.356194490192345;
  static const double dialSweep = 4.712388980384690;

  const AnimatedArc({
    super.key,
    required this.progress,
    required this.color,
    this.trackColor = AnalyticsTheme.surfaceMuted,
    this.strokeWidth = 12,
    this.startAngle = dialStart,
    this.sweepAngle = dialSweep,
    this.center,
    this.duration = AnalyticsTheme.motionSlow,
  });

  @override
  Widget build(BuildContext context) {
    final target = (progress ?? 0).clamp(0.0, 1.0);
    final animate = AnalyticsTheme.motionEnabled(context) && progress != null;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: animate ? duration : Duration.zero,
      curve: AnalyticsTheme.curveEnter,
      builder: (context, value, child) => CustomPaint(
        painter: _ArcPainter(
          progress: progress == null ? null : value,
          color: color,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
          startAngle: startAngle,
          sweepAngle: sweepAngle,
        ),
        child: child,
      ),
      child: center == null ? null : Center(child: center),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double? progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double startAngle;
  final double sweepAngle;

  _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2 + 1;
    final side = size.shortestSide - inset * 2;
    if (side <= 0) return;
    final rect = Rect.fromLTWH(
      (size.width - side) / 2,
      (size.height - side) / 2,
      side,
      side,
    );

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress == null || progress! <= 0) return;
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle * progress!,
      false,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.7), color],
        ).createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.startAngle != startAngle ||
      old.sweepAngle != sweepAngle;
}

/// Runs a one-shot 0..1 progress value for painters that "draw on".
///
/// Charts use this so the line grows left-to-right on first render; the final
/// frame is identical to the static chart, so nothing depends on the animation.
class DrawOnBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;

  const DrawOnBuilder({
    super.key,
    required this.builder,
    this.duration = AnalyticsTheme.motionSlow,
  });

  @override
  State<DrawOnBuilder> createState() => _DrawOnBuilderState();
}

class _DrawOnBuilderState extends State<DrawOnBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: AnalyticsTheme.curveEnter,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AnalyticsTheme.motionEnabled(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        builder: (context, _) =>
            widget.builder(context, _curve.value.clamp(0.0, 1.0)),
      );
}

/// Grows a horizontal bar to [fraction] of its width on first render.
class AnimatedBarFill extends StatelessWidget {
  final double? fraction;
  final Duration duration;
  final Widget Function(BuildContext context, double fraction) builder;

  const AnimatedBarFill({
    super.key,
    required this.fraction,
    required this.builder,
    this.duration = AnalyticsTheme.motionSlow,
  });

  @override
  Widget build(BuildContext context) {
    final target = (fraction ?? 0).clamp(0.0, 1.0);
    final animate = AnalyticsTheme.motionEnabled(context) && fraction != null;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: animate ? duration : Duration.zero,
      curve: AnalyticsTheme.curveEnter,
      builder: (context, value, _) => builder(context, value),
    );
  }
}


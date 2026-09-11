import 'package:flutter/material.dart';

class MagicalDashboardCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const MagicalDashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<MagicalDashboardCard> createState() => _MagicalDashboardCardState();
}

class _MagicalDashboardCardState extends State<MagicalDashboardCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _hover = false;
  bool _pressed = false;
  bool _isVisible = true;

  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        )..addStatusListener((status) {
          if (!mounted || !_isVisible) return;

          if (status == AnimationStatus.completed) {
            _pulseController.reverse();
          } else if (status == AnimationStatus.dismissed) {
            _pulseController.forward();
          }
        });
    _pulseController.forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Stop animations before disposing
    _pulseController.stop();
    _shimmerController.stop();

    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseAnimations();
    } else if (state == AppLifecycleState.resumed) {
      _resumeAnimations();
    }
  }

  void _pauseAnimations() {
    _isVisible = false;
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    if (_shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  void _resumeAnimations() {
    _isVisible = true;
    if (!_pulseController.isAnimating) {
      _pulseController.forward();
    }
  }

  void _startShimmer() {
    if (!mounted) return;

    if (_shimmerController.status == AnimationStatus.dismissed) {
      _shimmerController.repeat();
    }
  }

  void _stopShimmer() {
    if (!mounted) return;

    _shimmerController.stop();
    _shimmerController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    final double targetScale = (_hover || _pressed)
        ? (isMobile ? 1.01 : 1.03)
        : 1.0;
    final double lift = (_hover || _pressed) ? -6 : 0;
    final double radius = isMobile ? 14 : 18;

    Widget cardWidget = GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() => _pressed = true);
        if (isMobile) _startShimmer();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (isMobile) _stopShimmer();
        widget.onTap?.call();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        if (isMobile) _stopShimmer();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, lift)
          ..scale(targetScale),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: [
              widget.color.withOpacity((_hover || _pressed) ? 0.96 : 0.88),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (_hover || _pressed)
                  ? widget.color.withOpacity(0.4)
                  : Colors.black.withOpacity(0.08),
              blurRadius: (_hover || _pressed) ? 24 : 10,
              offset: Offset(0, (_hover || _pressed) ? 12 : 4),
            ),
          ],
          border: Border.all(
            color: (_hover || _pressed)
                ? widget.color.withOpacity(0.9)
                : widget.color.withOpacity(0.3),
            width: (_hover || _pressed) ? 1.5 : 1.0,
          ),
        ),
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Stack(
          children: [
            // Shimmer overlay
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                final double t = _shimmerController.value;
                final double dx = (t * 2 - 1) * 400;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Transform.translate(
                    offset: Offset(dx * 0.02, 0),
                    child: Opacity(
                      opacity: (_hover || _pressed) ? 0.2 : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.9),
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.0),
                            ],
                            begin: const Alignment(-1.5, -0.5),
                            end: const Alignment(1.5, 0.5),
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Main content
            Row(
              children: [
                ScaleTransition(
                  scale: _pulseController,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.18),
                      boxShadow: (_hover || _pressed)
                          ? [
                              BoxShadow(
                                color: widget.color.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    padding: EdgeInsets.all(isMobile ? 10 : 14),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: isMobile ? 22 : 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile ? 15 : 17,
                          color: const Color(0xFF0F1724),
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13.5,
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (_hover || _pressed) ? 1.0 : 0.0,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: widget.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Only use MouseRegion on desktop
    if (!isMobile) {
      cardWidget = MouseRegion(
        onEnter: (_) {
          setState(() => _hover = true);
          _startShimmer();
        },
        onExit: (_) {
          setState(() => _hover = false);
          _stopShimmer();
        },
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

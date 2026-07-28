import 'package:flutter/material.dart';

class EnhancedDashboardCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  const EnhancedDashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    this.onTap,
  });

  @override
  State<EnhancedDashboardCard> createState() => _EnhancedDashboardCardState();
}

class _EnhancedDashboardCardState extends State<EnhancedDashboardCard>
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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.985,
      upperBound: 1.02,
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
    if (_pulseController.isAnimating) _pulseController.stop();
    if (_shimmerController.isAnimating) _shimmerController.stop();
  }

  void _resumeAnimations() {
    _isVisible = true;
    if (!_pulseController.isAnimating) _pulseController.forward();
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
        ? (isMobile ? 1.015 : 1.04)
        : 1.0;
    final double lift = (_hover || _pressed) ? -8 : 0;
    final double radius = isMobile ? 12 : 24; // Increased radius to match design

    final primaryColor = widget.gradientColors.first;

    Widget cardWidget = GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() => _pressed = true);
        if (isMobile) _startShimmer();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (isMobile) _stopShimmer();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        if (isMobile) _stopShimmer();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(0.0, lift)
          ..scale(targetScale),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: widget.gradientColors.map((c) => 
              c.withOpacity((_hover || _pressed) ? 1.0 : 0.9)
            ).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (_hover || _pressed)
                  ? primaryColor.withOpacity(0.4)
                  : primaryColor.withOpacity(0.15),
              blurRadius: (_hover || _pressed) ? 20 : 12,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                      color: Colors.black.withOpacity(0.15),
                    ),
                    padding: EdgeInsets.all(isMobile ? 10 : 16),
                    child: Icon(
                      widget.icon,
                      color: Colors.black87,
                      size: isMobile ? 24 : 32,
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
                          fontWeight: FontWeight.w800,
                          fontSize: isMobile ? 16 : 18,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
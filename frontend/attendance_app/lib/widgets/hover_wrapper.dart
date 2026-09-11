import 'package:flutter/material.dart';

class HoverWrapper extends StatefulWidget {
  final Widget child;
  final double scaleOffset;
  final bool addShadow;

  const HoverWrapper({
    super.key,
    required this.child,
    this.scaleOffset = 0.02,
    this.addShadow = true,
  });

  @override
  State<HoverWrapper> createState() => _HoverWrapperState();
}

class _HoverWrapperState extends State<HoverWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..scale(_isHovered ? 1.0 + widget.scaleOffset : 1.0),
        decoration: _isHovered && widget.addShadow
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              )
            : const BoxDecoration(),
        child: widget.child,
      ),
    );
  }
}

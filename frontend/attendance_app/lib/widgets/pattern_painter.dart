import 'package:flutter/material.dart';
import 'dart:math' as math;

class PatternPainter extends CustomPainter {
  final Map<String, dynamic> shapeData;

  PatternPainter({required this.shapeData});

  void _drawShape(Canvas canvas, String shape, Offset center, double radius, Paint paint) {
    if (shape == 'circle') {
      canvas.drawCircle(center, radius, paint);
    } else if (shape == 'square') {
      final rect = Rect.fromCenter(center: center, width: radius * 1.7, height: radius * 1.7);
      canvas.drawRect(rect, paint);
    } else if (shape == 'diamond') {
      final path = Path();
      path.moveTo(center.dx, center.dy - radius);
      path.lineTo(center.dx + radius, center.dy);
      path.lineTo(center.dx, center.dy + radius);
      path.lineTo(center.dx - radius, center.dy);
      path.close();
      canvas.drawPath(path, paint);
    } else {
      // Polygon drawing logic
      int sides = 3;
      if (shape == 'triangle') sides = 3;
      else if (shape == 'pentagon') sides = 5;
      else if (shape == 'hexagon') sides = 6;
      else return; // fallback

      final path = Path();
      // Start at top (-pi/2)
      double startAngle = -math.pi / 2;
      for (int i = 0; i < sides; i++) {
        double angle = startAngle + (i * 2 * math.pi / sides);
        // Special case for triangle to shift it down slightly so the centroid looks centered
        double yOffset = (sides == 3) ? radius * 0.2 : 0;
        
        double x = center.dx + radius * math.cos(angle);
        double y = center.dy + radius * math.sin(angle) + yOffset;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2.2;
    final innerRadius = outerRadius * 0.55;

    String outer = shapeData['outer'] ?? 'circle';
    String inner = shapeData['inner'] ?? 'none';
    String number = shapeData['number'] ?? '00';

    // 1. Draw Outer Shape
    _drawShape(canvas, outer, center, outerRadius, paint);

    // 2. Draw Inner Shape (Optional)
    if (inner != 'none') {
      _drawShape(canvas, inner, center, innerRadius, paint);
    }

    // 3. Draw Number perfectly centered
    final textSpan = TextSpan(
      text: number,
      style: TextStyle(
        color: Colors.black,
        fontSize: inner != 'none' ? 42 : 56, // smaller if there is an inner shape
        fontWeight: FontWeight.w900,
        fontFamily: 'Roboto',
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    
    // Draw text vertically and horizontally centered
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

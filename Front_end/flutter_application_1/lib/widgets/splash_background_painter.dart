import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Motif de fond du splash : cercles concentriques discrets.
class SplashBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);

    for (var i = 1; i <= 6; i++) {
      final radius = 60.0 + i * 55;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = i.isEven
            ? AppColors.proxiGreen.withValues(alpha: 0.07)
            : AppColors.searchOrange.withValues(alpha: 0.06);

      canvas.drawCircle(center, radius, paint);

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = AppColors.proxiGreen.withValues(alpha: 0.05);

      final rect = Rect.fromCircle(center: center, radius: radius + 18);
      canvas.drawArc(rect, -math.pi / 3, math.pi / 1.5, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

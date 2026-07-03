import 'package:flutter/material.dart';

class WaveClipper extends CustomClipper<Path> {
  const WaveClipper({this.waveHeight = 80, this.inverted = false});

  final double waveHeight;
  final bool inverted;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (inverted) {
      path.lineTo(0, size.height - waveHeight);
      path.quadraticBezierTo(
        size.width * 0.25,
        size.height,
        size.width * 0.55,
        size.height - waveHeight * 0.4,
      );
      path.quadraticBezierTo(
        size.width * 0.85,
        size.height - waveHeight * 1.2,
        size.width,
        size.height - waveHeight * 0.6,
      );
      path.lineTo(size.width, 0);
    } else {
      path.lineTo(0, size.height - waveHeight);
      path.quadraticBezierTo(
        size.width * 0.3,
        size.height + waveHeight * 0.3,
        size.width * 0.65,
        size.height - waveHeight * 0.5,
      );
      path.quadraticBezierTo(
        size.width * 0.9,
        size.height - waveHeight * 1.1,
        size.width,
        size.height - waveHeight * 0.2,
      );
      path.lineTo(size.width, 0);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class TopographicPatternPainter extends CustomPainter {
  TopographicPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 8; i++) {
      final path = Path();
      final yOffset = size.height * 0.15 + i * 28.0;
      path.moveTo(0, yOffset);
      for (var x = 0.0; x <= size.width; x += 20) {
        path.quadraticBezierTo(
          x + 10,
          yOffset + (i.isEven ? 12 : -12),
          x + 20,
          yOffset,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

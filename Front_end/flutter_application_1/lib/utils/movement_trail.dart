import 'dart:math' as math;
import 'dart:ui';

import '../services/position_service.dart';

/// Filtrage + fenêtre glissante pour un tracé type GPS (courbe lisse, derniers mètres).
class MovementTrail {
  MovementTrail({
    this.minStepM = 0.30,
    this.maxLengthM = 10.0,
  });

  final double minStepM;
  final double maxLengthM;

  final List<MapPoint> _points = [];

  List<MapPoint> get points => List.unmodifiable(_points);

  void reset() => _points.clear();

  void add(MapPoint point) {
    if (_points.isEmpty) {
      _points.add(point);
      return;
    }
    final last = _points.last;
    if (_distance(last, point) < minStepM) return;

    _points.add(point);
    _trimToMaxLength();
  }

  void _trimToMaxLength() {
    while (_points.length > 2 && _totalLength() > maxLengthM) {
      _points.removeAt(0);
    }
  }

  double _totalLength() {
    var total = 0.0;
    for (var i = 1; i < _points.length; i++) {
      total += _distance(_points[i - 1], _points[i]);
    }
    return total;
  }

  static double _distance(MapPoint a, MapPoint b) {
    return math.sqrt(
      math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2),
    );
  }

  /// Courbe lisse (splines cubiques) à partir des points du tracé.
  static Path buildSmoothPath(
    List<MapPoint> points,
    Offset Function(MapPoint) toScreen,
  ) {
    final path = Path();
    if (points.isEmpty) return path;

    final screenPts = points.map(toScreen).toList();
    if (screenPts.length == 1) {
      path.addOval(Rect.fromCircle(center: screenPts.first, radius: 1));
      return path;
    }
    if (screenPts.length == 2) {
      path.moveTo(screenPts[0].dx, screenPts[0].dy);
      path.lineTo(screenPts[1].dx, screenPts[1].dy);
      return path;
    }

    path.moveTo(screenPts[0].dx, screenPts[0].dy);
    for (var i = 0; i < screenPts.length - 1; i++) {
      final p0 = i > 0 ? screenPts[i - 1] : screenPts[i];
      final p1 = screenPts[i];
      final p2 = screenPts[i + 1];
      final p3 = i + 2 < screenPts.length ? screenPts[i + 2] : p2;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }
}

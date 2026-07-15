import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/phone_mac_storage.dart';
import '../services/position_service.dart';
import '../theme/app_colors.dart';
import '../utils/movement_trail.dart';

class NavigationMapScreen extends StatefulWidget {
  const NavigationMapScreen({
    super.key,
    required this.standId,
    required this.standNom,
    this.phoneMac,
  });

  final String standId;
  final String standNom;
  final String? phoneMac;

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

enum _PhoneSetupPhase { resolving, waiting, selecting, navigating }

class _NavigationMapScreenState extends State<NavigationMapScreen> {
  final _service = PositionService();
  NavigationData? _data;
  String? _error;
  String? _mac;
  Timer? _timer;
  Timer? _detectTimer;
  _PhoneSetupPhase _phase = _PhoneSetupPhase.resolving;
  List<PhonePosition> _detectedPhones = [];
  String? _selectedMac;
  bool _detecting = false;
  final _movementTrail = MovementTrail();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _phase = _PhoneSetupPhase.resolving;
      _error = null;
    });

    _mac = widget.phoneMac ?? await PhoneMacStorage.getMac();
    if (_mac != null && _mac!.isNotEmpty) {
      await _startNavigation();
      return;
    }

    await _scanForPhones(autoStartIfSingle: true);
  }

  Future<void> _scanForPhones({required bool autoStartIfSingle}) async {
    setState(() {
      _detecting = true;
      _error = null;
    });

    try {
      final phones = await _service.getAllPositions();
      final mobile = phones.where((p) => !p.locked).toList();

      if (!mounted) return;

      if (mobile.isEmpty) {
        setState(() {
          _phase = _PhoneSetupPhase.waiting;
          _detectedPhones = mobile;
          _detecting = false;
        });
        _detectTimer ??= Timer.periodic(
          const Duration(seconds: 2),
          (_) => _scanForPhones(autoStartIfSingle: true),
        );
        return;
      }

      _detectTimer?.cancel();
      _detectTimer = null;

      if (autoStartIfSingle && mobile.length == 1) {
        await _usePhone(mobile.first.mac);
        return;
      }

      setState(() {
        _phase = _PhoneSetupPhase.selecting;
        _detectedPhones = mobile;
        _selectedMac ??= mobile.first.mac;
        _detecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PhoneSetupPhase.waiting;
        _error = e.toString();
        _detecting = false;
      });
    }
  }

  Future<void> _usePhone(String mac) async {
    _mac = mac.trim().toUpperCase();
    await PhoneMacStorage.saveMac(_mac!);
    await _startNavigation();
  }

  Future<void> _confirmPhoneSelection() async {
    final mac = _selectedMac;
    if (mac == null || mac.isEmpty) return;
    await _usePhone(mac);
  }

  Future<void> _startNavigation() async {
    setState(() {
      _phase = _PhoneSetupPhase.navigating;
      _error = null;
      _data = null;
    });
    _movementTrail.reset();
    await _refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<void> _changePhone() async {
    _timer?.cancel();
    _timer = null;
    _detectTimer?.cancel();
    _detectTimer = null;
    _mac = null;
    _data = null;
    _movementTrail.reset();
    await PhoneMacStorage.clear();
    await _scanForPhones(autoStartIfSingle: false);
  }

  Future<void> _refresh() async {
    if (_mac == null) return;
    try {
      final data = await _service.getNavigation(
        mac: _mac!,
        standId: widget.standId,
      );
      if (!mounted) return;
      _movementTrail.add(data.buyer);
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _detectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.oliveGreen),
        ),
        title: Text(
          'Vers ${widget.standNom}',
          style: const TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (_phase == _PhoneSetupPhase.navigating && _mac != null)
            IconButton(
              onPressed: _changePhone,
              tooltip: 'Changer de téléphone',
              icon: const Icon(Icons.phonelink_setup, color: AppColors.oliveGreen),
            ),
        ],
      ),
      body: _phase != _PhoneSetupPhase.navigating
          ? _buildPhoneSetupBody()
          : _error != null && _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _changePhone,
                          child: const Text('Choisir mon téléphone'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
              children: [
                if (_data != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_walk,
                            color: AppColors.oliveGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_data!.distanceM.toStringAsFixed(1)} m — position mise à jour en continu',
                          style: TextStyle(
                            color: AppColors.textGrey.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _data == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.oliveGreen,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.lightGrey,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CustomPaint(
                                    size: Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ),
                                    painter: _MarketMapPainter(
                                      data: _data!,
                                      trail: _movementTrail.points,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                if (_data != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFFE53935)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _data!.stand.nom,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkOlive,
                                  ),
                                ),
                                if (_data!.stand.positionLabel.isNotEmpty)
                                  Text(
                                    _data!.stand.positionLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGrey
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '📱 ${_data!.buyer.x.toStringAsFixed(2)}, '
                            '${_data!.buyer.y.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.oliveGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPhoneSetupBody() {
    if (_phase == _PhoneSetupPhase.resolving || _detecting) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.oliveGreen),
      );
    }

    if (_phase == _PhoneSetupPhase.waiting) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_find, size: 48, color: AppColors.oliveGreen),
              const SizedBox(height: 16),
              const Text(
                'Aucun téléphone détecté pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkOlive,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sur CE téléphone (celui avec l\'app) :\n'
                '1. Connectez-vous au Wi-Fi des ESP32\n'
                '2. Restez dans la salle quelques secondes\n'
                '3. Les ESP32 détectent votre MAC Wi-Fi automatiquement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha: 0.9),
                  height: 1.45,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: AppColors.oliveGreen,
                strokeWidth: 2,
              ),
              const SizedBox(height: 12),
              Text(
                'Recherche en cours…',
                style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quel est votre téléphone ?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Plusieurs appareils sont visibles sur le Wi-Fi du marché. '
                  'Sélectionnez celui que vous tenez en main pour afficher '
                  'votre position et l\'itinéraire.',
                  style: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _detectedPhones.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final phone = _detectedPhones[i];
                final selected = phone.mac == _selectedMac;
                return Material(
                  color: selected
                      ? AppColors.sageGreen.withValues(alpha: 0.4)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _selectedMac = phone.mac),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: AppColors.oliveGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  phone.mac,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkOlive,
                                  ),
                                ),
                                Text(
                                  'x = ${phone.x.toStringAsFixed(2)} m, '
                                  'y = ${phone.y.toStringAsFixed(2)} m',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGrey
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.smartphone, color: AppColors.oliveGreen),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmPhoneSelection,
              icon: const Icon(Icons.navigation),
              label: const Text('Utiliser ce téléphone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.oliveGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketMapPainter extends CustomPainter {
  _MarketMapPainter({required this.data, required this.trail});

  final NavigationData data;
  final List<MapPoint> trail;

  static const _espColors = {
    'A': Color(0xFFE53935),
    'B': Color(0xFF43A047),
    'C': Color(0xFF1E88E5),
  };

  Offset _toScreen(double x, double y, Size size) {
    final scaleX = size.width / data.roomWidth;
    final scaleY = size.height / data.roomHeight;
    return Offset(x * scaleX, size.height - y * scaleY);
  }

  void _drawGpsPin(Canvas canvas, Offset tip, {double height = 30}) {
    const pinColor = Color(0xFFE53935);
    final width = height * 0.58;
    final radius = width / 2;
    final bulbCenter = Offset(tip.dx, tip.dy - height + radius);

    final pinPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        tip.dx + radius * 1.15,
        bulbCenter.dy + radius * 0.35,
        tip.dx + radius,
        bulbCenter.dy,
      )
      ..arcTo(
        Rect.fromCircle(center: bulbCenter, radius: radius),
        0,
        math.pi,
        false,
      )
      ..quadraticBezierTo(
        tip.dx - radius * 1.15,
        bulbCenter.dy + radius * 0.35,
        tip.dx,
        tip.dy,
      )
      ..close();

    canvas.drawPath(
      pinPath,
      Paint()
        ..color = pinColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(pinPath, Paint()..color = pinColor);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = const Color(0xFFB71C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      bulbCenter,
      radius * 0.38,
      Paint()..color = Colors.white,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 0.5;
    for (double x = 0; x <= data.roomWidth; x += 0.4) {
      final p = _toScreen(x, 0, size);
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), gridPaint);
    }
    for (double y = 0; y <= data.roomHeight; y += 0.4) {
      final p = _toScreen(0, y, size);
      canvas.drawLine(Offset(0, p.dy), Offset(size.width, p.dy), gridPaint);
    }

    final majorGridPaint = Paint()
      ..color = const Color(0xFFD0D0D0)
      ..strokeWidth = 0.8;
    for (double x = 0; x <= data.roomWidth; x += 1.0) {
      final p = _toScreen(x, 0, size);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        majorGridPaint,
      );
    }
    for (double y = 0; y <= data.roomHeight; y += 1.0) {
      final p = _toScreen(0, y, size);
      canvas.drawLine(
        Offset(0, p.dy),
        Offset(size.width, p.dy),
        majorGridPaint,
      );
    }

    final border = Paint()
      ..color = AppColors.oliveGreen.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Offset.zero & size, border);

    for (final entry in data.espPositions.entries) {
      final color = _espColors[entry.key] ?? AppColors.textGrey;
      final p = _toScreen(entry.value.x, entry.value.y, size);
      canvas.drawCircle(p, 6, Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(
          text: 'ESP ${entry.key}',
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(p.dx + 8, p.dy - 6));
    }

    if (trail.length >= 2) {
      final trailPaint = Paint()
        ..color = AppColors.oliveGreen.withValues(alpha: 0.75)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final trailPath = MovementTrail.buildSmoothPath(
        trail,
        (p) => _toScreen(p.x, p.y, size),
      );
      canvas.drawPath(trailPath, trailPaint);
    }

    if (data.path.length >= 2) {
      final pathPaint = Paint()
        ..color = AppColors.searchOrange.withValues(alpha: 0.85)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final routePath = MovementTrail.buildSmoothPath(
        data.path,
        (p) => _toScreen(p.x, p.y, size),
      );
      canvas.drawPath(routePath, pathPaint);
    }

    final buyerPt = _toScreen(data.buyer.x, data.buyer.y, size);
    canvas.drawCircle(
      buyerPt,
      9,
      Paint()..color = const Color(0xFF1E88E5),
    );
    canvas.drawCircle(
      buyerPt,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final standPt = _toScreen(data.stand.x, data.stand.y, size);
    _drawGpsPin(canvas, standPt);
  }

  @override
  bool shouldRepaint(covariant _MarketMapPainter oldDelegate) {
    return oldDelegate.data.buyer.x != data.buyer.x ||
        oldDelegate.data.buyer.y != data.buyer.y ||
        oldDelegate.data.path.length != data.path.length ||
        oldDelegate.trail.length != trail.length;
  }
}

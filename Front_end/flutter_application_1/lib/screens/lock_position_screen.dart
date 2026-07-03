import 'dart:async';

import 'package:flutter/material.dart';

import '../services/marketplace_service.dart';
import '../services/position_service.dart';
import '../theme/app_colors.dart';

/// Écran vendeur : mesure la position Wi-Fi puis verrouille x/y en base.
class LockPositionScreen extends StatefulWidget {
  const LockPositionScreen({super.key});

  @override
  State<LockPositionScreen> createState() => _LockPositionScreenState();
}

class _LockPositionScreenState extends State<LockPositionScreen> {
  final _positionService = PositionService();
  final _marketplaceService = MarketplaceService();

  List<PhonePosition> _phones = [];
  String? _selectedMac;
  bool _locking = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final phones = await _positionService.getAllPositions();
      if (!mounted) return;
      final mobile = phones.where((p) => !p.locked).toList();
      setState(() {
        _phones = mobile;
        _error = null;
        if (_selectedMac == null && mobile.isNotEmpty) {
          _selectedMac = mobile.first.mac;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _verrouiller() async {
    if (_selectedMac == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez votre téléphone détecté')),
      );
      return;
    }

    setState(() => _locking = true);
    try {
      await _marketplaceService.verrouillerPosition(_selectedMac!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position verrouillée avec succès !'),
          backgroundColor: AppColors.oliveGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        title: const Text(
          'Verrouiller la position',
          style: TextStyle(
            color: AppColors.oliveGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
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
                    'Posez votre téléphone à votre stand',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkOlive,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Restez immobile pendant la mesure. Les ESP32 calculent votre '
                    'position x/y. Cliquez sur « Verrouiller » pour figer cette '
                    'position en base — elle ne sera plus recalculée.',
                    style: TextStyle(
                      color: AppColors.textGrey.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Téléphones détectés',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.darkOlive,
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            Expanded(
              child: _phones.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.oliveGreen,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'En attente de détection Wi-Fi…',
                            style: TextStyle(
                              color: AppColors.textGrey.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _phones.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final phone = _phones[i];
                        final selected = phone.mac == _selectedMac;
                        return Material(
                          color: selected
                              ? AppColors.sageGreen.withValues(alpha: 0.4)
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () =>
                                setState(() => _selectedMac = phone.mac),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                  const Icon(Icons.wifi,
                                      color: AppColors.oliveGreen),
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
                onPressed: _locking ? null : _verrouiller,
                icon: _locking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.lock),
                label: const Text('Verrouiller ma position'),
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
      ),
    );
  }
}

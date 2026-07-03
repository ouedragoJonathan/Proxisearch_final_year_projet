import 'package:flutter/material.dart';

import '../services/beacon_permission_helper.dart';
import '../services/beacon_permission_storage.dart';
import '../services/beacon_proximity_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/proxisearch_brand.dart';
import 'bot_screen.dart';

class BeaconPermissionScreen extends StatefulWidget {
  const BeaconPermissionScreen({super.key, required this.acheteurId});

  final String acheteurId;

  @override
  State<BeaconPermissionScreen> createState() => _BeaconPermissionScreenState();
}

class _BeaconPermissionScreenState extends State<BeaconPermissionScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _requestPermissions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final granted = await BeaconPermissionHelper.requestAll();

    if (!mounted) return;

    if (granted) {
      await NotificationService.instance.initialize();
      await BeaconPermissionStorage.setGranted(true);
      await BeaconProximityService.instance.start();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BotScreen(acheteurId: widget.acheteurId),
        ),
      );
      return;
    }

    setState(() {
      _loading = false;
      _error =
          'Certaines permissions sont nécessaires pour recevoir les promos à proximité. '
          'Activez Bluetooth et Localisation dans les réglages.';
    });
  }

  Future<void> _skip() async {
    await BeaconPermissionStorage.setGranted(false);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BotScreen(acheteurId: widget.acheteurId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const ProxiSearchTitle(fontSize: 26),
              const SizedBox(height: 40),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.limeGreen.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 44,
                  color: AppColors.oliveGreen,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Promos à proximité',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkOlive,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'ProxiSearch utilise le Bluetooth et votre position pour détecter '
                'les stands près de vous et vous envoyer des offres exclusives, '
                'même lorsque l\'app est fermée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.textGrey.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 28),
              _featureRow(
                Icons.bluetooth,
                'Bluetooth',
                'Détecte les balises iBeacon des stands',
              ),
              const SizedBox(height: 14),
              _featureRow(
                Icons.location_on_outlined,
                'Localisation',
                'Confirme que vous êtes bien au marché',
              ),
              const SizedBox(height: 14),
              _featureRow(
                Icons.local_offer_outlined,
                'Notifications',
                'Alertes promo comme sur l\'écran verrouillé',
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.oliveGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          'Autoriser et activer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : _skip,
                child: Text(
                  'Plus tard',
                  style: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.oliveGreen, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkOlive,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

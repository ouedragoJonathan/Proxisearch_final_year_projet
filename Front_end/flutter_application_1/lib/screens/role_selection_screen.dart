import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/proxisearch_brand.dart';
import 'beacon_permission_screen.dart';
import 'bot_screen.dart';
import 'login_screen.dart';
import '../services/acheteur_service.dart';
import '../services/beacon_permission_storage.dart';
import '../services/beacon_proximity_service.dart';
import '../services/notification_service.dart';
import '../services/token_storage.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  static const _logoPath = 'assets/images/proxisearch_logo.png';
  bool _loadingAcheteur = false;

  Future<void> _selectAcheteur() async {
    if (_loadingAcheteur) return;
    setState(() => _loadingAcheteur = true);
    try {
      final acheteurService = AcheteurService();
      final acheteurId = await acheteurService.loginOrRegister();
      if (!mounted) return;

      final permissionsOk = await BeaconPermissionStorage.hasGrantedPermissions();
      if (!mounted) return;

      if (permissionsOk) {
        await NotificationService.instance.initialize();
        await BeaconProximityService.instance.start();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => BotScreen(acheteurId: acheteurId),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => BeaconPermissionScreen(acheteurId: acheteurId),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAcheteur = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _selectVendeur() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    _logoPath,
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  const ProxiSearchTitle(fontSize: 24),
                ],
              ),
              const SizedBox(height: 48),
              const Text(
                'Comment souhaitez-vous\nutiliser ProxiSearch ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkOlive,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 36),
              _RoleCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Je fais mes achats',
                subtitle: 'Découvrir les produits locaux',
                loading: _loadingAcheteur,
                onTap: _selectAcheteur,
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.storefront_outlined,
                title: 'Je suis commerçant',
                subtitle: 'Vendre et gérer ma boutique',
                onTap: _selectVendeur,
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await TokenStorage.clearSession();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Retour',
                  style: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.8),
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
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightGrey),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.darkOlive, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkOlive,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.oliveGreen,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

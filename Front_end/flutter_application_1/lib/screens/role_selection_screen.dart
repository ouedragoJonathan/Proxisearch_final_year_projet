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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD8E8CC),
              Color(0xFFE6EFE0),
              Color(0xFFF5F2EC),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 28),
                  const ProxiSearchTitle(fontSize: 18),
                  const Spacer(flex: 2),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Qui êtes-vous ?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkOlive,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      height: 150,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 48,
                            child: _RolePill(
                              label: 'Acheter',
                              icon: Icons.shopping_bag_outlined,
                              iconOnLeft: true,
                              backgroundColor: AppColors.white,
                              loading: _loadingAcheteur,
                              onTap: _selectAcheteur,
                            ),
                          ),
                          Positioned(
                            top: 78,
                            left: 48,
                            right: 0,
                            child: _RolePill(
                              label: 'Vendre',
                              icon: Icons.storefront_outlined,
                              iconOnLeft: false,
                              backgroundColor:
                                  AppColors.sageGreen.withValues(alpha: 0.65),
                              onTap: _selectVendeur,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 140),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: TextButton(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({
    required this.label,
    required this.icon,
    required this.iconOnLeft,
    required this.backgroundColor,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final bool iconOnLeft;
  final Color backgroundColor;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: iconOnLeft ? 1 : 0.95),
        shape: BoxShape.circle,
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.oliveGreen,
              ),
            )
          : Icon(icon, color: AppColors.oliveGreen, size: 22),
    );

    final textWidget = Column(
      crossAxisAlignment:
          iconOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          'JE SOUHAITE',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
            color: AppColors.oliveGreen.withValues(alpha: 0.85),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.darkOlive,
          ),
        ),
      ],
    );

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(48),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(48),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(
            children: iconOnLeft
                ? [
                    iconWidget,
                    const SizedBox(width: 16),
                    Expanded(child: textWidget),
                  ]
                : [
                    Expanded(child: textWidget),
                    const SizedBox(width: 16),
                    iconWidget,
                  ],
          ),
        ),
      ),
    );
  }
}

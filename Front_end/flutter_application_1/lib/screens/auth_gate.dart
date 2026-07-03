import 'package:flutter/material.dart';

import '../services/token_storage.dart';
import '../services/beacon_permission_storage.dart';
import '../services/beacon_proximity_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'beacon_permission_screen.dart';
import 'bot_screen.dart';
import 'main_shell.dart';
import 'welcome_screen.dart';

/// Choisit l'écran initial : Home si session active, sinon Welcome.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _resolveInitialScreen();
  }

  Future<void> _resolveInitialScreen() async {
    final token = await TokenStorage.getAccessToken();
    final vendeurId = await TokenStorage.getVendeurId();
    final numTelephone = await TokenStorage.getNumTelephone();
    final acheteurId = await TokenStorage.getAcheteurId();
    final userRole = await TokenStorage.getUserRole();

    if (!mounted) return;

    Widget? nextScreen;
    if (token != null && vendeurId != null && numTelephone != null) {
      nextScreen = MainShell(
        vendeurId: vendeurId,
        numTelephone: numTelephone,
      );
    } else if (userRole == 'acheteur' && acheteurId != null) {
      final permissionsOk = await BeaconPermissionStorage.hasGrantedPermissions();
      if (permissionsOk) {
        await NotificationService.instance.initialize();
        await BeaconProximityService.instance.start();
        nextScreen = BotScreen(acheteurId: acheteurId);
      } else {
        nextScreen = BeaconPermissionScreen(acheteurId: acheteurId);
      }
    } else {
      nextScreen = const WelcomeScreen();
    }

    if (!mounted) return;
    setState(() => _screen = nextScreen);  }

  @override
  Widget build(BuildContext context) {
    if (_screen == null) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.oliveGreen),
        ),
      );
    }

    return _screen!;
  }
}

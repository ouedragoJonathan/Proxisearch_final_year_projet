import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/proxisearch_brand.dart';
import '../widgets/splash_background_painter.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _logoPath = 'assets/images/proxisearch_logo.png';

  @override
  void initState() {
    super.initState();
    _goToNextScreen();
  }

  Future<void> _goToNextScreen() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: SplashBackgroundPainter(),
            size: Size.infinite,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _logoPath,
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const ProxiSearchTitle(fontSize: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

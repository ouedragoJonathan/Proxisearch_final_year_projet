import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProxiSearchApp());
}

class ProxiSearchApp extends StatelessWidget {
  const ProxiSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProxiSearch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.oliveGreen,
          primary: AppColors.oliveGreen,
        ),
        scaffoldBackgroundColor: AppColors.white,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

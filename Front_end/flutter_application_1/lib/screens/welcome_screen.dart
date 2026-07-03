import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/wave_clipper.dart';
import 'role_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          ClipPath(
            clipper: const WaveClipper(waveHeight: 100),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.62,
              color: AppColors.sageGreen,
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenue',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkOlive,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Découvrez les meilleurs marchés locaux autour de vous en un clin d\'œil.',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          color: AppColors.darkOlive.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 32, bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'CONTINUER',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textGrey.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RoleSelectionScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.limeGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.limeGreen.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: AppColors.darkOlive,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

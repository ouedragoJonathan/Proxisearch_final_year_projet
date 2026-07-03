import 'package:flutter/material.dart';

import '../services/token_storage.dart';
import '../theme/app_colors.dart';
import 'ibeacon_screen.dart';
import 'stands_list_screen.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.numTelephone});

  final String numTelephone;

  Future<void> _logout(BuildContext context) async {
    await TokenStorage.clearSession();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.oliveGreen,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.oliveGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 52, color: AppColors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Vendeur',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.darkOlive,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: AppColors.textGrey.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  numTelephone,
                  style: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _MenuTile(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.sensors_outlined,
              label: 'iBeacon Management',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IBeaconScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.storefront_outlined,
              label: 'Stand gestion',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StandsListScreen()),
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.limeGreen,
                  foregroundColor: AppColors.darkOlive,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, size: 18, color: Color(0xFFC0392B)),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: Color(0xFFC0392B)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.textGrey.withValues(alpha: 0.4)),
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

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.oliveGreen),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkOlive,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textGrey.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

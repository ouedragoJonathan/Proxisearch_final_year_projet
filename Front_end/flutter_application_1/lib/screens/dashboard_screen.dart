import 'package:flutter/material.dart';

import '../models/dashboard_stats.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import 'lock_position_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = MarketplaceService();
  DashboardStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _service.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openLockPosition() async {
    final locked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LockPositionScreen()),
    );
    if (locked == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.oliveGreen,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkOlive,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vue d\'ensemble de votre activité',
                      style: TextStyle(
                        color: AppColors.textGrey.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.oliveGreen),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.oliveGreen,
                            foregroundColor: AppColors.white,
                          ),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_stats != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _StandHeader(nomStand: _stats!.nomStand),
                    const SizedBox(height: 20),
                    _StatCard(
                      icon: Icons.notifications_active_outlined,
                      label: 'Visiteurs via notification',
                      value: '${_stats!.clicsNotif}',
                      subtitle:
                          'Personnes venues en cliquant sur une alerte promo',
                      accentColor: AppColors.limeGreen,
                      highlighted: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.inventory_2_outlined,
                            label: 'Produits disponibles',
                            value: '${_stats!.produitsDisponibles}',
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Total produits',
                            value: '${_stats!.totalProduits}',
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.category_outlined,
                            label: 'Catégories',
                            value: '${_stats!.nombreCategories}',
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_offer_outlined,
                            label: 'Promotions actives',
                            value: '${_stats!.promotionsActives}',
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _PositionCard(
                      locked: _stats!.positionVerrouillee,
                      onLock: _openLockPosition,
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StandHeader extends StatelessWidget {
  const _StandHeader({required this.nomStand});

  final String nomStand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.oliveGreen,
            AppColors.oliveGreen.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mon stand',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nomStand.isEmpty ? '—' : nomStand,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.accentColor,
    this.highlighted = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color? accentColor;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.oliveGreen;

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: highlighted
            ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey.withValues(alpha: 0.85),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkOlive,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkOlive,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.locked, required this.onLock});

  final bool locked;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                locked ? Icons.lock : Icons.location_searching,
                color: AppColors.oliveGreen,
              ),
              const SizedBox(width: 10),
              Text(
                locked ? 'Position GPS verrouillée' : 'Position GPS non verrouillée',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkOlive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            locked
                ? 'Les acheteurs peuvent vous localiser sur la carte du marché.'
                : 'Verrouillez votre position pour que les acheteurs puissent vous trouver.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGrey.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLock,
              icon: Icon(locked ? Icons.lock_reset : Icons.lock_outline),
              label: Text(
                locked ? 'Re-verrouiller la position' : 'Verrouiller ma position',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.oliveGreen,
                side: const BorderSide(color: AppColors.oliveGreen),
                padding: const EdgeInsets.symmetric(vertical: 12),
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

import 'package:flutter/material.dart';

import '../models/promotion.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _service = MarketplaceService();
  List<Promotion> _promotions = [];
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
      final promos = await _service.getMesPromotions();
      if (!mounted) return;
      setState(() {
        _promotions = promos;
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offres Flash',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkOlive,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vos promotions actives',
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
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            else if (_promotions.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Aucune promotion pour le moment',
                    style: TextStyle(
                      color: AppColors.textGrey.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: _promotions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final promo = _promotions[index];
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE85D4C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'PROMO',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            promo.titre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkOlive,
                            ),
                          ),
                          if (promo.description != null &&
                              promo.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              promo.description!,
                              style: TextStyle(
                                color: AppColors.textGrey.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

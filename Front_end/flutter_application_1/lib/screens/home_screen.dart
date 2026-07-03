import 'package:flutter/material.dart';

import '../models/categorie.dart';
import '../models/produit.dart';
import '../models/promotion.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import '../utils/category_icon_helper.dart';
import '../utils/product_image_helper.dart';
import '../widgets/proxisearch_brand.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.vendeurId,
    required this.numTelephone,
    this.onNavigateToCategories,
    this.onNavigateToSearch,
  });

  final String vendeurId;
  final String numTelephone;
  final VoidCallback? onNavigateToCategories;
  final VoidCallback? onNavigateToSearch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = MarketplaceService();
  List<Produit> _produits = [];
  List<Promotion> _promotions = [];
  List<Categorie> _categories = [];
  bool _loading = true;

  static const _logoPath = 'assets/images/proxisearch_logo.png';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stand = await _service.getMonStand();
      final promos = await _service.getMesPromotions();
      final categories = stand?.categories ?? [];
      final produits = <Produit>[];
      for (final cat in categories) {
        produits.addAll(cat.produits);
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _produits = produits.take(6).toList();
        _promotions = promos;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.oliveGreen),
                )
              : RefreshIndicator(
                  color: AppColors.oliveGreen,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          title: 'Produits les plus consultés',
                          onVoirTout: widget.onNavigateToSearch,
                          child: _produits.isEmpty
                              ? _emptyHint('Aucun produit pour le moment')
                              : SizedBox(
                                  height: 210,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    itemCount: _produits.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 14),
                                    itemBuilder: (_, i) =>
                                        _ProductCard(produit: _produits[i]),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        _buildSection(
                          title: 'Offres Flash',
                          child: _promotions.isEmpty
                              ? _emptyHint('Aucune promotion active')
                              : SizedBox(
                                  height: 170,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    itemCount: _promotions.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 14),
                                    itemBuilder: (_, i) => _FlashDealCard(
                                      promotion: _promotions[i],
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        _buildSection(
                          title: 'Catégories',
                          onVoirTout: widget.onNavigateToCategories,
                          child: _categories.isEmpty
                              ? _emptyHint('Créez des catégories depuis l\'onglet Categories')
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: _categories
                                        .take(4)
                                        .map(
                                          (c) => _CategoryItem(
                                            label: c.nom,
                                            icon: CategoryIconHelper.iconFor(
                                                c.iconeUrl),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textGrey.withValues(alpha: 0.75),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.menu, color: AppColors.darkOlive),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                _logoPath,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const ProxiSearchTitle(fontSize: 20),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onNavigateToSearch,
            icon: const Icon(Icons.search, color: AppColors.darkOlive),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    VoidCallback? onVoirTout,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkOlive,
                ),
              ),
              if (onVoirTout != null)
                TextButton(
                  onPressed: onVoirTout,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Voir tout',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.oliveGreen,
                    ),
                  ),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.produit});

  final Produit produit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: produit.photoUrl.isEmpty
                ? ColoredBox(
                    color: AppColors.lightGrey,
                    child: const Center(
                      child: Icon(Icons.image_outlined,
                          size: 48, color: AppColors.oliveGreen),
                    ),
                  )
                : ProductImage(
                    photoUrl: produit.photoUrl,
                    fit: BoxFit.cover,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produit.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Produit.formatPrix(produit.prix),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.oliveGreen,
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

class _FlashDealCard extends StatelessWidget {
  const _FlashDealCard({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE85D4C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PROMO',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            promotion.titre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkOlive,
            ),
          ),
          if (promotion.description != null &&
              promotion.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              promotion.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGrey.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.oliveGreen, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

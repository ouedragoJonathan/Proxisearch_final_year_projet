import 'package:flutter/material.dart';

import '../models/produit.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import '../utils/product_image_helper.dart';
import 'add_product_screen.dart';
import 'create_promotion_screen.dart';
import 'edit_product_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({
    super.key,
    required this.categorieId,
    required this.categorieNom,
  });

  final String categorieId;
  final String categorieNom;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final _service = MarketplaceService();
  List<Produit> _produits = [];
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
      final produits =
          await _service.getProduitsParCategorie(widget.categorieId);
      if (!mounted) return;
      setState(() {
        _produits = produits;
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

  Future<void> _openPromotion(Produit produit) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePromotionScreen(
          preselectedProductId: produit.id,
          preselectedProductName: produit.nom,
        ),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openAddProduct() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          categorieId: widget.categorieId,
          categorieNom: widget.categorieNom,
        ),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openEditProduct(Produit produit) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProductScreen(
          produit: produit,
          categorieNom: widget.categorieNom,
        ),
      ),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.darkOlive),
        ),
        title: Text(
          widget.categorieNom,
          style: const TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddProduct,
        backgroundColor: AppColors.limeGreen,
        foregroundColor: AppColors.darkOlive,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.oliveGreen),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_produits.isEmpty) {
      return Center(
        child: Text(
          'Aucun produit dans cette catégorie',
          style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.oliveGreen,
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.64,
        ),
        itemCount: _produits.length,
        itemBuilder: (context, index) {
          final produit = _produits[index];
          final hasPromo = produit.promotions.isNotEmpty;
          return GestureDetector(
            onTap: () => _openEditProduct(produit),
            child: Container(
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
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: SizedBox.expand(
                          child: ProductImage(
                            photoUrl: produit.photoUrl,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: AppColors.lightGrey,
                              child: const Icon(Icons.image_outlined),
                            ),
                          ),
                        ),
                      ),
                      if (hasPromo)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE85D4C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Sale',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produit.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkOlive,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          produit.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey.withValues(alpha: 0.8),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                Produit.formatPrix(produit.prix),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.oliveGreen,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _openPromotion(produit),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: AppColors.limeGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppColors.darkOlive,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}

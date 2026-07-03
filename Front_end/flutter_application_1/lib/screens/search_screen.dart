import 'package:flutter/material.dart';

import '../models/produit.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import '../utils/product_image_helper.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = MarketplaceService();
  final _controller = TextEditingController();
  List<Produit> _results = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _query = query;
    });

    try {
      final results = await _service.rechercherProduits(query);
      if (!mounted) return;
      setState(() {
        _results = results;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: _search,
                onChanged: (v) {
                  if (v.isEmpty) _search('');
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.darkOlive,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                          icon: const Icon(Icons.close),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                '${_results.length} résultat${_results.length > 1 ? 's' : ''} pour "$_query"',
                style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_query.isEmpty) {
      return Center(
        child: Text(
          'Tapez un mot-clé pour lancer la recherche',
          style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Aucun produit trouvé',
          style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) =>
          _SearchProductCard(produit: _results[index]),
    );
  }
}

class _SearchProductCard extends StatelessWidget {
  const _SearchProductCard({required this.produit});

  final Produit produit;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ProductImage(
                photoUrl: produit.photoUrl,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: AppColors.lightGrey,
                  child: const Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: AppColors.oliveGreen,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produit.nom,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkOlive,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        produit.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Produit.formatPrix(produit.prix),
                  style: const TextStyle(
                    fontSize: 16,
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

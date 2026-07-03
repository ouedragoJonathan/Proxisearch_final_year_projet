import 'package:flutter/material.dart';

import '../models/produit_recommande.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../utils/product_image_helper.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key, required this.acheteurId});

  final String acheteurId;

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _chatService = ChatService();
  List<ProduitRecommande> _produits = [];
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
          await _chatService.getRecommandations(widget.acheteurId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.darkOlive),
        ),
        centerTitle: true,
        title: const Text(
          'Recommandations',
          style: TextStyle(
            color: AppColors.oliveGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _buildBody(),
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

    return RefreshIndicator(
      color: AppColors.oliveGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            'Pour vous',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkOlive,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Produits similaires à vos recherches (même catégorie)',
            style: TextStyle(
              color: AppColors.textGrey.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),
          if (_produits.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'Aucune recommandation pour le moment.\n'
                  'Posez des questions au Market Guide !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.8),
                  ),
                ),
              ),
            )
          else
            ..._produits.map((p) => _RecommendationCard(produit: p)),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.produit});

  final ProduitRecommande produit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            height: 180,
            width: double.infinity,
            child: ProductImage(
              photoUrl: produit.photoUrl,
              fit: BoxFit.cover,
              placeholder: ColoredBox(
                color: AppColors.lightGrey,
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: AppColors.textGrey.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        produit.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.darkOlive,
                        ),
                      ),
                    ),
                    Text(
                      produit.prixFormate,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.oliveGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.sageGreen.withValues(alpha: 0.5),
                      child: const Icon(Icons.store, size: 14, color: AppColors.oliveGreen),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        produit.nomStand,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGrey.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

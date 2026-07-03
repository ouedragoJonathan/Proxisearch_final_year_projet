import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/produit.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import '../utils/product_image_helper.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({
    super.key,
    required this.categorieId,
    required this.categorieNom,
  });

  final String categorieId;
  final String categorieNom;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _service = MarketplaceService();
  final _nomController = TextEditingController();
  final _prixController = TextEditingController();
  final _descController = TextEditingController();
  String _photoUrl = '';
  bool _enStock = true;
  bool _saving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prixController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final url = await ProductImageHelper.pickFromGallery(context);
    if (url != null && url.isNotEmpty) setState(() => _photoUrl = url);
  }

  Future<void> _save() async {
    final nom = _nomController.text.trim();
    if (nom.isEmpty) {
      _showError('Le nom du produit est requis');
      return;
    }
    final prix = Produit.parsePrixFromInput(_prixController.text);
    if (prix == null || prix <= 0) {
      _showError('Indiquez un prix valide (ex. 12,50)');
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.creerProduit(
        nom: nom,
        description: _descController.text.trim(),
        prix: prix,
        disponibilte: _enStock,
        photoUrl: _photoUrl,
        categorieId: widget.categorieId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          icon: const Icon(Icons.close, color: AppColors.darkOlive),
        ),
        centerTitle: true,
        title: const Text(
          'Ajouter un Produit',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPhotoSection(),
                  const SizedBox(height: 20),
                  _sectionCard(
                    title: 'Informations générales',
                    children: [
                      _fieldLabel('Nom du produit'),
                      TextField(
                        controller: _nomController,
                        decoration: _inputDecoration('Ex. Savon Artisanal Lavande'),
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('Prix (FCFA)'),
                      TextField(
                        controller: _prixController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d,.\s]'),
                          ),
                        ],
                        decoration: _inputDecoration('500000'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Détails',
                    children: [
                      _fieldLabel('Catégorie'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.categorieNom,
                                style: const TextStyle(
                                  color: AppColors.darkOlive,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.expand_more,
                              color: AppColors.textGrey.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('Description'),
                      TextField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: _inputDecoration(
                          'Décrivez votre produit...',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStockCard(),
                ],
              ),
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: _changePhoto,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _photoUrl.isEmpty
                  ? Container(
                      color: AppColors.lightGrey,
                      child: Icon(
                        Icons.image_outlined,
                        size: 64,
                        color: AppColors.textGrey.withValues(alpha: 0.4),
                      ),
                    )
                  : ProductImage(photoUrl: _photoUrl, fit: BoxFit.cover),
              Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.oliveGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ajouter une photo',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'En stock',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Afficher ce produit dans la boutique',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enStock,
            onChanged: (v) => setState(() => _enStock = v),
            activeTrackColor: AppColors.limeGreen,
            activeThumbColor: AppColors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.limeGreen,
              foregroundColor: AppColors.darkOlive,
              disabledBackgroundColor:
                  AppColors.limeGreen.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.darkOlive,
                    ),
                  )
                : const Text(
                    'Sauvegarder',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.darkOlive,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textGrey.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.lightGrey.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

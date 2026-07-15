import 'package:flutter/material.dart';

import '../models/categorie.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import '../utils/category_icon_helper.dart';

class EditCategoryScreen extends StatefulWidget {
  const EditCategoryScreen({super.key, required this.categorie});

  final Categorie categorie;

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  final _service = MarketplaceService();
  late final TextEditingController _nomController;
  late final TextEditingController _descController;
  late String _selectedIcon;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.categorie;
    _nomController = TextEditingController(text: c.nom);
    _descController = TextEditingController(text: c.description);
    _selectedIcon = CategoryIconHelper.iconOptions
            .any((option) => option.$1 == c.iconeUrl)
        ? c.iconeUrl
        : CategoryIconHelper.iconOptions.first.$1;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nom = _nomController.text.trim();
    if (nom.isEmpty) {
      _showError('Le nom de la catégorie est requis');
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.modifierCategorie(
        categorieId: widget.categorie.id,
        nom: nom,
        description: _descController.text.trim(),
        iconeUrl: _selectedIcon,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text(
          '« ${widget.categorie.nom} » et tous ses produits seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Color(0xFFC0392B)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await _service.supprimerCategorie(widget.categorie.id);
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
          'Modifier Catégorie',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFC0392B)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.oliveGreen,
                          AppColors.oliveGreen.withValues(alpha: 0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.categorie.nom,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.categorie.productCount} produit${widget.categorie.productCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _label('Nom de la catégorie'),
                  TextField(
                    controller: _nomController,
                    decoration: _inputDecoration('ex. Fruits & Légumes'),
                  ),
                  const SizedBox(height: 16),
                  _label('Description (optionnel)'),
                  TextField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: _inputDecoration(
                      'Décrivez brièvement cette catégorie...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('Choisir une icône'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: CategoryIconHelper.iconOptions.map((option) {
                      final selected = _selectedIcon == option.$1;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = option.$1),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.limeGreen
                                : AppColors.lightGrey.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(option.$2, color: AppColors.darkOlive),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          _buildSaveButton(),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textGrey.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';

class AddStandScreen extends StatefulWidget {
  const AddStandScreen({super.key});

  @override
  State<AddStandScreen> createState() => _AddStandScreenState();
}

class _AddStandScreenState extends State<AddStandScreen> {
  final _service = MarketplaceService();
  final _nomController = TextEditingController();
  final _descController = TextEditingController();
  final _positionController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _descController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nom = _nomController.text.trim();
    final position = _positionController.text.trim();
    if (nom.isEmpty || position.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nom et la position du stand sont requis'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.creerStand(
        nomDuStand: nom,
        description: _descController.text.trim(),
        position: position,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
          icon: const Icon(Icons.arrow_back, color: AppColors.oliveGreen),
        ),
        title: const Text(
          'Stand',
          style: TextStyle(
            color: AppColors.oliveGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajouter un Stand',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.darkOlive,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Partagez les détails de votre stand avec la communauté.',
              style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 24),
            _label('Nom du Stand'),
            TextField(
              controller: _nomController,
              decoration: _input('Ex: Les Délices de Marie'),
            ),
            const SizedBox(height: 16),
            _label('Description'),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: _input(
                'Décrivez les produits, l\'ambiance, vos spécialités...',
              ),
            ),
            const SizedBox(height: 16),
            _label('Position (Allée / Emplacement)'),
            TextField(
              controller: _positionController,
              decoration: _input('Ex: Allée C, Emplacement 12'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Enregistrer le stand'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.limeGreen,
                  foregroundColor: AppColors.darkOlive,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.darkOlive,
        ),
      ),
    );
  }

  InputDecoration _input(String hint) {
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

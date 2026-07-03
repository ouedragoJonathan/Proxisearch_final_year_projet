import 'package:flutter/material.dart';

import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';

class CreatePromotionScreen extends StatefulWidget {
  const CreatePromotionScreen({
    super.key,
    this.preselectedProductId,
    this.preselectedProductName,
  });

  final String? preselectedProductId;
  final String? preselectedProductName;

  @override
  State<CreatePromotionScreen> createState() => _CreatePromotionScreenState();
}

class _CreatePromotionScreenState extends State<CreatePromotionScreen> {
  final _service = MarketplaceService();
  final _titreController = TextEditingController();
  final _descController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titreController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final titre = _titreController.text.trim();
    if (titre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre de la promotion est requis')),
      );
      return;
    }
    if (widget.preselectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun produit sélectionné')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.creerPromotion(
        titre: titre,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        produitsIds: [widget.preselectedProductId!],
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
          icon: const Icon(Icons.arrow_back, color: AppColors.darkOlive),
        ),
        title: const Text(
          'Promotion',
          style: TextStyle(
            color: AppColors.oliveGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saving ? null : _publish,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.limeGreen,
                foregroundColor: AppColors.darkOlive,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Promotion',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.darkOlive,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Design a new flash deal to attract nearby customers.',
              style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 24),
            _card(
              title: 'Promotion Details',
              icon: Icons.edit_note_outlined,
              child: Column(
                children: [
                  _field(
                    label: 'Promotion Title',
                    controller: _titreController,
                    hint: 'e.g., Summer Weekend Flash Sale',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    label: 'Description',
                    controller: _descController,
                    hint: 'Describe the offer...',
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              title: 'Target Product',
              icon: Icons.category_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected product',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.lightGrey),
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.white,
                    ),
                    child: Text(
                      widget.preselectedProductName ?? 'Produit',
                      style: const TextStyle(color: AppColors.darkOlive),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
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
          Row(
            children: [
              Icon(icon, color: AppColors.oliveGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkOlive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textGrey.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.lightGrey),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

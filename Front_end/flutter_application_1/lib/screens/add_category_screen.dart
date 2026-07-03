import 'package:flutter/material.dart';

import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import '../utils/category_icon_helper.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _service = MarketplaceService();
  final _nomController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedIcon = CategoryIconHelper.iconOptions.first.$1;
  bool _saving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nom = _nomController.text.trim();
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom de la catégorie est requis')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.creerCategorie(
        nom: nom,
        description: _descController.text.trim(),
        iconeUrl: _selectedIcon,
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
          'Categories',
          style: TextStyle(
            color: AppColors.oliveGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.darkOlive),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Category',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Define an area of the market to organize listings.',
                    style: TextStyle(color: AppColors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _label('Category Name'),
            TextField(
              controller: _nomController,
              decoration: _inputDecoration('e.g. Fresh Produce'),
            ),
            const SizedBox(height: 16),
            _label('Description (Optional)'),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: _inputDecoration(
                'Briefly describe what goes in this category...',
              ),
            ),
            const SizedBox(height: 20),
            _label('Choose an Icon'),
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
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.oliveGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text('Save Category'),
                  ),
                ),
              ],
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

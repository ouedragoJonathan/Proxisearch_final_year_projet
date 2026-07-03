import 'package:flutter/material.dart';

import '../models/stand.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import 'lock_position_screen.dart';

class EditStandScreen extends StatefulWidget {
  const EditStandScreen({super.key, required this.stand});

  final Stand stand;

  @override
  State<EditStandScreen> createState() => _EditStandScreenState();
}

class _EditStandScreenState extends State<EditStandScreen> {
  final _service = MarketplaceService();
  late final TextEditingController _nomController;
  late final TextEditingController _descController;
  late final TextEditingController _positionController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.stand.nomDuStand);
    _descController = TextEditingController(text: widget.stand.description);
    _positionController = TextEditingController(text: widget.stand.position);
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    setState(() => _saving = true);
    try {
      await _service.modifierStand(
        nomDuStand: _nomController.text.trim(),
        description: _descController.text.trim(),
        position: _positionController.text.trim(),
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

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le stand ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.supprimerStand();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openLockPosition() async {
    final locked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LockPositionScreen()),
    );
    if (locked == true && mounted) {
      Navigator.of(context).pop(true);
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
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFC0392B)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modifier le Stand',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.darkOlive,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mettez à jour les informations de votre emplacement.',
              style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 24),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Nom du stand'),
                  TextField(
                    controller: _nomController,
                    decoration: _input(),
                  ),
                  const SizedBox(height: 16),
                  _label('Description'),
                  TextField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: _input(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOCALISATION',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGrey.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: widget.stand.positionVerrouillee
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock,
                                    size: 36, color: AppColors.oliveGreen),
                                const SizedBox(height: 8),
                                Text(
                                  'Position verrouillée : '
                                  '${widget.stand.positionX?.toStringAsFixed(2) ?? '—'} m, '
                                  '${widget.stand.positionY?.toStringAsFixed(2) ?? '—'} m',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkOlive,
                                  ),
                                ),
                              ],
                            )
                          : const Icon(Icons.location_searching,
                              size: 40, color: AppColors.oliveGreen),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openLockPosition,
                      icon: Icon(
                        widget.stand.positionVerrouillee
                            ? Icons.lock_reset
                            : Icons.lock_outline,
                      ),
                      label: Text(
                        widget.stand.positionVerrouillee
                            ? 'Re-verrouiller la position'
                            : 'Verrouiller ma position GPS',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.oliveGreen,
                        side: const BorderSide(color: AppColors.oliveGreen),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Position (Allée / Emplacement)'),
                  TextField(
                    controller: _positionController,
                    decoration: _input(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _update,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Mettre à jour'),
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

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppColors.oliveGreen, width: 4),
        ),
      ),
      child: child,
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textGrey.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  InputDecoration _input() {
    return InputDecoration(
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

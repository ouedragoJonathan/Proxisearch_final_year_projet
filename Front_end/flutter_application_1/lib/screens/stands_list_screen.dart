import 'package:flutter/material.dart';

import '../models/stand.dart';
import '../services/marketplace_service.dart';
import '../theme/app_colors.dart';
import 'add_stand_screen.dart';
import 'edit_stand_screen.dart';

class StandsListScreen extends StatefulWidget {
  const StandsListScreen({super.key});

  @override
  State<StandsListScreen> createState() => _StandsListScreenState();
}

class _StandsListScreenState extends State<StandsListScreen> {
  final _service = MarketplaceService();
  Stand? _stand;
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
      final stand = await _service.getMonStand();
      if (!mounted) return;
      setState(() {
        _stand = stand;
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

  Future<void> _openAddStand() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddStandScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openEditStand() async {
    if (_stand == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditStandScreen(stand: _stand!)),
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
        title: const Text(
          'Mes Stands',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: _stand == null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FloatingActionButton.extended(
                  onPressed: _openAddStand,
                  backgroundColor: AppColors.limeGreen,
                  foregroundColor: AppColors.darkOlive,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un stand'),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_stand == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Vous n\'avez pas encore de stand.\nAppuyez sur le bouton ci-dessous pour en créer un.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.85)),
          ),
        ),
      );
    }

    final stand = _stand!;
    return RefreshIndicator(
      color: AppColors.oliveGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gérez vos emplacements',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vous gérez actuellement 1 stand actif sur le marché.',
                  style: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _StandCard(stand: stand, onEdit: _openEditStand),
        ],
      ),
    );
  }
}

class _StandCard extends StatelessWidget {
  const _StandCard({required this.stand, required this.onEdit});

  final Stand stand;
  final VoidCallback onEdit;

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
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Center(
              child: Icon(Icons.storefront, size: 56, color: AppColors.oliveGreen),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stand.nomDuStand,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.darkOlive,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.oliveGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.place_outlined,
                        size: 16, color: AppColors.textGrey.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stand.position,
                        style: TextStyle(
                          color: AppColors.textGrey.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                if (stand.positionVerrouillee) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.lock,
                          size: 16, color: AppColors.oliveGreen),
                      const SizedBox(width: 6),
                      Text(
                        'GPS : ${stand.positionX?.toStringAsFixed(2) ?? '—'} m, '
                        '${stand.positionY?.toStringAsFixed(2) ?? '—'} m',
                        style: const TextStyle(
                          color: AppColors.oliveGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                if (stand.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    stand.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textGrey.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

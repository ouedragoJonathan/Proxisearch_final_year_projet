import 'package:flutter/material.dart';

import '../models/search_history_item.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import 'bot_screen.dart';

class SearchHistoryScreen extends StatefulWidget {
  const SearchHistoryScreen({super.key, required this.acheteurId});

  final String acheteurId;

  @override
  State<SearchHistoryScreen> createState() => _SearchHistoryScreenState();
}

class _SearchHistoryScreenState extends State<SearchHistoryScreen> {
  final _chatService = ChatService();
  List<SearchHistoryItem> _items = [];
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
      final items = await _chatService.getHistorique(widget.acheteurId);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer l\'historique ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _chatService.effacerHistorique(widget.acheteurId);
      if (!mounted) return;
      setState(() => _items = []);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _redoSearch(SearchHistoryItem item) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BotScreen(acheteurId: widget.acheteurId),
      ),
    );
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
          'Historique',
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
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'Aucune recherche enregistrée',
          style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.oliveGreen,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _clearHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textGrey,
                    side: BorderSide(
                      color: AppColors.textGrey.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Effacer l\'historique'),
                ),
              ),
            );
          }

          final item = _items[index];
          return _HistoryCard(
            item: item,
            onRedo: () => _redoSearch(item),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.onRedo});

  final SearchHistoryItem item;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                Text(
                  item.requete,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.formattedDate,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGrey.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.resultatTrouve
                        ? AppColors.sageGreen.withValues(alpha: 0.35)
                        : AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.resultatTrouve ? 'Résultat trouvé' : 'Non trouvé',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.resultatTrouve
                          ? AppColors.oliveGreen
                          : AppColors.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRedo,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: AppColors.oliveGreen, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

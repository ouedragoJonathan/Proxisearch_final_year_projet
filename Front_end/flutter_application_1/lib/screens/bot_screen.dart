import 'dart:async';

import 'package:flutter/material.dart';

import '../models/produit_recommande.dart';
import '../services/chat_service.dart';
import '../services/token_storage.dart';
import '../theme/app_colors.dart';
import '../utils/product_image_helper.dart';
import '../widgets/proxisearch_brand.dart';
import 'navigation_map_screen.dart';
import 'recommendations_screen.dart';
import 'search_history_screen.dart';
import 'welcome_screen.dart';

enum _SuggestionCardStyle { product, stand }

class BotScreen extends StatefulWidget {
  const BotScreen({super.key, required this.acheteurId});

  final String acheteurId;

  @override
  State<BotScreen> createState() => _BotScreenState();
}

class _BotScreenState extends State<BotScreen> {
  final _chatService = ChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _loading = false;
  ConversationContext? _conversationContext;

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatMessage(
        isBot: true,
        text:
            'Bonjour ! Je suis Fleur votre assistant ProxiSearch. '
            'Que recherchez-vous aujourd\'hui au marché ?',
        cardStyle: _SuggestionCardStyle.product,
      ),
    );
    _loadWelcomeSuggestions();
  }

  Future<void> _loadWelcomeSuggestions() async {
    try {
      final produits = await _chatService.getProduitsAleatoires();
      if (!mounted || produits.isEmpty) return;
      setState(() {
        _messages[0] = _ChatMessage(
          isBot: true,
          text:
              'Bonjour ! Je suis Fleur votre assistant ProxiSearch. '
              'Que recherchez-vous aujourd\'hui au marché ?',
          produits: produits,
          cardStyle: _SuggestionCardStyle.product,
        );
      });
    } catch (_) {
      // L'accueil texte reste affiché si les suggestions ne chargent pas.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _estNouveauSujet(String question) {
    final q = question.toLowerCase().trim();
    const marqueurs = [
      'je veux',
      'je cherche',
      "j'aimerais",
      'montrez',
      'donnez-moi',
      'maintenant',
    ];
    if (marqueurs.any(q.startsWith)) return true;

    final contexte = _conversationContext;
    if (contexte?.requeteInitiale == null) return false;

    final initiale = contexte!.requeteInitiale!.toLowerCase();
    final motsQuestion = q
        .split(RegExp(r'[\s,.!?]+'))
        .where((m) => m.length > 2)
        .toSet();
    final motsInitiale = initiale
        .split(RegExp(r'[\s,.!?]+'))
        .where((m) => m.length > 2)
        .toSet();
    return motsQuestion.intersection(motsInitiale).isEmpty;
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final question = (overrideText ?? _controller.text).trim();
    if (question.isEmpty || _loading) return;

    final contexteEnvoi =
        _estNouveauSujet(question) ? null : _conversationContext;

    setState(() {
      _loading = true;
      _messages.add(_ChatMessage(isBot: false, text: question));
      if (overrideText == null) {
        _controller.clear();
      }
    });
    _scrollToBottom();

    try {
      final response = await _chatService.interroger(
        question: question,
        userId: widget.acheteurId,
        contexteConversation: contexteEnvoi,
      );
      if (!mounted) return;
      setState(() {
        if (response.estClarification) {
          _conversationContext = response.contexteConversation ??
              ConversationContext(
                requeteInitiale:
                    _conversationContext?.requeteInitiale ?? question,
                derniereClarification: response.reponse,
              );
        } else {
          _conversationContext = null;
        }
        _messages.add(
          _ChatMessage(
            isBot: true,
            text: response.reponse,
            produits: response.produits,
            sousCategories: response.sousCategories,
            cardStyle: _SuggestionCardStyle.stand,
            estClarification: response.estClarification,
          ),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is TimeoutException
          ? 'La réponse met trop de temps. Réessayez dans un instant.'
          : 'Désolé, une erreur est survenue : $e';
      setState(() {
        _messages.add(_ChatMessage(isBot: true, text: message));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _onSousCategorieTap(String categorie) {
    _sendMessage(categorie);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _openDrawerPage(Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openNavigation(ProduitRecommande produit) {
    if (!produit.peutNaviguer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ce stand n\'a pas encore verrouillé sa position sur le marché.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NavigationMapScreen(
          standId: produit.standId!,
          standNom: produit.nomStand.isNotEmpty ? produit.nomStand : produit.nom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: Drawer(
        backgroundColor: AppColors.cream,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: ProxiSearchTitle(fontSize: 22),
              ),
              ListTile(
                leading: const Icon(
                  Icons.smart_toy_outlined,
                  color: AppColors.oliveGreen,
                ),
                title: const Text('Market Guide'),
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.history, color: AppColors.oliveGreen),
                title: const Text('Historique'),
                onTap: () => _openDrawerPage(
                  SearchHistoryScreen(acheteurId: widget.acheteurId),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.recommend_outlined,
                  color: AppColors.oliveGreen,
                ),
                title: const Text('Recommandations'),
                onTap: () => _openDrawerPage(
                  RecommendationsScreen(acheteurId: widget.acheteurId),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.textGrey),
                title: const Text('Déconnexion'),
                onTap: () async {
                  await TokenStorage.clearSession();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const WelcomeScreen(),
                    ),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu, color: AppColors.darkOlive),
                    ),
                  ),
                  const Expanded(
                    child: Center(child: ProxiSearchTitle(fontSize: 20)),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.darkOlive,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_loading && index == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.oliveGreen,
                          ),
                        ),
                      ),
                    );
                  }
                  return _ChatBubble(
                    message: _messages[index],
                    onStandTap: _openNavigation,
                    onSousCategorieTap: _onSousCategorieTap,
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.lightGrey),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Posez une question...',
                  hintStyle: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.oliveGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.isBot,
    required this.text,
    this.produits = const [],
    this.sousCategories = const [],
    this.cardStyle = _SuggestionCardStyle.stand,
    this.estClarification = false,
  });

  final bool isBot;
  final String text;
  final List<ProduitRecommande> produits;
  final List<String> sousCategories;
  final _SuggestionCardStyle cardStyle;
  final bool estClarification;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.onStandTap,
    this.onSousCategorieTap,
  });

  final _ChatMessage message;
  final void Function(ProduitRecommande)? onStandTap;
  final void Function(String)? onSousCategorieTap;

  @override
  Widget build(BuildContext context) {
    if (message.isBot) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.oliveGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: AppColors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Market Guide',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: const TextStyle(color: AppColors.darkOlive, height: 1.4),
              ),
            ),
            if (message.estClarification && message.sousCategories.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.sousCategories.map((categorie) {
                  return ActionChip(
                    label: Text(categorie),
                    backgroundColor: AppColors.sageGreen.withValues(alpha: 0.35),
                    labelStyle: const TextStyle(
                      color: AppColors.oliveGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: AppColors.oliveGreen.withValues(alpha: 0.4),
                    ),
                    onPressed: onSousCategorieTap == null
                        ? null
                        : () => onSousCategorieTap!(categorie),
                  );
                }).toList(),
              ),
            ],
            if (message.produits.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.produits.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _ProductSuggestionCard(
                    produit: message.produits[i],
                    style: message.cardStyle,
                    onTap: message.cardStyle == _SuggestionCardStyle.stand
                        ? () => onStandTap?.call(message.produits[i])
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.oliveGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: AppColors.white, height: 1.4),
        ),
      ),
    );
  }
}

class _ProductSuggestionCard extends StatelessWidget {
  const _ProductSuggestionCard({
    required this.produit,
    this.style = _SuggestionCardStyle.stand,
    this.onTap,
  });

  final ProduitRecommande produit;
  final _SuggestionCardStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (style == _SuggestionCardStyle.product) {
      return Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
              height: 100,
              width: double.infinity,
              child: ProductImage(
                photoUrl: produit.photoUrl,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produit.nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.darkOlive,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    produit.prixFormate,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 180,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
            height: 100,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProductImage(photoUrl: produit.photoUrl, fit: BoxFit.cover),
                if (produit.peutNaviguer)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.oliveGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Y aller',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produit.nomStand.isNotEmpty ? produit.nomStand : produit.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  produit.nomCategorie.isNotEmpty
                      ? produit.nomCategorie
                      : produit.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    produit.nom,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.oliveGreen,
                      fontWeight: FontWeight.w600,
                    ),
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
}

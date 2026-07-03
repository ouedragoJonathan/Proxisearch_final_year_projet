import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

class ProductImageHelper {
  ProductImageHelper._();

  static final _picker = ImagePicker();

  static Future<String?> pickFromGallery(BuildContext context) async {
    final source = await showModalBottomSheet<_PhotoPickSource?>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Choisir une photo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.darkOlive,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.oliveGreen),
              title: const Text('Galerie du téléphone'),
              onTap: () => Navigator.pop(context, _PhotoPickSource.gallery),
            ),
            ListTile(
              leading:
                  const Icon(Icons.link, color: AppColors.oliveGreen),
              title: const Text('URL internet'),
              onTap: () => Navigator.pop(context, _PhotoPickSource.url),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == _PhotoPickSource.gallery) {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final mime = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      return 'data:image/$mime;base64,${base64Encode(bytes)}';
    }

    if (source == _PhotoPickSource.url) {
      return await _pickFromUrlDialog(context);
    }
    return null;
  }

  static Future<String?> _pickFromUrlDialog(BuildContext context) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('URL de la photo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://exemple.com/photo.jpg',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    return url;
  }

  static Uint8List? decodeDataUrl(String photoUrl) {
    if (!photoUrl.startsWith('data:')) return null;
    final comma = photoUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(photoUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.photoUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String photoUrl;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final emptyPlaceholder = placeholder ??
        Container(
          color: AppColors.lightGrey,
          child: const Icon(Icons.image_outlined),
        );

    if (photoUrl.isEmpty) return emptyPlaceholder;

    final bytes = ProductImageHelper.decodeDataUrl(photoUrl);
    if (bytes != null) {
      return Image.memory(bytes, fit: fit, gaplessPlayback: true);
    }

    return Image.network(
      photoUrl,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => placeholder ??
          Container(
            color: AppColors.lightGrey,
            child: const Icon(Icons.broken_image_outlined),
          ),
    );
  }
}

enum _PhotoPickSource { gallery, url }

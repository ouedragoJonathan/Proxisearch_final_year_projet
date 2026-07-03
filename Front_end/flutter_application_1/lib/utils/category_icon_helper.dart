import 'package:flutter/material.dart';

class CategoryIconHelper {
  CategoryIconHelper._();

  static const iconOptions = [
    ('category', Icons.category_outlined),
    ('dining', Icons.restaurant_outlined),
    ('apparel', Icons.checkroom_outlined),
    ('electronics', Icons.devices_outlined),
    ('business', Icons.work_outline),
    ('gaming', Icons.sports_esports_outlined),
    ('arts', Icons.palette_outlined),
    ('sparkles', Icons.auto_awesome_outlined),
    ('fruits', Icons.apple_outlined),
    ('vegetables', Icons.grass_outlined),
    ('dairy', Icons.water_drop_outlined),
    ('bakery', Icons.bakery_dining_outlined),
    ('herbs', Icons.spa_outlined),
  ];

  static IconData iconFor(String key) {
    return iconOptions
        .firstWhere(
          (e) => e.$1 == key,
          orElse: () => ('category', Icons.category_outlined),
        )
        .$2;
  }
}

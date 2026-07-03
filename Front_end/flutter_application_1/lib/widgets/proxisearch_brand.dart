import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProxiSearchTitle extends StatelessWidget {
  const ProxiSearchTitle({
    super.key,
    this.fontSize = 28,
    this.fontWeight = FontWeight.bold,
  });

  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.2,
        ),
        children: const [
          TextSpan(
            text: 'Proxi',
            style: TextStyle(color: AppColors.proxiGreen),
          ),
          TextSpan(
            text: 'Search',
            style: TextStyle(color: AppColors.searchOrange),
          ),
        ],
      ),
    );
  }
}

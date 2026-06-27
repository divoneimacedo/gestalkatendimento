import 'package:flutter/material.dart';

class GestalkBrand extends StatelessWidget {
  final double logoWidth;
  final bool showText;

  const GestalkBrand({
    super.key,
    this.logoWidth = 112,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: logoWidth,
          fit: BoxFit.contain,
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          const Text(
            'Gestalk',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

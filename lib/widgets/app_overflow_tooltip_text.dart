import 'package:flutter/material.dart';

class AppOverflowTooltipText extends StatelessWidget {
  final String text;
  final String? tooltip;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  const AppOverflowTooltipText(
    this.text, {
    super.key,
    this.tooltip,
    this.style,
    this.maxLines = 1,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? text,
      waitDuration: const Duration(milliseconds: 450),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

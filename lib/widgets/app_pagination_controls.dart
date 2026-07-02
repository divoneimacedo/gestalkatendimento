import 'package:flutter/material.dart';

class AppPaginationControls extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onFirst;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onLast;
  final Color color;
  final Color? disabledColor;

  const AppPaginationControls({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    this.color = Colors.white,
    this.disabledColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDisabledColor =
        disabledColor ?? color.withValues(alpha: 0.42);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: [
        Text(
          'Página $page de $totalPages | Total: $total',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Primeira página',
              onPressed: canGoPrevious ? onFirst : null,
              icon: const Icon(Icons.first_page),
              color: color,
              disabledColor: effectiveDisabledColor,
            ),
            IconButton(
              tooltip: 'Página anterior',
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
              color: color,
              disabledColor: effectiveDisabledColor,
            ),
            IconButton(
              tooltip: 'Próxima página',
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right),
              color: color,
              disabledColor: effectiveDisabledColor,
            ),
            IconButton(
              tooltip: 'Última página',
              onPressed: canGoNext ? onLast : null,
              icon: const Icon(Icons.last_page),
              color: color,
              disabledColor: effectiveDisabledColor,
            ),
          ],
        ),
      ],
    );
  }
}

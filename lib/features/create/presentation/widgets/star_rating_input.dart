import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Interactive 1–5 star rating with half-star precision.
/// Tap or drag horizontally; tap the current value again to clear.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  final double? value;
  final ValueChanged<double?> onChanged;
  final double size;

  void _handle(Offset localPosition) {
    final raw = (localPosition.dx / size).clamp(0.0, 5.0);
    // Round up to the nearest half star, minimum 0.5.
    var next = (raw * 2).ceil() / 2;
    if (next < 0.5) next = 0.5;
    if (next == value) {
      onChanged(null); // tap same value → clear
    } else {
      onChanged(next.clamp(0.5, 5.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    return GestureDetector(
      onTapUp: (d) => _handle(d.localPosition),
      onHorizontalDragUpdate: (d) {
        final raw = (d.localPosition.dx / size).clamp(0.0, 5.0);
        var next = (raw * 2).ceil() / 2;
        if (next < 0.5) next = 0.5;
        onChanged(next);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final starValue = i + 1;
          IconData icon;
          if (v >= starValue) {
            icon = Icons.star_rounded;
          } else if (v >= starValue - 0.5) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_border_rounded;
          }
          return Icon(
            icon,
            size: size,
            color: v >= starValue - 0.5
                ? AppColors.ratingStar
                : Theme.of(context).colorScheme.onSurfaceVariant,
          );
        }),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Consistent snackbars for feedback across the app.
abstract final class AppSnackbar {
  static void show(BuildContext context, String message) {
    _present(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
    );
  }

  static void error(BuildContext context, String message) {
    _present(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      background: AppColors.error,
    );
  }

  static void success(BuildContext context, String message) {
    _present(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      background: AppColors.success,
    );
  }

  static void undo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
  }) {
    _present(
      context,
      message: message,
      icon: Icons.undo_rounded,
      actionLabel: 'Undo',
      onAction: onUndo,
      duration: const Duration(seconds: 4),
    );
  }

  static void _present(
    BuildContext context, {
    required String message,
    required IconData icon,
    Color? background,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final onColor = background != null
        ? Colors.white
        : Theme.of(context).colorScheme.onInverseSurface;
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: background,
        content: Row(
          children: [
            Icon(icon, size: 20, color: onColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: onColor)),
            ),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: onColor,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_snackbar.dart';
import 'app_legal.dart';

/// Opens the support mailbox or copies it if the mail app cannot launch.
abstract final class ContactSupport {
  static Future<void> email(
    BuildContext context, {
    String subject = 'TasteWise support',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppLegal.supportEmail,
      queryParameters: {'subject': subject},
    );
    try {
      final opened = await launchUrl(uri);
      if (opened || !context.mounted) return;
    } catch (_) {}
    await copyEmail(context);
  }

  static Future<void> copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: AppLegal.supportEmail));
    if (context.mounted) {
      AppSnackbar.success(context, 'Copied ${AppLegal.supportEmail}');
    }
  }
}

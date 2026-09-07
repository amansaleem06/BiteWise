import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_legal.dart';
import '../../../../core/constants/contact_support.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Shown to the owner after they submit proof. Random users never see this.
class ClaimPendingCard extends StatelessWidget {
  const ClaimPendingCard({
    super.key,
    required this.restaurantName,
    required this.claimCode,
    this.mapsUrl,
  });

  final String restaurantName;
  final String claimCode;
  final String? mapsUrl;

  String get _mailBody {
    final maps = mapsUrl == null || mapsUrl!.isEmpty
        ? restaurantName
        : mapsUrl!;
    return 'I am claiming $restaurantName on TasteWise.\n\n'
        'Claim code: $claimCode\n'
        'Google listing: $maps\n\n'
        'I attached (or will reply with) a photo of my storefront sign '
        'or business license.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim submitted — not verified yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Anyone can look up a restaurant on Maps. We only mark '
              'Verified Owner after you send something a random diner '
              'would not have: this code plus a photo of your sign or license.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: claimCode));
                if (context.mounted) {
                  AppSnackbar.success(context, 'Copied $claimCode');
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your claim code',
                      style: theme.textTheme.labelSmall,
                    ),
                    Text(
                      claimCode,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Email $claimCode, the Google Maps link, and your proof photo '
              'to ${AppLegal.supportEmail}. We mark the page Verified Owner '
              'after that review. Until then you cannot post as the restaurant.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Email the claim to support',
              onPressed: () => ContactSupport.email(
                context,
                subject: 'Restaurant claim $claimCode',
                body: _mailBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

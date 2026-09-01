import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/page_identity_provider.dart';
import '../providers/restaurant_providers.dart';

/// Lets a page owner switch between restaurant identity and personal account.
class PageIdentityBar extends ConsumerWidget {
  const PageIdentityBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(pageIdentityProvider);
    if (!identity.hasPage) return const SizedBox.shrink();
    final page = ref.watch(restaurantControllerProvider(identity.ownedRestaurantId!))
        .valueOrNull;
    final pageName = page?.name ?? 'your restaurant';
    final asPage = identity.actingAsPage;

    return Material(
      color: asPage
          ? AppColors.primary.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              asPage ? Icons.storefront_rounded : Icons.person_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                asPage
                    ? (compact
                        ? 'As $pageName'
                        : 'Acting as $pageName — posts and comments use the restaurant name and logo, not your personal profile.')
                    : (compact
                        ? 'As your personal account'
                        : 'Acting as yourself. Switch to the restaurant page to post as the business.'),
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 13 : 13.5,
                  height: 1.3,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(pageIdentityProvider.notifier)
                  .setPreferPersonal(asPage),
              child: Text(asPage ? 'Use personal' : 'Use page'),
            ),
          ],
        ),
      ),
    );
  }
}

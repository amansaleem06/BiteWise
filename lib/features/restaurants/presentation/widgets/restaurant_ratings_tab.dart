import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../providers/restaurant_providers.dart';

final restaurantRatedPostsProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, restaurantId) async {
  final snap = await FirebaseFirestore.instance
      .collection('posts')
      .where('restaurantId', isEqualTo: restaurantId)
      .limit(60)
      .get();
  return snap.docs
      .map(PostModel.fromDoc)
      .where((p) => p.rating != null)
      .toList()
    ..sort((a, b) {
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      if (byRating != 0) return byRating;
      return (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0));
    });
});

final restaurantPendingVerifyProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, restaurantId) async {
  final snap = await FirebaseFirestore.instance
      .collection('posts')
      .where('restaurantId', isEqualTo: restaurantId)
      .limit(60)
      .get();
  return snap.docs
      .map(PostModel.fromDoc)
      .where((p) => !p.restaurantVerified)
      .toList()
    ..sort(
      (a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)),
    );
});

class RestaurantRatingsTab extends ConsumerWidget {
  const RestaurantRatingsTab({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider);
    final restaurant =
        ref.watch(restaurantControllerProvider(restaurantId)).valueOrNull;
    final isOwner =
        me != null && restaurant?.ownerId != null && me.uid == restaurant!.ownerId;
    final rated = ref.watch(restaurantRatedPostsProvider(restaurantId));
    final pending = isOwner
        ? ref.watch(restaurantPendingVerifyProvider(restaurantId))
        : const AsyncData(<Post>[]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (restaurant?.isClaimed ?? false)
                ? AppColors.accentLight
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            (restaurant?.isClaimed ?? false)
                ? 'Verified owner page — diner ratings on this listing stay here, including reviews posted before the claim.'
                : 'Unclaimed listing. These ratings come from TasteWise diners and are not moderated by a restaurant owner.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (isOwner) ...[
          Text(
            'Pending plates',
            style: GoogleFonts.fraunces(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          pending.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, __) => Text(
              'Couldn’t load pending plates.',
              style: theme.textTheme.bodyMedium,
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return Text(
                  'No unverified plates right now.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (final p in posts.take(12))
                    Card(
                      child: ListTile(
                        title: Text(p.authorName),
                        subtitle: Text(
                          [
                            if (p.rating != null)
                              '${p.rating!.toStringAsFixed(1)}★',
                            p.caption,
                          ].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(72, 36),
                          ),
                          onPressed: () async {
                            await ref
                                .read(feedRepositoryProvider)
                                .setRestaurantVerified(p.id, verified: true);
                            ref.invalidate(
                              restaurantPendingVerifyProvider(restaurantId),
                            );
                            ref.invalidate(
                              restaurantRatedPostsProvider(restaurantId),
                            );
                          },
                          child: const Text('Verify'),
                        ),
                        onTap: () => context.push(Routes.postPath(p.id)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          'Ratings wall',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        rated.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
          error: (e, _) => Text(
            'Ratings need a Firestore index, or try again.\n$e',
            style: theme.textTheme.bodySmall,
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return Text(
                'No ratings yet. Guests who rate a plate will appear here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: [
                for (final p in posts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        (p.rating ?? 0).toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(p.authorName)),
                        if (p.restaurantVerified)
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    subtitle: Text(
                      p.caption.isEmpty
                          ? (p.dishName ?? 'Rated plate')
                          : p.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => context.push(Routes.postPath(p.id)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

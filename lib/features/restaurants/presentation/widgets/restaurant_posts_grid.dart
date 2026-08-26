import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../feed/domain/entities/post.dart';
import '../providers/restaurant_providers.dart';

/// 3-column media grid of a restaurant's posts with infinite scroll.
class RestaurantPostsGrid extends ConsumerWidget {
  const RestaurantPostsGrid({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(restaurantPostsProvider(restaurantId));
    final controller = ref.read(restaurantPostsProvider(restaurantId).notifier);

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () =>
              ref.invalidate(restaurantPostsProvider(restaurantId)),
          child: const Text('Retry'),
        ),
      ),
      data: (feed) {
        if (feed.posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Official plates from this restaurant, plus guest photos tagged here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
              controller.loadMore();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 160),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: feed.posts.length,
            itemBuilder: (context, index) =>
                _GridTile(post: feed.posts[index]),
          ),
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final media = post.media.isNotEmpty ? post.media.first : null;
    return GestureDetector(
      onTap: () => context.push(Routes.postPath(post.id)),
      child: _buildTile(media),
    );
  }

  Widget _buildTile(PostMedia? media) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (media != null)
          CachedNetworkImage(
            imageUrl: media.type == MediaType.video
                ? (media.thumbnailUrl ?? media.url)
                : media.url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
            ),
            errorWidget: (_, __, ___) => const ColoredBox(
              color: AppColors.primaryLight,
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        if (post.postedAsRestaurant)
          const Positioned(
            top: 6,
            left: 6,
            child: Icon(
              Icons.storefront_rounded,
              size: 14,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
          const Positioned(
            top: 6,
            right: 6,
            child: Icon(
              Icons.collections_rounded,
              size: 16,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        if (media?.type == MediaType.video)
          const Positioned(
            top: 6,
            right: 6,
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 16,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
      ],
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../feed/domain/entities/post.dart';
import '../providers/profile_providers.dart';

/// Avatar + name + bio + stats row, shared by own and public profiles.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.user, this.trailing});

  final AppUser user;

  /// Follow button (public) or Edit button (own).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(user: user, radius: 40),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Posts', value: user.postCount),
                    _Stat(label: 'Followers', value: user.followerCount),
                    _Stat(label: 'Following', value: user.followingCount),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(user.displayName, style: theme.textTheme.titleLarge),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(user.bio!, style: theme.textTheme.bodyMedium),
          ],
          if (trailing != null) ...[
            const SizedBox(height: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.radius});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: user.photoUrl != null
          ? CachedNetworkImageProvider(user.photoUrl!)
          : null,
      child: user.photoUrl == null
          ? Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : '?',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.primaryDark),
            )
          : null,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(Formatters.compactCount(value),
            style: theme.textTheme.titleLarge,),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// 3-column grid of a user's posts with infinite scroll.
/// Rendered inside a scrollable parent via shrinkWrap-free sliver pattern:
/// used as the body of a NestedScrollView tab or a plain scaffold body.
class UserPostsGrid extends ConsumerWidget {
  const UserPostsGrid({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(uid));
    final controller = ref.read(userPostsProvider(uid).notifier);

    return postsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(userPostsProvider(uid)),
          child: const Text('Retry'),
        ),
      ),
      data: (feed) {
        if (feed.posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'No posts yet.',
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
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: feed.posts.length,
            itemBuilder: (context, i) => _GridTile(post: feed.posts[i]),
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
      child: media == null
          ? const ColoredBox(color: AppColors.primaryLight)
          : CachedNetworkImage(
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
    );
  }
}

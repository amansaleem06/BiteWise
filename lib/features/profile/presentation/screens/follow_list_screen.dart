import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../providers/profile_providers.dart';

enum FollowListKind { followers, following }

final followListProvider = FutureProvider.autoDispose
    .family<List<AppUser>, ({String uid, FollowListKind kind})>((ref, args) {
  final repo = ref.watch(userRepositoryProvider);
  return args.kind == FollowListKind.followers
      ? repo.fetchFollowers(args.uid)
      : repo.fetchFollowing(args.uid);
});

/// Instagram-style list of followers or following.
class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({
    super.key,
    required this.uid,
    required this.kind,
  });

  final String uid;
  final FollowListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        kind == FollowListKind.followers ? 'Followers' : 'Following';
    final async = ref.watch(followListProvider((uid: uid, kind: kind)));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (e, st) => AsyncErrorView(
          error: e,
          stackTrace: st,
          title: 'Couldn\'t load $title',
          onRetry: () =>
              ref.invalidate(followListProvider((uid: uid, kind: kind))),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                kind == FollowListKind.followers
                    ? 'No followers yet'
                    : 'Not following anyone yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final user = users[i];
              return ListTile(
                leading: CircleAvatar(
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
                              .titleSmall
                              ?.copyWith(color: AppColors.primaryDark),
                        )
                      : null,
                ),
                title: Text(user.displayName),
                subtitle: user.isBusiness
                    ? Text(user.businessName ?? 'Restaurant owner')
                    : null,
                onTap: () => context.push(Routes.userPath(user.uid)),
              );
            },
          );
        },
      ),
    );
  }
}

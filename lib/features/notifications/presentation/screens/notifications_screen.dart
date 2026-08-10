import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: stateAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(notificationsControllerProvider),
            child: const Text(AppStrings.retry),
          ),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('No notifications yet',
                        style: theme.textTheme.titleLarge,),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Likes, comments, and new followers show up here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(notificationsControllerProvider),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                  controller.loadMore();
                }
                return false;
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= state.items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return _NotificationTile(notification: state.items[i]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notification;

    return ListTile(
      tileColor: n.read
          ? null
          : AppColors.primaryLight.withValues(alpha: 0.25),
      leading: GestureDetector(
        onTap: () => context.push(Routes.userPath(n.actorId)),
        child: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          backgroundImage: n.actorPhotoUrl != null
              ? CachedNetworkImageProvider(n.actorPhotoUrl!)
              : null,
          child: n.actorPhotoUrl == null
              ? Text(
                  n.actorName.isNotEmpty ? n.actorName[0].toUpperCase() : '?',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: AppColors.primaryDark),
                )
              : null,
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: n.actorName, style: theme.textTheme.titleSmall),
            TextSpan(text: ' ${n.message}', style: theme.textTheme.bodyMedium),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        Formatters.relativeTime(n.createdAt),
        style: theme.textTheme.bodySmall,
      ),
      trailing: n.postMediaUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: CachedNetworkImage(
                imageUrl: n.postMediaUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            )
          : null,
      onTap: () {
        if (n.type == NotificationType.reservation) {
          context.push(Routes.reservations);
        } else if (n.postId != null) {
          context.push(Routes.postPath(n.postId!));
        } else {
          context.push(Routes.userPath(n.actorId));
        }
      },
    );
  }
}

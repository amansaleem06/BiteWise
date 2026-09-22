import '../../../safety/presentation/providers/safety_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/push_notification_service.dart';
import '../../data/repositories/firestore_notification_repository.dart';
import '../../domain/entities/app_notification.dart';

final notificationRepositoryProvider =
    Provider<FirestoreNotificationRepository>(
  (ref) => FirestoreNotificationRepository(),
);

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(),
);

/// Drives the bell badge.
final hasUnreadNotificationsProvider = StreamProvider.autoDispose<bool>(
  (ref) async* {
    final blocked = await ref.watch(blockedUserIdsProvider.future);
    yield* ref.read(notificationRepositoryProvider).hasUnread(blocked: blocked);
  },
);

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<AppNotification> items;
  final Object? cursor;
  final bool hasMore;
  final bool isLoadingMore;

  NotificationsState copyWith({
    List<AppNotification>? items,
    Object? cursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        cursor: cursor ?? this.cursor,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

class NotificationsController
    extends AutoDisposeAsyncNotifier<NotificationsState> {
  FirestoreNotificationRepository get _repo =>
      ref.read(notificationRepositoryProvider);

  @override
  Future<NotificationsState> build() async {
    await ref.watch(blockedUserIdsProvider.future);
    final page = await _repo.fetch();
    // Opening the screen clears the badge.
    Future<void>.microtask(_repo.markAllRead);
    return NotificationsState(
      items: _visible(page.items),
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }

  List<AppNotification> _visible(List<AppNotification> items) {
    final ids = ref.read(blockedUserIdsProvider).valueOrNull;
    if (ids == null) return [];
    return items.where((n) => !ids.contains(n.actorId)).toList();
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.fetch(cursor: current.cursor);
      state = AsyncData(
        current.copyWith(
          items: _visible([...current.items, ...page.items]),
          cursor: page.cursor ?? current.cursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final notificationsControllerProvider = AsyncNotifierProvider.autoDispose<
    NotificationsController, NotificationsState>(NotificationsController.new);

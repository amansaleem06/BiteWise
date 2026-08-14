import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../domain/entities/chat.dart';
import '../providers/chat_providers.dart';

/// Messages tab: live conversation list + new-message flow.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chatsAsync = ref.watch(chatsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Messages',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.8,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            tooltip: 'New message',
            onPressed: () => _NewChatSheet.show(context),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: chatsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (error, stack) => AsyncErrorView(
          error: error,
          stackTrace: stack,
          title: 'Couldn\'t load messages',
          onRetry: () => ref.invalidate(chatsProvider),
        ),
        data: (chats) {
          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('No messages yet', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Start a conversation with a fellow food lover.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => _NewChatSheet.show(context),
                      icon: const Icon(Icons.edit_square, size: 18),
                      label: const Text('New message'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, i) => _ChatTile(chat: chats[i]),
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = chat.hasUnread;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryLight,
        backgroundImage: chat.peer.photoUrl != null
            ? CachedNetworkImageProvider(chat.peer.photoUrl!)
            : null,
        child: chat.peer.photoUrl == null
            ? Text(
                chat.peer.name.isNotEmpty
                    ? chat.peer.name[0].toUpperCase()
                    : '?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppColors.primaryDark),
              )
            : null,
      ),
      title: Text(
        chat.peer.name,
        style: unread
            ? theme.textTheme.titleSmall
            : theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        chat.isPeerTyping ? 'typing…' : (chat.lastMessageText ?? ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: chat.isPeerTyping
              ? AppColors.accent
              : unread
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.relativeTime(chat.lastMessageAt),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          if (unread)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: () => context.push(Routes.chatPath(chat.id)),
    );
  }
}

/// User picker for starting a new conversation (reuses explore search).
class _NewChatSheet extends ConsumerStatefulWidget {
  const _NewChatSheet();

  static void show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _NewChatSheet(),
      );

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(searchResultsProvider(_query));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search people…',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (r) => ListView(
                  controller: scrollController,
                  children: [
                    if (_query.trim().length < 2)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'Search for someone to message.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    for (final user in r.users)
                      ListTile(
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
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppColors.primaryDark,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(user.displayName),
                        onTap: () async {
                          final chatId = await ref
                              .read(chatRepositoryProvider)
                              .openChatWith(
                                peerUid: user.uid,
                                peerName: user.displayName,
                                peerPhotoUrl: user.photoUrl,
                              );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            context.push(Routes.chatPath(chatId));
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

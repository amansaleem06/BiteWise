import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/chat_providers.dart';
import '../widgets/message_bubble.dart';

/// One-to-one conversation.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _picker = ImagePicker();
  bool _sendingImage = false;

  @override
  void initState() {
    super.initState();
    // Opening the conversation clears its unread state.
    Future<void>.microtask(
      () => ref.read(chatActionsProvider).markRead(widget.chatId),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref.read(chatActionsProvider).sendText(widget.chatId, text);
  }

  Future<void> _sendImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (image == null) return;
    setState(() => _sendingImage = true);
    try {
      await ref.read(chatActionsProvider).sendImage(widget.chatId, image);
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider)?.uid ?? '';
    final chat = ref.watch(chatProvider(widget.chatId)).valueOrNull;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

    // New incoming messages while the screen is open → mark read.
    ref.listen(chatMessagesProvider(widget.chatId), (_, next) {
      final latest = next.valueOrNull?.firstOrNull;
      if (latest != null && latest.senderId != me) {
        ref.read(chatActionsProvider).markRead(widget.chatId);
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: chat == null
            ? const SizedBox.shrink()
            : InkWell(
                onTap: () => context.push(Routes.userPath(chat.peer.uid)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: chat.peer.photoUrl != null
                          ? CachedNetworkImageProvider(chat.peer.photoUrl!)
                          : null,
                      child: chat.peer.photoUrl == null
                          ? Text(
                              chat.peer.name.isNotEmpty
                                  ? chat.peer.name[0].toUpperCase()
                                  : '?',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.primaryDark,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(chat.peer.name,
                            style: theme.textTheme.titleMedium,),
                        if (chat.isPeerTyping)
                          Text(
                            'typing…',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.accent),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              error: (_, __) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(chatMessagesProvider(widget.chatId)),
                  child: const Text('Couldn\'t load messages — retry'),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hi 👋',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                // Newest first + reversed ListView keeps scroll pinned to
                // the bottom as messages arrive.
                final myLatestIndex =
                    messages.indexWhere((m) => m.senderId == me);
                return ListView.builder(
                  reverse: true,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final message = messages[i];
                    final isMine = message.senderId == me;
                    final isRead = chat?.peerLastReadAt != null &&
                        message.createdAt != null &&
                        !message.createdAt!.isAfter(chat!.peerLastReadAt!);
                    return MessageBubble(
                      message: message,
                      isMine: isMine,
                      showReadReceipt: isMine && i == myLatestIndex,
                      isRead: isRead,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: _sendingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_outlined),
                    onPressed: _sendingImage ? null : _sendImage,
                    tooltip: 'Send photo',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        isDense: true,
                      ),
                      onChanged: (_) =>
                          ref.read(chatActionsProvider).typing(widget.chatId),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: _sendText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

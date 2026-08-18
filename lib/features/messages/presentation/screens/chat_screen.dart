import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
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
  final _recorder = AudioRecorder();
  bool _sendingImage = false;
  bool _recording = false;
  bool _sendingAudio = false;
  DateTime? _recordStartedAt;
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(chatActionsProvider).markRead(widget.chatId),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _input.dispose();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref.read(chatActionsProvider).sendText(widget.chatId, text);
  }

  Future<void> _pickAndSendImage() async {
    if (_sendingImage) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 95,
    );
    if (image == null) return;
    setState(() => _sendingImage = true);
    try {
      await ref.read(chatActionsProvider).sendImage(widget.chatId, image);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, userMessageFrom(e));
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  Future<void> _toggleRecord() async {
    if (_sendingAudio) return;
    if (_recording) {
      await _stopAndSend();
      return;
    }
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      if (mounted) {
        AppSnackbar.error(
          context,
          'Microphone access is needed for voice notes.',
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _recordStartedAt = DateTime.now();
    _elapsed = Duration.zero;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final start = _recordStartedAt;
      if (start == null || !mounted) return;
      setState(() => _elapsed = DateTime.now().difference(start));
    });
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _cancelRecord() async {
    _tick?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    if (mounted) {
      setState(() {
        _recording = false;
        _elapsed = Duration.zero;
      });
    }
  }

  Future<void> _stopAndSend() async {
    _tick?.cancel();
    final path = await _recorder.stop();
    final durationMs = _elapsed.inMilliseconds;
    setState(() {
      _recording = false;
      _sendingAudio = true;
    });
    try {
      if (path != null && durationMs >= 400) {
        await ref.read(chatActionsProvider).sendAudio(
              widget.chatId,
              filePath: path,
              durationMs: durationMs,
            );
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, userMessageFrom(e));
    } finally {
      if (mounted) {
        setState(() {
          _sendingAudio = false;
          _elapsed = Duration.zero;
        });
      }
    }
  }

  String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider)?.uid ?? '';
    final chat = ref.watch(chatProvider(widget.chatId)).valueOrNull;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat.peer.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (chat.isPeerTyping)
                            Text(
                              'typing…',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.accent),
                            ),
                        ],
                      ),
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
              child: _recording
                  ? Row(
                      children: [
                        IconButton(
                          tooltip: 'Cancel',
                          onPressed: _cancelRecord,
                          icon: const Icon(Icons.close_rounded),
                        ),
                        Expanded(
                          child: Text(
                            'Recording  ${_clock(_elapsed)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Send voice note',
                          onPressed: _stopAndSend,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(
                          icon: _sendingImage
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_outlined),
                          onPressed: _sendingImage ? null : _pickAndSendImage,
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
                            onChanged: (_) => ref
                                .read(chatActionsProvider)
                                .typing(widget.chatId),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Voice note',
                          onPressed: _sendingAudio ? null : _toggleRecord,
                          icon: _sendingAudio
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.mic_none_rounded),
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

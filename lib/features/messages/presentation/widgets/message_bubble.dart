import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showReadReceipt = false,
    this.isRead = false,
  });

  final Message message;
  final bool isMine;

  /// Only shown under the sender's latest message.
  final bool showReadReceipt;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.xs),
      bottomRight: Radius.circular(isMine ? AppRadius.xs : AppRadius.lg),
    );

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: isMine ? 64 : AppSpacing.md,
            right: isMine ? AppSpacing.md : 64,
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs,
          ),
          child: switch (message.type) {
            MessageType.image => ClipRRect(
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 240,
                    maxHeight: 320,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: message.imageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 240,
                      height: 240,
                      color: AppColors.primaryLight.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            MessageType.audio => _VoiceNoteBubble(
                url: message.audioUrl ?? '',
                durationMs: message.durationMs ?? 0,
                isMine: isMine,
                radius: radius,
              ),
            MessageType.text => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isMine ? AppColors.primary : theme.colorScheme.surface,
                  borderRadius: radius,
                  border: isMine
                      ? null
                      : Border.all(color: theme.colorScheme.outline),
                ),
                child: Text(
                  message.text ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isMine ? AppColors.cream : null,
                  ),
                ),
              ),
          },
        ),
        if (showReadReceipt)
          Padding(
            padding: const EdgeInsets.only(
              right: AppSpacing.md,
              bottom: AppSpacing.xxs,
            ),
            child: Text(
              isRead
                  ? 'Seen'
                  : 'Sent · ${Formatters.relativeTime(message.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _VoiceNoteBubble extends StatefulWidget {
  const _VoiceNoteBubble({
    required this.url,
    required this.durationMs,
    required this.isMine,
    required this.radius,
  });

  final String url;
  final int durationMs;
  final bool isMine;
  final BorderRadius radius;

  @override
  State<_VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<_VoiceNoteBubble> {
  final _player = AudioPlayer();
  var _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.durationMs);
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted || d == Duration.zero) return;
      setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.url.isEmpty) return;
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_position > Duration.zero) {
      await _player.resume();
      return;
    }
    await _player.play(UrlSource(widget.url));
  }

  String _fmt(Duration d) {
    final total = d.inSeconds.clamp(0, 99 * 60);
    final m = (total ~/ 60).toString().padLeft(1, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _duration.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    final fg = widget.isMine ? AppColors.cream : AppColors.primary;
    final bg = widget.isMine ? AppColors.primary : theme.colorScheme.surface;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: widget.radius,
        border: widget.isMine
            ? null
            : Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: fg,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: fg.withValues(alpha: 0.22),
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _playing ? _fmt(_position) : _fmt(_duration),
                  style: theme.textTheme.labelSmall?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

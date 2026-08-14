import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../messages/presentation/providers/chat_providers.dart';
import '../providers/feed_providers.dart';

String postShareLink(String postId) => 'https://tastewise.app/post/$postId';

/// In-app share: copy link or send the post to another TasteWise user.
class SharePostSheet extends ConsumerStatefulWidget {
  const SharePostSheet({
    super.key,
    required this.postId,
    required this.restaurantName,
    this.caption = '',
  });

  final String postId;
  final String restaurantName;
  final String caption;

  static Future<void> show(
    BuildContext context, {
    required String postId,
    required String restaurantName,
    String caption = '',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SharePostSheet(
        postId: postId,
        restaurantName: restaurantName,
        caption: caption,
      ),
    );
  }

  @override
  ConsumerState<SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends ConsumerState<SharePostSheet> {
  String _query = '';
  String? _sendingUid;

  String get _link => postShareLink(widget.postId);

  String get _message {
    final place = widget.restaurantName.trim().isEmpty
        ? 'this bite'
        : widget.restaurantName.trim();
    final caption = widget.caption.trim();
    if (caption.isEmpty) {
      return 'Shared a TasteWise post from $place\n$_link';
    }
    return 'Shared a TasteWise post from $place\n$caption\n$_link';
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _link));
    await ref.read(feedRepositoryProvider).recordShare(widget.postId);
    if (!mounted) return;
    Navigator.pop(context);
    AppSnackbar.success(context, 'Link copied');
  }

  Future<void> _sendToUser({
    required String uid,
    required String name,
    String? photoUrl,
  }) async {
    if (_sendingUid != null) return;
    setState(() => _sendingUid = uid);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final chatId = await repo.openChatWith(
        peerUid: uid,
        peerName: name,
        peerPhotoUrl: photoUrl,
      );
      await repo.sendText(chatId, _message);
      await ref.read(feedRepositoryProvider).recordShare(widget.postId);
      if (!mounted) return;
      Navigator.pop(context);
      context.push(Routes.chatPath(chatId));
      AppSnackbar.success(context, 'Sent to $name');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingUid = null);
      AppSnackbar.error(context, 'Couldn’t send. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider)?.uid;
    final results = ref.watch(searchResultsProvider(_query));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Share post',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.link_rounded, color: AppColors.primary),
                ),
                title: const Text('Copy link'),
                subtitle: Text(
                  _link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: _copyLink,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Send to a TasteWise user…',
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
                  error: (_, __) => Center(
                    child: Text(
                      'Search failed.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  data: (r) {
                    if (_query.trim().length < 2) {
                      return Center(
                        child: Text(
                          'Search someone to send this post in Messages.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final users =
                        r.users.where((u) => u.uid != me).toList(growable: false);
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'No people found.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final user = users[i];
                        final busy = _sendingUid == user.uid;
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
                                  )
                                : null,
                          ),
                          title: Text(user.displayName),
                          trailing: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          onTap: busy
                              ? null
                              : () => _sendToUser(
                                    uid: user.uid,
                                    name: user.displayName,
                                    photoUrl: user.photoUrl,
                                  ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

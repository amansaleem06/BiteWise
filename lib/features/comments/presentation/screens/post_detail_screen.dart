import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/feed_shimmer.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../feed/presentation/widgets/share_post_sheet.dart';
import '../providers/comment_providers.dart';
import '../widgets/comment_tile.dart';

/// Full post view with its conversation.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ok = await ref
        .read(commentsControllerProvider(widget.postId).notifier)
        .send(_input.text);
    if (ok) {
      _input.clear();
      _inputFocus.unfocus();
    } else if (mounted && _input.text.trim().isNotEmpty) {
      AppSnackbar.error(context, AppStrings.genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync =
        ref.watch(commentsControllerProvider(widget.postId));
    final commentsController =
        ref.read(commentsControllerProvider(widget.postId).notifier);
    final me = ref.watch(currentUserProvider);

    final replyToName = commentsAsync.valueOrNull?.replyToName;
    final isSending = commentsAsync.valueOrNull?.isSending ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: postAsync.when(
              loading: () => const FeedShimmer(itemCount: 1),
              error: (_, __) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Post unavailable', style: theme.textTheme.titleLarge),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(postDetailProvider(widget.postId)),
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
              data: (post) => NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                    commentsController.loadMore();
                  }
                  return false;
                },
                child: ListView(
                  children: [
                    PostCard(
                      post: post,
                      onLike: () => ref
                          .read(postDetailProvider(widget.postId).notifier)
                          .toggleLike(),
                      onBookmark: () => ref
                          .read(postDetailProvider(widget.postId).notifier)
                          .toggleBookmark(),
                      onRepost: () async {
                        final next = !post.isRepostedByMe;
                        await ref
                            .read(feedRepositoryProvider)
                            .setReposted(post.id, reposted: next);
                        ref.invalidate(postDetailProvider(widget.postId));
                      },
                      onShare: () => SharePostSheet.show(
                        context,
                        postId: post.id,
                        restaurantName: post.restaurantName,
                        caption: post.caption,
                      ),
                      onComment: _inputFocus.requestFocus,
                      onAuthorTap: () =>
                          context.push(Routes.userPath(post.authorId)),
                      onRestaurantTap: () => context.push(
                        Routes.restaurantPath(post.restaurantId),
                      ),
                    ),
                    const Divider(),
                    commentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                      error: (_, __) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: TextButton(
                            onPressed: () => ref.invalidate(
                              commentsControllerProvider(widget.postId),
                            ),
                            child: const Text('Couldn\'t load comments — retry'),
                          ),
                        ),
                      ),
                      data: (comments) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (comments.comments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Center(
                                child: Text(
                                  'No comments yet. Start the conversation.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          for (final comment in comments.comments)
                            CommentTile(
                              comment: comment,
                              isMine: comment.authorId == me?.uid,
                              onReply: () {
                                commentsController
                                    .startReply(comment.authorName);
                                _inputFocus.requestFocus();
                              },
                              onDelete: () =>
                                  commentsController.delete(comment.id),
                            ),
                          if (comments.isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Input bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outline, width: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyToName != null)
                    Row(
                      children: [
                        Text(
                          'Replying to @$replyToName',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: commentsController.cancelReply,
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _inputFocus,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment…',
                            counterText: '',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(
                        icon: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: AppColors.primary,
                              ),
                        onPressed: isSending ? null : _send,
                      ),
                    ],
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

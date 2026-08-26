import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/domain/entities/post.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../restaurants/presentation/providers/page_identity_provider.dart';
import '../../data/repositories/firestore_comment_repository.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => FirestoreCommentRepository(),
);

/// Single post for the detail screen with working like/bookmark.
class PostDetailController
    extends AutoDisposeFamilyAsyncNotifier<Post, String> {
  @override
  Future<Post> build(String postId) =>
      ref.read(feedRepositoryProvider).getPostById(postId);

  Future<void> toggleLike() => _toggle(
        apply: (p) => p.copyWith(
          isLikedByMe: !p.isLikedByMe,
          likeCount: p.likeCount + (p.isLikedByMe ? -1 : 1),
        ),
        write: (p) => ref
            .read(feedRepositoryProvider)
            .setLiked(arg, liked: !p.isLikedByMe),
      );

  Future<void> toggleBookmark() => _toggle(
        apply: (p) => p.copyWith(isBookmarkedByMe: !p.isBookmarkedByMe),
        write: (p) => ref
            .read(feedRepositoryProvider)
            .setBookmarked(arg, bookmarked: !p.isBookmarkedByMe),
      );

  Future<void> toggleRepost() => _toggle(
        apply: (p) => p.copyWith(isRepostedByMe: !p.isRepostedByMe),
        write: (p) => ref
            .read(feedRepositoryProvider)
            .setReposted(arg, reposted: !p.isRepostedByMe),
      );

  void adjustCommentCount(int delta) {
    final post = state.valueOrNull;
    if (post == null) return;
    state = AsyncData(post.copyWith(commentCount: post.commentCount + delta));
  }

  Future<void> _toggle({
    required Post Function(Post) apply,
    required Future<void> Function(Post original) write,
  }) async {
    final original = state.valueOrNull;
    if (original == null) return;
    state = AsyncData(apply(original));
    try {
      await write(original);
    } catch (_) {
      state = AsyncData(original);
    }
  }
}

final postDetailProvider = AsyncNotifierProvider.autoDispose
    .family<PostDetailController, Post, String>(PostDetailController.new);

class CommentsState {
  const CommentsState({
    this.comments = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isSending = false,
    this.replyToName,
  });

  final List<Comment> comments;
  final Object? cursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSending;

  /// Set when the user taps "Reply" on a comment.
  final String? replyToName;

  CommentsState copyWith({
    List<Comment>? comments,
    Object? cursor,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isSending,
    String? replyToName,
    bool clearReplyTo = false,
  }) =>
      CommentsState(
        comments: comments ?? this.comments,
        cursor: cursor ?? this.cursor,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isSending: isSending ?? this.isSending,
        replyToName: clearReplyTo ? null : (replyToName ?? this.replyToName),
      );
}

class CommentsController
    extends AutoDisposeFamilyAsyncNotifier<CommentsState, String> {
  CommentRepository get _repo => ref.read(commentRepositoryProvider);

  @override
  Future<CommentsState> build(String postId) async {
    final page = await _repo.fetchComments(postId);
    return CommentsState(
      comments: page.comments,
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.fetchComments(arg, cursor: current.cursor);
      state = AsyncData(
        current.copyWith(
          comments: [...current.comments, ...page.comments],
          cursor: page.cursor ?? current.cursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  void startReply(String authorName) =>
      state = AsyncData((state.valueOrNull ?? const CommentsState())
          .copyWith(replyToName: authorName),);

  void cancelReply() => state = AsyncData(
      (state.valueOrNull ?? const CommentsState()).copyWith(clearReplyTo: true),);

  /// Returns true on success.
  Future<bool> send(String text) async {
    final current = state.valueOrNull;
    if (current == null || current.isSending || text.trim().isEmpty) {
      return false;
    }
    state = AsyncData(current.copyWith(isSending: true));
    try {
      final comment = await _repo.addComment(
        postId: arg,
        text: text,
        replyToName: current.replyToName,
        asRestaurantPage: ref.read(pageIdentityProvider).actingAsPage,
      );
      state = AsyncData(
        current.copyWith(
          comments: [...current.comments, comment],
          isSending: false,
          clearReplyTo: true,
        ),
      );
      ref.read(postDetailProvider(arg).notifier).adjustCommentCount(1);
      ref.invalidate(feedControllerProvider(FeedTab.forYou));
      ref.invalidate(feedControllerProvider(FeedTab.following));
      return true;
    } catch (_) {
      state = AsyncData(current.copyWith(isSending: false));
      return false;
    }
  }

  Future<void> delete(String commentId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final removed = [...current.comments]
      ..removeWhere((c) => c.id == commentId);
    state = AsyncData(current.copyWith(comments: removed));
    try {
      await _repo.deleteComment(postId: arg, commentId: commentId);
      ref.read(postDetailProvider(arg).notifier).adjustCommentCount(-1);
    } catch (_) {
      state = AsyncData(current); // roll back
    }
  }
}

final commentsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsController, CommentsState, String>(CommentsController.new);

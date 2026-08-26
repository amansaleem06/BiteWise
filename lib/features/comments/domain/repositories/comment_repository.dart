import '../entities/comment.dart';

class CommentPage {
  const CommentPage({
    required this.comments,
    this.cursor,
    required this.hasMore,
  });

  final List<Comment> comments;
  final Object? cursor;
  final bool hasMore;
}

abstract interface class CommentRepository {
  /// Oldest first (natural reading order for conversations).
  Future<CommentPage> fetchComments(String postId, {Object? cursor, int limit});

  Future<Comment> addComment({
    required String postId,
    required String text,
    String? replyToName,
    bool asRestaurantPage = false,
  });

  /// Author-only; also decrements the post's comment counter.
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  });
}

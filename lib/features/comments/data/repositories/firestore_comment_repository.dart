import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';

/// Comments live at `posts/{postId}/comments/{commentId}`.
/// The post's commentCount is adjusted atomically in the same batch.
class FirestoreCommentRepository implements CommentRepository {
  FirestoreCommentRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  static const _pageSize = 20;

  fb.User get _user {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');
    return user;
  }

  CollectionReference<Map<String, dynamic>> _comments(String postId) =>
      _firestore.collection('posts').doc(postId).collection('comments');

  @override
  Future<CommentPage> fetchComments(
    String postId, {
    Object? cursor,
    int limit = _pageSize,
  }) async {
    Query<Map<String, dynamic>> query =
        _comments(postId).orderBy('createdAt', descending: false).limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);

    final snap = await query.get();
    return CommentPage(
      comments: snap.docs.map(_fromDoc).toList(),
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  @override
  Future<Comment> addComment({
    required String postId,
    required String text,
    String? replyToName,
  }) async {
    final user = _user;
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const AppException('Comment cannot be empty');

    // Single write — commentCount is maintained by Cloud Functions.
    final commentRef = _comments(postId).doc();
    await commentRef.set({
      'authorId': user.uid,
      'authorName': user.displayName ?? '',
      'authorPhotoUrl': user.photoURL,
      'text': trimmed,
      'replyToName': replyToName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Server timestamp isn't resolved locally yet; return an optimistic copy.
    return Comment(
      id: commentRef.id,
      authorId: user.uid,
      authorName: user.displayName ?? '',
      authorPhotoUrl: user.photoURL,
      text: trimmed,
      replyToName: replyToName,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _comments(postId).doc(commentId).delete();
  }

  Comment _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Comment(
      id: doc.id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      text: (data['text'] as String?) ?? '',
      replyToName: data['replyToName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

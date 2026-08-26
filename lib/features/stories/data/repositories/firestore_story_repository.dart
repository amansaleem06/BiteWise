import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';

class FirestoreStoryRepository implements StoryRepository {
  FirestoreStoryRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    MediaUploadService? uploads,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _uploads = uploads ?? MediaUploadService();

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final MediaUploadService _uploads;

  CollectionReference<Map<String, dynamic>> get _stories =>
      _firestore.collection('stories');

  fb.User get _user {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');
    return user;
  }

  String get _uid => _user.uid;

  CollectionReference<Map<String, dynamic>> _likes(String storyId) =>
      _stories.doc(storyId).collection('likes');

  CollectionReference<Map<String, dynamic>> _comments(String storyId) =>
      _stories.doc(storyId).collection('comments');

  @override
  Stream<List<StoryRing>> watchRings() {
    return _stories
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: true)
        .limit(80)
        .snapshots()
        .map(_ringsFrom);
  }

  String _ringKey(Story story) => story.postedAsRestaurant
      ? 'r:${story.asRestaurantId}'
      : 'u:${story.authorId}';

  List<StoryRing> _ringsFrom(QuerySnapshot<Map<String, dynamic>> snap) {
    final byRing = <String, List<Story>>{};
    final meta = <String, Story>{};
    for (final doc in snap.docs) {
      final story = _fromDoc(doc);
      if (!story.isLive) continue;
      final key = _ringKey(story);
      byRing.putIfAbsent(key, () => []).add(story);
      meta.putIfAbsent(key, () => story);
    }
    final rings = byRing.entries.map((e) {
      final stories = [...e.value]
        ..sort(
          (a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
        );
      final head = meta[e.key]!;
      return StoryRing(
        authorId: head.authorId,
        authorName: head.authorName,
        authorPhotoUrl: head.authorPhotoUrl,
        asRestaurantId: head.asRestaurantId,
        stories: stories,
      );
    }).toList()
      ..sort((a, b) {
        final at = a.latestAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.latestAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    return rings;
  }

  Story _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Story(
      id: doc.id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      asRestaurantId: data['asRestaurantId'] as String?,
      mediaUrl: (data['mediaUrl'] as String?) ?? '',
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<void> publish(XFile image, {bool asRestaurant = false}) async {
    final user = _user;
    final url = await _uploads.uploadStoryImage(uid: user.uid, file: image);
    final now = DateTime.now();

    var authorName = user.displayName ?? '';
    String? authorPhotoUrl = user.photoURL;
    String? asRestaurantId;
    if (asRestaurant) {
      final userSnap =
          await _firestore.collection('users').doc(user.uid).get();
      final owned = userSnap.data()?['ownedRestaurantId'] as String?;
      if (owned != null && owned.isNotEmpty) {
        final rest =
            await _firestore.collection('restaurants').doc(owned).get();
        final data = rest.data();
        final pageName = (data?['name'] as String?)?.trim();
        if (pageName != null && pageName.isNotEmpty) {
          authorName = pageName;
        }
        authorPhotoUrl = data?['logoUrl'] as String? ?? authorPhotoUrl;
        asRestaurantId = owned;
      }
    }

    await _stories.add({
      'authorId': user.uid,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'mediaUrl': url,
      'likeCount': 0,
      'commentCount': 0,
      if (asRestaurantId != null) 'asRestaurantId': asRestaurantId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
    });
  }

  @override
  Future<void> delete(String storyId) async {
    await _stories.doc(storyId).delete();
  }

  @override
  Future<bool> isLiked(String storyId) async {
    final snap = await _likes(storyId).doc(_uid).get();
    return snap.exists;
  }

  @override
  Future<void> setLiked(String storyId, {required bool liked}) async {
    final likeRef = _likes(storyId).doc(_uid);
    final storyRef = _stories.doc(storyId);
    final batch = _firestore.batch();
    if (liked) {
      batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.update(storyRef, {'likeCount': FieldValue.increment(1)});
    } else {
      batch.delete(likeRef);
      batch.update(storyRef, {'likeCount': FieldValue.increment(-1)});
    }
    await batch.commit();
  }

  @override
  Stream<List<StoryComment>> watchComments(String storyId) {
    return _comments(storyId)
        .orderBy('createdAt', descending: false)
        .limit(80)
        .snapshots()
        .map((snap) => snap.docs.map(_commentFromDoc).toList());
  }

  @override
  Future<void> addComment(String storyId, String text) async {
    final user = _user;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const AppException('Comment cannot be empty');
    }
    if (trimmed.length > 280) {
      throw const AppException('Keep comments under 280 characters');
    }

    var authorName = user.displayName ?? '';
    String? authorPhotoUrl = user.photoURL;
    final storySnap = await _stories.doc(storyId).get();
    final story = storySnap.data();
    final asRestaurantId = story?['asRestaurantId'] as String?;
    if (asRestaurantId != null &&
        asRestaurantId.isNotEmpty &&
        story?['authorId'] == user.uid) {
      final rest =
          await _firestore.collection('restaurants').doc(asRestaurantId).get();
      final pageName = (rest.data()?['name'] as String?)?.trim();
      if (pageName != null && pageName.isNotEmpty) authorName = pageName;
      authorPhotoUrl = rest.data()?['logoUrl'] as String? ?? authorPhotoUrl;
    }

    final commentRef = _comments(storyId).doc();
    final batch = _firestore.batch()
      ..set(commentRef, {
        'authorId': user.uid,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(_stories.doc(storyId), {
        'commentCount': FieldValue.increment(1),
      });
    await batch.commit();
  }

  StoryComment _commentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StoryComment(
      id: doc.id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      text: (data['text'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

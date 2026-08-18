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

  @override
  Stream<List<StoryRing>> watchRings() {
    return _stories
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: true)
        .limit(80)
        .snapshots()
        .map(_ringsFrom);
  }

  List<StoryRing> _ringsFrom(QuerySnapshot<Map<String, dynamic>> snap) {
    final byAuthor = <String, List<Story>>{};
    final meta = <String, Story>{};
    for (final doc in snap.docs) {
      final story = _fromDoc(doc);
      if (!story.isLive) continue;
      byAuthor.putIfAbsent(story.authorId, () => []).add(story);
      meta.putIfAbsent(story.authorId, () => story);
    }
    final rings = byAuthor.entries.map((e) {
      final stories = [...e.value]
        ..sort(
          (a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
        );
      final head = meta[e.key]!;
      return StoryRing(
        authorId: e.key,
        authorName: head.authorName,
        authorPhotoUrl: head.authorPhotoUrl,
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
      mediaUrl: (data['mediaUrl'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<void> publish(XFile image) async {
    final user = _user;
    final url = await _uploads.uploadStoryImage(uid: user.uid, file: image);
    final now = DateTime.now();
    await _stories.add({
      'authorId': user.uid,
      'authorName': user.displayName ?? '',
      'authorPhotoUrl': user.photoURL,
      'mediaUrl': url,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
    });
  }

  @override
  Future<void> delete(String storyId) async {
    await _stories.doc(storyId).delete();
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

import '../errors/app_exception.dart';

/// Result of a single media upload.
class UploadedMedia {
  const UploadedMedia({required this.url, required this.aspectRatio});

  final String url;
  final double aspectRatio;
}

/// Compresses and uploads media to Firebase Storage.
///
/// Storage layout: `posts/{uid}/{uuid}.jpg` — matches storage.rules.
/// Images are re-encoded to JPEG (max 1920px, q82): typically 200–500 KB,
/// indistinguishable from the original on a phone screen.
class MediaUploadService {
  MediaUploadService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  /// Uploads [files] for [uid], reporting overall progress (0..1).
  Future<List<UploadedMedia>> uploadImages({
    required String uid,
    required List<XFile> files,
    void Function(double progress)? onProgress,
  }) async {
    final results = <UploadedMedia>[];
    for (var i = 0; i < files.length; i++) {
      final compressed = await _compress(files[i]);
      final aspectRatio = await _aspectRatioOf(compressed);

      final ref = _storage.ref('posts/$uid/${_uuid.v4()}.jpg');
      final task = ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0 && onProgress != null) {
          final fileProgress = snap.bytesTransferred / snap.totalBytes;
          onProgress((i + fileProgress) / files.length);
        }
      });

      try {
        await task;
      } on FirebaseException catch (e) {
        throw AppException(
          'Upload failed. Check your connection and try again.',
          code: e.code,
        );
      }

      results.add(
        UploadedMedia(
          url: await ref.getDownloadURL(),
          aspectRatio: aspectRatio,
        ),
      );
    }
    return results;
  }

  /// Uploads a square-ish avatar (small, aggressive compression).
  ///
  /// A unique object name makes replacement atomic from the viewer's point of
  /// view: the previous avatar remains usable until the profile points at the
  /// newly uploaded object.
  Future<String> uploadAvatar({
    required String uid,
    required XFile file,
  }) async {
    final compressed = await FlutterImageCompress.compressWithFile(
          file.path,
          minWidth: 512,
          minHeight: 512,
          quality: 85,
          format: CompressFormat.jpeg,
          keepExif: false,
        ) ??
        await file.readAsBytes();

    if (compressed.length >= 2 * 1024 * 1024) {
      throw const AppException(
          'Photo is too large. Please choose another image.');
    }
    final ref = _storage.ref('avatars/$uid/${_uuid.v4()}.jpg');
    try {
      await ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } on FirebaseException catch (e) {
      throw AppException('Avatar upload failed.', code: e.code);
    }
    try {
      return await ref.getDownloadURL();
    } catch (_) {
      // The upload finished, but no profile can reference an object without
      // its URL. Remove it instead of silently leaving an orphan behind.
      try {
        await ref.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Deletes an avatar only when its Storage path belongs to [uid].
  ///
  /// This is used to clean up a newly uploaded object if the following profile
  /// update fails. Previous live avatars are cleaned up by the profile
  /// denormalization function after copied avatar references are updated.
  Future<void> deleteOwnedAvatar({
    required String uid,
    required String downloadUrl,
  }) async {
    Reference ref;
    try {
      ref = _storage.refFromURL(downloadUrl);
    } on Object {
      throw const AppException('Invalid profile photo reference.');
    }
    if (!ref.fullPath.startsWith('avatars/$uid/')) {
      throw const AppException('This profile photo cannot be removed.');
    }
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw AppException('Avatar cleanup failed.', code: e.code);
    }
  }

  /// Uploads a chat photo. Path: `chats/{chatId}/{uid}/{uuid}.jpg` —
  /// the uid segment lets storage rules verify ownership.
  Future<String> uploadChatImage({
    required String chatId,
    required String uid,
    required XFile file,
  }) async {
    final compressed = await _compress(file);
    final ref = _storage.ref('chats/$chatId/$uid/${_uuid.v4()}.jpg');
    try {
      await ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } on FirebaseException catch (e) {
      throw AppException('Photo upload failed.', code: e.code);
    }
    return ref.getDownloadURL();
  }

  /// Voice note. Path: `chats/{chatId}/{uid}/{uuid}.m4a`
  Future<String> uploadChatAudio({
    required String chatId,
    required String uid,
    required String filePath,
  }) async {
    final bytes = await XFile(filePath).readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const AppException(
        'Voice note is too long. Try a shorter one.',
      );
    }
    final ref = _storage.ref('chats/$chatId/$uid/${_uuid.v4()}.m4a');
    try {
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'audio/mp4'),
      );
    } on FirebaseException catch (e) {
      throw AppException('Voice note upload failed.', code: e.code);
    }
    return ref.getDownloadURL();
  }

  /// Page logo or cover. Path: `restaurants/{uid}/{kind}.jpg`
  Future<String> uploadRestaurantImage({
    required String uid,
    required XFile file,
    required String kind,
  }) async {
    final compressed = await _compress(file);
    final ref = _storage.ref('restaurants/$uid/$kind.jpg');
    try {
      await ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } on FirebaseException catch (e) {
      throw AppException('Photo upload failed.', code: e.code);
    }
    return ref.getDownloadURL();
  }

  Future<String> uploadStoryImage({
    required String uid,
    required XFile file,
  }) async {
    final compressed = await _compress(file);
    final ref = _storage.ref('stories/$uid/${_uuid.v4()}.jpg');
    try {
      await ref.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } on FirebaseException catch (e) {
      throw AppException('Story upload failed.', code: e.code);
    }
    return ref.getDownloadURL();
  }

  Future<Uint8List> _compress(XFile file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: 1920,
      minHeight: 1920,
      quality: 82,
      format: CompressFormat.jpeg,
      keepExif: false, // strip GPS/EXIF for privacy
    );
    if (result != null) return result;
    // Fallback: original bytes (e.g. unsupported source format).
    return file.readAsBytes();
  }

  Future<double> _aspectRatioOf(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final ratio = image.width / image.height;
      image.dispose();
      return ratio;
    } catch (_) {
      return 1.0;
    }
  }
}

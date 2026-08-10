import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/post.dart';

/// Firestore (de)serialization for [Post].
///
/// Document path: `posts/{postId}`
/// Viewer state:  `posts/{postId}/likes/{uid}`, `users/{uid}/bookmarks/{postId}`
abstract final class PostModel {
  static Post fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool isLikedByMe = false,
    bool isBookmarkedByMe = false,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final mediaRaw = (data['media'] as List?) ?? const [];
    return Post(
      id: doc.id,
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      restaurantId: (data['restaurantId'] as String?) ?? '',
      restaurantName: (data['restaurantName'] as String?) ?? '',
      dishId: data['dishId'] as String?,
      dishName: data['dishName'] as String?,
      media: mediaRaw
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => PostMedia(
              url: (m['url'] as String?) ?? '',
              type: MediaType.fromKey(m['type'] as String?),
              thumbnailUrl: m['thumbnailUrl'] as String?,
              aspectRatio: (m['aspectRatio'] as num?)?.toDouble() ?? 1.0,
            ),
          )
          .where((m) => m.url.isNotEmpty)
          .toList(),
      caption: (data['caption'] as String?) ?? '',
      rating: (data['rating'] as num?)?.toDouble(),
      price: (data['price'] as num?)?.toDouble(),
      currencyCode: (data['currencyCode'] as String?) ?? 'USD',
      tags: ((data['tags'] as List?) ?? const []).whereType<String>().toList(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

import 'package:equatable/equatable.dart';

enum MediaType {
  image,
  video;

  static MediaType fromKey(String? key) =>
      key == 'video' ? MediaType.video : MediaType.image;
}

/// A single media item within a post.
class PostMedia extends Equatable {
  const PostMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.aspectRatio = 1.0,
  });

  final String url;
  final MediaType type;

  /// For videos: poster frame. For images: optional low-res preview.
  final String? thumbnailUrl;

  /// width / height — lets the feed reserve layout space before load.
  final double aspectRatio;

  @override
  List<Object?> get props => [url, type, thumbnailUrl, aspectRatio];
}

/// A food post. Every post belongs to a restaurant (BiteWise is
/// food-centric, not post-centric); dish is optional but encouraged.
class Post extends Equatable {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.restaurantId,
    required this.restaurantName,
    this.dishId,
    this.dishName,
    required this.media,
    this.caption = '',
    this.rating,
    this.price,
    this.currencyCode = 'USD',
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
    this.createdAt,
  });

  final String id;

  // Author (denormalized to avoid N+1 reads when rendering the feed).
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;

  // Food context (denormalized names for the same reason).
  final String restaurantId;
  final String restaurantName;
  final String? dishId;
  final String? dishName;

  final List<PostMedia> media;
  final String caption;

  /// 1.0–5.0 in half steps, or null if the author didn't rate.
  final double? rating;

  /// What the author paid, or null.
  final double? price;
  final String currencyCode;

  final List<String> tags;
  final int likeCount;
  final int commentCount;

  // Viewer-specific state (resolved separately from the post document).
  final bool isLikedByMe;
  final bool isBookmarkedByMe;

  final DateTime? createdAt;

  Post copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
    bool? isBookmarkedByMe,
  }) =>
      Post(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        dishId: dishId,
        dishName: dishName,
        media: media,
        caption: caption,
        rating: rating,
        price: price,
        currencyCode: currencyCode,
        tags: tags,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, likeCount, commentCount, isLikedByMe, isBookmarkedByMe];
}

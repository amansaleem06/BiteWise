import 'package:equatable/equatable.dart';

enum MediaType {
  image,
  video;

  static MediaType fromKey(String? key) =>
      key == 'video' ? MediaType.video : MediaType.image;
}

class PostMedia extends Equatable {
  const PostMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.aspectRatio = 1.0,
  });

  final String url;
  final MediaType type;
  final String? thumbnailUrl;
  final double aspectRatio;

  @override
  List<Object?> get props => [url, type, thumbnailUrl, aspectRatio];
}

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
    this.shareCount = 0,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
    this.isRepostedByMe = false,
    this.restaurantVerified = false,
    this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String restaurantId;
  final String restaurantName;
  final String? dishId;
  final String? dishName;
  final List<PostMedia> media;
  final String caption;
  final double? rating;
  final double? price;
  final String currencyCode;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLikedByMe;
  final bool isBookmarkedByMe;
  final bool isRepostedByMe;
  final bool restaurantVerified;
  final DateTime? createdAt;

  Post copyWith({
    int? likeCount,
    int? commentCount,
    int? shareCount,
    bool? isLikedByMe,
    bool? isBookmarkedByMe,
    bool? isRepostedByMe,
    bool? restaurantVerified,
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
        shareCount: shareCount ?? this.shareCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
        isRepostedByMe: isRepostedByMe ?? this.isRepostedByMe,
        restaurantVerified: restaurantVerified ?? this.restaurantVerified,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        likeCount,
        commentCount,
        shareCount,
        isLikedByMe,
        isBookmarkedByMe,
        isRepostedByMe,
        restaurantVerified,
      ];
}

import 'package:equatable/equatable.dart';

enum MediaType {
  image,
  video;

  static MediaType fromKey(String? key) =>
      key == 'video' ? MediaType.video : MediaType.image;
}

/// Official restaurant-page post kind. Diners tagging a restaurant never
/// set this — those land in Mentions instead.
enum PagePostKind {
  plate,
  promo,
  menu;

  static PagePostKind fromKey(String? key) => switch (key) {
        'promo' => PagePostKind.promo,
        'menu' => PagePostKind.menu,
        _ => PagePostKind.plate,
      };

  String get key => name;

  String get label => switch (this) {
        PagePostKind.plate => 'Plate',
        PagePostKind.promo => 'Promo',
        PagePostKind.menu => 'Menu update',
      };

  String get createHint => switch (this) {
        PagePostKind.plate =>
          'A dish from your kitchen. Diners see it as an official post on your page.',
        PagePostKind.promo =>
          'A limited offer or special. The post shows a “Get yours here” button.',
        PagePostKind.menu =>
          'A new item or menu change. Use the dish field for the item name.',
      };
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
    this.asRestaurantId,
    this.pageKind = PagePostKind.plate,
    this.mentionApproved = false,
    this.mentionHidden = false,
    this.previewCommentAuthor,
    this.previewCommentText,
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

  /// When set, this plate was published as the restaurant page, not a person.
  final String? asRestaurantId;

  /// Official page post type (plate / promo / menu). Ignored for diner tags.
  final PagePostKind pageKind;

  /// Owner featured this diner tag on the Mentions tab (approval mode).
  final bool mentionApproved;

  /// Owner hid this diner tag from the public Mentions tab.
  final bool mentionHidden;

  /// True only when the restaurant published as the business page.
  /// Diner tags must never use this — they keep the diner's identity.
  bool get postedAsRestaurant =>
      asRestaurantId != null && asRestaurantId!.isNotEmpty;

  /// Diner tagged this restaurant but did not post as the page.
  bool get isMention => hasRestaurant && !postedAsRestaurant;

  /// Whether this diner tag should appear on the restaurant Mentions tab.
  bool visibleOnMentions({
    required bool approvalRequired,
    required bool viewerIsOwner,
  }) {
    if (!isMention) return false;
    if (viewerIsOwner) return true;
    if (mentionHidden) return false;
    if (approvalRequired) return mentionApproved;
    return true;
  }

  /// Restaurant page this plate belongs to when it was posted as the business.
  String? get pageId {
    if (asRestaurantId != null && asRestaurantId!.isNotEmpty) {
      return asRestaurantId;
    }
    return null;
  }

  /// Name diners should see — restaurant name for official page posts.
  String get publicAuthorName => postedAsRestaurant && restaurantName.trim().isNotEmpty
      ? restaurantName
      : authorName;
  final String? previewCommentAuthor;
  final String? previewCommentText;

  final DateTime? createdAt;

  bool get hasRestaurant => restaurantName.trim().isNotEmpty;

  bool get hasCommentPreview =>
      commentCount > 0 &&
      previewCommentText != null &&
      previewCommentText!.trim().isNotEmpty;

  Post copyWith({
    int? likeCount,
    int? commentCount,
    int? shareCount,
    bool? isLikedByMe,
    bool? isBookmarkedByMe,
    bool? isRepostedByMe,
    bool? restaurantVerified,
    bool? mentionApproved,
    bool? mentionHidden,
    String? previewCommentAuthor,
    String? previewCommentText,
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
        asRestaurantId: asRestaurantId,
        pageKind: pageKind,
        mentionApproved: mentionApproved ?? this.mentionApproved,
        mentionHidden: mentionHidden ?? this.mentionHidden,
        previewCommentAuthor:
            previewCommentAuthor ?? this.previewCommentAuthor,
        previewCommentText: previewCommentText ?? this.previewCommentText,
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
        asRestaurantId,
        pageKind,
        mentionApproved,
        mentionHidden,
        previewCommentAuthor,
        previewCommentText,
      ];
}

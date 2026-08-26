import 'package:equatable/equatable.dart';

class Story extends Equatable {
  const Story({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.mediaUrl,
    this.authorPhotoUrl,
    this.asRestaurantId,
    this.likeCount = 0,
    this.commentCount = 0,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String mediaUrl;
  final String? authorPhotoUrl;
  final String? asRestaurantId;
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  bool get isLive =>
      expiresAt == null || expiresAt!.isAfter(DateTime.now());

  bool get postedAsRestaurant =>
      asRestaurantId != null && asRestaurantId!.isNotEmpty;

  @override
  List<Object?> get props => [id, likeCount, commentCount];
}

class StoryRing extends Equatable {
  const StoryRing({
    required this.authorId,
    required this.authorName,
    required this.stories,
    this.authorPhotoUrl,
    this.asRestaurantId,
  });

  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String? asRestaurantId;
  final List<Story> stories;

  bool get postedAsRestaurant =>
      asRestaurantId != null && asRestaurantId!.isNotEmpty;

  DateTime? get latestAt => stories
      .map((s) => s.createdAt)
      .whereType<DateTime>()
      .fold<DateTime?>(null, (latest, at) {
        if (latest == null || at.isAfter(latest)) return at;
        return latest;
      });

  @override
  List<Object?> get props => [authorId, stories];
}

class StoryComment extends Equatable {
  const StoryComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.authorPhotoUrl,
    this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id];
}

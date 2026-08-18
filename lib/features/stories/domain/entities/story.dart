import 'package:equatable/equatable.dart';

class Story extends Equatable {
  const Story({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.mediaUrl,
    this.authorPhotoUrl,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String mediaUrl;
  final String? authorPhotoUrl;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  bool get isLive =>
      expiresAt == null || expiresAt!.isAfter(DateTime.now());

  @override
  List<Object?> get props => [id];
}

class StoryRing extends Equatable {
  const StoryRing({
    required this.authorId,
    required this.authorName,
    required this.stories,
    this.authorPhotoUrl,
  });

  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final List<Story> stories;

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

import 'package:equatable/equatable.dart';

/// A comment on a post. Replies are flat (Instagram-style): a reply is a
/// normal comment that tags the person it responds to via [replyToName].
class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    this.replyToName,
    this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final String? replyToName;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id];
}

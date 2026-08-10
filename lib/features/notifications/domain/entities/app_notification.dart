import 'package:equatable/equatable.dart';

enum NotificationType {
  like,
  comment,
  follow,
  reservation;

  static NotificationType fromKey(String? key) => NotificationType.values
      .firstWhere((t) => t.name == key, orElse: () => NotificationType.like);
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    this.actorPhotoUrl,
    this.postId,
    this.postMediaUrl,
    this.text,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String actorId;
  final String actorName;
  final String? actorPhotoUrl;
  final String? postId;
  final String? postMediaUrl;
  final String? text;
  final bool read;
  final DateTime? createdAt;

  String get message => switch (type) {
        NotificationType.like => 'liked your post',
        NotificationType.comment =>
          'commented: ${text ?? ''}'.trimRight(),
        NotificationType.follow => 'started following you',
        NotificationType.reservation => text ?? 'updated your reservation',
      };

  @override
  List<Object?> get props => [id, read];
}

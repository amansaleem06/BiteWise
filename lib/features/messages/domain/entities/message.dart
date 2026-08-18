import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  image,
  audio;

  static MessageType fromKey(String? key) => switch (key) {
        'image' => MessageType.image,
        'audio' => MessageType.audio,
        _ => MessageType.text,
      };
}

class Message extends Equatable {
  const Message({
    required this.id,
    required this.senderId,
    required this.type,
    this.text,
    this.imageUrl,
    this.audioUrl,
    this.durationMs,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final String? audioUrl;
  final int? durationMs;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id];
}

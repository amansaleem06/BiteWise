import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  image;

  static MessageType fromKey(String? key) =>
      key == 'image' ? MessageType.image : MessageType.text;
}

class Message extends Equatable {
  const Message({
    required this.id,
    required this.senderId,
    required this.type,
    this.text,
    this.imageUrl,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id];
}

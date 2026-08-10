import 'package:equatable/equatable.dart';

/// Minimal peer identity denormalized onto the chat document.
class ChatPeer extends Equatable {
  const ChatPeer({required this.uid, required this.name, this.photoUrl});

  final String uid;
  final String name;
  final String? photoUrl;

  @override
  List<Object?> get props => [uid, name, photoUrl];
}

/// A one-to-one conversation.
///
/// Chat ID is deterministic: the two UIDs sorted and joined with '_',
/// so opening a chat never requires a lookup query.
class Chat extends Equatable {
  const Chat({
    required this.id,
    required this.peer,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.lastMessageAt,
    this.myLastReadAt,
    this.peerLastReadAt,
    this.peerTypingAt,
  });

  final String id;
  final ChatPeer peer;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime? myLastReadAt;
  final DateTime? peerLastReadAt;
  final DateTime? peerTypingAt;

  static String idFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  /// Unread when the last message is incoming and newer than my last read.
  bool get hasUnread =>
      lastMessageAt != null &&
      lastMessageSenderId == peer.uid &&
      (myLastReadAt == null || lastMessageAt!.isAfter(myLastReadAt!));

  /// Peer is typing if their typing timestamp is fresh (<6s).
  bool get isPeerTyping =>
      peerTypingAt != null &&
      DateTime.now().difference(peerTypingAt!).inSeconds < 6;

  @override
  List<Object?> get props =>
      [id, lastMessageText, lastMessageAt, myLastReadAt, peerLastReadAt, peerTypingAt];
}

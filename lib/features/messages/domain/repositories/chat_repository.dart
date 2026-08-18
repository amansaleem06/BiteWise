import 'package:image_picker/image_picker.dart';

import '../entities/chat.dart';
import '../entities/message.dart';

abstract interface class ChatRepository {
  /// The viewer's conversations, most recent first (live).
  Stream<List<Chat>> watchChats();

  /// One conversation (live — typing, read receipts, peer info).
  Stream<Chat?> watchChat(String chatId);

  /// Latest [limit] messages, newest first (live).
  Stream<List<Message>> watchMessages(String chatId, {int limit});

  /// Ensures the chat document exists and returns its id.
  Future<String> openChatWith({
    required String peerUid,
    required String peerName,
    String? peerPhotoUrl,
  });

  Future<void> sendText(String chatId, String text);

  Future<void> sendImage(String chatId, XFile image);

  Future<void> sendAudio(
    String chatId, {
    required String filePath,
    required int durationMs,
  });

  /// Updates the viewer's lastReadAt (read receipt + clears unread).
  Future<void> markRead(String chatId);

  /// Refreshes the viewer's typing timestamp (call throttled while typing).
  Future<void> setTyping(String chatId);
}

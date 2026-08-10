import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/firestore_chat_repository.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => FirestoreChatRepository(),
);

final chatsProvider = StreamProvider.autoDispose<List<Chat>>(
  (ref) => ref.read(chatRepositoryProvider).watchChats(),
);

final chatProvider = StreamProvider.autoDispose.family<Chat?, String>(
  (ref, chatId) => ref.read(chatRepositoryProvider).watchChat(chatId),
);

final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>(
  (ref, chatId) => ref.read(chatRepositoryProvider).watchMessages(chatId),
);

/// Send actions with throttled typing signal.
class ChatActions {
  ChatActions(this._repo);

  final ChatRepository _repo;
  DateTime _lastTypingSignal = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> sendText(String chatId, String text) =>
      _repo.sendText(chatId, text);

  Future<void> sendImage(String chatId, XFile image) =>
      _repo.sendImage(chatId, image);

  Future<void> markRead(String chatId) => _repo.markRead(chatId);

  /// At most one typing write every 3 seconds.
  void typing(String chatId) {
    final now = DateTime.now();
    if (now.difference(_lastTypingSignal).inSeconds < 3) return;
    _lastTypingSignal = now;
    _repo.setTyping(chatId);
  }
}

final chatActionsProvider = Provider<ChatActions>(
  (ref) => ChatActions(ref.read(chatRepositoryProvider)),
);

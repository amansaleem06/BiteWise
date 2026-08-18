import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';

/// Firestore layout:
///   chats/{chatId}                       — participants, peer info, receipts
///   chats/{chatId}/messages/{messageId}  — immutable messages
class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    MediaUploadService? uploads,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _uploads = uploads ?? MediaUploadService();

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final MediaUploadService _uploads;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  fb.User get _user {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');
    return user;
  }

  @override
  Stream<List<Chat>> watchChats() {
    final me = _user.uid;
    return _chats
        .where('participants', arrayContains: me)
        .orderBy('updatedAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _chatFromDoc(d, me))
            .whereType<Chat>()
            .toList(),);
  }

  @override
  Stream<Chat?> watchChat(String chatId) {
    final me = _user.uid;
    return _chats
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? _chatFromDoc(doc, me) : null);
  }

  @override
  Stream<List<Message>> watchMessages(String chatId, {int limit = 50}) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_messageFromDoc).toList());
  }

  @override
  Future<String> openChatWith({
    required String peerUid,
    required String peerName,
    String? peerPhotoUrl,
  }) async {
    final user = _user;
    final chatId = Chat.idFor(user.uid, peerUid);
    final existing = await _chats.doc(chatId).get();
    if (existing.exists) {
      await _chats.doc(chatId).set({
        'participantInfo': {
          user.uid: {
            'name': user.displayName ?? '',
            'photoUrl': user.photoURL,
          },
          peerUid: {'name': peerName, 'photoUrl': peerPhotoUrl},
        },
      }, SetOptions(merge: true),);
      return chatId;
    }

    await _assertCanMessage(peerUid);

    await _chats.doc(chatId).set({
      'participants': [user.uid, peerUid]..sort(),
      'participantInfo': {
        user.uid: {
          'name': user.displayName ?? '',
          'photoUrl': user.photoURL,
        },
        peerUid: {'name': peerName, 'photoUrl': peerPhotoUrl},
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return chatId;
  }

  Future<void> _assertCanMessage(String peerUid) async {
    final peerDoc = await _firestore.collection('users').doc(peerUid).get();
    final privacy = MessagePrivacy.fromKey(
      peerDoc.data()?['messagePrivacy'] as String?,
    );
    if (privacy == MessagePrivacy.everyone) return;
    if (privacy == MessagePrivacy.none) {
      throw const AppException(
        'This account is not accepting new messages.',
      );
    }
    final followsMe = await _firestore
        .collection('users')
        .doc(peerUid)
        .collection('followers')
        .doc(_user.uid)
        .get();
    if (!followsMe.exists) {
      throw const AppException(
        'They only accept messages from people who follow them.',
      );
    }
  }

  @override
  Future<void> sendText(String chatId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _send(chatId, type: MessageType.text, text: trimmed);
  }

  @override
  Future<void> sendImage(String chatId, XFile image) async {
    final url = await _uploads.uploadChatImage(
      chatId: chatId,
      uid: _user.uid,
      file: image,
    );
    await _send(chatId, type: MessageType.image, imageUrl: url);
  }

  @override
  Future<void> sendAudio(
    String chatId, {
    required String filePath,
    required int durationMs,
  }) async {
    final url = await _uploads.uploadChatAudio(
      chatId: chatId,
      uid: _user.uid,
      filePath: filePath,
    );
    await _send(
      chatId,
      type: MessageType.audio,
      audioUrl: url,
      durationMs: durationMs,
    );
  }

  Future<void> _send(
    String chatId, {
    required MessageType type,
    String? text,
    String? imageUrl,
    String? audioUrl,
    int? durationMs,
  }) async {
    final me = _user.uid;
    final preview = switch (type) {
      MessageType.image => 'Photo',
      MessageType.audio => 'Voice note',
      MessageType.text => text,
    };
    final batch = _firestore.batch()
      ..set(_chats.doc(chatId).collection('messages').doc(), {
        'senderId': me,
        'type': type.name,
        'text': text,
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'durationMs': durationMs,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(
        _chats.doc(chatId),
        {
          'lastMessage': {
            'text': preview,
            'senderId': me,
          },
          'updatedAt': FieldValue.serverTimestamp(),
          // Sending implies having read the conversation.
          'lastReadAt': {me: FieldValue.serverTimestamp()},
        },
        SetOptions(merge: true),
      );
    await batch.commit();
  }

  @override
  Future<void> markRead(String chatId) async {
    await _chats.doc(chatId).set(
      {
        'lastReadAt': {_user.uid: FieldValue.serverTimestamp()},
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> setTyping(String chatId) async {
    await _chats.doc(chatId).set(
      {
        'typingAt': {_user.uid: FieldValue.serverTimestamp()},
      },
      SetOptions(merge: true),
    );
  }

  Chat? _chatFromDoc(DocumentSnapshot<Map<String, dynamic>> doc, String me) {
    final data = doc.data();
    if (data == null) return null;

    final participants =
        ((data['participants'] as List?) ?? const []).whereType<String>();
    final peerUid = participants.firstWhere((p) => p != me, orElse: () => '');
    if (peerUid.isEmpty) return null;

    final info = (data['participantInfo'] as Map?) ?? const {};
    final peerInfo = (info[peerUid] as Map?) ?? const {};
    final lastMessage = (data['lastMessage'] as Map?) ?? const {};
    final lastReadAt = (data['lastReadAt'] as Map?) ?? const {};
    final typingAt = (data['typingAt'] as Map?) ?? const {};

    return Chat(
      id: doc.id,
      peer: ChatPeer(
        uid: peerUid,
        name: (peerInfo['name'] as String?) ?? '',
        photoUrl: peerInfo['photoUrl'] as String?,
      ),
      lastMessageText: lastMessage['text'] as String?,
      lastMessageSenderId: lastMessage['senderId'] as String?,
      lastMessageAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      myLastReadAt: (lastReadAt[me] as Timestamp?)?.toDate(),
      peerLastReadAt: (lastReadAt[peerUid] as Timestamp?)?.toDate(),
      peerTypingAt: (typingAt[peerUid] as Timestamp?)?.toDate(),
    );
  }

  Message _messageFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Message(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      type: MessageType.fromKey(data['type'] as String?),
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      audioUrl: data['audioUrl'] as String?,
      durationMs: (data['durationMs'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

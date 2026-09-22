import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_safety_repository.dart';
import '../../domain/repositories/safety_repository.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => FirestoreSafetyRepository(),
);

final blockedUserIdsProvider = StreamProvider<Set<String>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return ref.watch(safetyRepositoryProvider).watchBlockedUserIds();
});

/// Outgoing blocks only, used for management (incoming blocks are not editable).
final myBlockedUserIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (uid == null) return Stream.value({});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('blocked')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.id).toSet());
});

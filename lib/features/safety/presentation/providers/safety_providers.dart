import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/firestore_safety_repository.dart';
import '../../domain/repositories/safety_repository.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => FirestoreSafetyRepository(),
);

final blockedUserIdsProvider = StreamProvider<Set<String>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(safetyRepositoryProvider).watchBlockedUserIds();
});

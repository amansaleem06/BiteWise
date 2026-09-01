enum ReportTargetType { post, user, message, story, comment }

abstract class SafetyRepository {
  Future<void> report({
    required ReportTargetType type,
    required String targetId,
    required String targetUserId,
    required String reason,
  });

  Future<void> blockUser(String uid);

  Future<void> unblockUser(String uid);

  Stream<Set<String>> watchBlockedUserIds();
}

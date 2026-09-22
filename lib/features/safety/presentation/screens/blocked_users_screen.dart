import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/safety_providers.dart';
import '../widgets/safety_actions.dart';

final _blockedNameProvider =
    FutureProvider.autoDispose.family<String, String>((ref, uid) async {
  final doc = await FirebaseFirestore.instance.doc('publicProfiles/$uid').get();
  return doc.data()?['displayName'] as String? ?? 'Deleted account';
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Blocked accounts')),
        body: ref.watch(myBlockedUserIdsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(myBlockedUserIdsProvider),
                  child: const Text('Could not load. Retry'),
                ),
              ),
              data: (ids) => ids.isEmpty
                  ? const Center(child: Text('No blocked accounts'))
                  : ListView(
                      children: [
                        for (final uid in ids)
                          ListTile(
                            title: Text(
                              ref
                                      .watch(_blockedNameProvider(uid))
                                      .valueOrNull ??
                                  'Blocked account',
                            ),
                            trailing: TextButton(
                              onPressed: () => SafetyActions.unblockUser(
                                context,
                                ref,
                                uid: uid,
                              ),
                              child: const Text('Unblock'),
                            ),
                          ),
                      ],
                    ),
            ),
      );
}

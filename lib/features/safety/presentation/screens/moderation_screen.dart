import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Uses the existing admin role; the callable independently checks that role.
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});
  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  bool _busy = false;
  late final _reports = FirebaseFirestore.instance
      .collection('reports')
      .where('status', isEqualTo: 'open')
      .limit(100)
      .snapshots();

  Future<void> _review(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final note = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                'Target: ${doc.data()['targetType']} / ${doc.data()['targetId']}\n'
                'Account: ${doc.data()['targetUserId']}\nReason: ${doc.data()['reason']}',
              ),
              const Text(
                'Inspect the reported content in Firestore before acting. Hiding preserves it for review; suspension prevents participation.',
              ),
              TextField(
                controller: note,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Review note (required)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          for (final entry in {
            'dismiss': 'Dismiss',
            'hide': 'Hide content',
            'suspend': 'Suspend account',
          }.entries)
            TextButton(
              onPressed: () {
                if (note.text.trim().isNotEmpty) {
                  Navigator.pop(context, entry.key);
                }
              },
              child: Text(entry.value),
            ),
        ],
      ),
    );
    final reviewNote = note.text.trim();
    // The dialog's text field may still be animating out.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    note.dispose();
    if (action == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final project = Firebase.app().options.projectId;
      final response = await http
          .post(
            Uri.https(
              'us-central1-$project.cloudfunctions.net',
              '/resolveReport',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'data': {
                'reportId': doc.id,
                'action': action,
                'note': reviewNote,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw StateError(
          'Review failed. Check your access and function deployment; retry to confirm the result.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report resolved')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not confirm resolution. Check the report and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Moderation reports')),
        body: ref.watch(currentUserProvider)?.role != UserRole.admin
            ? const Center(child: Text('Moderator access required'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _reports,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load reports. Check access and retry.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No open reports'));
                  }
                  return ListView(
                    children: [
                      for (final doc in docs)
                        ListTile(
                          title: Text(
                            '${doc.data()['reason']} · ${doc.data()['targetType']}',
                          ),
                          subtitle: Text('${doc.data()['targetId']}'),
                          trailing: const Icon(Icons.chevron_right),
                          enabled: !_busy,
                          onTap: () => _review(doc),
                        ),
                    ],
                  );
                },
              ),
      );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_legal.dart';
import 'auth_providers.dart';

/// Only an explicit user action may set this; never restored from preferences.
final termsCheckedProvider = StateProvider<bool>((ref) => false);
final consentStoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final termsAcceptedProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (uid == null) return Stream.value(false);
  return ref
      .watch(consentStoreProvider)
      .doc('users/$uid/legal/current')
      .snapshots()
      .map((doc) => doc.data()?['version'] == AppLegal.termsVersion);
});

Future<void> recordTermsAcceptance(Ref ref, String uid) async {
  await ref.read(consentStoreProvider).doc('users/$uid/legal/current').set({
    'version': AppLegal.termsVersion,
    'acceptedAt': FieldValue.serverTimestamp(),
  });
}

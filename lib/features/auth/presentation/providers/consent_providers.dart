import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_legal.dart';
import 'auth_providers.dart';

/// Only an explicit user action may set this; never restored from preferences.
final termsCheckedProvider = StateProvider<bool>((ref) => false);
final consentStoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final termsAcceptedProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUserProvider.select((user) => user?.uid));
  if (uid == null) return Stream.value(false);
  return ref
      .watch(consentStoreProvider)
      .doc('users/$uid')
      .snapshots()
      .map(
        (doc) => doc.data()?['termsAcceptedVersion'] == AppLegal.termsVersion,
      );
});

Future<bool> recordTermsAcceptance(Ref ref, String uid) async {
  final userRef = ref.read(consentStoreProvider).doc('users/$uid');
  final existing = await userRef.get();
  if (existing.data()?['termsAcceptedVersion'] == AppLegal.termsVersion) {
    return false;
  }
  await userRef.set({
    'termsAcceptedVersion': AppLegal.termsVersion,
    'termsAcceptedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  return true;
}

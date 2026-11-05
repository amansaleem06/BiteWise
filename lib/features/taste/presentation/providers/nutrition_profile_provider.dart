import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/nutrition_profile.dart';

/// Loads existing taste preferences for the personalized Palette feed.
final nutritionProfileProvider =
    FutureProvider.autoDispose<NutritionProfile?>((ref) async {
  final uid = fb.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('nutrition')
      .get();
  return NutritionProfile.fromMap(snapshot.data());
});

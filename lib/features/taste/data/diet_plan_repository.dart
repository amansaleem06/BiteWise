import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/config/ai_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/gemini_service.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../feed/domain/entities/post.dart';
import '../../restaurants/domain/entities/restaurant.dart';
import '../domain/diet_plan.dart';
import '../domain/nutrition_profile.dart';
import '../domain/taste_stats.dart';

/// Generates and stores AI diet plans grounded in the diner's own history.
class DietPlanRepository {
  DietPlanRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    GeminiService? gemini,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _gemini = gemini ?? GeminiService();

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final GeminiService _gemini;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Not signed in');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _planRef =>
      _firestore.collection('users').doc(_uid).collection('aiPlans').doc('current');

  DocumentReference<Map<String, dynamic>> get _nutritionRef =>
      _firestore.collection('users').doc(_uid).collection('private').doc('nutrition');

  Future<NutritionProfile?> loadProfile() async {
    final snap = await _nutritionRef.get();
    return NutritionProfile.fromMap(snap.data());
  }

  Future<void> saveProfile(NutritionProfile profile) async {
    await _nutritionRef.set({
      ...profile.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DietPlan?> loadCurrentPlan() async {
    final snap = await _planRef.get();
    return DietPlan.fromMap(snap.data());
  }

  /// One Gemini call; the result is validated and cached for 7 days.
  ///
  /// Pass [force] after the diner edits stats so a fresh plan is written
  /// even if the current one has not expired.
  Future<DietPlan> generate({
    required NutritionProfile profile,
    required List<DietaryPreference> preferences,
    required TasteStats stats,
    required List<Post> recentPosts,
    required List<Restaurant> candidateRestaurants,
    bool force = false,
  }) async {
    if (!force) {
      final existing = await loadCurrentPlan();
      if (existing != null && !existing.isExpired) return existing;
    }

    if (!_gemini.isConfigured) {
      throw const AppException(
        'AI plans are not available in this build.',
        code: 'GEMINI_KEY_MISSING',
      );
    }

    final candidates = candidateRestaurants.take(12).toList();
    final postedDishes = [
      for (final post in recentPosts
          .where((p) => (p.dishName ?? '').trim().isNotEmpty)
          .take(8))
        {
          'dish': post.dishName,
          'source': 'posted',
          if (post.rating != null) 'rating': post.rating,
          if (post.restaurantName.trim().isNotEmpty)
            'restaurant': post.restaurantName,
        },
    ];
    final input = {
      'profile': {
        ...profile.toMap(),
        'dietaryPreferences': [
          for (final preference in preferences) preference.name,
        ],
      },
      'taste': {
        'favoriteCuisines': profile.favoriteCuisines,
        'favoriteDishes': profile.favoriteDishes,
        'source': profile.hasTaste && stats.postCount > 0
            ? 'manual+posts'
            : profile.hasTaste
                ? 'manual'
                : 'posts',
      },
      'history': {
        'platesLogged': stats.postCount,
        'averageRatingGiven': stats.averageRating,
        'topCuisines': [
          if (profile.favoriteCuisines.isNotEmpty)
            for (final cuisine in profile.favoriteCuisines)
              {'cuisine': cuisine, 'source': 'chosen'}
          else
            for (final stamp in stats.earnedStamps.take(6))
              {'cuisine': stamp.cuisine, 'count': stamp.count},
        ],
        'dishes': [
          for (final dish in profile.favoriteDishes)
            {'dish': dish, 'source': 'chosen'},
          ...postedDishes,
        ],
      },
      'candidateRestaurants': [
        for (final restaurant in candidates)
          {
            'restaurantId': restaurant.id,
            'name': restaurant.name,
            'cuisines': restaurant.cuisines,
            if (restaurant.averageRating != null)
              'rating': double.parse(
                restaurant.averageRating!.toStringAsFixed(1),
              ),
          },
      ],
    };

    final response = await _gemini.generateJson(
      model: AiConfig.planModel,
      fallbackModels: AiConfig.planFallbacks,
      prompt: '''
You are a nutrition coach inside TasteWise, a food-sharing app. Using the
user data below, produce a practical weekly guidance plan.

Rules:
- Estimate daily calories with Mifflin-St Jeor adjusted for activityLevel
  and goal (moderate deficit for loseWeight, surplus for gainMuscle).
- Respect dietaryPreferences as HARD restrictions (vegan/vegetarian).
- Prefer taste.favoriteDishes and taste.favoriteCuisines. Also use
  history.dishes posted by the user when present.
- "meals": 3-4 suggestions built on those dishes/cuisines ("basedOn"),
  with a healthier variant in "swap".
- "restaurantPicks": if candidateRestaurants is empty, return [].
  Otherwise choose 2-3 ONLY from that list, copying restaurantId and
  name exactly. Never invent restaurants.
- "tips": 2-3 short, specific habits based on their actual pattern.
- "summary": 2-3 friendly sentences referencing what they actually eat.
- Plain language, no markdown, metric units.

USER DATA:
${jsonEncode(input)}

Respond with JSON only, exactly this shape:
{"calorieTarget": 2200,
 "macros": {"proteinG": 150, "carbsG": 220, "fatG": 70},
 "summary": "...",
 "meals": [{"title": "...", "basedOn": "...", "swap": "...", "approxKcal": 550}],
 "restaurantPicks": [{"restaurantId": "...", "name": "...", "why": "..."}],
 "tips": ["...", "..."]}''',
      maxOutputTokens: 8192,
      timeout: const Duration(seconds: 45),
    );

    // Ground restaurant picks: drop anything not in the candidate list.
    final validIds = {for (final restaurant in candidates) restaurant.id};
    final picks = (response['restaurantPicks'] as List<dynamic>? ?? const [])
        .map(RestaurantPick.fromMap)
        .whereType<RestaurantPick>()
        .where((pick) => validIds.contains(pick.restaurantId))
        .toList();

    final now = DateTime.now();
    final plan = DietPlan.fromMap({
      ...response,
      'restaurantPicks': [for (final pick in picks) pick.toMap()],
      'generatedAt': now.toIso8601String(),
      'expiresAt': now.add(const Duration(days: 7)).toIso8601String(),
    });
    if (plan == null || plan.calorieTarget < 800 || plan.calorieTarget > 6000) {
      throw const AppException(
        'The AI plan came back malformed. Please try again.',
        code: 'PLAN_INVALID',
      );
    }

    await _planRef.set(plan.toMap());
    return plan;
  }
}

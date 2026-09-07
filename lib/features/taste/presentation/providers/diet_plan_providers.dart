import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/utils/dietary_ranking.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/diet_plan_repository.dart';
import '../../domain/diet_plan.dart';
import '../../domain/nutrition_profile.dart';
import 'taste_providers.dart';

final dietPlanRepositoryProvider = Provider<DietPlanRepository>(
  (ref) => DietPlanRepository(),
);

final nutritionProfileProvider =
    FutureProvider.autoDispose<NutritionProfile?>(
  (ref) => ref.read(dietPlanRepositoryProvider).loadProfile(),
);

final currentDietPlanProvider = FutureProvider.autoDispose<DietPlan?>(
  (ref) => ref.read(dietPlanRepositoryProvider).loadCurrentPlan(),
);

/// Saves the profile and/or generates a fresh plan.
class DietPlanController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> saveProfile(NutritionProfile profile) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(dietPlanRepositoryProvider).saveProfile(profile),
    );
    if (!state.hasError) ref.invalidate(nutritionProfileProvider);
    return !state.hasError;
  }

  /// Returns null on success, or a user-facing error message.
  Future<String?> generate(
    NutritionProfile profile, {
    bool force = false,
  }) async {
    final me = ref.read(currentUserProvider);
    if (me == null) return 'Not signed in.';

    state = const AsyncLoading();
    try {
      if (!force) {
        final existing =
            await ref.read(dietPlanRepositoryProvider).loadCurrentPlan();
        if (existing != null && !existing.isExpired) {
          state = const AsyncData(null);
          return null;
        }
      }

      final stats = await ref.read(tasteStatsProvider(me.uid).future);
      if (!profile.hasTaste && stats.postCount == 0) {
        state = const AsyncData(null);
        return 'Pick at least one cuisine or add a dish you eat.';
      }

      // Recent posts for dish-level grounding.
      final page = await ref
          .read(userRepositoryProvider)
          .fetchUserPosts(me.uid, limit: 30);

      // Real TasteWise restaurants, biased to their dietary preferences.
      final topRated = await ref.read(topRatedRestaurantsProvider.future);
      final candidates = DietaryRanking.rankRestaurants(
        topRated,
        me.dietaryPreferences,
      );

      await ref.read(dietPlanRepositoryProvider).generate(
            profile: profile,
            preferences: me.dietaryPreferences,
            stats: stats,
            recentPosts: page.posts,
            candidateRestaurants: candidates,
            force: force,
          );
      ref.invalidate(currentDietPlanProvider);
      state = const AsyncData(null);
      return null;
    } on AppException catch (e) {
      state = const AsyncData(null);
      return e.code == 'GEMINI_KEY_MISSING'
          ? 'Your Palette isn\'t available in this build.'
          : e.message;
    } catch (e) {
      state = const AsyncData(null);
      return userMessageFrom(e);
    }
  }
}

final dietPlanControllerProvider =
    AsyncNotifierProvider.autoDispose<DietPlanController, void>(
  DietPlanController.new,
);

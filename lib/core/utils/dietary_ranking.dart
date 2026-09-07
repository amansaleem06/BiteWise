import '../../features/auth/domain/entities/app_user.dart';
import '../../features/feed/domain/entities/post.dart';
import '../../features/restaurants/domain/entities/restaurant.dart';

/// Boosts content matching the diner's dietary preferences.
///
/// Additive to the cuisine filter: matching items float up inside each
/// fetched page; nothing is hidden, and order within each score band stays
/// newest-first (stable sort).
abstract final class DietaryRanking {
  static const Map<DietaryPreference, Set<String>> _keywords = {
    DietaryPreference.vegan: {
      'vegan',
      'plantbased',
      'plant-based',
      'dairyfree',
      'meatfree',
    },
    DietaryPreference.vegetarian: {
      'vegetarian',
      'veggie',
      'vegan',
      'plantbased',
      'meatfree',
    },
    DietaryPreference.healthy: {
      'healthy',
      'salad',
      'fresh',
      'bowl',
      'poke',
      'wholegrain',
      'lowcal',
      'glutenfree',
      'mediterranean',
    },
    DietaryPreference.fitness: {
      'protein',
      'highprotein',
      'fitness',
      'gym',
      'lowcarb',
      'healthy',
      'keto',
    },
  };

  static Set<String> keywordsFor(List<DietaryPreference> preferences) => {
        for (final preference in preferences)
          ..._keywords[preference] ?? const <String>{},
      };

  static int _matchCount(Iterable<String> haystack, Set<String> keywords) {
    var count = 0;
    for (final raw in haystack) {
      final value = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      for (final keyword in keywords) {
        if (value == keyword || value.contains(keyword)) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  static int postScore(Post post, Set<String> keywords) {
    if (keywords.isEmpty) return 0;
    return _matchCount(
      [
        ...post.tags,
        if (post.dishName != null) post.dishName!,
      ],
      keywords,
    );
  }

  static int restaurantScore(Restaurant restaurant, Set<String> keywords) {
    if (keywords.isEmpty) return 0;
    return _matchCount(restaurant.cuisines, keywords);
  }

  /// Stable re-rank: preference matches first, original order otherwise.
  static List<Post> rankPosts(
    List<Post> posts,
    List<DietaryPreference> preferences,
  ) {
    final keywords = keywordsFor(preferences);
    if (keywords.isEmpty || posts.length < 2) return posts;
    final indexed = posts.asMap().entries.toList()
      ..sort((a, b) {
        final byScore = postScore(b.value, keywords)
            .compareTo(postScore(a.value, keywords));
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });
    return [for (final entry in indexed) entry.value];
  }

  static List<Restaurant> rankRestaurants(
    List<Restaurant> restaurants,
    List<DietaryPreference> preferences,
  ) {
    final keywords = keywordsFor(preferences);
    if (keywords.isEmpty || restaurants.length < 2) return restaurants;
    final indexed = restaurants.asMap().entries.toList()
      ..sort((a, b) {
        final byScore = restaurantScore(b.value, keywords)
            .compareTo(restaurantScore(a.value, keywords));
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });
    return [for (final entry in indexed) entry.value];
  }
}

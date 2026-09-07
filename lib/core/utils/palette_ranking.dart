import '../../features/auth/domain/entities/app_user.dart';
import '../../features/feed/domain/entities/post.dart';
import 'dietary_ranking.dart';

/// Ranks and filters the Palette feed from Your Palette tastes.
///
/// Matching cuisines, dishes, and meal hints float up. Avoids (allergies
/// and skip-list) are dropped entirely for this tab only.
abstract final class PaletteRanking {
  static const _aliases = <String, Set<String>>{
    'nuts': {
      'almond',
      'walnut',
      'cashew',
      'hazelnut',
      'pecan',
      'pistachio',
      'macadamia',
    },
    'peanuts': {'peanut', 'peanuts'},
    'dairy': {
      'dairy',
      'milk',
      'cheese',
      'cream',
      'yogurt',
      'yoghurt',
      'butter',
      'lactose',
    },
    'gluten': {'gluten', 'wheat', 'barley', 'rye'},
    'eggs': {'egg', 'eggs'},
    'shellfish': {
      'shellfish',
      'shrimp',
      'prawn',
      'crab',
      'lobster',
      'mussel',
      'oyster',
      'clam',
    },
    'fish': {'fish', 'salmon', 'tuna', 'cod', 'anchovy', 'sardine'},
    'soy': {'soy', 'soya', 'tofu', 'edamame'},
    'sesame': {'sesame', 'tahini'},
    'pork': {'pork', 'bacon', 'ham', 'lard'},
  };

  static String _norm(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

  static Set<String> _keywords(Iterable<String> values) => {
        for (final value in values)
          if (value.trim().isNotEmpty) _norm(value),
      };

  static Set<String> avoidKeywords(List<String> avoids) {
    final out = <String>{};
    for (final avoid in avoids) {
      final key = _norm(avoid);
      if (key.isEmpty) continue;
      out.add(key);
      out.addAll(_aliases[key] ?? const {});
    }
    return out;
  }

  static bool _looksLike(String haystack, String needle) {
    if (needle.length < 3 || !haystack.contains(needle)) return false;
    // Avoid "egg" in eggplant, "nut" in coconut / donut / nutmeg.
    if (needle == 'egg' && haystack.contains('eggplant')) return false;
    if (needle == 'nut' &&
        (haystack.contains('coconut') ||
            haystack.contains('donut') ||
            haystack.contains('doughnut') ||
            haystack.contains('nutmeg'))) {
      return false;
    }
    return true;
  }

  static String _haystack(Post post) => _norm(
        [
          ...post.tags,
          if (post.dishName != null) post.dishName!,
          post.caption,
        ].join(' '),
      );

  static bool hitsAvoid(Post post, Set<String> avoids) {
    if (avoids.isEmpty) return false;
    final hay = _haystack(post);
    for (final avoid in avoids) {
      if (_looksLike(hay, avoid)) return true;
    }
    return false;
  }

  static int score({
    required Post post,
    required Set<String> cuisineKeys,
    required Set<String> dishKeys,
    required Set<String> mealKeys,
    required Set<String> preferenceKeys,
  }) {
    final hay = _haystack(post);
    var points = 0;
    for (final key in cuisineKeys) {
      if (_looksLike(hay, key)) points += 3;
    }
    for (final key in dishKeys) {
      if (_looksLike(hay, key)) points += 4;
    }
    for (final key in mealKeys) {
      if (_looksLike(hay, key)) points += 5;
    }
    if (preferenceKeys.isNotEmpty) {
      points += DietaryRanking.postScore(post, preferenceKeys);
    }
    return points;
  }

  static List<Post> apply({
    required List<Post> posts,
    required List<String> cuisines,
    required List<String> dishes,
    required List<String> avoids,
    required List<String> mealHints,
    required List<DietaryPreference> preferences,
  }) {
    final avoidKeys = avoidKeywords(avoids);
    final visible = [
      for (final post in posts)
        if (!hitsAvoid(post, avoidKeys)) post,
    ];
    if (visible.length < 2) return visible;

    final cuisineKeys = _keywords(cuisines);
    final dishKeys = _keywords(dishes);
    final mealKeys = _keywords(mealHints);
    final preferenceKeys = DietaryRanking.keywordsFor(preferences);

    final indexed = visible.asMap().entries.toList()
      ..sort((a, b) {
        final byScore = score(
          post: b.value,
          cuisineKeys: cuisineKeys,
          dishKeys: dishKeys,
          mealKeys: mealKeys,
          preferenceKeys: preferenceKeys,
        ).compareTo(
          score(
            post: a.value,
            cuisineKeys: cuisineKeys,
            dishKeys: dishKeys,
            mealKeys: mealKeys,
            preferenceKeys: preferenceKeys,
          ),
        );
        return byScore != 0 ? byScore : a.key.compareTo(b.key);
      });
    return [for (final entry in indexed) entry.value];
  }
}

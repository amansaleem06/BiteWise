/// AI-generated diet plan built from Taste Passport history.
///
/// Stored at `users/{uid}/aiPlans/current`. Regenerated at most weekly
/// unless the nutrition profile changes.
class PlanMeal {
  const PlanMeal({
    required this.title,
    this.basedOn,
    this.swap,
    this.approxKcal,
  });

  final String title;

  /// The dish from the diner's own history this suggestion builds on.
  final String? basedOn;

  /// The healthier variant or adjustment.
  final String? swap;
  final int? approxKcal;

  static PlanMeal? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final title = (raw['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;
    return PlanMeal(
      title: title,
      basedOn: raw['basedOn'] as String?,
      swap: raw['swap'] as String?,
      approxKcal: (raw['approxKcal'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        if (basedOn != null) 'basedOn': basedOn,
        if (swap != null) 'swap': swap,
        if (approxKcal != null) 'approxKcal': approxKcal,
      };
}

class RestaurantPick {
  const RestaurantPick({
    required this.restaurantId,
    required this.name,
    this.why,
  });

  final String restaurantId;
  final String name;
  final String? why;

  static RestaurantPick? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final id = (raw['restaurantId'] as String?)?.trim();
    final name = (raw['name'] as String?)?.trim();
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
    return RestaurantPick(
      restaurantId: id,
      name: name,
      why: raw['why'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'restaurantId': restaurantId,
        'name': name,
        if (why != null) 'why': why,
      };
}

class DietPlan {
  const DietPlan({
    required this.generatedAt,
    required this.expiresAt,
    required this.calorieTarget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.summary,
    required this.meals,
    required this.restaurantPicks,
    required this.tips,
  });

  final DateTime generatedAt;
  final DateTime expiresAt;
  final int calorieTarget;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String summary;
  final List<PlanMeal> meals;
  final List<RestaurantPick> restaurantPicks;
  final List<String> tips;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  static DietPlan? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final generatedAt = DateTime.tryParse(raw['generatedAt'] as String? ?? '');
    final expiresAt = DateTime.tryParse(raw['expiresAt'] as String? ?? '');
    final calories = (raw['calorieTarget'] as num?)?.toInt();
    final macrosRaw = raw['macros'];
    final macros = macrosRaw is Map
        ? Map<String, dynamic>.from(macrosRaw)
        : const <String, dynamic>{};
    final summary = (raw['summary'] as String?)?.trim() ?? '';
    if (generatedAt == null || expiresAt == null || calories == null) {
      return null;
    }
    return DietPlan(
      generatedAt: generatedAt,
      expiresAt: expiresAt,
      calorieTarget: calories,
      proteinG: (macros['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (macros['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (macros['fatG'] as num?)?.toInt() ?? 0,
      summary: summary,
      meals: [
        for (final meal in raw['meals'] as List<dynamic>? ?? const [])
          if (PlanMeal.fromMap(meal) != null) PlanMeal.fromMap(meal)!,
      ],
      restaurantPicks: [
        for (final pick
            in raw['restaurantPicks'] as List<dynamic>? ?? const [])
          if (RestaurantPick.fromMap(pick) != null)
            RestaurantPick.fromMap(pick)!,
      ],
      tips: (raw['tips'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'generatedAt': generatedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'calorieTarget': calorieTarget,
        'macros': {'proteinG': proteinG, 'carbsG': carbsG, 'fatG': fatG},
        'summary': summary,
        'meals': [for (final meal in meals) meal.toMap()],
        'restaurantPicks': [
          for (final pick in restaurantPicks) pick.toMap(),
        ],
        'tips': tips,
      };
}

/// One-time personal stats for AI diet plans. Editable anytime.
///
/// Stored at `users/{uid}/private/nutrition` — owner-only read/write.
/// Never written onto the public profile document.
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active;

  static ActivityLevel? fromKey(String? key) =>
      ActivityLevel.values.where((level) => level.name == key).firstOrNull;

  String get label => switch (this) {
        ActivityLevel.sedentary => 'Mostly sitting',
        ActivityLevel.light => 'Lightly active',
        ActivityLevel.moderate => 'Moderately active',
        ActivityLevel.active => 'Very active',
      };
}

enum NutritionGoal {
  loseWeight,
  gainMuscle,
  maintain,
  eatHealthier;

  static NutritionGoal? fromKey(String? key) =>
      NutritionGoal.values.where((goal) => goal.name == key).firstOrNull;

  String get label => switch (this) {
        NutritionGoal.loseWeight => 'Lose weight',
        NutritionGoal.gainMuscle => 'Gain muscle',
        NutritionGoal.maintain => 'Maintain',
        NutritionGoal.eatHealthier => 'Eat healthier',
      };
}

class NutritionProfile {
  const NutritionProfile({
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.activityLevel,
    required this.goal,
    this.sex,
    this.favoriteCuisines = const [],
    this.favoriteDishes = const [],
  });

  final int heightCm;
  final double weightKg;
  final int age;
  final ActivityLevel activityLevel;
  final NutritionGoal goal;

  /// 'male' | 'female' | null (prefer not to say).
  final String? sex;

  /// Manual cuisine picks so a plan can be built without posting plates.
  final List<String> favoriteCuisines;

  /// Dishes the diner typed in (e.g. "goulash", "avocado toast").
  final List<String> favoriteDishes;

  bool get hasTaste =>
      favoriteCuisines.isNotEmpty || favoriteDishes.isNotEmpty;

  static List<String> _stringList(dynamic raw, {int maxItems = 16}) {
    if (raw is! List) return const [];
    final values = <String>[];
    for (final item in raw) {
      if (item is! String) continue;
      final trimmed = item.trim();
      if (trimmed.isEmpty || values.contains(trimmed)) continue;
      values.add(trimmed);
      if (values.length >= maxItems) break;
    }
    return values;
  }

  static NutritionProfile? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final height = (raw['heightCm'] as num?)?.toInt();
    final weight = (raw['weightKg'] as num?)?.toDouble();
    final age = (raw['age'] as num?)?.toInt();
    final activity = ActivityLevel.fromKey(raw['activityLevel'] as String?);
    final goal = NutritionGoal.fromKey(raw['goal'] as String?);
    if (height == null ||
        weight == null ||
        age == null ||
        activity == null ||
        goal == null) {
      return null;
    }
    return NutritionProfile(
      heightCm: height,
      weightKg: weight,
      age: age,
      activityLevel: activity,
      goal: goal,
      sex: raw['sex'] as String?,
      favoriteCuisines: _stringList(raw['favoriteCuisines']),
      favoriteDishes: _stringList(raw['favoriteDishes'], maxItems: 12),
    );
  }

  Map<String, dynamic> toMap() => {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'age': age,
        'activityLevel': activityLevel.name,
        'goal': goal.name,
        if (sex != null) 'sex': sex,
        'favoriteCuisines': favoriteCuisines,
        'favoriteDishes': favoriteDishes,
      };
}

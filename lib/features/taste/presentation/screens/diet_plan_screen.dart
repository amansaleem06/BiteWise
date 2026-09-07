import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/cuisines.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/diet_plan.dart';
import '../../domain/nutrition_profile.dart';
import '../providers/diet_plan_providers.dart';
import '../providers/taste_providers.dart';

/// AI diet plan: one-time profile setup, then a weekly cached plan.
class DietPlanScreen extends ConsumerStatefulWidget {
  const DietPlanScreen({super.key});

  @override
  ConsumerState<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends ConsumerState<DietPlanScreen> {
  var _editingProfile = false;

  Future<void> _generate(
    NutritionProfile profile, {
    bool force = false,
  }) async {
    final error = await ref
        .read(dietPlanControllerProvider.notifier)
        .generate(profile, force: force);
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      AppSnackbar.success(context, 'Your plan is ready.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(nutritionProfileProvider);
    final planAsync = ref.watch(currentDietPlanProvider);
    final generating = ref.watch(dietPlanControllerProvider).isLoading;
    final uid = ref.watch(currentUserProvider)?.uid;
    final stats = uid == null ? null : ref.watch(tasteStatsProvider(uid)).valueOrNull;
    final suggestedCuisines =
        stats?.earnedStamps.map((stamp) => stamp.cuisine).toList() ??
            const <String>[];
    final hasPostedPlates = (stats?.postCount ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Diet Plan',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w800),
        ),
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (error, stack) => AsyncErrorView(
          error: error,
          stackTrace: stack,
          title: 'Couldn\'t load your profile',
          onRetry: () => ref.invalidate(nutritionProfileProvider),
        ),
        data: (profile) {
          final needsTaste =
              profile != null && !profile.hasTaste && !hasPostedPlates;
          if (profile == null || _editingProfile || needsTaste) {
            return _ProfileForm(
              initial: profile,
              saving: generating,
              suggestedCuisines: suggestedCuisines,
              hasPostedPlates: hasPostedPlates,
              onSubmit: (updated) async {
                final saved = await ref
                    .read(dietPlanControllerProvider.notifier)
                    .saveProfile(updated);
                if (!context.mounted) return;
                if (!saved) {
                  final error = ref.read(dietPlanControllerProvider).error;
                  AppSnackbar.error(
                    context,
                    error != null
                        ? userMessageFrom(error)
                        : 'Couldn\'t save your stats.',
                  );
                  return;
                }
                setState(() => _editingProfile = false);
                await _generate(updated, force: true);
              },
            );
          }
          return planAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            error: (error, stack) => AsyncErrorView(
              error: error,
              stackTrace: stack,
              title: 'Couldn\'t load your plan',
              onRetry: () => ref.invalidate(currentDietPlanProvider),
            ),
            data: (plan) => _PlanBody(
              plan: plan,
              profile: profile,
              generating: generating,
              onGenerate: () => _generate(profile),
              onEditProfile: () => setState(() => _editingProfile = true),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    required this.initial,
    required this.saving,
    required this.suggestedCuisines,
    required this.hasPostedPlates,
    required this.onSubmit,
  });

  final NutritionProfile? initial;
  final bool saving;
  final List<String> suggestedCuisines;
  final bool hasPostedPlates;
  final Future<void> Function(NutritionProfile profile) onSubmit;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _height = TextEditingController(
    text: widget.initial?.heightCm.toString() ?? '',
  );
  late final _weight = TextEditingController(
    text: widget.initial?.weightKg.toStringAsFixed(0) ?? '',
  );
  late final _age = TextEditingController(
    text: widget.initial?.age.toString() ?? '',
  );
  late var _activity = widget.initial?.activityLevel ?? ActivityLevel.moderate;
  late var _goal = widget.initial?.goal ?? NutritionGoal.eatHealthier;
  late String? _sex = widget.initial?.sex;
  late final _dish = TextEditingController();
  late final _cuisines = <String>{
    ...?widget.initial?.favoriteCuisines,
    if (widget.initial == null || widget.initial!.favoriteCuisines.isEmpty)
      ...widget.suggestedCuisines.take(6),
  };
  late final _dishes = [...?widget.initial?.favoriteDishes];
  var _tasteError = false;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _age.dispose();
    _dish.dispose();
    super.dispose();
  }

  String? _numberValidator(String? value, int min, int max, String label) {
    final parsed = num.tryParse((value ?? '').replaceAll(',', '.'));
    if (parsed == null || parsed < min || parsed > max) {
      return 'Enter a $label between $min and $max';
    }
    return null;
  }

  void _addDish() {
    final added = <String>[];
    for (final part in _dish.text.split(',')) {
      final value = part.trim();
      if (value.isEmpty || value.length > 40) continue;
      if (_dishes.contains(value) || added.contains(value)) continue;
      added.add(value);
    }
    if (added.isEmpty) return;
    setState(() {
      _dishes.addAll(added.take(12 - _dishes.length));
      _tasteError = false;
    });
    _dish.clear();
  }

  void _submit() {
    if (_dish.text.trim().isNotEmpty) _addDish();
    if (!_formKey.currentState!.validate()) return;
    if (_cuisines.isEmpty && _dishes.isEmpty && !widget.hasPostedPlates) {
      setState(() => _tasteError = true);
      return;
    }
    widget.onSubmit(
      NutritionProfile(
        heightCm: int.parse(_height.text.trim()),
        weightKg: double.parse(_weight.text.trim().replaceAll(',', '.')),
        age: int.parse(_age.text.trim()),
        activityLevel: _activity,
        goal: _goal,
        sex: _sex,
        favoriteCuisines: _cuisines.toList(),
        favoriteDishes: _dishes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text(
          'Stats size the calorie target. Cuisines and dishes tell the plan '
          'what you actually like — no posts required.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _height,
                      decoration:
                          const InputDecoration(labelText: 'Height (cm)'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          _numberValidator(value, 100, 250, 'height'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      decoration:
                          const InputDecoration(labelText: 'Weight (kg)'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          _numberValidator(value, 30, 300, 'weight'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      decoration: const InputDecoration(labelText: 'Age'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          _numberValidator(value, 13, 110, 'age'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Sex (optional)', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final option in const ['male', 'female'])
              ChoiceChip(
                label: Text(option == 'male' ? 'Male' : 'Female'),
                selected: _sex == option,
                onSelected: (selected) =>
                    setState(() => _sex = selected ? option : null),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Activity level', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final level in ActivityLevel.values)
              ChoiceChip(
                label: Text(level.label),
                selected: _activity == level,
                onSelected: (_) => setState(() => _activity = level),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Goal', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final goal in NutritionGoal.values)
              ChoiceChip(
                label: Text(goal.label),
                selected: _goal == goal,
                onSelected: (_) => setState(() => _goal = goal),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Cuisines you like', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Pick a few. We\'ll build meals around them.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final cuisine in Cuisines.all)
              FilterChip(
                label: Text(cuisine),
                selected: _cuisines.contains(cuisine),
                onSelected: (selected) => setState(() {
                  _tasteError = false;
                  if (selected) {
                    _cuisines.add(cuisine);
                  } else {
                    _cuisines.remove(cuisine);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Dishes you eat', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Type a dish and tap add. Commas work too.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _dish,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addDish(),
          decoration: InputDecoration(
            labelText: 'e.g. goulash, avocado toast',
            suffixIcon: IconButton(
              tooltip: 'Add dish',
              onPressed: _addDish,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ),
        if (_dishes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final dish in _dishes)
                InputChip(
                  label: Text(dish),
                  onDeleted: () => setState(() => _dishes.remove(dish)),
                ),
            ],
          ),
        ],
        if (_tasteError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pick at least one cuisine or add a dish you eat.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Save and generate my plan',
          isLoading: widget.saving,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.md),
        const _Disclaimer(),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({
    required this.plan,
    required this.profile,
    required this.generating,
    required this.onGenerate,
    required this.onEditProfile,
  });

  final DietPlan? plan;
  final NutritionProfile profile;
  final bool generating;
  final VoidCallback onGenerate;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = plan;

    if (current == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Generate a plan from the cuisines and dishes you picked. '
            'Logged plates are included when you have them.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Generate my plan',
            isLoading: generating,
            onPressed: onGenerate,
          ),
          TextButton(
            onPressed: onEditProfile,
            child: const Text('Edit stats and tastes'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _Disclaimer(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        // Targets card.
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAILY TARGET',
                style: GoogleFonts.sourceSans3(
                  color: AppColors.accentLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${current.calorieTarget} kcal',
                style: GoogleFonts.fraunces(
                  color: AppColors.cream,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Macro(label: 'Protein', grams: current.proteinG),
                  const SizedBox(width: AppSpacing.md),
                  _Macro(label: 'Carbs', grams: current.carbsG),
                  const SizedBox(width: AppSpacing.md),
                  _Macro(label: 'Fat', grams: current.fatG),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(current.summary, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),

        if (current.meals.isNotEmpty) ...[
          Text(
            'Meal ideas',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final meal in current.meals)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                title: Text(meal.title),
                subtitle: Text(
                  [
                    if (meal.basedOn != null) 'Based on ${meal.basedOn}',
                    if (meal.swap != null) meal.swap!,
                  ].join(' · '),
                ),
                trailing: meal.approxKcal != null
                    ? Text(
                        '~${meal.approxKcal} kcal',
                        style: theme.textTheme.labelMedium,
                      )
                    : null,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (current.restaurantPicks.isNotEmpty) ...[
          Text('Good picks on TasteWise', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final pick in current.restaurantPicks)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(pick.name),
                subtitle: pick.why != null ? Text(pick.why!) : null,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    context.push(Routes.restaurantPath(pick.restaurantId)),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (current.tips.isNotEmpty) ...[
          Text('Habits to try', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final tip in current.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(tip, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        Text(
          '${Formatters.updated(current.generatedAt)} · '
          '${current.isExpired ? 'You can regenerate now.' : 'Refreshes weekly.'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: current.isExpired ? 'Regenerate plan' : 'Plan is up to date',
          isLoading: generating,
          onPressed: current.isExpired ? onGenerate : null,
        ),
        TextButton(
          onPressed: onEditProfile,
          child: const Text('Edit stats and tastes (regenerates the plan)'),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _Disclaimer(),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams});

  final String label;
  final int grams;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${grams}g',
          style: GoogleFonts.fraunces(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.sourceSans3(
            color: AppColors.cream.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        'General guidance generated by AI — not medical advice. Consult a '
        'professional for personalized nutrition needs.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

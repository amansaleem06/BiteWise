import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/cuisines.dart';
import '../../../../core/utils/locale_currency.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../restaurants/domain/entities/restaurant_ref.dart';
import '../../../restaurants/presentation/providers/restaurant_providers.dart';
import '../providers/create_post_providers.dart';
import '../widgets/media_picker_grid.dart';
import '../widgets/restaurant_picker_sheet.dart';
import '../widgets/star_rating_input.dart';

/// Compose a post: photos → restaurant → details → publish.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _dish = TextEditingController();
  final _caption = TextEditingController();
  final _price = TextEditingController();
  final _tags = TextEditingController();
  final _cuisines = <String>{};

  @override
  void dispose() {
    _dish.dispose();
    _caption.dispose();
    _price.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _parseTags() {
    final freeform = _tags.text
        .split(RegExp(r'[,#\s]+'))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty);
    final cuisineTags = _cuisines.map((c) => c.toLowerCase());
    return {...cuisineTags, ...freeform}.take(12).toList();
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    final error =
        await ref.read(createPostControllerProvider.notifier).submit(
              dishName: _dish.text,
              caption: _caption.text,
              price: double.tryParse(_price.text.replaceAll(',', '.')),
              tags: _parseTags(),
            );
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      _dish.clear();
      _caption.clear();
      _price.clear();
      _tags.clear();
      setState(_cuisines.clear);
      AppSnackbar.success(context, 'Posted!');
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(createPostControllerProvider);
    final controller = ref.read(createPostControllerProvider.notifier);
    final me = ref.watch(currentUserProvider);
    final ownedId = me?.ownedRestaurantId;
    if (me?.hasVerifiedBusiness == true &&
        ownedId != null &&
        state.restaurant == null) {
      final owned =
          ref.watch(restaurantControllerProvider(ownedId)).valueOrNull;
      if (owned != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.setRestaurant(
            RestaurantRef(id: owned.id, name: owned.name, city: owned.city),
          );
        });
      }
    }
    final restaurantLocked = me?.hasVerifiedBusiness == true;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Create',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.8,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          const SizedBox(height: AppSpacing.sm),
          MediaPickerGrid(
            images: state.images,
            onAddFromGallery: controller.pickImages,
            onAddFromCamera: controller.takePhoto,
            onRemove: controller.removeImage,
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Tag restaurant'),
                Text(
                  restaurantLocked
                      ? 'Owner posts are published on your restaurant page.'
                      : state.rating != null
                          ? 'Required when you add a rating.'
                          : 'Optional — skip for a photo-only post.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.storefront_outlined,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  title: Text(
                    state.restaurant?.name ?? 'Tag a restaurant (optional)',
                    style: state.restaurant == null
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : theme.textTheme.titleMedium,
                  ),
                  trailing: restaurantLocked
                      ? const Icon(Icons.lock_outline_rounded)
                      : state.restaurant == null
                          ? const Icon(Icons.chevron_right_rounded)
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => controller.setRestaurant(null),
                            ),
                  onTap: restaurantLocked
                      ? null
                      : () async {
                    final restaurant =
                        await RestaurantPickerSheet.show(context);
                    if (restaurant != null) {
                      controller.setRestaurant(restaurant);
                    }
                  },
                ),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                const _SectionLabel('Dish'),
                TextField(
                  controller: _dish,
                  decoration: const InputDecoration(
                    hintText: 'Optional — e.g. Truffle mushroom pizza',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.md),
                const _SectionLabel('Caption'),
                TextField(
                  controller: _caption,
                  decoration: const InputDecoration(
                    hintText: 'Explain the feeling — or leave blank',
                  ),
                  maxLines: 4,
                  maxLength: 2200,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _SectionLabel('Rate dish'),
                Text(
                  'Optional. If you rate, tag a restaurant first.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                StarRatingInput(
                  value: state.rating,
                  onChanged: controller.setRating,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            'Price paid (${LocaleCurrency.code})',
                          ),
                          TextField(
                            controller: _price,
                            decoration: InputDecoration(
                              hintText: '0',
                              prefixText: LocaleCurrency.inputPrefix,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const _SectionLabel('Cuisine'),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final cuisine in Cuisines.all)
                      FilterChip(
                        label: Text(cuisine),
                        selected: _cuisines.contains(cuisine),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _cuisines.add(cuisine);
                            } else {
                              _cuisines.remove(cuisine);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const _SectionLabel('More tags'),
                TextField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    hintText: 'pizza datenight spicy',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (state.isSubmitting) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: state.progress > 0 ? state.progress : null,
                      minHeight: 6,
                      backgroundColor: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Text(
                      'Uploading ${(state.progress * 100).round()}%…',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppButton(
                  label: 'Publish',
                  isLoading: state.isSubmitting,
                  onPressed: state.canSubmit ? _publish : null,
                ),
                if (!state.canSubmit && !state.isSubmitting) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.submitBlockedReason ??
                        'Add at least one photo to publish.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.fraunces(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

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
      setState(() => _cuisines.clear());
      AppSnackbar.success(context, 'Posted!');
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(createPostControllerProvider);
    final controller = ref.read(createPostControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'New post',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.8,
            color: AppColors.primaryDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
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
                // Restaurant — required, the anchor of every post.
                const _SectionLabel('Restaurant *'),
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
                    state.restaurant?.name ?? 'Tag the restaurant',
                    style: state.restaurant == null
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : theme.textTheme.titleMedium,
                  ),
                  trailing: state.restaurant == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => controller.setRestaurant(null),
                        ),
                  onTap: () async {
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
                    hintText: 'e.g. Truffle mushroom pizza',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.md),
                const _SectionLabel('Caption'),
                TextField(
                  controller: _caption,
                  decoration: const InputDecoration(
                    hintText: 'Tell the story of this bite…',
                  ),
                  maxLines: 4,
                  maxLength: 2200,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _SectionLabel('Your rating'),
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
                    state.images.isEmpty && state.restaurant == null
                        ? 'Add at least one photo and tag a restaurant to publish.'
                        : state.images.isEmpty
                            ? 'Add at least one photo to publish.'
                            : 'Tag a restaurant to publish.',
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
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../restaurants/domain/entities/restaurant_ref.dart';
import '../providers/create_post_providers.dart';

/// Bottom sheet: search restaurants, or create one that doesn't exist yet.
///
/// Returns the chosen [RestaurantRef] via Navigator.pop.
class RestaurantPickerSheet extends ConsumerStatefulWidget {
  const RestaurantPickerSheet({super.key});

  static Future<RestaurantRef?> show(BuildContext context) =>
      showModalBottomSheet<RestaurantRef>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const RestaurantPickerSheet(),
      );

  @override
  ConsumerState<RestaurantPickerSheet> createState() =>
      _RestaurantPickerSheetState();
}

class _RestaurantPickerSheetState extends ConsumerState<RestaurantPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.length < 2 || _creating) return;
    setState(() => _creating = true);
    try {
      final restaurant = await ref
          .read(createPostControllerProvider.notifier)
          .createRestaurant(name);
      if (mounted) Navigator.of(context).pop(restaurant);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(restaurantSearchProvider(_query));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search restaurants…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                error: (_, __) => Center(
                  child: Text(
                    'Search failed. Try again.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (restaurants) => ListView(
                  controller: scrollController,
                  children: [
                    for (final r in restaurants)
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.storefront_outlined,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        title: Text(r.name),
                        subtitle: r.city != null ? Text(r.city!) : null,
                        onTap: () => Navigator.of(context).pop(r),
                      ),
                    if (_query.trim().length >= 2)
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.accentLight,
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                        title: Text('Add "${_query.trim()}"'),
                        subtitle: const Text('Create a new restaurant'),
                        trailing: _creating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        onTap: _create,
                      ),
                    if (_query.trim().length < 2)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'Type at least 2 characters to search.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

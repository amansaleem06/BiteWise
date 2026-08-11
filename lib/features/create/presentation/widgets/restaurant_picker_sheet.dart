import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../restaurants/domain/entities/restaurant_ref.dart';
import '../providers/create_post_providers.dart';

/// Bottom sheet: Google Maps restaurant recommendations near the user.
///
/// Type a keyword → closest matching Places names → tap to add from Maps.
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
  String? _selectingPlaceId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectPlace(PlaceSuggestion place) async {
    if (_selectingPlaceId != null) return;
    setState(() => _selectingPlaceId = place.placeId);
    try {
      final restaurant = await ref
          .read(createPostControllerProvider.notifier)
          .upsertRestaurantFromPlace(place);
      if (mounted) Navigator.of(context).pop(restaurant);
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectingPlaceId = null);
      AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(placesRestaurantSearchProvider(_query));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                'Find on Maps',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Type a name — we recommend the closest restaurants nearby.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. pizza, Café Central…',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Couldn’t search Maps. Check location permission and that Places API is enabled.\n\n${userMessageFrom(e)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                data: (places) {
                  if (_query.trim().length < 2) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Type at least 2 characters to see nearby recommendations.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }
                  if (places.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No restaurants found nearby for “${_query.trim()}”. Try another keyword.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: places.length,
                    itemBuilder: (context, i) {
                      final p = places[i];
                      final busy = _selectingPlaceId == p.placeId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.storefront_outlined,
                                  color: AppColors.primaryDark,
                                ),
                        ),
                        title: Text(p.name),
                        subtitle: p.address != null ? Text(p.address!) : null,
                        trailing: const Icon(Icons.add_location_alt_outlined),
                        onTap: busy ? null : () => _selectPlace(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

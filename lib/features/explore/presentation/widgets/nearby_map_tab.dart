import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/presentation/widgets/claim_status_badge.dart';
import '../providers/explore_providers.dart';
import 'rating_map_pin.dart';

/// Viewer position + nearby restaurants, loaded together.
class NearbyState {
  const NearbyState({required this.position, required this.restaurants});

  final Position? position;
  final List<Restaurant> restaurants;
}

final nearbyProvider = FutureProvider.autoDispose<NearbyState>((ref) async {
  final position = await LocationService().currentPosition();
  if (position == null) {
    return const NearbyState(position: null, restaurants: []);
  }
  final restaurants =
      await ref.read(exploreRepositoryProvider).fetchNearbyRestaurants(
            latitude: position.latitude,
            longitude: position.longitude,
          );
  return NearbyState(position: position, restaurants: restaurants);
});

/// Google Map of nearby restaurants with a tappable preview card.
///
/// [isActive] must be true only when the Nearby tab is visible so the map
/// platform view is not kept alive under other Explore tabs / main tabs.
class NearbyMapTab extends ConsumerStatefulWidget {
  const NearbyMapTab({super.key, this.isActive = true});

  final bool isActive;

  @override
  ConsumerState<NearbyMapTab> createState() => _NearbyMapTabState();
}

class _NearbyMapTabState extends ConsumerState<NearbyMapTab> {
  Restaurant? _selected;
  Set<Marker> _markers = {};
  String? _markerKey;

  Future<void> _syncMarkers(List<Restaurant> restaurants) async {
    final key = restaurants
        .map((r) => '${r.id}:${r.averageRating}:${r.isClaimed}')
        .join('|');
    if (_markerKey == key) return;
    _markerKey = key;
    final next = <Marker>{};
    for (final r in restaurants) {
      if (r.latitude == null || r.longitude == null) continue;
      final icon = await RatingMapPin.descriptor(
        rating: r.averageRating,
        claimed: r.isClaimed,
      );
      next.add(
        Marker(
          markerId: MarkerId(r.id),
          position: LatLng(r.latitude!, r.longitude!),
          icon: icon,
          infoWindow: InfoWindow(
            title: r.name,
            snippet: [
              if (r.averageRating != null)
                '${r.averageRating!.toStringAsFixed(1)} ★',
              r.isClaimed ? 'Verified Owner' : 'Unclaimed listing',
            ].join(' · '),
          ),
          onTap: () => setState(() => _selected = r),
        ),
      );
    }
    if (mounted) setState(() => _markers = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const Center(
        child: Text('Swipe to Nearby to load the map'),
      );
    }

    final theme = Theme.of(context);
    final nearbyAsync = ref.watch(nearbyProvider);

    return nearbyAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (error, stack) => AsyncErrorView(
        error: error,
        stackTrace: stack,
        title: 'Couldn\'t load the map',
        onRetry: () => ref.invalidate(nearbyProvider),
      ),
      data: (nearby) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncMarkers(nearby.restaurants);
        });
        if (nearby.position == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Location unavailable',
                      style: theme.textTheme.titleLarge,),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Allow location access to see restaurants near you.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => ref.invalidate(nearbyProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final me = LatLng(
          nearby.position!.latitude,
          nearby.position!.longitude,
        );

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: me, zoom: 14),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              padding: const EdgeInsets.only(bottom: 108, right: 8),
              // Win the gesture arena against the parent TabBarView.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                const Factory<EagerGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
                const Factory<PanGestureRecognizer>(PanGestureRecognizer.new),
                const Factory<ScaleGestureRecognizer>(
                  ScaleGestureRecognizer.new,
                ),
              },
              onTap: (_) => setState(() => _selected = null),
              markers: _markers,
            ),
            if (nearby.restaurants.isEmpty)
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      'No restaurants on the map yet — restaurants created '
                      'while sharing a post appear here.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (_selected != null)
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: 96,
                child: _RestaurantPreviewCard(restaurant: _selected!),
              ),
          ],
        );
      },
    );
  }
}

class _RestaurantPreviewCard extends StatelessWidget {
  const _RestaurantPreviewCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = restaurant.averageRating;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(Routes.restaurantPath(restaurant.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: restaurant.logoUrl != null
                    ? CachedNetworkImageProvider(restaurant.logoUrl!)
                    : null,
                child: restaurant.logoUrl == null
                    ? const Icon(
                        Icons.storefront_outlined,
                        color: AppColors.primaryDark,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    ClaimStatusBadge(restaurant: restaurant),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (rating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.ratingStar,
                          ),
                          Text(
                            ' ${rating.toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text('  ·  ', style: theme.textTheme.bodySmall),
                        ],
                        Flexible(
                          child: Text(
                            restaurant.city ?? 'View profile',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

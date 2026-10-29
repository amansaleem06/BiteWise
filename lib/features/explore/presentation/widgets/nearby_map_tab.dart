import 'dart:async';

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

/// Used when GPS is denied or times out so the map still renders.
const _fallbackMapCenter = LatLng(47.4979, 19.0402);

final nearbyProvider = FutureProvider.autoDispose<NearbyState>((ref) async {
  final position = await LocationService().currentPosition();
  final latitude = position?.latitude ?? _fallbackMapCenter.latitude;
  final longitude = position?.longitude ?? _fallbackMapCenter.longitude;
  final restaurants =
      await ref.read(exploreRepositoryProvider).fetchNearbyRestaurants(
            latitude: latitude,
            longitude: longitude,
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
  GoogleMapController? _mapController;
  LatLng? _lastCameraTarget;

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
              r.isClaimed
                  ? 'Verified Owner'
                  : r.isPendingClaim
                      ? 'Claim under review'
                      : 'Unclaimed listing',
            ].join(' · '),
          ),
          onTap: () => setState(() => _selected = r),
        ),
      );
    }
    if (mounted) setState(() => _markers = next);
  }

  void _showNearbyData(NearbyState nearby) {
    unawaited(_syncMarkers(nearby.restaurants));
    final position = nearby.position;
    final controller = _mapController;
    if (position == null || controller == null) return;

    final target = LatLng(position.latitude, position.longitude);
    if (_lastCameraTarget?.latitude == target.latitude &&
        _lastCameraTarget?.longitude == target.longitude) {
      return;
    }
    _lastCameraTarget = target;
    unawaited(controller.animateCamera(CameraUpdate.newLatLngZoom(target, 14)));
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
    final nearby = nearbyAsync.valueOrNull;
    if (nearby != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNearbyData(nearby);
      });
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _fallbackMapCenter,
            zoom: 12,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            if (nearby != null) _showNearbyData(nearby);
          },
          myLocationEnabled: nearby?.position != null,
          myLocationButtonEnabled: nearby?.position != null,
          zoomControlsEnabled: false,
          padding: const EdgeInsets.only(bottom: 108, right: 8),
          // Win the gesture arena against the parent TabBarView.
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            const Factory<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
            ),
            const Factory<PanGestureRecognizer>(PanGestureRecognizer.new),
            const Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
          },
          onTap: (_) => setState(() => _selected = null),
          markers: _markers,
        ),
        if (nearbyAsync.isLoading)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Finding nearby restaurants…',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          )
        else if (nearbyAsync.hasError)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: [
                    Text(
                      'Couldn’t load nearby restaurants.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(nearbyProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (nearby != null && nearby.position == null)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: [
                    Text(
                      'Location is off — showing a default area. '
                      'Allow location to center the map on you.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(nearbyProvider),
                      child: const Text('Retry location'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (nearby != null && nearby.restaurants.isEmpty)
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

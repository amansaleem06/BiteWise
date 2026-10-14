import 'package:geolocator/geolocator.dart';

enum DiscoveryScope { nearby, city, country, global }

/// User-selected geographic scope for the For You feed.
/// Coordinates are kept in memory only and are never written to the profile.
class DiscoveryLocation {
  const DiscoveryLocation({
    required this.scope,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
  });

  final DiscoveryScope scope;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;

  factory DiscoveryLocation.nearby(Position? position) => DiscoveryLocation(
        scope: DiscoveryScope.nearby,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

  factory DiscoveryLocation.global() =>
      const DiscoveryLocation(scope: DiscoveryScope.global);

  String get label => switch (scope) {
        DiscoveryScope.nearby => 'Nearby',
        DiscoveryScope.city => city ?? 'City',
        DiscoveryScope.country => country ?? 'Country',
        DiscoveryScope.global => 'Global',
      };
}

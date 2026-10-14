import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/location_service.dart';
import '../../domain/entities/discovery_location.dart';

final discoveryLocationProvider =
    AsyncNotifierProvider<DiscoveryLocationController, DiscoveryLocation>(
  DiscoveryLocationController.new,
);

class DiscoveryLocationController extends AsyncNotifier<DiscoveryLocation> {
  static const _scopeKey = 'for_you_discovery_scope';
  static const _cityKey = 'for_you_discovery_city';
  static const _countryKey = 'for_you_discovery_country';

  @override
  Future<DiscoveryLocation> build() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = DiscoveryScope.values.firstWhere(
      (value) => value.name == prefs.getString(_scopeKey),
      orElse: () => DiscoveryScope.global,
    );
    if (scope == DiscoveryScope.nearby) {
      final position =
          await LocationService().currentPosition(requestPermission: false);
      return DiscoveryLocation.nearby(position);
    }
    return DiscoveryLocation(
      scope: scope,
      city: prefs.getString(_cityKey),
      country: prefs.getString(_countryKey),
    );
  }

  Future<bool> chooseNearby() async {
    final position = await LocationService().currentPosition();
    if (position == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopeKey, DiscoveryScope.nearby.name);
    state = AsyncData(DiscoveryLocation.nearby(position));
    return true;
  }

  Future<void> chooseCity(String city, {String? country}) async {
    final value = city.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopeKey, DiscoveryScope.city.name);
    await prefs.setString(_cityKey, value);
    if (country?.trim().isNotEmpty == true) {
      await prefs.setString(_countryKey, country!.trim());
    } else {
      await prefs.remove(_countryKey);
    }
    state = AsyncData(
      DiscoveryLocation(
        scope: DiscoveryScope.city,
        city: value,
        country: country?.trim().isNotEmpty == true ? country!.trim() : null,
      ),
    );
  }

  Future<void> chooseCountry(String country) async {
    final value = country.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopeKey, DiscoveryScope.country.name);
    await prefs.setString(_countryKey, value);
    await prefs.remove(_cityKey);
    state = AsyncData(
      DiscoveryLocation(scope: DiscoveryScope.country, country: value),
    );
  }

  Future<void> chooseGlobal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopeKey, DiscoveryScope.global.name);
    await prefs.remove(_cityKey);
    await prefs.remove(_countryKey);
    state = AsyncData(DiscoveryLocation.global());
  }
}

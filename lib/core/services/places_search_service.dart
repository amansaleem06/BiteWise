import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/maps_config.dart';
import '../errors/app_exception.dart';
import 'location_service.dart';

/// A nearby place suggestion from Google Places Text Search.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  String? get city {
    final parts = address?.split(',') ?? const [];
    if (parts.length < 2) return null;
    return parts[parts.length - 2].trim();
  }
}

/// Keyword → nearby restaurant recommendations via Google Places.
class PlacesSearchService {
  PlacesSearchService({LocationService? location})
      : _location = location ?? LocationService();

  final LocationService _location;

  /// Returns restaurants matching [query], biased to the user's location.
  Future<List<PlaceSuggestion>> searchRestaurants(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final position = await _location.currentPosition();
    final key = MapsConfig.placesApiKey;

    Future<List<PlaceSuggestion>> run(String apiKey) async {
      final params = <String, String>{
        'query': q,
        'type': 'restaurant',
        'key': apiKey,
      };
      if (position != null) {
        params['location'] = '${position.latitude},${position.longitude}';
        params['radius'] = '12000';
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        params,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final status = body['status'] as String? ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        throw PlacesApiException(status, body['error_message'] as String?);
      }

      final results = body['results'] as List<dynamic>? ?? const [];
      return results.take(12).map((raw) {
        final m = raw as Map<String, dynamic>;
        final geo = m['geometry'] as Map<String, dynamic>?;
        final loc = geo?['location'] as Map<String, dynamic>?;
        return PlaceSuggestion(
          placeId: m['place_id'] as String? ?? '',
          name: m['name'] as String? ?? '',
          address: m['formatted_address'] as String?,
          latitude: (loc?['lat'] as num?)?.toDouble(),
          longitude: (loc?['lng'] as num?)?.toDouble(),
        );
      }).where((p) => p.placeId.isNotEmpty && p.name.isNotEmpty).toList();
    }

    try {
      return await run(key);
    } on PlacesApiException catch (e) {
      if (e.status == 'REQUEST_DENIED' &&
          key != MapsConfig.placesApiKeyFallback) {
        try {
          return await run(MapsConfig.placesApiKeyFallback);
        } on PlacesApiException catch (e2) {
          throw AppException(
            'Maps restaurant search blocked (${e2.status}). Enable Places API in Google Cloud.',
            code: e2.status,
          );
        }
      }
      throw AppException(
        e.status == 'REQUEST_DENIED'
            ? 'Maps restaurant search blocked. Enable Places API in Google Cloud for this key.'
            : 'Maps search failed (${e.status}).',
        code: e.status,
      );
    }
  }
}

class PlacesApiException implements Exception {
  PlacesApiException(this.status, this.message);
  final String status;
  final String? message;

  @override
  String toString() => 'Places API $status${message != null ? ': $message' : ''}';
}

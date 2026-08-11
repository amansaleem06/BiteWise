import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';
import '../errors/app_exception.dart';
import 'location_service.dart';

/// A nearby place suggestion from Google Places.
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

/// Keyword → nearby restaurant recommendations via Places API (New).
class PlacesSearchService {
  PlacesSearchService({LocationService? location})
      : _location = location ?? LocationService();

  final LocationService _location;

  /// Returns restaurants matching [query], biased to the user's location.
  Future<List<PlaceSuggestion>> searchRestaurants(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final position = await _location.currentPosition();
    final keys = MapsConfig.placesApiKeys;
    PlacesApiException? last;

    for (final apiKey in keys) {
      try {
        return await _searchTextNew(q, apiKey, position);
      } on PlacesApiException catch (e) {
        last = e;
        debugPrint('Places key denied/failed (${e.status}): ${e.message}');
        // Try next key for auth / enablement issues.
        if (e.status == 'REQUEST_DENIED' ||
            e.status == 'PERMISSION_DENIED' ||
            e.status == 'API_KEY_INVALID') {
          continue;
        }
        break;
      }
    }

    final detail = last?.message?.trim();
    throw AppException(
      detail != null && detail.isNotEmpty
          ? detail
          : 'Places search blocked. In Google Cloud: (1) enable Places API (New) '
              'under APIs & Services → Library, (2) create a key with Application '
              'restrictions = None and API restriction = Places API (New) only.',
      code: last?.status,
    );
  }

  Future<List<PlaceSuggestion>> _searchTextNew(
    String query,
    String apiKey,
    Position? position,
  ) async {
    final body = <String, dynamic>{
      'textQuery': query,
      'includedType': 'restaurant',
      'maxResultCount': 12,
    };
    if (position != null) {
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'radius': 12000.0,
        },
      };
    }

    final res = await http
        .post(
          Uri.https('places.googleapis.com', '/v1/places:searchText'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'places.id,places.displayName,places.formattedAddress,places.location',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw PlacesApiException('INVALID_RESPONSE', 'Unexpected Places response');
    }

    if (res.statusCode != 200) {
      final err = decoded['error'] as Map<String, dynamic>?;
      final status = (err?['status'] as String?) ?? 'HTTP_${res.statusCode}';
      final message = err?['message'] as String?;
      throw PlacesApiException(status, message);
    }

    final places = decoded['places'] as List<dynamic>? ?? const [];
    return places.map((raw) {
      final m = raw as Map<String, dynamic>;
      final display = m['displayName'] as Map<String, dynamic>?;
      final loc = m['location'] as Map<String, dynamic>?;
      var id = m['id'] as String? ?? '';
      if (id.startsWith('places/')) id = id.substring('places/'.length);
      return PlaceSuggestion(
        placeId: id,
        name: (display?['text'] as String?) ?? '',
        address: m['formattedAddress'] as String?,
        latitude: (loc?['latitude'] as num?)?.toDouble(),
        longitude: (loc?['longitude'] as num?)?.toDouble(),
      );
    }).where((p) => p.placeId.isNotEmpty && p.name.isNotEmpty).toList();
  }
}

class PlacesApiException implements Exception {
  PlacesApiException(this.status, this.message);
  final String status;
  final String? message;

  @override
  String toString() =>
      'Places API $status${message != null ? ': $message' : ''}';
}

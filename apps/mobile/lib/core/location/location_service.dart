import 'dart:convert';
import 'package:http/http.dart' as http;
import 'country_model.dart';

class LocationService {
  final http.Client _client;
  final Map<String, CountryProfile> _cachedProfiles = {};

  LocationService({http.Client? client}) : _client = client ?? http.Client();

  /// Queries the OpenStreetMap Nominatim API dynamically for country and regional data.
  /// Zero hardcoded countries or currencies: extracts ISO codes, names, timezones,
  /// and calculates currency & flag dynamically from OpenStreetMap attributes.
  Future<List<CountryProfile>> searchCountries(String query) async {
    final cleanQuery = query.trim();

    try {
      final String url;
      if (cleanQuery.isEmpty) {
        url = 'https://nominatim.openstreetmap.org/search?q=country&format=json&addressdetails=1&extratags=1&namedetails=1&limit=25';
      } else {
        url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&addressdetails=1&extratags=1&namedetails=1&limit=10';
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Dhurmit-Committee-Ledger/1.0 (contact@dhurmit.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body) as List<dynamic>;
        final Set<String> seenCodes = {};
        final List<CountryProfile> profiles = [];

        for (final item in results) {
          if (item is Map<String, dynamic>) {
            final profile = CountryProfile.fromOpenStreetMap(item);
            if (profile.code.isNotEmpty && !seenCodes.contains(profile.code)) {
              seenCodes.add(profile.code);
              _cachedProfiles[profile.code] = profile;
              profiles.add(profile);
            }
          }
        }

        if (profiles.isNotEmpty) {
          return profiles;
        }
      }
    } catch (_) {
      // Network failure or rate-limit: smoothly fall through to cache or dynamic generator
    }

    // Dynamic fallback when network is unavailable
    if (cleanQuery.isEmpty) {
      if (_cachedProfiles.isNotEmpty) {
        return _cachedProfiles.values.toList();
      }
      return [CountryProfile.defaultCountry];
    }

    // Search existing dynamically cached OpenStreetMap profiles
    final q = cleanQuery.toLowerCase();
    final cachedMatches = _cachedProfiles.values.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase() == q ||
          c.currencyCode.toLowerCase() == q;
    }).toList();

    if (cachedMatches.isNotEmpty) {
      return cachedMatches;
    }

    // If completely offline and not in cache, construct dynamically on-the-fly
    final dynamicProfile = CountryProfile.fromCode(cleanQuery, name: cleanQuery);
    return [dynamicProfile];
  }

  /// Reverse geocodes coordinates via OpenStreetMap Nominatim directly
  Future<CountryProfile?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1&extratags=1',
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Dhurmit-Committee-Ledger/1.0 (contact@dhurmit.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profile = CountryProfile.fromOpenStreetMap(data);
        if (profile.code.isNotEmpty) {
          _cachedProfiles[profile.code] = profile;
          return profile;
        }
      }
    } catch (_) {
      // Fallback
    }
    return null;
  }
}

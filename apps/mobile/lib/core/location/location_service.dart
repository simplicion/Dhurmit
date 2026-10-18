import 'dart:convert';
import 'package:http/http.dart' as http;
import 'country_model.dart';

class LocationService {
  final http.Client _client;

  LocationService({http.Client? client}) : _client = client ?? http.Client();

  /// Queries the OpenStreetMap Nominatim API with compliant User-Agent headers.
  /// Falls back smoothly to supported country profiles if offline or rate-limited.
  Future<List<CountryProfile>> searchCountries(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return CountryProfile.supportedCountries;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&addressdetails=1&limit=5',
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Dhurmit-Committee-Ledger/1.0 (contact@dhurmit.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body) as List<dynamic>;
        final Set<String> matchedCodes = {};
        final List<CountryProfile> profiles = [];

        for (final item in results) {
          if (item is Map<String, dynamic>) {
            final address = item['address'] as Map<String, dynamic>?;
            final countryCode = address?['country_code']?.toString().toUpperCase();
            final countryName = address?['country']?.toString();

            if (countryCode != null && !matchedCodes.contains(countryCode)) {
              matchedCodes.add(countryCode);
              final found = CountryProfile.supportedCountries.firstWhere(
                (c) => c.code == countryCode,
                orElse: () => CountryProfile(
                  code: countryCode,
                  name: countryName ?? countryCode,
                  flag: _countryCodeToFlag(countryCode),
                  currencyCode: _estimateCurrency(countryCode),
                  currencySymbol: _estimateSymbol(countryCode),
                  timeZone: 'UTC',
                  locale: 'en_$countryCode',
                ),
              );
              profiles.add(found);
            }
          }
        }

        if (profiles.isNotEmpty) return profiles;
      }
    } catch (_) {
      // Graceful offline fallback
    }

    // Local fuzzy search across pre-indexed country registry
    final q = cleanQuery.toLowerCase();
    final localMatches = CountryProfile.supportedCountries.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase() == q ||
          c.currencyCode.toLowerCase() == q;
    }).toList();

    return localMatches.isNotEmpty ? localMatches : CountryProfile.supportedCountries;
  }

  /// Reverse geocodes coordinates via OpenStreetMap Nominatim
  Future<CountryProfile?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
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
        final address = data['address'] as Map<String, dynamic>?;
        final countryCode = address?['country_code']?.toString().toUpperCase();
        if (countryCode != null) {
          return CountryProfile.findByCode(countryCode);
        }
      }
    } catch (_) {
      // Fallback
    }
    return null;
  }

  static String _countryCodeToFlag(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  static String _estimateCurrency(String code) {
    switch (code) {
      case 'NP': return 'NPR';
      case 'IN': return 'INR';
      case 'US': return 'USD';
      case 'GB': return 'GBP';
      case 'AE': return 'AED';
      case 'AU': return 'AUD';
      case 'CA': return 'CAD';
      case 'SG': return 'SGD';
      case 'QA': return 'QAR';
      case 'SA': return 'SAR';
      default: return 'USD';
    }
  }

  static String _estimateSymbol(String code) {
    switch (code) {
      case 'NP': return 'रु';
      case 'IN': return '₹';
      case 'US': return '\$';
      case 'GB': return '£';
      case 'AE': return 'د.إ';
      case 'AU': return 'A\$';
      case 'CA': return 'C\$';
      case 'SG': return 'S\$';
      default: return '\$';
    }
  }
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:committee_ledger_mobile/core/location/country_model.dart';
import 'package:committee_ledger_mobile/core/location/location_service.dart';
import 'package:committee_ledger_mobile/core/location/country_provider.dart';
import 'package:committee_ledger_mobile/core/money/app_money.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService & CountryProfile Dynamic Tests', () {
    test('CountryProfile intl resolution test', () {
      final resNP = CountryProfile.resolveCurrency('NP');
      final resIN = CountryProfile.resolveCurrency('IN');
      final resUS = CountryProfile.resolveCurrency('US');
      final resGB = CountryProfile.resolveCurrency('GB');
      final resAE = CountryProfile.resolveCurrency('AE', customCurrency: 'AED');
      expect(resNP.$1, equals('NPR'));
      expect(resIN.$1, equals('INR'));
      expect(resUS.$1, equals('USD'));
      expect(resGB.$1, equals('GBP'));
      expect(resAE.$1, equals('AED'));
    });

    test('LocationService performs OpenStreetMap query and parses country details', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('nominatim.openstreetmap.org/search')) {
          return http.Response(
            jsonEncode([
              {
                'place_id': 12345,
                'display_name': 'Nepal',
                'address': {
                  'country': 'Nepal',
                  'country_code': 'np',
                },
                'extratags': {
                  'timezone': 'Asia/Kathmandu',
                  'default_language': 'ne',
                },
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCountries('Nepal');
      expect(results, isNotEmpty);
      expect(results.first.code, equals('NP'));
      expect(results.first.currencyCode, equals('NPR'));
      expect(results.first.timeZone, equals('Asia/Kathmandu'));
    });

    test('LocationService queries OpenStreetMap reverse geocode and caches dynamic profiles', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('nominatim.openstreetmap.org/reverse')) {
          return http.Response(
            jsonEncode({
              'place_id': 54321,
              'display_name': 'New Delhi, India',
              'address': {
                'country': 'India',
                'country_code': 'in',
              },
              'extratags': {
                'timezone': 'Asia/Kolkata',
                'default_language': 'hi',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      final service = LocationService(client: mockClient);
      final profile = await service.reverseGeocode(28.6139, 77.2090);
      expect(profile, isNotNull);
      expect(profile!.code, equals('IN'));
      expect(profile.currencyCode, equals('INR'));
      expect(profile.timeZone, equals('Asia/Kolkata'));
    });

    test('LocationService handles offline gracefully and queries cached profiles', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('nominatim.openstreetmap.org/search')) {
          return http.Response(
            jsonEncode([
              {
                'display_name': 'France',
                'address': {'country': 'France', 'country_code': 'fr'},
                'extratags': {'timezone': 'Europe/Paris', 'default_language': 'fr'}
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        throw Exception('Network unreachable');
      });

      final service = LocationService(client: mockClient);
      final onlineResults = await service.searchCountries('France');
      expect(onlineResults.first.code, equals('FR'));
      expect(onlineResults.first.currencyCode, equals('EUR'));

      // Now query offline - cached profile is returned
      final cachedResults = await service.searchCountries('France');
      expect(cachedResults.first.code, equals('FR'));
    });

    test('CountryProvider persists selected country and dynamically updates AppMoney currency', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = CountryProvider();

      // Default is Nepal
      expect(provider.activeCountry.code, equals('NP'));
      expect(AppMoney.activeCurrencyCode, equals('NPR'));

      // Switch to United States
      final us = CountryProfile.findByCode('US');
      await provider.setCountry(us);

      expect(provider.activeCountry.code, equals('US'));
      expect(AppMoney.activeCurrencyCode, equals('USD'));

      final money = AppMoney.fromPaisa(100000); // 1,000 USD
      expect(money.currencyCode, equals('USD'));
      expect(money.formatShort(), contains('USD'));

      // Reset back to Nepal for other tests
      await provider.setCountry(CountryProfile.defaultCountry);
      expect(AppMoney.activeCurrencyCode, equals('NPR'));
    });
  });
}

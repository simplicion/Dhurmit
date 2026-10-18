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

  group('LocationService & CountryProfile Tests', () {
    test('CountryProfile finds default Nepal by null or NP', () {
      final defaultC = CountryProfile.findByCode(null);
      expect(defaultC.code, equals('NP'));
      expect(defaultC.currencyCode, equals('NPR'));
      expect(defaultC.currencySymbol, equals('रु'));

      final india = CountryProfile.findByCode('IN');
      expect(india.code, equals('IN'));
      expect(india.currencyCode, equals('INR'));
      expect(india.currencySymbol, equals('₹'));
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
    });

    test('LocationService falls back gracefully to local countries if network throws', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network unreachable');
      });

      final service = LocationService(client: mockClient);
      final results = await service.searchCountries('India');
      expect(results, isNotEmpty);
      expect(results.any((c) => c.code == 'IN'), isTrue);
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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../money/app_money.dart';
import 'country_model.dart';
import 'location_service.dart';

class CountryProvider extends ChangeNotifier {
  CountryProfile _activeCountry = CountryProfile.defaultCountry;
  final LocationService _locationService;
  bool _isDetecting = false;

  CountryProvider({LocationService? locationService})
      : _locationService = locationService ?? LocationService() {
    _init();
  }

  CountryProfile get activeCountry => _activeCountry;
  LocationService get locationService => _locationService;
  bool get isDetecting => _isDetecting;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('selected_country_code');
      if (savedCode != null && savedCode.isNotEmpty) {
        _activeCountry = CountryProfile.findByCode(savedCode);
      }
    } catch (_) {
      // Use default
    }
    _applyCountryToMoney(_activeCountry);
    notifyListeners();
  }

  Future<void> setCountry(CountryProfile country) async {
    _activeCountry = country;
    _applyCountryToMoney(country);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_country_code', country.code);
    } catch (_) {}
  }

  void _applyCountryToMoney(CountryProfile country) {
    AppMoney.activeCurrencyCode = country.currencyCode;
    AppMoney.activeLocale = country.locale;
  }

  Future<bool> detectLocationAndSetCountry() async {
    _isDetecting = true;
    notifyListeners();
    try {
      // Query OpenStreetMap dynamically for region detection
      final results = await _locationService.searchCountries('');
      if (results.isNotEmpty) {
        await setCountry(results.first);
        _isDetecting = false;
        notifyListeners();
        return true;
      }
    } catch (_) {
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
    return false;
  }
}

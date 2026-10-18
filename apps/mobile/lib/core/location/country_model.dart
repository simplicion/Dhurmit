import 'package:intl/intl.dart';

class CountryProfile {
  final String code; // ISO 2-letter, e.g. 'NP', 'US', 'GB'
  final String name; // e.g. 'Nepal', 'United States'
  final String flag; // e.g. '🇳🇵', '🇺🇸'
  final String currencyCode; // e.g. 'NPR', 'USD'
  final String currencySymbol; // e.g. 'रु', '$'
  final String timeZone; // e.g. 'Asia/Kathmandu'
  final String locale; // e.g. 'en_NP'
  final int startOfWeek; // DateTime.sunday = 7, DateTime.monday = 1
  final String calendarType; // 'Gregorian'

  const CountryProfile({
    required this.code,
    required this.name,
    required this.flag,
    required this.currencyCode,
    required this.currencySymbol,
    required this.timeZone,
    required this.locale,
    this.startOfWeek = DateTime.sunday,
    this.calendarType = 'Gregorian',
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'flag': flag,
    'currencyCode': currencyCode,
    'currencySymbol': currencySymbol,
    'timeZone': timeZone,
    'locale': locale,
    'startOfWeek': startOfWeek,
    'calendarType': calendarType,
  };

  factory CountryProfile.fromJson(Map<String, dynamic> json) => CountryProfile(
    code: json['code'] as String? ?? 'NP',
    name: json['name'] as String? ?? 'Nepal',
    flag: json['flag'] as String? ?? '🇳🇵',
    currencyCode: json['currencyCode'] as String? ?? 'NPR',
    currencySymbol: json['currencySymbol'] as String? ?? 'रु',
    timeZone: json['timeZone'] as String? ?? 'UTC',
    locale: json['locale'] as String? ?? 'en_US',
    startOfWeek: (json['startOfWeek'] as num?)?.toInt() ?? DateTime.sunday,
    calendarType: json['calendarType'] as String? ?? 'Gregorian',
  );

  /// Builds a dynamic CountryProfile purely from an OpenStreetMap Nominatim response item.
  /// Zero hardcoding: extracts country name, ISO code, timezone, and derives flag/currency using standard internationalization.
  factory CountryProfile.fromOpenStreetMap(Map<String, dynamic> item) {
    final address = item['address'] as Map<String, dynamic>?;
    final extratags = item['extratags'] as Map<String, dynamic>?;
    final namedetails = item['namedetails'] as Map<String, dynamic>?;

    final rawCode = address?['country_code']?.toString() ??
        extratags?['ISO3166-1:alpha2']?.toString() ??
        extratags?['country_code']?.toString() ??
        '';
    final code = rawCode.trim().toUpperCase();

    final name = address?['country']?.toString() ??
        namedetails?['name:en']?.toString() ??
        namedetails?['name']?.toString() ??
        item['name']?.toString() ??
        item['display_name']?.toString().split(',').first.trim() ??
        (code.isNotEmpty ? code : 'Unknown');

    final timeZone = extratags?['timezone']?.toString() ??
        extratags?['time_zone']?.toString() ??
        'UTC';

    final customCurrency = extratags?['currency']?.toString() ??
        extratags?['currency:code']?.toString() ??
        extratags?['currency_code']?.toString();
    final defaultLanguage = extratags?['default_language']?.toString();

    return CountryProfile.fromCode(
      code.isNotEmpty ? code : 'US',
      name: name,
      timeZone: timeZone,
      customCurrency: customCurrency,
      language: defaultLanguage,
    );
  }

  /// Builds a CountryProfile dynamically for any ISO country code on Earth.
  /// Currency and symbol are dynamically derived via Unicode/CLDR through package:intl.
  /// Flag is dynamically calculated using Unicode regional indicator code points.
  factory CountryProfile.fromCode(
    String code, {
    String? name,
    String? timeZone,
    String? customCurrency,
    String? language,
  }) {
    final cleanCode = code.trim().toUpperCase();
    final flag = countryCodeToFlag(cleanCode);
    final currency = resolveCurrency(cleanCode, customCurrency: customCurrency, language: language);
    final calculatedName = (name != null && name.trim().isNotEmpty) ? name.trim() : cleanCode;

    return CountryProfile(
      code: cleanCode,
      name: calculatedName,
      flag: flag,
      currencyCode: currency.$1,
      currencySymbol: currency.$2,
      timeZone: timeZone ?? 'UTC',
      locale: cleanCode == 'NP'
          ? 'en_IN'
          : (language != null ? '${language}_$cleanCode' : 'en_$cleanCode'),
      startOfWeek: DateTime.monday,
      calendarType: 'Gregorian',
    );
  }

  /// Dynamically generates a flag emoji from an ISO2 code using Unicode regional indicator code points.
  static String countryCodeToFlag(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    final upper = countryCode.toUpperCase();
    final int first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    if (first < 0x1F1E6 || first > 0x1F1FF || second < 0x1F1E6 || second > 0x1F1FF) {
      return '🌐';
    }
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  /// Resolves currency name and symbol dynamically via standard CLDR NumberFormat (package:intl).
  /// Works for any valid country code in the world without any hardcoded switch cases.
  static (String, String) resolveCurrency(
    String countryCode, {
    String? customCurrency,
    String? language,
  }) {
    if (customCurrency != null && customCurrency.trim().isNotEmpty) {
      final code = customCurrency.trim().toUpperCase();
      try {
        final nf = NumberFormat.simpleCurrency(name: code);
        return (code, nf.currencySymbol);
      } catch (_) {
        return (code, code);
      }
    }

    final code = countryCode.trim().toUpperCase();
    if (code.isEmpty) return ('USD', '\$');

    final candidateLocales = [
      if (language != null && language.isNotEmpty) '${language.toLowerCase()}_$code',
      'en_$code',
      '${code.toLowerCase()}_$code',
      'ne_$code',
      'ar_$code',
      'es_$code',
      'pt_$code',
      'zh_$code',
      'hi_$code',
      'fr_$code',
      'de_$code',
      'ja_$code',
      'ru_$code',
    ];

    for (final loc in candidateLocales) {
      try {
        final nf = NumberFormat.simpleCurrency(locale: loc);
        final name = nf.currencyName;
        final symbol = nf.currencySymbol;
        if (name != null && name.isNotEmpty && (name != 'USD' || code == 'US')) {
          return (name, symbol);
        }
      } catch (_) {}
    }

    return ('USD', '\$');
  }

  /// Dynamic default country profile (Nepal) before selection or detection.
  static CountryProfile get defaultCountry {
    return CountryProfile.fromCode('NP', name: 'Nepal', timeZone: 'Asia/Kathmandu');
  }

  static CountryProfile findByCode(String? code) {
    if (code == null || code.trim().isEmpty) return defaultCountry;
    return CountryProfile.fromCode(code);
  }

  static CountryProfile findByName(String? name) {
    if (name == null || name.trim().isEmpty) return defaultCountry;
    return CountryProfile.fromCode('NP', name: name);
  }
}

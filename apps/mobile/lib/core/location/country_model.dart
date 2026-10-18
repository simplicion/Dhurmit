class CountryProfile {
  final String code; // ISO 2-letter, e.g. 'NP'
  final String name; // e.g. 'Nepal'
  final String flag; // e.g. '🇳🇵'
  final String currencyCode; // e.g. 'NPR'
  final String currencySymbol; // e.g. 'रु'
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
    timeZone: json['timeZone'] as String? ?? 'Asia/Kathmandu',
    locale: json['locale'] as String? ?? 'en_NP',
    startOfWeek: (json['startOfWeek'] as num?)?.toInt() ?? DateTime.sunday,
    calendarType: json['calendarType'] as String? ?? 'Gregorian',
  );

  static const List<CountryProfile> supportedCountries = [
    CountryProfile(
      code: 'NP',
      name: 'Nepal',
      flag: '🇳🇵',
      currencyCode: 'NPR',
      currencySymbol: 'रु',
      timeZone: 'Asia/Kathmandu',
      locale: 'en_NP',
      startOfWeek: DateTime.sunday,
    ),
    CountryProfile(
      code: 'IN',
      name: 'India',
      flag: '🇮🇳',
      currencyCode: 'INR',
      currencySymbol: '₹',
      timeZone: 'Asia/Kolkata',
      locale: 'en_IN',
      startOfWeek: DateTime.monday,
    ),
    CountryProfile(
      code: 'US',
      name: 'United States',
      flag: '🇺🇸',
      currencyCode: 'USD',
      currencySymbol: '\$',
      timeZone: 'America/New_York',
      locale: 'en_US',
      startOfWeek: DateTime.sunday,
    ),
    CountryProfile(
      code: 'GB',
      name: 'United Kingdom',
      flag: '🇬🇧',
      currencyCode: 'GBP',
      currencySymbol: '£',
      timeZone: 'Europe/London',
      locale: 'en_GB',
      startOfWeek: DateTime.monday,
    ),
    CountryProfile(
      code: 'AE',
      name: 'United Arab Emirates',
      flag: '🇦🇪',
      currencyCode: 'AED',
      currencySymbol: 'د.إ',
      timeZone: 'Asia/Dubai',
      locale: 'en_AE',
      startOfWeek: DateTime.monday,
    ),
    CountryProfile(
      code: 'AU',
      name: 'Australia',
      flag: '🇦🇺',
      currencyCode: 'AUD',
      currencySymbol: 'A\$',
      timeZone: 'Australia/Sydney',
      locale: 'en_AU',
      startOfWeek: DateTime.monday,
    ),
    CountryProfile(
      code: 'CA',
      name: 'Canada',
      flag: '🇨🇦',
      currencyCode: 'CAD',
      currencySymbol: 'C\$',
      timeZone: 'America/Toronto',
      locale: 'en_CA',
      startOfWeek: DateTime.sunday,
    ),
    CountryProfile(
      code: 'SG',
      name: 'Singapore',
      flag: '🇸🇬',
      currencyCode: 'SGD',
      currencySymbol: 'S\$',
      timeZone: 'Asia/Singapore',
      locale: 'en_SG',
      startOfWeek: DateTime.monday,
    ),
    CountryProfile(
      code: 'QA',
      name: 'Qatar',
      flag: '🇶🇦',
      currencyCode: 'QAR',
      currencySymbol: 'ر.ق',
      timeZone: 'Asia/Qatar',
      locale: 'en_QA',
      startOfWeek: DateTime.sunday,
    ),
    CountryProfile(
      code: 'SA',
      name: 'Saudi Arabia',
      flag: '🇸🇦',
      currencyCode: 'SAR',
      currencySymbol: '﷼',
      timeZone: 'Asia/Riyadh',
      locale: 'en_SA',
      startOfWeek: DateTime.sunday,
    ),
    CountryProfile(
      code: 'DE',
      name: 'Germany (EU)',
      flag: '🇩🇪',
      currencyCode: 'EUR',
      currencySymbol: '€',
      timeZone: 'Europe/Berlin',
      locale: 'de_DE',
      startOfWeek: DateTime.monday,
    ),
    CountryProfile(
      code: 'JP',
      name: 'Japan',
      flag: '🇯🇵',
      currencyCode: 'JPY',
      currencySymbol: '¥',
      timeZone: 'Asia/Tokyo',
      locale: 'ja_JP',
      startOfWeek: DateTime.sunday,
    ),
  ];

  static CountryProfile defaultCountry = supportedCountries.first;

  static CountryProfile findByCode(String? code) {
    if (code == null) return defaultCountry;
    final upper = code.trim().toUpperCase();
    return supportedCountries.firstWhere(
      (c) => c.code.toUpperCase() == upper,
      orElse: () => defaultCountry,
    );
  }

  static CountryProfile findByName(String? name) {
    if (name == null) return defaultCountry;
    final clean = name.trim().toLowerCase();
    return supportedCountries.firstWhere(
      (c) => c.name.toLowerCase().contains(clean) || clean.contains(c.name.toLowerCase()),
      orElse: () => defaultCountry,
    );
  }
}

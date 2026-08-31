import 'dart:ui' show PlatformDispatcher;

import 'package:intl/intl.dart';

/// ISO 4217 currency the diner picks when posting a price.
class AppCurrency {
  const AppCurrency(this.code, this.name);

  final String code;
  final String name;

  String get symbol {
    try {
      final sym = NumberFormat.simpleCurrency(name: code).currencySymbol.trim();
      return sym.isEmpty ? code : sym;
    } catch (_) {
      return code;
    }
  }

  String get menuLabel => '$code · $symbol';

  String get pickerLabel => '$name ($code)';
}

/// Device default plus a full circulating-fiat catalog for the create picker.
abstract final class LocaleCurrency {
  /// ISO code from the device region (HUF in Hungary, USD in the US, …).
  static String get code => deviceDefault.code;

  static String get symbol => deviceDefault.symbol;

  static String get inputPrefix => '${deviceDefault.symbol} ';

  static AppCurrency get deviceDefault {
    final format = NumberFormat.simpleCurrency(locale: _localeTag);
    final detected = format.currencyName;
    if (detected != null && detected.isNotEmpty) {
      return byCode(detected) ?? AppCurrency(detected, detected);
    }
    return byCode('USD')!;
  }

  static AppCurrency? byCode(String code) {
    final upper = code.toUpperCase();
    for (final c in all) {
      if (c.code == upper) return c;
    }
    return null;
  }

  static String get _localeTag {
    final locale = PlatformDispatcher.instance.locale;
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '${locale.languageCode}_$country';
    }
    return locale.languageCode;
  }

  /// Shown first in the picker. Hungarian Forint is always included.
  static List<AppCurrency> get suggested {
    final codes = <String>{
      'HUF',
      deviceDefault.code,
      'EUR',
      'USD',
      'GBP',
      'PLN',
      'CZK',
      'RON',
      'CHF',
    };
    return [
      for (final code in codes)
        if (byCode(code) != null) byCode(code)!,
    ];
  }

  static const all = <AppCurrency>[
    AppCurrency('AED', 'UAE Dirham'),
    AppCurrency('AFN', 'Afghan Afghani'),
    AppCurrency('ALL', 'Albanian Lek'),
    AppCurrency('AMD', 'Armenian Dram'),
    AppCurrency('ANG', 'Netherlands Antillean Guilder'),
    AppCurrency('AOA', 'Angolan Kwanza'),
    AppCurrency('ARS', 'Argentine Peso'),
    AppCurrency('AUD', 'Australian Dollar'),
    AppCurrency('AWG', 'Aruban Florin'),
    AppCurrency('AZN', 'Azerbaijani Manat'),
    AppCurrency('BAM', 'Bosnia-Herzegovina Convertible Mark'),
    AppCurrency('BBD', 'Barbadian Dollar'),
    AppCurrency('BDT', 'Bangladeshi Taka'),
    AppCurrency('BGN', 'Bulgarian Lev'),
    AppCurrency('BHD', 'Bahraini Dinar'),
    AppCurrency('BIF', 'Burundian Franc'),
    AppCurrency('BMD', 'Bermudian Dollar'),
    AppCurrency('BND', 'Brunei Dollar'),
    AppCurrency('BOB', 'Bolivian Boliviano'),
    AppCurrency('BRL', 'Brazilian Real'),
    AppCurrency('BSD', 'Bahamian Dollar'),
    AppCurrency('BTN', 'Bhutanese Ngultrum'),
    AppCurrency('BWP', 'Botswana Pula'),
    AppCurrency('BYN', 'Belarusian Ruble'),
    AppCurrency('BZD', 'Belize Dollar'),
    AppCurrency('CAD', 'Canadian Dollar'),
    AppCurrency('CDF', 'Congolese Franc'),
    AppCurrency('CHF', 'Swiss Franc'),
    AppCurrency('CLP', 'Chilean Peso'),
    AppCurrency('CNY', 'Chinese Yuan'),
    AppCurrency('COP', 'Colombian Peso'),
    AppCurrency('CRC', 'Costa Rican Colón'),
    AppCurrency('CUP', 'Cuban Peso'),
    AppCurrency('CVE', 'Cape Verdean Escudo'),
    AppCurrency('CZK', 'Czech Koruna'),
    AppCurrency('DJF', 'Djiboutian Franc'),
    AppCurrency('DKK', 'Danish Krone'),
    AppCurrency('DOP', 'Dominican Peso'),
    AppCurrency('DZD', 'Algerian Dinar'),
    AppCurrency('EGP', 'Egyptian Pound'),
    AppCurrency('ERN', 'Eritrean Nakfa'),
    AppCurrency('ETB', 'Ethiopian Birr'),
    AppCurrency('EUR', 'Euro'),
    AppCurrency('FJD', 'Fijian Dollar'),
    AppCurrency('FKP', 'Falkland Islands Pound'),
    AppCurrency('GBP', 'British Pound'),
    AppCurrency('GEL', 'Georgian Lari'),
    AppCurrency('GHS', 'Ghanaian Cedi'),
    AppCurrency('GIP', 'Gibraltar Pound'),
    AppCurrency('GMD', 'Gambian Dalasi'),
    AppCurrency('GNF', 'Guinean Franc'),
    AppCurrency('GTQ', 'Guatemalan Quetzal'),
    AppCurrency('GYD', 'Guyanese Dollar'),
    AppCurrency('HKD', 'Hong Kong Dollar'),
    AppCurrency('HNL', 'Honduran Lempira'),
    AppCurrency('HTG', 'Haitian Gourde'),
    AppCurrency('HUF', 'Hungarian Forint'),
    AppCurrency('IDR', 'Indonesian Rupiah'),
    AppCurrency('ILS', 'Israeli New Shekel'),
    AppCurrency('INR', 'Indian Rupee'),
    AppCurrency('IQD', 'Iraqi Dinar'),
    AppCurrency('IRR', 'Iranian Rial'),
    AppCurrency('ISK', 'Icelandic Króna'),
    AppCurrency('JMD', 'Jamaican Dollar'),
    AppCurrency('JOD', 'Jordanian Dinar'),
    AppCurrency('JPY', 'Japanese Yen'),
    AppCurrency('KES', 'Kenyan Shilling'),
    AppCurrency('KGS', 'Kyrgyzstani Som'),
    AppCurrency('KHR', 'Cambodian Riel'),
    AppCurrency('KMF', 'Comorian Franc'),
    AppCurrency('KRW', 'South Korean Won'),
    AppCurrency('KWD', 'Kuwaiti Dinar'),
    AppCurrency('KYD', 'Cayman Islands Dollar'),
    AppCurrency('KZT', 'Kazakhstani Tenge'),
    AppCurrency('LAK', 'Lao Kip'),
    AppCurrency('LBP', 'Lebanese Pound'),
    AppCurrency('LKR', 'Sri Lankan Rupee'),
    AppCurrency('LRD', 'Liberian Dollar'),
    AppCurrency('LSL', 'Lesotho Loti'),
    AppCurrency('LYD', 'Libyan Dinar'),
    AppCurrency('MAD', 'Moroccan Dirham'),
    AppCurrency('MDL', 'Moldovan Leu'),
    AppCurrency('MGA', 'Malagasy Ariary'),
    AppCurrency('MKD', 'Macedonian Denar'),
    AppCurrency('MMK', 'Myanmar Kyat'),
    AppCurrency('MNT', 'Mongolian Tögrög'),
    AppCurrency('MOP', 'Macanese Pataca'),
    AppCurrency('MRU', 'Mauritanian Ouguiya'),
    AppCurrency('MUR', 'Mauritian Rupee'),
    AppCurrency('MVR', 'Maldivian Rufiyaa'),
    AppCurrency('MWK', 'Malawian Kwacha'),
    AppCurrency('MXN', 'Mexican Peso'),
    AppCurrency('MYR', 'Malaysian Ringgit'),
    AppCurrency('MZN', 'Mozambican Metical'),
    AppCurrency('NAD', 'Namibian Dollar'),
    AppCurrency('NGN', 'Nigerian Naira'),
    AppCurrency('NIO', 'Nicaraguan Córdoba'),
    AppCurrency('NOK', 'Norwegian Krone'),
    AppCurrency('NPR', 'Nepalese Rupee'),
    AppCurrency('NZD', 'New Zealand Dollar'),
    AppCurrency('OMR', 'Omani Rial'),
    AppCurrency('PAB', 'Panamanian Balboa'),
    AppCurrency('PEN', 'Peruvian Sol'),
    AppCurrency('PGK', 'Papua New Guinean Kina'),
    AppCurrency('PHP', 'Philippine Peso'),
    AppCurrency('PKR', 'Pakistani Rupee'),
    AppCurrency('PLN', 'Polish Zloty'),
    AppCurrency('PYG', 'Paraguayan Guaraní'),
    AppCurrency('QAR', 'Qatari Riyal'),
    AppCurrency('RON', 'Romanian Leu'),
    AppCurrency('RSD', 'Serbian Dinar'),
    AppCurrency('RUB', 'Russian Ruble'),
    AppCurrency('RWF', 'Rwandan Franc'),
    AppCurrency('SAR', 'Saudi Riyal'),
    AppCurrency('SBD', 'Solomon Islands Dollar'),
    AppCurrency('SCR', 'Seychellois Rupee'),
    AppCurrency('SDG', 'Sudanese Pound'),
    AppCurrency('SEK', 'Swedish Krona'),
    AppCurrency('SGD', 'Singapore Dollar'),
    AppCurrency('SHP', 'Saint Helena Pound'),
    AppCurrency('SLE', 'Sierra Leonean Leone'),
    AppCurrency('SOS', 'Somali Shilling'),
    AppCurrency('SRD', 'Surinamese Dollar'),
    AppCurrency('SSP', 'South Sudanese Pound'),
    AppCurrency('STN', 'São Tomé and Príncipe Dobra'),
    AppCurrency('SYP', 'Syrian Pound'),
    AppCurrency('SZL', 'Swazi Lilangeni'),
    AppCurrency('THB', 'Thai Baht'),
    AppCurrency('TJS', 'Tajikistani Somoni'),
    AppCurrency('TMT', 'Turkmenistani Manat'),
    AppCurrency('TND', 'Tunisian Dinar'),
    AppCurrency('TOP', 'Tongan Paʻanga'),
    AppCurrency('TRY', 'Turkish Lira'),
    AppCurrency('TTD', 'Trinidad and Tobago Dollar'),
    AppCurrency('TWD', 'New Taiwan Dollar'),
    AppCurrency('TZS', 'Tanzanian Shilling'),
    AppCurrency('UAH', 'Ukrainian Hryvnia'),
    AppCurrency('UGX', 'Ugandan Shilling'),
    AppCurrency('USD', 'US Dollar'),
    AppCurrency('UYU', 'Uruguayan Peso'),
    AppCurrency('UZS', 'Uzbekistani Som'),
    AppCurrency('VES', 'Venezuelan Bolívar'),
    AppCurrency('VND', 'Vietnamese Dong'),
    AppCurrency('VUV', 'Vanuatu Vatu'),
    AppCurrency('WST', 'Samoan Tala'),
    AppCurrency('XAF', 'Central African CFA Franc'),
    AppCurrency('XCD', 'East Caribbean Dollar'),
    AppCurrency('XOF', 'West African CFA Franc'),
    AppCurrency('XPF', 'CFP Franc'),
    AppCurrency('YER', 'Yemeni Rial'),
    AppCurrency('ZAR', 'South African Rand'),
    AppCurrency('ZMW', 'Zambian Kwacha'),
    AppCurrency('ZWG', 'Zimbabwe Gold'),
  ];
}

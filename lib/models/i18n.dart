import 'i18n_zh.dart';
import 'i18n_en.dart';
import 'i18n_zh_tw.dart';
import 'i18n_ja.dart';
import 'i18n_ko.dart';
import 'i18n_es.dart';
import 'i18n_de.dart';
import 'i18n_fr.dart';
import 'i18n_pt.dart';
import 'i18n_ru.dart';

class I18n {
  static String currentLang = 'zh';

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': i18nZh,
    'en': i18nEn,
    'zh_tw': i18nZhTw,
    'ja': i18nJa,
    'ko': i18nKo,
    'es': i18nEs,
    'de': i18nDe,
    'fr': i18nFr,
    'pt': i18nPt,
    'ru': i18nRu,
  };

  static const Map<String, Map<String, String>> _countryNames = {
    'zh': countriesZh,
    'en': countriesEn,
    'zh_tw': countriesZhTw,
    'ja': countriesJa,
    'ko': countriesKo,
    'es': countriesEs,
    'de': countriesDe,
    'fr': countriesFr,
    'pt': countriesPt,
    'ru': countriesRu,
  };

  static String t(String key, {Map<String, String>? args}) {
    var value = _localizedValues[currentLang]?[key] ??
        _localizedValues['en']?[key] ??
        key;
    if (args != null) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }

  static String countryName(String code) {
    final lang = currentLang;
    return _countryNames[lang]?[code] ??
        _countryNames['en']?[code] ??
        _countryNames['zh']?[code] ??
        code;
  }
}



import 'package:flutter_test/flutter_test.dart';
import 'package:finance_manager/models/i18n.dart';
import 'package:finance_manager/models/app_config.dart';

void main() {
  group('I18n Tests', () {
    setUp(() {
      // 每次测试前重置为默认语言 'zh'
      I18n.currentLang = 'zh';
    });

    test('Translates with default language (zh)', () {
      expect(I18n.t('nav_dashboard'), '看板');
      expect(I18n.t('title_config'), '连接凭证');
      expect(I18n.t('sub_lifetime'), '一次性买断');
      expect(I18n.t('currency_note_none'), '暂无币种');
      expect(I18n.t('kpi_mom'), '环比 ');
    });

    test('Translates with switch language (en)', () {
      I18n.currentLang = 'en';
      expect(I18n.t('nav_dashboard'), 'Dashboard');
      expect(I18n.t('title_config'), 'Connection Credentials');
      expect(I18n.t('sub_lifetime'), 'Lifetime Purchase');
      expect(I18n.t('currency_note_none'), 'No currencies');
      expect(I18n.t('kpi_mom'), 'MoM ');
    });

    test('Translates with new languages (zh_tw, ja, ko, es, de, fr, pt, ru)', () {
      I18n.currentLang = 'zh_tw';
      expect(I18n.t('nav_dashboard'), '看板');
      expect(I18n.t('title_config'), '連接憑證');

      I18n.currentLang = 'ja';
      expect(I18n.t('nav_dashboard'), '看板');
      expect(I18n.t('title_config'), '接続資格情報');

      I18n.currentLang = 'ko';
      expect(I18n.t('nav_dashboard'), '대시보드');
      expect(I18n.t('title_config'), '연결 자격 증명');

      I18n.currentLang = 'es';
      expect(I18n.t('nav_dashboard'), 'Panel');
      expect(I18n.t('title_config'), 'Credenciales de Conexión');

      I18n.currentLang = 'de';
      expect(I18n.t('nav_dashboard'), 'Dashboard');
      expect(I18n.t('title_config'), 'Verbindungsdaten');

      I18n.currentLang = 'fr';
      expect(I18n.t('nav_dashboard'), 'Tableau de bord');
      expect(I18n.t('title_config'), 'Identifiants de connexion');

      I18n.currentLang = 'pt';
      expect(I18n.t('nav_dashboard'), 'Painel');
      expect(I18n.t('title_config'), 'Credenciais de Conexão');

      I18n.currentLang = 'ru';
      expect(I18n.t('nav_dashboard'), 'Панель');
      expect(I18n.t('title_config'), 'Ключи подключения');
    });

    test('I18n.t falls back to English when language is not defined or key is missing', () {
      I18n.currentLang = 'it'; // 没有配置 it
      expect(I18n.t('nav_dashboard'), 'Dashboard'); // 回退到 en 翻译
      expect(I18n.t('non_existent_key_123'), 'non_existent_key_123'); // 两者都没有，回退到 key 名
    });

    test('Replaces placeholder arguments correctly', () {
      // 简体中文测试
      expect(
        I18n.t('kpi_converted_note', args: {'currency': 'USD'}),
        '折合 USD',
      );
      expect(
        I18n.t('currency_note_multiple', args: {'list': 'CNY, EUR'}),
        '多币种: CNY, EUR',
      );

      // 英文测试
      I18n.currentLang = 'en';
      expect(
        I18n.t('kpi_converted_note', args: {'currency': 'EUR'}),
        'Converted to EUR',
      );
      expect(
        I18n.t('currency_note_multiple', args: {'list': 'GBP, CAD'}),
        'Currencies: GBP, CAD',
      );
    });

    test('Falls back to key name if translation key is missing', () {
      expect(I18n.t('non_existent_key_123'), 'non_existent_key_123');
    });

    test('Translates country names and handles fallbacks', () {
      // 中文环境下
      expect(I18n.countryName('CN'), '中国');
      expect(I18n.countryName('US'), '美国');

      // 切换到英文
      I18n.currentLang = 'en';
      expect(I18n.countryName('CN'), 'China');
      expect(I18n.countryName('US'), 'United States');

      // 缺失翻译时的回退机制
      expect(I18n.countryName('UNKNOWN'), 'UNKNOWN');

      // 模拟未配置小语种（如 'it'）下的回退机制，自动回退到英文 'en'
      I18n.currentLang = 'it';
      expect(I18n.countryName('CN'), 'China');
    });
  });

  group('AppConfig Language Serialization Tests', () {
    test('Serializes and deserializes isLanguageUserSet correctly', () {
      const configDefault = AppConfig();
      expect(configDefault.isLanguageUserSet, isFalse);

      final jsonDefault = configDefault.toJson();
      expect(jsonDefault['isLanguageUserSet'], isFalse);

      final fromJsonDefault = AppConfig.fromJson(jsonDefault);
      expect(fromJsonDefault.isLanguageUserSet, isFalse);

      final configUserSet = configDefault.copyWith(isLanguageUserSet: true, language: 'en');
      expect(configUserSet.isLanguageUserSet, isTrue);
      expect(configUserSet.language, 'en');

      final jsonUserSet = configUserSet.toJson();
      expect(jsonUserSet['isLanguageUserSet'], isTrue);
      expect(jsonUserSet['language'], 'en');

      final fromJsonUserSet = AppConfig.fromJson(jsonUserSet);
      expect(fromJsonUserSet.isLanguageUserSet, isTrue);
      expect(fromJsonUserSet.language, 'en');
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models/app_config.dart';
import 'models/i18n.dart';
import 'models/revenue_record.dart';
import 'services/revenue_repository.dart';
import 'pages/dashboard_page.dart';
import 'pages/import_page.dart';
import 'pages/mappings_page.dart';
import 'pages/config_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const FinanceManagerApp());
}

class FinanceManagerApp extends StatelessWidget {
  const FinanceManagerApp({super.key, this.openRepository});

  final Future<RevenueRepository> Function()? openRepository;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff1f7a5c);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Store Finance Desk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff6f7f5),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xffdfe4df)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          isDense: true,
        ),
      ),
      home: FinanceHomePage(openRepository: openRepository),
    );
  }
}

class FinanceHomePage extends StatefulWidget {
  const FinanceHomePage({super.key, this.openRepository});

  final Future<RevenueRepository> Function()? openRepository;

  @override
  State<FinanceHomePage> createState() => _FinanceHomePageState();
}

class _FinanceHomePageState extends State<FinanceHomePage> {
  final _syncStartMonthController = TextEditingController(text: '2026-05');
  final _syncEndMonthController = TextEditingController(text: '2026-05');
  final _appleIssuerController = TextEditingController();
  final _appleKeyController = TextEditingController();
  final _appleVendorController = TextEditingController();
  final _applePrivateKeyController = TextEditingController();
  final _googleBucketController = TextEditingController();
  final _googleServiceAccountController = TextEditingController();
  final _appMappingsController = TextEditingController();

  final _filterStartMonthController = TextEditingController();
  final _filterEndMonthController = TextEditingController();
  final _skuController = TextEditingController();

  String? _startMonthFilter;
  String? _endMonthFilter;
  String? _skuFilter;
  String? _countryFilter;
  String? _rawCurrencyFilter;
  String? _settlementCurrencyFilter;

  bool _showAdvancedFilters = false;
  String _trendMetric = 'net';
  String _rankingTab = 'countries';

  var _tabIndex = 0;
  String _reportCurrency = 'USD';
  String _language = 'zh';
  bool _isLanguageUserSet = false;
  String? _platformFilter;
  String? _appFilter;
  String? _message;
  String? _configMessage;
  String? _mappingsMessage;
  String? _settingsMessage;
  Map<String, double> _customRates = {};
  bool _isSyncing = false;
  bool _isSyncingRates = false;
  bool _isTestingApple = false;
  bool _isTestingGoogle = false;
  bool _isLoading = true;
  late RevenueRepository _repository;

  String _getLastMonthStr() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
  }

  String _getSixMonthsAgoStr() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 6);
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _filterStartMonthController.text = _getSixMonthsAgoStr();
    _filterEndMonthController.text = _getLastMonthStr();
    _startMonthFilter = _filterStartMonthController.text;
    _endMonthFilter = _filterEndMonthController.text;
    _loadRepository();
  }

  @override
  void dispose() {
    _syncStartMonthController.dispose();
    _syncEndMonthController.dispose();
    _appleIssuerController.dispose();
    _appleKeyController.dispose();
    _appleVendorController.dispose();
    _applePrivateKeyController.dispose();
    _googleBucketController.dispose();
    _googleServiceAccountController.dispose();
    _filterStartMonthController.dispose();
    _filterEndMonthController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  List<RevenueRecord> get _filteredRecords {
    final start = _startMonthFilter;
    final end = _endMonthFilter;
    return _repository.records.where((record) {
      final platformOk =
          _platformFilter == null ||
          record.platform.name == _platformFilter!.toLowerCase();
      
      final appOk =
          _appFilter == null || formatAppName(record.appIdentifier, _repository.config.appMappings, _repository.records) == _appFilter;
      
      final skuOk = _skuFilter == null || _skuFilter!.isEmpty ||
          record.productId.toLowerCase().contains(_skuFilter!.toLowerCase());
          
      final countryOk = _countryFilter == null || record.countryCode == _countryFilter;
      
      final rawCurrencyOk = _rawCurrencyFilter == null || record.rawCurrency == _rawCurrencyFilter;
      
      final settlementCurrencyOk = _settlementCurrencyFilter == null || record.settlementCurrency == _settlementCurrencyFilter;
      
      final monthOk =
          (start == null || start.isEmpty || record.reportMonth.compareTo(start) >= 0) &&
          (end == null || end.isEmpty || record.reportMonth.compareTo(end) <= 0);
          
      return platformOk && appOk && skuOk && countryOk && rawCurrencyOk && settlementCurrencyOk && monthOk;
    }).toList()..sort((a, b) {
      final month = b.reportMonth.compareTo(a.reportMonth);
      if (month != 0) {
        return month;
      }
      return b.netAmountCents.compareTo(a.netAmountCents);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    final pages = [
      DashboardPage(
        records: _filteredRecords,
        repository: _repository,
        platformFilter: _platformFilter,
        appFilter: _appFilter,
        skuFilter: _skuFilter,
        countryFilter: _countryFilter,
        rawCurrencyFilter: _rawCurrencyFilter,
        settlementCurrencyFilter: _settlementCurrencyFilter,
        showAdvancedFilters: _showAdvancedFilters,
        trendMetric: _trendMetric,
        rankingTab: _rankingTab,
        reportCurrency: _reportCurrency,
        startMonthController: _filterStartMonthController,
        endMonthController: _filterEndMonthController,
        skuController: _skuController,
        onPlatformChanged: (value) => setState(() => _platformFilter = value),
        onAppChanged: (value) => setState(() => _appFilter = value),
        onSkuChanged: (value) => setState(() => _skuFilter = value),
        onCountryChanged: (value) => setState(() => _countryFilter = value),
        onRawCurrencyChanged: (value) => setState(() => _rawCurrencyFilter = value),
        onSettlementCurrencyChanged: (value) => setState(() => _settlementCurrencyFilter = value),
        onShowAdvancedFiltersChanged: (value) => setState(() => _showAdvancedFilters = value),
        onTrendMetricChanged: (value) => setState(() => _trendMetric = value),
        onRankingTabChanged: (value) => setState(() => _rankingTab = value),
        onReportCurrencyChanged: (value) =>
            setState(() => _reportCurrency = value!),
        onSearch: () => setState(() {
          _startMonthFilter = _filterStartMonthController.text.trim();
          _endMonthFilter = _filterEndMonthController.text.trim();
          _skuFilter = _skuController.text.trim();
        }),
        onClearFilters: () => setState(() {
          _platformFilter = null;
          _appFilter = null;
          _skuFilter = null;
          _countryFilter = null;
          _rawCurrencyFilter = null;
          _settlementCurrencyFilter = null;
          _skuController.clear();
        }),
      ),
      ImportPage(
        syncStartMonthController: _syncStartMonthController,
        syncEndMonthController: _syncEndMonthController,
        isSyncing: _isSyncing,
        message: _message,
        onSync: _syncOfficialReports,
        syncRuns: _repository.syncRuns,
      ),
      MappingsPage(
        appMappingsController: _appMappingsController,
        message: _mappingsMessage,
        onSave: _saveMappings,
        unmappedApps: _getUnmappedAppIdentifiers(),
        onPopulateTemplate: _autoPopulateMappingsTemplate,
      ),
      ConfigPage(
        appleIssuerController: _appleIssuerController,
        appleKeyController: _appleKeyController,
        appleVendorController: _appleVendorController,
        applePrivateKeyController: _applePrivateKeyController,
        googleBucketController: _googleBucketController,
        googleServiceAccountController: _googleServiceAccountController,
        message: _configMessage,
        onSave: _saveConfig,
        isTestingApple: _isTestingApple,
        isTestingGoogle: _isTestingGoogle,
        onTestApple: _testAppleConfig,
        onTestGoogle: _testGoogleConfig,
      ),
      SettingsPage(
        language: _language,
        onLanguageChanged: (val) async {
          setState(() {
            _language = val;
            I18n.currentLang = val;
            _isLanguageUserSet = true;
          });
          await _saveCurrentConfig();
        },
        onClearData: _clearAllData,
        message: _settingsMessage,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _tabIndex,
              onDestinationSelected: (index) =>
                  setState(() => _tabIndex = index),
              labelType: NavigationRailLabelType.all,
              minWidth: 88,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard),
                  label: Text(I18n.t('nav_dashboard')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.cloud_sync_outlined),
                  selectedIcon: const Icon(Icons.cloud_sync),
                  label: Text(I18n.t('nav_import')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.apps_outlined),
                  selectedIcon: const Icon(Icons.apps),
                  label: Text(I18n.t('nav_mappings')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.key_outlined),
                  selectedIcon: const Icon(Icons.key),
                  label: Text(I18n.t('nav_config')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(I18n.t('nav_settings')),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages[_tabIndex]),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRepository() async {
    final openRepository = widget.openRepository ?? RevenueRepository.open;
    final repository = await openRepository();
    if (!mounted) {
      return;
    }

    _repository = repository;
    _applyConfigToControllers(repository.config);
    setState(() => _isLoading = false);

    // 启动时自动静默同步最新网络汇率
    _autoSyncRates();
  }

  void _applyConfigToControllers(AppConfig config) {
    _appleIssuerController.text = config.appleIssuerId;
    _appleKeyController.text = config.appleKeyId;
    _appleVendorController.text = config.appleVendorNumber;
    _applePrivateKeyController.text = config.applePrivateKeyPath;
    _googleBucketController.text = config.googleBucketId;
    _googleServiceAccountController.text = config.googleServiceAccountPath;
    _appMappingsController.text = config.appMappings;
    _customRates = Map<String, double>.from(config.customRates);
    _isLanguageUserSet = config.isLanguageUserSet;
    if (_isLanguageUserSet) {
      _language = config.language;
      I18n.currentLang = config.language;
    } else {
      String sysLang = 'en';
      try {
        final rawLocale = Platform.localeName.toLowerCase();
        if (rawLocale.startsWith('zh')) {
          if (rawLocale.contains('tw') || rawLocale.contains('hk') || rawLocale.contains('mo') || rawLocale.contains('hant')) {
            sysLang = 'zh_tw';
          } else {
            sysLang = 'zh';
          }
        } else if (rawLocale.startsWith('ja')) {
          sysLang = 'ja';
        } else if (rawLocale.startsWith('ko')) {
          sysLang = 'ko';
        } else if (rawLocale.startsWith('es')) {
          sysLang = 'es';
        } else if (rawLocale.startsWith('de')) {
          sysLang = 'de';
        } else if (rawLocale.startsWith('fr')) {
          sysLang = 'fr';
        } else if (rawLocale.startsWith('pt')) {
          sysLang = 'pt';
        } else if (rawLocale.startsWith('ru')) {
          sysLang = 'ru';
        } else {
          sysLang = 'en';
        }
      } catch (_) {
        sysLang = 'en';
      }
      _language = sysLang;
      I18n.currentLang = sysLang;
    }
  }

  Future<void> _autoSyncRates() async {
    if (_isSyncingRates) return;
    setState(() {
      _isSyncingRates = true;
    });

    try {
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP Error ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['result'] != 'success') {
        throw Exception('API error: ${data['error-type'] ?? 'unknown'}');
      }

      final rates = data['rates'] as Map<String, dynamic>;

      setState(() {
        for (final entry in rates.entries) {
          final currency = entry.key.toUpperCase();
          if (currency == 'USD') continue;
          final rateFromApi = (entry.value as num).toDouble();
          if (rateFromApi > 0) {
            final rateToUsd = 1.0 / rateFromApi;
            _customRates[currency] = double.parse(rateToUsd.toStringAsFixed(6));
          }
        }
      });

      await _saveCurrentConfig();
    } catch (e) {
      // 启动时自动静默同步最新汇率，即使网络连接失败或超时，也静默失败，保留使用本地上次缓存的汇率即可，避免影响用户离线体验
      debugPrint('Auto sync rates failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingRates = false;
        });
      }
    }
  }

  Future<void> _saveCurrentConfig() async {
    final config = AppConfig(
      appleIssuerId: _appleIssuerController.text.trim(),
      appleKeyId: _appleKeyController.text.trim(),
      appleVendorNumber: _appleVendorController.text.trim(),
      applePrivateKeyPath: _applePrivateKeyController.text.trim(),
      googleBucketId: _googleBucketController.text.trim(),
      googleServiceAccountPath: _googleServiceAccountController.text.trim(),
      appMappings: _appMappingsController.text.trim(),
      customRates: _customRates,
      language: _language,
      isLanguageUserSet: _isLanguageUserSet,
    );
    await _repository.updateConfig(config);
  }

  Future<void> _saveConfig() async {
    final config = AppConfig(
      appleIssuerId: _appleIssuerController.text.trim(),
      appleKeyId: _appleKeyController.text.trim(),
      appleVendorNumber: _appleVendorController.text.trim(),
      applePrivateKeyPath: _applePrivateKeyController.text.trim(),
      googleBucketId: _googleBucketController.text.trim(),
      googleServiceAccountPath: _googleServiceAccountController.text.trim(),
      appMappings: _appMappingsController.text.trim(),
      customRates: _customRates,
      language: _language,
      isLanguageUserSet: _isLanguageUserSet,
    );
    await _repository.updateConfig(config);
    if (!mounted) {
      return;
    }
    setState(() {
      _configMessage = I18n.t('msg_config_saved');
      _mappingsMessage = null;
      _settingsMessage = null;
    });
  }

  Future<void> _showTestResultDialog({
    required bool success,
    required String title,
    required String content,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: success ? const Color(0xff81c784) : const Color(0xffe57373),
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(content),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.t('dialog_btn_confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _testAppleConfig() async {
    if (_isTestingApple) return;
    setState(() {
      _isTestingApple = true;
      _configMessage = null;
    });

    final tempConfig = AppConfig(
      appleIssuerId: _appleIssuerController.text.trim(),
      appleKeyId: _appleKeyController.text.trim(),
      appleVendorNumber: _appleVendorController.text.trim(),
      applePrivateKeyPath: _applePrivateKeyController.text.trim(),
      googleBucketId: _googleBucketController.text.trim(),
      googleServiceAccountPath: _googleServiceAccountController.text.trim(),
      appMappings: _appMappingsController.text.trim(),
      customRates: _customRates,
      language: _language,
      isLanguageUserSet: _isLanguageUserSet,
    );

    try {
      await _repository.testAppleConnection(tempConfig);
      if (!mounted) return;
      await _showTestResultDialog(
        success: true,
        title: I18n.t('dialog_test_success_title'),
        content: I18n.t('dialog_test_success_desc'),
      );
    } catch (e) {
      if (!mounted) return;
      await _showTestResultDialog(
        success: false,
        title: I18n.t('dialog_test_failed_title'),
        content: I18n.t('dialog_test_failed_desc_prefix', args: {'error': e.toString()}),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTestingApple = false;
        });
      }
    }
  }

  Future<void> _testGoogleConfig() async {
    if (_isTestingGoogle) return;
    setState(() {
      _isTestingGoogle = true;
      _configMessage = null;
    });

    final tempConfig = AppConfig(
      appleIssuerId: _appleIssuerController.text.trim(),
      appleKeyId: _appleKeyController.text.trim(),
      appleVendorNumber: _appleVendorController.text.trim(),
      applePrivateKeyPath: _applePrivateKeyController.text.trim(),
      googleBucketId: _googleBucketController.text.trim(),
      googleServiceAccountPath: _googleServiceAccountController.text.trim(),
      appMappings: _appMappingsController.text.trim(),
      customRates: _customRates,
      language: _language,
      isLanguageUserSet: _isLanguageUserSet,
    );

    try {
      await _repository.testGoogleConnection(tempConfig);
      if (!mounted) return;
      await _showTestResultDialog(
        success: true,
        title: I18n.t('dialog_test_success_title'),
        content: I18n.t('dialog_test_success_desc'),
      );
    } catch (e) {
      if (!mounted) return;
      await _showTestResultDialog(
        success: false,
        title: I18n.t('dialog_test_failed_title'),
        content: I18n.t('dialog_test_failed_desc_prefix', args: {'error': e.toString()}),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTestingGoogle = false;
        });
      }
    }
  }

  Future<void> _saveMappings() async {
    final config = AppConfig(
      appleIssuerId: _appleIssuerController.text.trim(),
      appleKeyId: _appleKeyController.text.trim(),
      appleVendorNumber: _appleVendorController.text.trim(),
      applePrivateKeyPath: _applePrivateKeyController.text.trim(),
      googleBucketId: _googleBucketController.text.trim(),
      googleServiceAccountPath: _googleServiceAccountController.text.trim(),
      appMappings: _appMappingsController.text.trim(),
      customRates: _customRates,
      language: _language,
      isLanguageUserSet: _isLanguageUserSet,
    );
    await _repository.updateConfig(config);
    if (!mounted) {
      return;
    }
    setState(() {
      _mappingsMessage = I18n.t('msg_mappings_saved');
      _configMessage = null;
      _settingsMessage = null;
    });
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(I18n.t('dialog_clear_data_title')),
        content: Text(I18n.t('dialog_clear_data_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(I18n.t('dialog_btn_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(I18n.t('dialog_btn_clear_confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    await _repository.clearAllData();
    setState(() {
      _isLoading = false;
      _settingsMessage = I18n.t('msg_data_cleared');
    });
  }

  Map<String, List<String>> _getUnmappedAppIdentifiers() {
    if (_isLoading) return const {};
    
    // 找出所有在 records 中出现过但还没有在映射规则中被匹配的原始 appIdentifier
    final allIdentifiers = _repository.records.map((r) => r.appIdentifier.trim()).toSet();
    final mappingsText = _appMappingsController.text;
    
    // 找出目前在 appMappings 规则中已被声明配置的标识符
    final configuredIdentifiers = <String>{};
    for (final line in mappingsText.split('\n')) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final ids = parts[1].split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
        configuredIdentifiers.addAll(ids);
      }
    }
    
    final unmapped = <String, List<String>>{};
    for (final id in allIdentifiers) {
      if (id.isEmpty) continue;
      // 用小写或者去空白进行包含判定，以防配置出错
      final isConfigured = configuredIdentifiers.any(
        (confId) => confId.toLowerCase() == id.toLowerCase(),
      );
      if (!isConfigured) {
        // 收集该 appIdentifier 对应的所有唯一商品 ID
        final productIds = _repository.records
            .where((r) => r.appIdentifier.trim().toLowerCase() == id.toLowerCase())
            .map((r) => r.productId)
            .toSet()
            .toList();
        unmapped[id] = productIds;
      }
    }
    return unmapped;
  }

  void _autoPopulateMappingsTemplate() {
    final unmapped = _getUnmappedAppIdentifiers();
    if (unmapped.isEmpty) return;

    final builder = StringBuffer();
    if (_appMappingsController.text.isNotEmpty && !_appMappingsController.text.endsWith('\n')) {
      builder.write('\n');
    }

    unmapped.forEach((id, productIds) {
      // 智能转换：拿第一个 productId 当基础推导 App 别名
      final productId = productIds.isNotEmpty ? productIds.first : '';
      final suggestedName = _suggestAppName(productId, id);
      builder.writeln('$suggestedName, $id: ');
    });

    setState(() {
      _appMappingsController.text += builder.toString();
      _configMessage = I18n.t('msg_mappings_template_appended');
    });
  }

  String _suggestAppName(String productId, String appIdentifier) {
    if (productId.isEmpty) return 'App_$appIdentifier';
    
    String name = productId;
    // 如果是以 com. / net. / org. / cn. / io. / co. 等根域名开头，我们剥离前缀，保留 App 特征名字
    if (name.startsWith(RegExp(r'^(com|net|org|cn|io|co)\.'))) {
      final idx = name.indexOf('.');
      if (idx >= 0 && idx < name.length - 1) {
        name = name.substring(idx + 1);
      }
    }
    
    // 然后将点号、下划线、中划线替换为空格
    name = name.replaceAll('.', ' ').replaceAll('_', ' ').replaceAll('-', ' ');
    // 首字母大写
    return name.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ').trim();
  }



  Future<void> _syncOfficialReports() async {
    final startMonth = _syncStartMonthController.text.trim();
    final endMonth = _syncEndMonthController.text.trim();
    final monthPattern = RegExp(r'^\d{4}-\d{2}$');
    if (!monthPattern.hasMatch(startMonth) ||
        !monthPattern.hasMatch(endMonth)) {
      setState(() => _message = I18n.t('err_sync_month_format'));
      return;
    }
    if (startMonth.compareTo(endMonth) > 0) {
      setState(() => _message = I18n.t('err_sync_month_range'));
      return;
    }

    setState(() {
      _isSyncing = true;
      _message = null;
    });

    try {
      final runs = await _repository.syncOfficialReports(
        startMonth: startMonth,
        endMonth: endMonth,
      );
      final successCount = runs.where((run) => run.status == 'success' || run.status == 'partial').length;
      final hasPartial = runs.any((run) => run.status == 'partial');
      final totalRecords = runs.fold(0, (sum, run) => sum + run.recordsCount);
      setState(() {
        _isSyncing = false;
        _message = hasPartial
            ? I18n.t('msg_sync_partial', args: {'successCount': '$successCount', 'totalCount': '${runs.length}', 'records': '$totalRecords'})
            : I18n.t('msg_sync_success', args: {'successCount': '$successCount', 'totalCount': '${runs.length}', 'records': '$totalRecords'});
      });
    } catch (error) {
      setState(() {
        _isSyncing = false;
        _message = I18n.t('msg_sync_failed', args: {'error': '$error'});
      });
    }
  }
}


String _formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final whole = abs ~/ 100;
  final fraction = (abs % 100).toString().padLeft(2, '0');
  return '$sign$whole.$fraction';
}



String formatCountryName(String code) {
  final cleanCode = code.trim().toUpperCase();
  return I18n.countryName(cleanCode);
}

String formatAppName(String id, [String? mappingsText, List<RevenueRecord>? records]) {
  final mappings = mappingsText ?? AppConfig.defaultAppMappings;
  final cleanId = id.trim().toLowerCase();
  if (cleanId.isEmpty) return id;

  final lines = mappings.split('\n');
  for (final line in lines) {
    final parts = line.split(':');
    if (parts.length < 2) continue;
    
    // 新语法：右半部分是归并后的 App 显示名字，左半部分是匹配的标识符/商品名关键字列表
    final appName = parts[1].trim();
    if (appName.isEmpty) continue; // 若右侧名字为空，说明用户尚未填入映射，跳过

    final keywords = parts[0].split(',').map((k) => k.trim().toLowerCase()).toList();

    for (final kw in keywords) {
      if (kw.isEmpty) continue;
      if (cleanId == kw || cleanId.contains(kw)) {
        return appName;
      }
    }
  }

  // 如果没有匹配到映射别名，且传入了 records，则降级显示为最简短的 productId
  if (records != null && records.isNotEmpty) {
    final relatedProductIds = records
        .where((r) => r.appIdentifier.trim().toLowerCase() == cleanId)
        .map((r) => r.productId)
        .toSet()
        .toList();
    if (relatedProductIds.isNotEmpty) {
      return relatedProductIds.first;
    }
  }

  return id;
}


String formatMoney(int cents) => _formatMoney(cents);

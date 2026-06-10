
import 'package:finance_manager/models/app_config.dart';
import 'package:finance_manager/models/revenue_record.dart';
import 'package:finance_manager/services/finance_remote_sync_service.dart';
import 'package:finance_manager/services/revenue_repository.dart';
import 'package:finance_manager/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_local_store.dart';

void main() {
  test('opens and persists config updates', () async {
    final store = MemoryLocalStore();
    final repository = await RevenueRepository.open(store: store);

    expect(repository.records, isEmpty);
    expect(store.state?.records, isEmpty);

    await repository.updateConfig(
      const AppConfig(
        appleIssuerId: 'issuer',
        appleKeyId: 'key',
        appleVendorNumber: 'vendor',
        applePrivateKeyPath: '/tmp/key.p8',
        googleBucketId: 'pubsite_prod_rev_123',
        googleServiceAccountPath: '/tmp/google.json',
      ),
    );

    expect(store.state?.config.hasAppleConfig, isTrue);
    expect(store.state?.config.hasGoogleConfig, isTrue);
  });


  test('syncs remote records into local state and history', () async {
    final store = MemoryLocalStore();
    final repository = await RevenueRepository.open(
      store: store,
      remoteSyncService: _FakeRemoteSyncService(),
    );

    final runs = await repository.syncOfficialReports(
      startMonth: '2026-05',
      endMonth: '2026-05',
    );

    expect(runs, hasLength(1));
    expect(runs.first.status, 'partial');
    expect(repository.records, hasLength(1));
    expect(repository.syncRuns.first.source, 'remote');
    expect(store.state?.records, hasLength(1));
  });

  test('convertRevenueCents converts currencies correctly', () async {
    final repository = await RevenueRepository.open(store: MemoryLocalStore());

    expect(
      repository.convertRevenueCents(
        amountCents: 1000,
        sourceCurrency: 'USD',
        reportCurrency: 'CNY',
      ),
      7194,
    );

    expect(
      repository.convertRevenueCents(
        amountCents: 1000,
        sourceCurrency: 'CNY',
        reportCurrency: 'USD',
      ),
      139,
    );

    expect(
      repository.convertRevenueCents(
        amountCents: 1000,
        sourceCurrency: 'EUR',
        reportCurrency: 'EUR',
      ),
      1000,
    );
  });

  test('convertRevenueCents prioritizes config customRates', () async {
    final store = MemoryLocalStore();
    final repository = await RevenueRepository.open(store: store);

    final customRatesConfig = repository.config.copyWith(
      customRates: {'CNY': 0.2},
    );
    await repository.updateConfig(customRatesConfig);

    expect(
      repository.convertRevenueCents(
        amountCents: 1000,
        sourceCurrency: 'CNY',
        reportCurrency: 'USD',
      ),
      200,
    );

    expect(
      repository.convertRevenueCents(
        amountCents: 1000,
        sourceCurrency: 'USD',
        reportCurrency: 'CNY',
      ),
      5000,
    );
  });

  test('convertRevenueCents falls back to static rates when customRates is empty', () async {
    final store = MemoryLocalStore();
    final repository = await RevenueRepository.open(store: store);

    final emptyRatesConfig = repository.config.copyWith(
      customRates: const {},
    );
    await repository.updateConfig(emptyRatesConfig);

    expect(
      repository.convertRevenueCents(
        amountCents: 1000,
        sourceCurrency: 'CNY',
        reportCurrency: 'USD',
      ),
      139,
    );
  });



  test('summarize and groupBy applies currency conversions correctly', () async {
    final repository = await RevenueRepository.open(store: MemoryLocalStore());
    
    final records = [
      const RevenueRecord(
        platform: RevenuePlatform.apple,
        appIdentifier: 'App A',
        reportMonth: '2026-05',
        productId: 'prod1',
        countryCode: 'US',
        rawCurrency: 'USD',
        settlementCurrency: 'USD',
        grossAmountCents: 1000,
        netAmountCents: 700,
        refundsCount: 0,
        refundsAmountCents: 0,
        settlementAmountCents: 700,
      ),
      const RevenueRecord(
        platform: RevenuePlatform.google,
        appIdentifier: 'App A',
        reportMonth: '2026-05',
        productId: 'prod2',
        countryCode: 'DE',
        rawCurrency: 'EUR',
        settlementCurrency: 'EUR',
        grossAmountCents: 1000,
        netAmountCents: 700,
        refundsCount: 1,
        refundsAmountCents: 100,
        settlementAmountCents: 700,
      ),
    ];

    final summaryUsd = repository.summarize(records, reportCurrency: 'USD');
    expect(summaryUsd.grossAmountCents, 1000 + 1080);
    expect(summaryUsd.netAmountCents, 700 + 756);
    expect(summaryUsd.refundsAmountCents, 108);

    final summaryCny = repository.summarize(records, reportCurrency: 'CNY');
    expect(summaryCny.grossAmountCents, 7194 + 7770);
    expect(summaryCny.netAmountCents, 5036 + 5439);

    final grouped = repository.groupBy(records, (r) => r.platformLabel, reportCurrency: 'USD');
    final appleTotal = grouped.firstWhere((g) => g.label == 'Apple');
    final googleTotal = grouped.firstWhere((g) => g.label == 'Google');
    expect(appleTotal.netAmountCents, 700);
    expect(googleTotal.netAmountCents, 756);
  });


  test('formats App name and Country name correctly', () {
    const mappings = '111222333, 111222334: DemoApp\n222333444: SampleApp';
    expect(formatAppName('111222333', mappings), 'DemoApp');
    expect(formatAppName('222333444', mappings), 'SampleApp');
    expect(formatAppName('other', mappings), 'other');
    expect(formatAppName('111222333'), '111222333');

    // 测试未配映射规则但传入了 records 时，组合 Product ID 与 App ID 的降级显示逻辑
    final mockRecords = [
      const RevenueRecord(
        platform: RevenuePlatform.apple,
        appIdentifier: '111222333',
        reportMonth: '2026-05',
        productId: 'demoapp_plus_lifetime',
        countryCode: 'US',
        rawCurrency: 'USD',
        settlementCurrency: 'USD',
        grossAmountCents: 1000,
        netAmountCents: 700,
        refundsCount: 0,
        refundsAmountCents: 0,
        settlementAmountCents: 700,
      ),
      const RevenueRecord(
        platform: RevenuePlatform.apple,
        appIdentifier: '111222333',
        reportMonth: '2026-05',
        productId: 'demoapp_plus_annual',
        countryCode: 'US',
        rawCurrency: 'USD',
        settlementCurrency: 'USD',
        grossAmountCents: 1000,
        netAmountCents: 700,
        refundsCount: 0,
        refundsAmountCents: 0,
        settlementAmountCents: 700,
      ),
    ];
    
    // 如果没有映射别名，直接返回第一个产品ID作为代称，去除括号和标识符
    expect(
      formatAppName('111222333', '', mockRecords),
      'demoapp_plus_lifetime',
    );

    expect(formatCountryName('US'), '美国');
    expect(formatCountryName('CN'), '中国');
    expect(formatCountryName('XX'), 'XX');
  });

  test('groupBy aggregates app identifiers under the same app name', () async {
    final repository = await RevenueRepository.open(store: MemoryLocalStore());
    final records = [
      const RevenueRecord(
        platform: RevenuePlatform.apple,
        appIdentifier: '111222333',
        reportMonth: '2026-05',
        productId: 'prod1',
        countryCode: 'US',
        rawCurrency: 'USD',
        settlementCurrency: 'USD',
        grossAmountCents: 1000,
        netAmountCents: 700,
        refundsCount: 0,
        refundsAmountCents: 0,
        settlementAmountCents: 700,
      ),
      const RevenueRecord(
        platform: RevenuePlatform.apple,
        appIdentifier: 'com.demoapp.scanner',
        reportMonth: '2026-05',
        productId: 'prod2',
        countryCode: 'US',
        rawCurrency: 'USD',
        settlementCurrency: 'USD',
        grossAmountCents: 2000,
        netAmountCents: 1400,
        refundsCount: 0,
        refundsAmountCents: 0,
        settlementAmountCents: 1400,
      ),
    ];

    const mappings = '111222333, com.demoapp.scanner: DemoApp';
    final grouped = repository.groupBy(records, (r) => formatAppName(r.appIdentifier, mappings), reportCurrency: 'USD');
    expect(grouped, hasLength(1));
    expect(grouped.first.label, 'DemoApp');
    expect(grouped.first.netAmountCents, 700 + 1400);
  });

  test('OfficialSyncResult.overallStatus handles state combinations correctly', () {
    expect(
      const OfficialSyncResult(
        apple: PlatformSyncResult(status: 'success', records: []),
        google: PlatformSyncResult(status: 'success', records: []),
      ).overallStatus,
      'success',
    );

    expect(
      const OfficialSyncResult(
        apple: PlatformSyncResult(status: 'success', records: []),
        google: PlatformSyncResult(status: 'skipped', records: []),
      ).overallStatus,
      'partial',
    );

    expect(
      const OfficialSyncResult(
        apple: PlatformSyncResult(status: 'success', records: []),
        google: PlatformSyncResult(status: 'error', records: []),
      ).overallStatus,
      'partial',
    );

    expect(
      const OfficialSyncResult(
        apple: PlatformSyncResult(status: 'not_available', records: []),
        google: PlatformSyncResult(status: 'not_available', records: []),
      ).overallStatus,
      'not_available',
    );

    expect(
      const OfficialSyncResult(
        apple: PlatformSyncResult(status: 'error', records: []),
        google: PlatformSyncResult(status: 'error', records: []),
      ).overallStatus,
      'error',
    );
  });

  test('clearAllData clears all records and syncRuns and persists them', () async {
    final store = MemoryLocalStore();
    final repository = await RevenueRepository.open(
      store: store,
      remoteSyncService: _FakeRemoteSyncService(),
    );

    // Sync some fake data
    await repository.syncOfficialReports(
      startMonth: '2026-05',
      endMonth: '2026-05',
    );
    expect(repository.records, isNotEmpty);
    expect(repository.syncRuns, isNotEmpty);

    // Clear data
    await repository.clearAllData();
    expect(repository.records, isEmpty);
    expect(repository.syncRuns, isEmpty);
    expect(store.state?.records, isEmpty);
    expect(store.state?.syncRuns, isEmpty);
  });

  test('automatically cleans both records and syncRuns when upgrading from old sample data state', () async {
    final store = MemoryLocalStore();
    
    // Pre-populate with dirty mock records & syncRuns
    final oldRecords = [
      const RevenueRecord(
        platform: RevenuePlatform.apple,
        appIdentifier: 'DemoApp',
        reportMonth: '2025-01',
        productId: 'prod1',
        countryCode: 'US',
        rawCurrency: 'USD',
        settlementCurrency: 'USD',
        grossAmountCents: 1000,
        netAmountCents: 700,
        refundsCount: 0,
        refundsAmountCents: 0,
        settlementAmountCents: 700,
      ),
    ];
    final oldSyncRuns = [
      SyncRun(
        reportMonth: '2025-01',
        source: 'remote',
        status: 'success',
        appleStatus: 'success',
        googleStatus: 'success',
        recordsCount: 1,
        startedAt: DateTime.now(),
      ),
    ];
    
    await store.save(
      records: oldRecords,
      syncRuns: oldSyncRuns,
      config: const AppConfig(),
    );
    
    final repository = await RevenueRepository.open(store: store);
    expect(repository.records, isEmpty);
    expect(repository.syncRuns, isEmpty);
    
    expect(store.state?.records, isEmpty);
    expect(store.state?.syncRuns, isEmpty);
  });

  test('testAppleConnection throws FormatException for invalid/empty configs', () async {
    final repository = await RevenueRepository.open(store: MemoryLocalStore());
    expect(
      () => repository.testAppleConnection(const AppConfig()),
      throwsA(isA<FormatException>()),
    );
  });

  test('testGoogleConnection throws FormatException for invalid/empty configs', () async {
    final repository = await RevenueRepository.open(store: MemoryLocalStore());
    expect(
      () => repository.testGoogleConnection(const AppConfig()),
      throwsA(isA<FormatException>()),
    );
  });

  test('testAppleConnection throws FormatException when private key file is missing', () async {
    final repository = await RevenueRepository.open(store: MemoryLocalStore());
    final config = const AppConfig(
      appleIssuerId: 'issuer',
      appleKeyId: 'key',
      appleVendorNumber: 'vendor',
      applePrivateKeyPath: 'non_existent_file.p8',
    );
    expect(
      () => repository.testAppleConnection(config),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('无法读取私钥文件'),
        ),
      ),
    );
  });

  test('testGoogleConnection throws FormatException when service account file is missing', () async {
    final repository = await RevenueRepository.open(store: MemoryLocalStore());
    final config = const AppConfig(
      googleBucketId: 'bucket',
      googleServiceAccountPath: 'non_existent_file.json',
    );
    expect(
      () => repository.testGoogleConnection(config),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('无法读取 Service Account JSON'),
        ),
      ),
    );
  });
}

class _FakeRemoteSyncService extends FinanceRemoteSyncService {
  @override
  Future<OfficialSyncResult> syncMonth({
    required AppConfig config,
    required String reportMonth,
  }) async {
    return OfficialSyncResult(
      apple: PlatformSyncResult(
        status: 'success',
        records: [
          RevenueRecord(
            platform: RevenuePlatform.apple,
            appIdentifier: 'Test App',
            reportMonth: reportMonth,
            productId: 'com.test.monthly',
            countryCode: 'US',
            rawCurrency: 'USD',
            settlementCurrency: 'USD',
            grossAmountCents: 999,
            netAmountCents: 700,
            refundsCount: 0,
            refundsAmountCents: 0,
            settlementAmountCents: 700,
          ),
        ],
      ),
      google: const PlatformSyncResult(status: 'skipped', records: []),
    );
  }
}

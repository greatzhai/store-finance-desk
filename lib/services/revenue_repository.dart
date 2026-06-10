import '../models/app_config.dart';
import '../models/revenue_record.dart';
import 'finance_remote_sync_service.dart';
import 'local_store.dart';
import 'revenue_parser.dart';

class RevenueRepository {
  RevenueRepository._({
    required RevenueParser parser,
    required FinanceRemoteSyncService remoteSyncService,
    required LocalStore store,
    required List<RevenueRecord> records,
    required List<SyncRun> syncRuns,
    required this.config,
  }) : _parser = parser,
       _remoteSyncService = remoteSyncService,
       _store = store,
       _records = records,
       _syncRuns = syncRuns;

  static Future<RevenueRepository> open({
    RevenueParser? parser,
    FinanceRemoteSyncService? remoteSyncService,
    LocalStore? store,
  }) async {
    final resolvedStore = store ?? const LocalStore();
    final state = await resolvedStore.load();
    if (state != null) {
      // 过滤旧版本写入本地存储的内置模拟数据记录
      final cleanRecords = state.records
          .where((r) => r.appIdentifier != 'DemoApp' && r.appIdentifier != 'SampleApp')
          .toList();
      
      // 如果过滤掉了旧模拟数据，说明是历史遗留的模拟状态，此时将同步历史也一并清空以保持纯净化
      final cleanSyncRuns = cleanRecords.length != state.records.length
          ? <SyncRun>[]
          : state.syncRuns
              .where((run) => run.source != 'sample')
              .toList();

      final repository = RevenueRepository._(
        parser: parser ?? const RevenueParser(),
        remoteSyncService: remoteSyncService ?? FinanceRemoteSyncService(),
        store: resolvedStore,
        records: cleanRecords,
        syncRuns: cleanSyncRuns,
        config: state.config,
      );

      // 如果过滤掉了脏数据，则立即回写保存到本地
      if (cleanRecords.length != state.records.length ||
          cleanSyncRuns.length != state.syncRuns.length) {
        await repository.save();
      }

      return repository;
    }

    final records = <RevenueRecord>[];
    final syncRuns = <SyncRun>[];
    final repository = RevenueRepository._(
      parser: parser ?? const RevenueParser(),
      remoteSyncService: remoteSyncService ?? FinanceRemoteSyncService(),
      store: resolvedStore,
      records: records,
      syncRuns: syncRuns,
      config: const AppConfig(),
    );
    await repository.save();
    return repository;
  }

  Future<void> clearAllData() async {
    _records.clear();
    _syncRuns.clear();
    await save();
  }

  final RevenueParser _parser;
  final FinanceRemoteSyncService _remoteSyncService;
  final LocalStore _store;
  final List<RevenueRecord> _records;
  final List<SyncRun> _syncRuns;
  AppConfig config;

  List<RevenueRecord> get records => List.unmodifiable(_records);
  List<SyncRun> get syncRuns => List.unmodifiable(_syncRuns);

  Future<void> save() {
    return _store.save(records: _records, syncRuns: _syncRuns, config: config);
  }

  Future<void> updateConfig(AppConfig nextConfig) async {
    config = nextConfig;
    await save();
  }

  Future<void> testAppleConnection(AppConfig config) {
    return _remoteSyncService.testAppleConnection(config);
  }

  Future<void> testGoogleConnection(AppConfig config) {
    return _remoteSyncService.testGoogleConnection(config);
  }


  Future<SyncRun> importReport({
    required RevenuePlatform platform,
    required String reportMonth,
    required String path,
  }) async {
    final startedAt = DateTime.now();
    try {
      final imported = await _parser.importFile(
        platform: platform,
        reportMonth: reportMonth,
        path: path,
      );
      upsertAll(imported);

      final run = SyncRun(
        reportMonth: reportMonth,
        source: 'local_file',
        status: 'success',
        appleStatus: platform == RevenuePlatform.apple ? 'success' : 'skipped',
        googleStatus: platform == RevenuePlatform.google ? 'success' : 'skipped',
        recordsCount: imported.length,
        startedAt: startedAt,
      );
      _syncRuns.insert(0, run);
      await save();
      return run;
    } catch (error) {
      final run = SyncRun(
        reportMonth: reportMonth,
        source: 'local_file',
        status: 'error',
        appleStatus: platform == RevenuePlatform.apple ? 'error' : 'skipped',
        googleStatus: platform == RevenuePlatform.google ? 'error' : 'skipped',
        recordsCount: 0,
        startedAt: startedAt,
        errorMessage: '$error',
      );
      _syncRuns.insert(0, run);
      await save();
      rethrow;
    }
  }

  Future<List<SyncRun>> syncOfficialReports({
    required String startMonth,
    required String endMonth,
  }) async {
    final runs = <SyncRun>[];
    for (final month in _monthRange(startMonth, endMonth)) {
      final startedAt = DateTime.now();
      final result = await _remoteSyncService.syncMonth(
        config: config,
        reportMonth: month,
      );
      upsertAll([...result.apple.records, ...result.google.records]);

      final run = SyncRun(
        reportMonth: month,
        source: 'remote',
        status: result.overallStatus,
        appleStatus: result.apple.status,
        googleStatus: result.google.status,
        recordsCount: result.recordsCount,
        startedAt: startedAt,
        errorMessage: result.errorMessage,
      );
      _syncRuns.insert(0, run);
      runs.add(run);
      await save();
    }
    return runs;
  }

  void upsertAll(List<RevenueRecord> incoming) {
    for (final record in incoming) {
      final index = _records.indexWhere(
        (existing) => existing.aggregateKey == record.aggregateKey,
      );
      if (index >= 0) {
        _records[index] = record;
      } else {
        _records.add(record);
      }
    }
  }

  static const fallbackFxToUsd = AppConfig.defaultFxRates;

  int convertRevenueCents({
    required int amountCents,
    required String sourceCurrency,
    required String reportCurrency,
  }) {
    final source = sourceCurrency.toUpperCase().trim();
    final target = reportCurrency.toUpperCase().trim();
    if (source == target) {
      return amountCents;
    }
    final sourceToUsd = config.customRates[source] ?? fallbackFxToUsd[source];
    final targetToUsd = config.customRates[target] ?? fallbackFxToUsd[target];
    if (sourceToUsd == null || targetToUsd == null) {
      // ignore: avoid_print
      print('Warning: Missing FX rate for $source -> $target. Returning 0.');
      return 0;
    }
    final converted = amountCents * sourceToUsd / targetToUsd;
    return converted.round();
  }

  RevenueSummary summarize(List<RevenueRecord> records, {String reportCurrency = 'USD'}) {
    var grossSum = 0;
    var netSum = 0;
    var refundSum = 0;
    var refundsCount = 0;

    for (final r in records) {
      grossSum += convertRevenueCents(
        amountCents: r.grossAmountCents,
        sourceCurrency: r.rawCurrency,
        reportCurrency: reportCurrency,
      );
      netSum += convertRevenueCents(
        amountCents: r.netAmountCents,
        sourceCurrency: r.settlementCurrency,
        reportCurrency: reportCurrency,
      );
      refundSum += convertRevenueCents(
        amountCents: r.refundsAmountCents,
        sourceCurrency: r.settlementCurrency,
        reportCurrency: reportCurrency,
      );
      refundsCount += r.refundsCount;
    }

    return RevenueSummary(
      grossAmountCents: grossSum,
      netAmountCents: netSum,
      refundsAmountCents: refundSum,
      refundsCount: refundsCount,
      activeMonths: records.map((r) => r.reportMonth).toSet().length,
    );
  }

  List<DimensionTotal> groupBy(
    List<RevenueRecord> records,
    String Function(RevenueRecord record) keyOf, {
    String reportCurrency = 'USD',
  }) {
    final map = <String, DimensionTotal>{};
    for (final record in records) {
      final key = keyOf(record);
      final current = map[key];

      final convertedGross = convertRevenueCents(
        amountCents: record.grossAmountCents,
        sourceCurrency: record.rawCurrency,
        reportCurrency: reportCurrency,
      );
      final convertedNet = convertRevenueCents(
        amountCents: record.netAmountCents,
        sourceCurrency: record.settlementCurrency,
        reportCurrency: reportCurrency,
      );
      final convertedRefund = convertRevenueCents(
        amountCents: record.refundsAmountCents,
        sourceCurrency: record.settlementCurrency,
        reportCurrency: reportCurrency,
      );

      map[key] = DimensionTotal(
        label: key,
        grossAmountCents: (current?.grossAmountCents ?? 0) + convertedGross,
        netAmountCents: (current?.netAmountCents ?? 0) + convertedNet,
        refundsAmountCents:
            (current?.refundsAmountCents ?? 0) + convertedRefund,
        refundsCount: (current?.refundsCount ?? 0) + record.refundsCount,
        quantity: (current?.quantity ?? 0) + record.quantity,
      );
    }
    final result = map.values.toList()
      ..sort((a, b) => b.netAmountCents.compareTo(a.netAmountCents));
    return result;
  }

  List<String> _monthRange(String startMonth, String endMonth) {
    final startParts = startMonth.split('-').map(int.parse).toList();
    final endParts = endMonth.split('-').map(int.parse).toList();
    var year = startParts[0];
    var month = startParts[1];
    final endYear = endParts[0];
    final endMonthNumber = endParts[1];
    final result = <String>[];

    while (year < endYear || year == endYear && month <= endMonthNumber) {
      result.add('$year-${month.toString().padLeft(2, '0')}');
      month++;
      if (month == 13) {
        month = 1;
        year++;
      }
    }
    return result;
  }
}

import 'dart:convert';
import 'dart:io';

import '../models/app_config.dart';
import '../models/revenue_record.dart';

class LocalStoreState {
  const LocalStoreState({
    required this.records,
    required this.syncRuns,
    required this.config,
  });

  final List<RevenueRecord> records;
  final List<SyncRun> syncRuns;
  final AppConfig config;
}

class LocalStore {
  const LocalStore();

  Future<LocalStoreState?> load() async {
    final file = await _stateFile();
    if (!await file.exists()) {
      return null;
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('本地状态文件格式错误');
    }

    final recordsJson = decoded['records'] as List<dynamic>? ?? const [];
    final syncRunsJson = decoded['syncRuns'] as List<dynamic>? ?? const [];
    final configJson =
        decoded['config'] as Map<String, Object?>? ?? const <String, Object?>{};

    return LocalStoreState(
      records: recordsJson
          .cast<Map<String, Object?>>()
          .map(RevenueRecord.fromJson)
          .toList(),
      syncRuns: syncRunsJson
          .cast<Map<String, Object?>>()
          .map(SyncRun.fromJson)
          .toList(),
      config: AppConfig.fromJson(configJson),
    );
  }

  Future<void> save({
    required List<RevenueRecord> records,
    required List<SyncRun> syncRuns,
    required AppConfig config,
  }) async {
    final file = await _stateFile();
    await file.parent.create(recursive: true);
    final data = {
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'records': records.map((record) => record.toJson()).toList(),
      'syncRuns': syncRuns.map((run) => run.toJson()).toList(),
      'config': config.toJson(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<File> _stateFile() async {
    final base = _appDataDirectory();
    return File('${base.path}${Platform.pathSeparator}state.json');
  }

  Directory _appDataDirectory() {
    final env = Platform.environment;
    if (Platform.isMacOS) {
      final home = env['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(
          '$home/Library/Application Support/store_finance_desk',
        );
      }
    }

    if (Platform.isWindows) {
      final appData = env['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory('$appData\\StoreFinanceDesk');
      }
    }

    final xdgDataHome = env['XDG_DATA_HOME'];
    if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
      return Directory('$xdgDataHome/store_finance_desk');
    }

    final home = env['HOME'] ?? Directory.current.path;
    return Directory('$home/.store_finance_desk');
  }
}

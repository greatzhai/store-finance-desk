import 'package:finance_manager/models/app_config.dart';
import 'package:finance_manager/models/revenue_record.dart';
import 'package:finance_manager/services/local_store.dart';

class MemoryLocalStore extends LocalStore {
  MemoryLocalStore({this.state});

  LocalStoreState? state;

  @override
  Future<LocalStoreState?> load() async => state;

  @override
  Future<void> save({
    required List<RevenueRecord> records,
    required List<SyncRun> syncRuns,
    required AppConfig config,
  }) async {
    state = LocalStoreState(
      records: List.of(records),
      syncRuns: List.of(syncRuns),
      config: config,
    );
  }
}

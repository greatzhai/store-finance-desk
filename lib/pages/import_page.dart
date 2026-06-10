import 'package:flutter/material.dart';
import '../models/i18n.dart';
import '../models/revenue_record.dart';
import '../widgets/panel.dart';

class ImportPage extends StatelessWidget {
  const ImportPage({
    super.key,
    required this.syncStartMonthController,
    required this.syncEndMonthController,
    required this.isSyncing,
    required this.message,
    required this.onSync,
    required this.syncRuns,
  });

  final TextEditingController syncStartMonthController;
  final TextEditingController syncEndMonthController;
  final bool isSyncing;
  final String? message;
  final VoidCallback onSync;
  final List<SyncRun> syncRuns;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: I18n.t('title_import'),
      subtitle: I18n.t('subtitle_import'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Panel(
            title: I18n.t('panel_sync_reports'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 620;
                    final startField = TextField(
                      controller: syncStartMonthController,
                      decoration: InputDecoration(
                        labelText: I18n.t('lbl_sync_start_month'),
                        hintText: '2026-05',
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                      ),
                    );
                    final endField = TextField(
                      controller: syncEndMonthController,
                      decoration: InputDecoration(
                        labelText: I18n.t('lbl_sync_end_month'),
                        hintText: '2026-05',
                        prefixIcon: const Icon(Icons.event_outlined),
                      ),
                    );
                    return wide
                        ? Row(
                            children: [
                              Expanded(child: startField),
                              const SizedBox(width: 12),
                              Expanded(child: endField),
                            ],
                          )
                        : Column(
                            children: [
                              startField,
                              const SizedBox(height: 12),
                              endField,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isSyncing ? null : onSync,
                  icon: isSyncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_sync_outlined),
                  label: Text(isSyncing ? I18n.t('btn_syncing') : I18n.t('btn_sync')),
                ),
              ],
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: (message!.contains('失败') || message!.contains('failed') || message!.contains('Error') || message!.contains('Exception'))
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Panel(
            title: I18n.t('panel_recent_jobs'),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(I18n.t('col_job_month'))),
                  DataColumn(label: Text(I18n.t('col_job_source'))),
                  DataColumn(label: Text(I18n.t('col_job_status'))),
                  const DataColumn(label: Text('Apple')),
                  const DataColumn(label: Text('Google')),
                  DataColumn(label: Text(I18n.t('col_job_records'))),
                  DataColumn(label: Text(I18n.t('col_job_time'))),
                  DataColumn(label: Text(I18n.t('col_job_error'))),
                ],
                rows: [
                  for (final run in syncRuns)
                    DataRow(
                      cells: [
                        DataCell(Text(run.reportMonth)),
                        DataCell(Text(run.source)),
                        DataCell(_StatusPill(status: run.status)),
                        DataCell(Text(run.appleStatus)),
                        DataCell(Text(run.googleStatus)),
                        DataCell(Text('${run.recordsCount}')),
                        DataCell(Text(_formatDateTime(run.startedAt))),
                        DataCell(
                          SizedBox(
                            width: 260,
                            child: Text(
                              run.errorMessage ?? '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final success = status == 'success';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: success ? const Color(0xffe2f2e7) : const Color(0xffffece8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          status,
          style: TextStyle(
            color: success ? const Color(0xff17653c) : const Color(0xffa33020),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

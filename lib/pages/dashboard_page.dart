import 'package:flutter/material.dart';
import '../models/i18n.dart';
import '../models/app_config.dart';
import '../models/revenue_record.dart';
import '../services/revenue_repository.dart';
import '../widgets/kpi_card.dart';
import '../widgets/panel.dart';
import '../widgets/trend_chart.dart';
import '../widgets/searchable_dropdown.dart';
import '../main.dart'; // 引入 formatMoney, formatCountryName, formatAppName, AppConfig

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.records,
    required this.repository,
    required this.platformFilter,
    required this.appFilter,
    required this.skuFilter,
    required this.countryFilter,
    required this.rawCurrencyFilter,
    required this.settlementCurrencyFilter,
    required this.showAdvancedFilters,
    required this.trendMetric,
    required this.rankingTab,
    required this.reportCurrency,
    required this.startMonthController,
    required this.endMonthController,
    required this.skuController,
    required this.onPlatformChanged,
    required this.onAppChanged,
    required this.onSkuChanged,
    required this.onCountryChanged,
    required this.onRawCurrencyChanged,
    required this.onSettlementCurrencyChanged,
    required this.onShowAdvancedFiltersChanged,
    required this.onTrendMetricChanged,
    required this.onRankingTabChanged,
    required this.onReportCurrencyChanged,
    required this.onSearch,
    required this.onClearFilters,
  });

  final List<RevenueRecord> records;
  final RevenueRepository repository;
  final String? platformFilter;
  final String? appFilter;
  final String? skuFilter;
  final String? countryFilter;
  final String? rawCurrencyFilter;
  final String? settlementCurrencyFilter;
  final bool showAdvancedFilters;
  final String trendMetric;
  final String rankingTab;
  final String reportCurrency;
  final TextEditingController startMonthController;
  final TextEditingController endMonthController;
  final TextEditingController skuController;

  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onAppChanged;
  final ValueChanged<String?> onSkuChanged;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onRawCurrencyChanged;
  final ValueChanged<String?> onSettlementCurrencyChanged;
  final ValueChanged<bool> onShowAdvancedFiltersChanged;
  final ValueChanged<String> onTrendMetricChanged;
  final ValueChanged<String> onRankingTabChanged;
  final ValueChanged<String?> onReportCurrencyChanged;
  final VoidCallback onSearch;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final summary = repository.summarize(records, reportCurrency: reportCurrency);
    final platforms = repository.groupBy(records, (r) => r.platformLabel, reportCurrency: reportCurrency);
    final apps = repository.groupBy(records, (r) => formatAppName(r.appIdentifier, repository.config.appMappings, records), reportCurrency: reportCurrency);
    final countries = repository.groupBy(records, (r) => formatCountryName(r.countryCode), reportCurrency: reportCurrency);
    final products = repository
        .groupBy(records, (r) => r.productId, reportCurrency: reportCurrency)
        .take(10)
        .toList();
    final months = repository.groupBy(records, (r) => r.reportMonth, reportCurrency: reportCurrency)
      ..sort((a, b) => a.label.compareTo(b.label));

    // 计算全局实际渠道费率与扣除金额 (包含抽成、增值税等)
    final feeCents = summary.grossAmountCents - summary.netAmountCents - summary.refundsAmountCents;
    final feePct = summary.grossAmountCents > 0 ? (feeCents / summary.grossAmountCents * 100) : 0.0;
    final safeFeePct = feePct < 0 ? 0.0 : (feePct > 100 ? 100.0 : feePct);

    // 订阅周期结构统计数据
    final billingCycles = repository.groupBy(records, (r) => _detectBillingCycle(r.productId), reportCurrency: reportCurrency);

    // 计算原始币种分布数据 (追溯用)
    final rawCurrencyMap = <String, int>{};
    final settlementCurrencyMap = <String, List<int>>{};
    final totalNetCents = summary.netAmountCents;

    for (final r in records) {
      final rawCurr = r.rawCurrency.toUpperCase();
      final settleCurr = r.settlementCurrency.toUpperCase();

      final convGross = repository.convertRevenueCents(
        amountCents: r.grossAmountCents,
        sourceCurrency: r.rawCurrency,
        reportCurrency: reportCurrency,
      );
      final convNet = repository.convertRevenueCents(
        amountCents: r.netAmountCents,
        sourceCurrency: r.settlementCurrency,
        reportCurrency: reportCurrency,
      );
      final convRefund = repository.convertRevenueCents(
        amountCents: r.refundsAmountCents,
        sourceCurrency: r.settlementCurrency,
        reportCurrency: reportCurrency,
      );

      rawCurrencyMap[rawCurr] = (rawCurrencyMap[rawCurr] ?? 0) + convGross;

      final currentSettle = settlementCurrencyMap[settleCurr] ?? [0, 0, 0];
      settlementCurrencyMap[settleCurr] = [
        currentSettle[0] + convNet,
        currentSettle[1] + convRefund,
        currentSettle[2] + r.refundsCount,
      ];
    }

    final currencyRows = <_CurrencyDistributionRow>[];
    rawCurrencyMap.forEach((curr, gross) {
      currencyRows.add(_CurrencyDistributionRow(
        currency: curr,
        type: 'raw',
        grossCents: gross,
        netCents: 0,
        refundCents: 0,
        refundCount: 0,
        share: totalNetCents > 0 ? (gross / totalNetCents) : 0.0,
      ));
    });

    settlementCurrencyMap.forEach((curr, values) {
      currencyRows.add(_CurrencyDistributionRow(
        currency: curr,
        type: 'settlement',
        grossCents: 0,
        netCents: values[0],
        refundCents: values[1],
        refundCount: values[2],
        share: totalNetCents > 0 ? (values[0] / totalNetCents) : 0.0,
      ));
    });

    currencyRows.sort((a, b) => b.share.compareTo(a.share));

    // 根据 rankingTab 获取排行列表数据
    List<DimensionTotal> activeRankingList;
    if (rankingTab == 'countries') {
      activeRankingList = countries;
    } else if (rankingTab == 'apps') {
      activeRankingList = apps;
    } else if (rankingTab == 'platforms') {
      activeRankingList = platforms;
    } else if (rankingTab == 'subscriptions') {
      activeRankingList = billingCycles;
    } else {
      activeRankingList = products;
    }

    return PageShell(
      title: I18n.t('title_dashboard'),
      subtitle: I18n.t('subtitle_dashboard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterBar(
            records: repository.records,
            customRates: repository.config.customRates,
            platformFilter: platformFilter,
            appFilter: appFilter,
            skuFilter: skuFilter,
            countryFilter: countryFilter,
            rawCurrencyFilter: rawCurrencyFilter,
            settlementCurrencyFilter: settlementCurrencyFilter,
            showAdvancedFilters: showAdvancedFilters,
            reportCurrency: reportCurrency,
            startMonthController: startMonthController,
            endMonthController: endMonthController,
            skuController: skuController,
            appMappings: repository.config.appMappings,
            onPlatformChanged: onPlatformChanged,
            onAppChanged: onAppChanged,
            onSkuChanged: onSkuChanged,
            onCountryChanged: onCountryChanged,
            onRawCurrencyChanged: onRawCurrencyChanged,
            onSettlementCurrencyChanged: onSettlementCurrencyChanged,
            onShowAdvancedFiltersChanged: onShowAdvancedFiltersChanged,
            onReportCurrencyChanged: onReportCurrencyChanged,
            onSearch: onSearch,
            onClearFilters: onClearFilters,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1080 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 4 ? 2.3 : 2.65,
                children: [
                  KpiCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: I18n.t('kpi_net'),
                    value: formatMoney(summary.netAmountCents),
                    note: I18n.t('kpi_converted_note', args: {'currency': reportCurrency}),
                  ),
                  KpiCard(
                    icon: Icons.payments_outlined,
                    label: I18n.t('kpi_gross'),
                    value: formatMoney(summary.grossAmountCents),
                    note: I18n.t('kpi_gross_desc'),
                  ),
                  KpiCard(
                    icon: Icons.keyboard_return_outlined,
                    label: I18n.t('kpi_refund'),
                    value: formatMoney(summary.refundsAmountCents),
                    note: I18n.t('kpi_refund_desc'),
                  ),
                  KpiCard(
                    icon: Icons.calendar_month_outlined,
                    label: I18n.t('kpi_refund_count'),
                    value: '${summary.refundsCount}',
                    note: I18n.t('kpi_refund_count_desc'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final trendPanel = Panel(
                title: I18n.t('chart_trend_title_with_currency', args: {'currency': reportCurrency}),
                action: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'net', label: Text(I18n.t('chart_metric_net'))),
                    ButtonSegment(value: 'gross', label: Text(I18n.t('chart_metric_gross'))),
                    ButtonSegment(value: 'refund', label: Text(I18n.t('chart_metric_refund'))),
                  ],
                  selected: {trendMetric},
                  onSelectionChanged: (set) => onTrendMetricChanged(set.first),
                ),
                child: SizedBox(
                  height: wide ? 440 : 260,
                  child: TrendChart(
                    data: months,
                    metric: trendMetric,
                    reportCurrency: reportCurrency,
                  ),
                ),
              );
              final platformPanel = Panel(
                title: I18n.t('chart_platform_title_with_currency', args: {'currency': reportCurrency}),
                child: SizedBox(height: 260, child: _BarList(data: platforms)),
              );
              final channelFeePanel = Panel(
                title: I18n.t('chart_fee_loss_title'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          I18n.t('chart_fee_loss_deducted'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '${safeFeePct.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: safeFeePct / 100,
                        backgroundColor: const Color(0xffedf0ec),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(I18n.t('chart_fee_loss_total')),
                        Text(
                          '${formatMoney(feeCents)} $reportCurrency',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      I18n.t('chart_fee_loss_note'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff65736a),
                      ),
                    ),
                  ],
                ),
              );
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: trendPanel,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              platformPanel,
                              const SizedBox(height: 12),
                              channelFeePanel,
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        trendPanel,
                        const SizedBox(height: 12),
                        platformPanel,
                        const SizedBox(height: 12),
                        channelFeePanel,
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final countryPanel = Panel(
                title: I18n.t('chart_country_title_with_currency', args: {'currency': reportCurrency}),
                child: SizedBox(
                  height: 280,
                  child: _BarList(data: countries.take(10).toList()),
                ),
              );
              final appPanel = Panel(
                title: I18n.t('chart_app_title_with_currency', args: {'currency': reportCurrency}),
                child: SizedBox(height: 280, child: _BarList(data: apps)),
              );
              final productPanel = Panel(
                title: I18n.t('chart_sku_title_with_currency', args: {'currency': reportCurrency}),
                child: SizedBox(height: 280, child: _BarList(data: products)),
              );
              return wide
                  ? Row(
                      children: [
                        Expanded(child: countryPanel),
                        const SizedBox(width: 12),
                        Expanded(child: appPanel),
                        const SizedBox(width: 12),
                        Expanded(child: productPanel),
                      ],
                    )
                  : Column(
                      children: [
                        countryPanel,
                        const SizedBox(height: 12),
                        appPanel,
                        const SizedBox(height: 12),
                        productPanel,
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final rankingPanel = Panel(
                title: I18n.t('ranking_title'),
                action: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'countries', label: Text(I18n.t('ranking_tab_countries'))),
                    ButtonSegment(value: 'apps', label: Text(I18n.t('ranking_tab_apps'))),
                    ButtonSegment(value: 'platforms', label: Text(I18n.t('ranking_tab_platforms'))),
                    ButtonSegment(value: 'products', label: Text(I18n.t('ranking_tab_skus'))),
                    ButtonSegment(value: 'subscriptions', label: Text(I18n.t('ranking_tab_subscriptions'))),
                  ],
                  selected: {rankingTab},
                  onSelectionChanged: (set) => onRankingTabChanged(set.first),
                ),
                child: SizedBox(
                  height: 276,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Builder(
                        builder: (context) {
                          List<DataColumn> cols;
                          List<DataRow> tblRows;

                          if (rankingTab == 'countries') {
                            cols = [
                              DataColumn(label: Text(I18n.t('col_country'))),
                              DataColumn(label: Text(I18n.t('col_net'))),
                              DataColumn(label: Text(I18n.t('col_sales_share'))),
                              DataColumn(label: Text(I18n.t('col_order_count'))),
                              DataColumn(label: Text(I18n.t('col_asp'))),
                              DataColumn(label: Text(I18n.t('col_refund_rate'))),
                            ];
                            tblRows = [
                              for (final item in activeRankingList)
                                DataRow(
                                  cells: [
                                    DataCell(Text(item.label)),
                                    DataCell(Text('${formatMoney(item.netAmountCents)} $reportCurrency')),
                                    DataCell(Text('${(totalNetCents > 0 ? (item.netAmountCents / totalNetCents * 100) : 0.0).toStringAsFixed(1)}%')),
                                    DataCell(Text('${item.quantity}')),
                                    DataCell(Builder(builder: (context) {
                                      final asp = item.quantity > 0 ? (item.grossAmountCents / item.quantity).round() : 0;
                                      return Text('${formatMoney(asp)} $reportCurrency');
                                    })),
                                    DataCell(Builder(builder: (context) {
                                      final denom = item.netAmountCents + item.refundsAmountCents;
                                      final rate = denom > 0 ? (item.refundsAmountCents / denom * 100) : 0.0;
                                      return Text('${rate.toStringAsFixed(1)}%');
                                    })),
                                  ],
                                ),
                            ];
                          } else if (rankingTab == 'subscriptions') {
                            cols = [
                              DataColumn(label: Text(I18n.t('col_subscription_type'))),
                              DataColumn(label: Text(I18n.t('col_net'))),
                              DataColumn(label: Text(I18n.t('col_sales_share'))),
                              DataColumn(label: Text(I18n.t('col_refund'))),
                              DataColumn(label: Text(I18n.t('col_refund_rate'))),
                            ];
                            tblRows = [
                              for (final item in activeRankingList)
                                DataRow(
                                  cells: [
                                    DataCell(Text(item.label)),
                                    DataCell(Text('${formatMoney(item.netAmountCents)} $reportCurrency')),
                                    DataCell(Text('${(totalNetCents > 0 ? (item.netAmountCents / totalNetCents * 100) : 0.0).toStringAsFixed(1)}%')),
                                    DataCell(Text('${formatMoney(item.refundsAmountCents)} $reportCurrency')),
                                    DataCell(Builder(builder: (context) {
                                      final denom = item.netAmountCents + item.refundsAmountCents;
                                      final rate = denom > 0 ? (item.refundsAmountCents / denom * 100) : 0.0;
                                      return Text('${rate.toStringAsFixed(1)}%');
                                    })),
                                  ],
                                ),
                            ];
                          } else {
                            cols = [
                              DataColumn(label: Text(I18n.t('col_dimension'))),
                              DataColumn(label: Text(I18n.t('col_net'))),
                              DataColumn(label: Text(I18n.t('col_sales_share'))),
                              DataColumn(label: Text(I18n.t('col_refund'))),
                            ];
                            tblRows = [
                              for (final item in activeRankingList)
                                DataRow(
                                  cells: [
                                    DataCell(Text(item.label)),
                                    DataCell(Text('${formatMoney(item.netAmountCents)} $reportCurrency')),
                                    DataCell(Text('${(totalNetCents > 0 ? (item.netAmountCents / totalNetCents * 100) : 0.0).toStringAsFixed(1)}%')),
                                    DataCell(Text('${formatMoney(item.refundsAmountCents)} $reportCurrency')),
                                  ],
                                ),
                            ];
                          }

                          return DataTable(
                            columns: cols,
                            rows: tblRows,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );

              final distributionPanel = Panel(
                title: I18n.t('currency_dist_title'),
                child: SizedBox(
                  height: 276,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(I18n.t('col_currency'))),
                          DataColumn(label: Text(I18n.t('col_type'))),
                          DataColumn(label: Text(I18n.t('col_conv_gross'))),
                          DataColumn(label: Text(I18n.t('col_conv_net'))),
                          DataColumn(label: Text(I18n.t('col_conv_refund'))),
                          DataColumn(label: Text(I18n.t('col_sales_share'))),
                        ],
                        rows: [
                          for (final row in currencyRows)
                            DataRow(
                              cells: [
                                DataCell(Text(row.currency)),
                                DataCell(Text(row.type == 'raw' ? I18n.t('filter_raw_currency') : I18n.t('filter_settlement_currency'))),
                                DataCell(Text(row.type == 'raw' ? '${formatMoney(row.grossCents)} $reportCurrency' : '-')),
                                DataCell(Text(row.type == 'settlement' ? '${formatMoney(row.netCents)} $reportCurrency' : '-')),
                                DataCell(Text(row.type == 'settlement' ? '${formatMoney(row.refundCents)} $reportCurrency' : '-')),
                                DataCell(Text('${(row.share * 100).toStringAsFixed(1)}%')),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: rankingPanel),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: distributionPanel),
                      ],
                    )
                  : Column(
                      children: [
                        rankingPanel,
                        const SizedBox(height: 12),
                        distributionPanel,
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          _RecordsTable(records: records, appMappings: repository.config.appMappings),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.records,
    required this.customRates,
    required this.platformFilter,
    required this.appFilter,
    required this.skuFilter,
    required this.countryFilter,
    required this.rawCurrencyFilter,
    required this.settlementCurrencyFilter,
    required this.showAdvancedFilters,
    required this.reportCurrency,
    required this.startMonthController,
    required this.endMonthController,
    required this.skuController,
    required this.appMappings,
    required this.onPlatformChanged,
    required this.onAppChanged,
    required this.onSkuChanged,
    required this.onCountryChanged,
    required this.onRawCurrencyChanged,
    required this.onSettlementCurrencyChanged,
    required this.onShowAdvancedFiltersChanged,
    required this.onReportCurrencyChanged,
    required this.onSearch,
    required this.onClearFilters,
  });

  final List<RevenueRecord> records;
  final Map<String, double> customRates;
  final String? platformFilter;
  final String? appFilter;
  final String? skuFilter;
  final String? countryFilter;
  final String? rawCurrencyFilter;
  final String? settlementCurrencyFilter;
  final bool showAdvancedFilters;
  final String reportCurrency;
  final TextEditingController startMonthController;
  final TextEditingController endMonthController;
  final TextEditingController skuController;
  final String appMappings;

  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onAppChanged;
  final ValueChanged<String?> onSkuChanged;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onRawCurrencyChanged;
  final ValueChanged<String?> onSettlementCurrencyChanged;
  final ValueChanged<bool> onShowAdvancedFiltersChanged;
  final ValueChanged<String?> onReportCurrencyChanged;
  final VoidCallback onSearch;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final apps = records.map((r) => formatAppName(r.appIdentifier, appMappings, records)).toSet().toList()..sort();
    final countries = records.map((r) => r.countryCode).toSet().toList()..sort();
    final rawCurrencies = records.map((r) => r.rawCurrency.toUpperCase()).toSet().toList()..sort();
    final settlementCurrencies = records.map((r) => r.settlementCurrency.toUpperCase()).toSet().toList()..sort();

    final availableReportCurrencies = {
      'USD',
      'CNY',
      'EUR',
      'GBP',
      'HKD',
      'JPY',
      'CAD',
      'AUD',
      ...customRates.keys,
      ...AppConfig.defaultFxRates.keys,
    }.where((c) => c.isNotEmpty).toList()..sort();

    // 检查并重置不在当前选项中的过滤器状态
    if (appFilter != null && !apps.contains(appFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onAppChanged(null));
    }
    if (countryFilter != null && !countries.contains(countryFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onCountryChanged(null));
    }
    if (rawCurrencyFilter != null && !rawCurrencies.contains(rawCurrencyFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onRawCurrencyChanged(null));
    }
    if (settlementCurrencyFilter != null && !settlementCurrencies.contains(settlementCurrencyFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onSettlementCurrencyChanged(null));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 130,
              child: TextField(
                controller: startMonthController,
                decoration: InputDecoration(
                  labelText: I18n.t('filter_start_month'),
                  hintText: '2026-01',
                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
            ),
            const Text('-'),
            SizedBox(
              width: 130,
              child: TextField(
                controller: endMonthController,
                decoration: InputDecoration(
                  labelText: I18n.t('filter_end_month'),
                  hintText: '2026-05',
                  prefixIcon: const Icon(Icons.event_note_outlined),
                ),
              ),
            ),
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<String?>(
                initialValue: platformFilter,
                decoration: InputDecoration(labelText: I18n.t('filter_platform')),
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: null, child: Text(I18n.t('filter_all_platforms'))),
                  const DropdownMenuItem(value: 'apple', child: Text('Apple')),
                  const DropdownMenuItem(value: 'google', child: Text('Google')),
                ],
                onChanged: onPlatformChanged,
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                initialValue: (appFilter != null && apps.contains(appFilter)) ? appFilter : null,
                decoration: InputDecoration(labelText: I18n.t('filter_app')),
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: null, child: Text(I18n.t('filter_all_apps'))),
                  for (final app in apps)
                    DropdownMenuItem(
                      value: app,
                      child: Text(
                        app,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onAppChanged,
              ),
            ),
            SearchableDropdown(
              initialValue: reportCurrency,
              items: availableReportCurrencies.toList(),
              label: I18n.t('filter_report_currency'),
              onChanged: onReportCurrencyChanged,
            ),
            FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: Text(I18n.t('filter_btn_search')),
            ),
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: Text(I18n.t('filter_btn_reset')),
            ),
            TextButton.icon(
              onPressed: () => onShowAdvancedFiltersChanged(!showAdvancedFilters),
              icon: Icon(showAdvancedFilters ? Icons.expand_less : Icons.expand_more),
              label: Text(I18n.t(showAdvancedFilters ? 'filter_collapse_advanced' : 'filter_expand_advanced')),
            ),
          ],
        ),
        if (showAdvancedFilters) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: skuController,
                  decoration: InputDecoration(
                    labelText: I18n.t('filter_sku'),
                    hintText: I18n.t('filter_sku_hint'),
                    prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: (countryFilter != null && countries.contains(countryFilter)) ? countryFilter : null,
                  decoration: InputDecoration(labelText: I18n.t('filter_country')),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: null, child: Text(I18n.t('filter_all_countries'))),
                    for (final c in countries)
                      DropdownMenuItem(
                        value: c,
                        child: Text('${formatCountryName(c)} ($c)'),
                      ),
                  ],
                  onChanged: onCountryChanged,
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String?>(
                  initialValue: (rawCurrencyFilter != null && rawCurrencies.contains(rawCurrencyFilter)) ? rawCurrencyFilter : null,
                  decoration: InputDecoration(labelText: I18n.t('filter_raw_currency')),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: null, child: Text(I18n.t('filter_all_currencies'))),
                    for (final rc in rawCurrencies)
                      DropdownMenuItem(value: rc, child: Text(rc)),
                  ],
                  onChanged: onRawCurrencyChanged,
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String?>(
                  initialValue: (settlementCurrencyFilter != null && settlementCurrencies.contains(settlementCurrencyFilter)) ? settlementCurrencyFilter : null,
                  decoration: InputDecoration(labelText: I18n.t('filter_settlement_currency')),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: null, child: Text(I18n.t('filter_all_currencies'))),
                    for (final sc in settlementCurrencies)
                      DropdownMenuItem(value: sc, child: Text(sc)),
                  ],
                  onChanged: onSettlementCurrencyChanged,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({
    required this.records,
    required this.appMappings,
  });

  final List<RevenueRecord> records;
  final String appMappings;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: I18n.t('records_detail_title'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(I18n.t('col_job_month'))),
            DataColumn(label: Text(I18n.t('col_platform'))),
            DataColumn(label: Text(I18n.t('ranking_tab_apps'))),
            DataColumn(label: Text(I18n.t('col_sku'))),
            DataColumn(label: Text(I18n.t('col_country'))),
            DataColumn(label: Text(I18n.t('col_gross'))),
            DataColumn(label: Text(I18n.t('col_net'))),
            DataColumn(label: Text(I18n.t('col_refund'))),
          ],
          rows: [
            for (final record in records)
              DataRow(
                cells: [
                  DataCell(Text(record.reportMonth)),
                  DataCell(Text(record.platformLabel)),
                  DataCell(Text(formatAppName(record.appIdentifier, appMappings, records))),
                  DataCell(
                    SizedBox(
                      width: 230,
                      child: Text(
                        record.productId,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(formatCountryName(record.countryCode))),
                  DataCell(
                    Text(
                      '${record.rawCurrency} ${formatMoney(record.grossAmountCents)}',
                    ),
                  ),
                  DataCell(
                    Text(
                      '${record.settlementCurrency} ${formatMoney(record.netAmountCents)}',
                    ),
                  ),
                  DataCell(
                    Text(
                      record.refundsCount == 0
                          ? '-'
                          : '${record.settlementCurrency} ${formatMoney(record.refundsAmountCents)} / ${record.refundsCount}',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BarList extends StatelessWidget {
  const _BarList({required this.data});

  final List<DimensionTotal> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text(I18n.t('chart_no_data')));
    }
    final maxValue = data
        .map((item) => item.netAmountCents.abs())
        .fold<int>(1, (max, value) => value > max ? value : max);
    return ListView.separated(
      itemCount: data.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = data[index];
        final ratio = item.netAmountCents.abs() / maxValue;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(formatMoney(item.netAmountCents)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: ratio,
                backgroundColor: const Color(0xffedf0ec),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CurrencyDistributionRow {
  final String currency;
  final String type; // 'raw' or 'settlement'
  final int grossCents;
  final int netCents;
  final int refundCents;
  final int refundCount;
  final double share;
  _CurrencyDistributionRow({
    required this.currency,
    required this.type,
    required this.grossCents,
    required this.netCents,
    required this.refundCents,
    required this.refundCount,
    required this.share,
  });
}

String _detectBillingCycle(String productId) {
  final lower = productId.toLowerCase();
  if (lower.contains('lifetime') || lower.contains('forever') || lower.contains('ever') || lower.contains('life') || lower.contains('time')) {
    return I18n.t('sub_lifetime');
  }
  if (lower.contains('yearly') || lower.contains('annual') || lower.contains('year')) {
    return I18n.t('sub_yearly');
  }
  if (lower.contains('quarterly') || lower.contains('quarter')) {
    return I18n.t('sub_quarterly');
  }
  if (lower.contains('monthly') || lower.contains('month')) {
    return I18n.t('sub_monthly');
  }
  if (lower.contains('weekly') || lower.contains('week')) {
    return I18n.t('sub_weekly');
  }
  return I18n.t('sub_other');
}

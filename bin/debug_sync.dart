// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings
import 'package:finance_manager/services/revenue_repository.dart';

void main() async {
  print("读取本地 records...");
  final repository = await RevenueRepository.open();
  
  print("当前共有 " + repository.records.length.toString() + " 条真实记录:");
  
  var totalGrossConverted = 0.0;
  var totalNetConverted = 0.0;
  
  for (final r in repository.records) {
    final convertedGross = repository.convertRevenueCents(
      amountCents: r.grossAmountCents,
      sourceCurrency: r.rawCurrency,
      reportCurrency: 'USD',
    );
    final convertedNet = repository.convertRevenueCents(
      amountCents: r.netAmountCents,
      sourceCurrency: r.settlementCurrency,
      reportCurrency: 'USD',
    );
    
    totalGrossConverted += convertedGross / 100.0;
    totalNetConverted += convertedNet / 100.0;
    
    // 如果折算后的 Gross 大于 10.0，或者 Net 大于 10.0，打印出来看看
    if (convertedGross > 1000 || convertedNet > 1000 || r.rawCurrency != 'USD' || r.settlementCurrency != 'USD') {
      print("Record: platform=" + r.platform.name +
            ", app=" + r.appIdentifier +
            ", month=" + r.reportMonth +
            ", prod=" + r.productId +
            ", country=" + r.countryCode +
            ", rawCurr=" + r.rawCurrency + 
            ", gross=" + (r.grossAmountCents / 100.0).toStringAsFixed(2) + " (->\$" + (convertedGross / 100.0).toStringAsFixed(2) + ")" +
            ", settleCurr=" + r.settlementCurrency +
            ", net=" + (r.netAmountCents / 100.0).toStringAsFixed(2) + " (->\$" + (convertedNet / 100.0).toStringAsFixed(2) + ")");
    }
  }
  
  print("\nTotal Gross Converted: \$" + totalGrossConverted.toStringAsFixed(2));
  print("Total Net Converted: \$" + totalNetConverted.toStringAsFixed(2));
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/revenue_record.dart';

class RevenueParser {
  const RevenueParser();

  Future<List<RevenueRecord>> importFile({
    required RevenuePlatform platform,
    required String reportMonth,
    required String path,
  }) async {
    final file = File(path.trim());
    if (!await file.exists()) {
      throw FormatException('文件不存在: ${file.path}');
    }

    final bytes = await file.readAsBytes();
    final text = _decodeReport(bytes, path);

    return switch (platform) {
      RevenuePlatform.apple => parseAppleTsv(text, reportMonth),
      RevenuePlatform.google => parseGoogleCsv(text, reportMonth),
    };
  }

  List<RevenueRecord> parseAppleTsv(String tsvContent, String reportMonth) {
    final lines = const LineSplitter()
        .convert(tsvContent.trim())
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length <= 1) {
      return const [];
    }

    final rawHeaders = lines.first.split('\t').map((h) => h.trim()).toList();
    final headers = <String, int>{};
    for (var i = 0; i < rawHeaders.length; i++) {
      headers[rawHeaders[i].toLowerCase()] = i;
    }

    int indexOf(List<String> names) {
      for (final name in names) {
        final index = headers[name.toLowerCase()];
        if (index != null) {
          return index;
        }
      }
      throw FormatException('Apple 报表缺少列: ${names.join(' / ')}');
    }

    final productIndex = indexOf([
      'Developer Identifier',
      'Vendor Identifier',
      'Product Identifier',
    ]);
    final appIndex = indexOf(['Apple Identifier']);
    final countryIndex = indexOf(['Country of Sale']);
    final qtyIndex = indexOf(['Quantity']);
    final grossIndex = indexOf(['Customer Price']);
    final rawCurrencyIndex = indexOf(['Customer Currency']);
    final settlementCurrencyIndex = indexOf(['Partner Share Currency']);
    final extendedNetIndex = indexOf(['Extended Partner Share']);
    final saleReturnIndex = indexOf(['Sales or Return', 'Sale or Return']);

    final grouped = <String, RevenueRecord>{};
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split('\t');
      if (parts.firstOrNull?.startsWith('Total_Rows') ?? false) {
        break;
      }
      if (parts.length < rawHeaders.length) {
        throw FormatException('Apple 第 ${i + 1} 行列数不足');
      }

      final productId = parts[productIndex].trim();
      final rawAppleIdentifier = parts[appIndex].trim();
      if (rawAppleIdentifier.isEmpty) {
        throw FormatException('Apple 第 ${i + 1} 行 Apple Identifier 为空');
      }
      if (productId.isEmpty) {
        throw FormatException('Apple 第 ${i + 1} 行 Product ID 为空');
      }

      final appIdentifier = _normalizeAppIdentifier(
        rawAppleIdentifier,
        productId,
      );
      final countryCode = parts[countryIndex].trim().toUpperCase();
      final rawCurrency = parts[rawCurrencyIndex].trim().toUpperCase();
      final settlementCurrency = parts[settlementCurrencyIndex]
          .trim()
          .toUpperCase();
      final saleOrReturn = parts[saleReturnIndex].trim().toUpperCase();
      final qty = int.parse(parts[qtyIndex].trim());
      final extendedNetCents = toCents(parts[extendedNetIndex]);
      final customerPriceCents = toCents(parts[grossIndex]);

      final base = RevenueRecord(
        platform: RevenuePlatform.apple,
        appIdentifier: appIdentifier,
        reportMonth: reportMonth,
        productId: productId,
        countryCode: countryCode,
        rawCurrency: rawCurrency,
        settlementCurrency: settlementCurrency,
        grossAmountCents: 0,
        netAmountCents: 0,
        refundsCount: 0,
        refundsAmountCents: 0,
        settlementAmountCents: 0,
        quantity: 0,
      );
      final current = grouped[base.aggregateKey] ?? base;
      final isRefund = saleOrReturn == 'R';

      grouped[base.aggregateKey] = current.copyWith(
        grossAmountCents:
            current.grossAmountCents +
            (isRefund ? 0 : qty * customerPriceCents),
        netAmountCents: current.netAmountCents + extendedNetCents,
        refundsCount: current.refundsCount + (isRefund ? qty.abs() : 0),
        refundsAmountCents:
            current.refundsAmountCents +
            (isRefund ? extendedNetCents.abs() : 0),
        settlementAmountCents: current.settlementAmountCents + extendedNetCents,
        quantity: current.quantity + (isRefund ? 0 : qty),
      );
    }

    return grouped.values.toList();
  }

  List<RevenueRecord> parseGoogleCsv(String csvContent, String reportMonth) {
    final rows = const CsvReader().read(csvContent);
    if (rows.isEmpty) {
      return const [];
    }

    final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
    if (rows.length == 1) {
      return const [];
    }
    int indexOf(List<String> names) {
      for (final name in names) {
        final index = headers.indexOf(name.toLowerCase());
        if (index >= 0) {
          return index;
        }
      }
      throw FormatException('Google 报表缺少列: ${names.join(' / ')}');
    }

    final descIndex = indexOf(['Description']);
    final productIndex = indexOf(['Sku ID', 'Product ID']);
    final appIndex = indexOf(['Package ID', 'Product ID']);
    final countryIndex = indexOf(['Buyer Country']);
    final netIndex = indexOf(['Amount (Merchant Currency)']);
    final grossIndex = indexOf(['Amount (Buyer Currency)']);
    final rawCurrencyIndex = indexOf(['Buyer Currency']);
    final settlementCurrencyIndex = indexOf(['Merchant Currency']);
    final typeIndex = indexOf(['Transaction Type']);

    final grouped = <String, RevenueRecord>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < headers.length) {
        throw FormatException('Google 第 ${i + 1} 行列数不足');
      }

      final desc = row[descIndex].trim();
      final productId = row[productIndex].trim();
      final rawAppIdentifier = row[appIndex].trim();
      final transactionType = row[typeIndex].trim();

      final lowerType = transactionType.toLowerCase();
      final lowerDesc = desc.toLowerCase();
      final isAccountAdjustment =
          lowerType != 'charge' && lowerType != 'charge refund' ||
          lowerDesc.contains('tax') ||
          lowerDesc.contains('withholding');
      if ((productId.isEmpty || rawAppIdentifier.isEmpty) &&
          isAccountAdjustment) {
        continue;
      }
      if (rawAppIdentifier.isEmpty) {
        throw FormatException('Google 第 ${i + 1} 行 Package ID 为空');
      }
      if (productId.isEmpty) {
        throw FormatException('Google 第 ${i + 1} 行 SKU ID / Product ID 为空');
      }

      final appIdentifier = _normalizeAppIdentifier(
        rawAppIdentifier,
        productId,
      );
      final countryCode = row[countryIndex].trim().toUpperCase();
      final rawCurrency = row[rawCurrencyIndex].trim().toUpperCase();
      final settlementCurrency = row[settlementCurrencyIndex]
          .trim()
          .toUpperCase();
      final netAmountCents = toCents(row[netIndex]);
      final grossAmountCents = toCents(row[grossIndex]);
      final isRefund = transactionType == 'Charge refund';

      final base = RevenueRecord(
        platform: RevenuePlatform.google,
        appIdentifier: appIdentifier,
        reportMonth: reportMonth,
        productId: productId,
        countryCode: countryCode,
        rawCurrency: rawCurrency,
        settlementCurrency: settlementCurrency,
        grossAmountCents: 0,
        netAmountCents: 0,
        refundsCount: 0,
        refundsAmountCents: 0,
        settlementAmountCents: 0,
        quantity: 0,
      );
      final current = grouped[base.aggregateKey] ?? base;
      grouped[base.aggregateKey] = current.copyWith(
        grossAmountCents:
            current.grossAmountCents +
            (transactionType == 'Charge' ? grossAmountCents : 0),
        netAmountCents: current.netAmountCents + netAmountCents,
        refundsCount: current.refundsCount + (isRefund ? 1 : 0),
        refundsAmountCents:
            current.refundsAmountCents + (isRefund ? netAmountCents.abs() : 0),
        settlementAmountCents: current.settlementAmountCents + netAmountCents,
        quantity: current.quantity + (transactionType == 'Charge' ? 1 : 0),
      );
    }

    return grouped.values.toList();
  }

  static int toCents(String amount) {
    final clean = amount.replaceAll(',', '').trim();
    if (clean.isEmpty) {
      throw const FormatException('金额不能为空');
    }
    final value = double.parse(clean);
    return (value * 100).round();
  }

  static String _decodeReport(List<int> bytes, String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.zip')) {
      return extractFirstCsvFromZip(bytes);
    }
    if (lowerPath.endsWith('.gz')) {
      return utf8.decode(gzip.decode(bytes));
    }
    if (_startsWith(bytes, [0xff, 0xfe])) {
      return _decodeUtf16(bytes.skip(2).toList(), littleEndian: true);
    }
    if (_startsWith(bytes, [0xfe, 0xff])) {
      return _decodeUtf16(bytes.skip(2).toList(), littleEndian: false);
    }
    return utf8.decode(bytes);
  }

  static String extractFirstCsvFromZip(List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    final view = ByteData.sublistView(data);

    // 尝试在字节流中扫描 Central Directory Header 的 Signature: 0x02014b50
    int? cdOffset;
    for (var i = 0; i <= data.length - 46; i++) {
      if (view.getUint32(i, Endian.little) == 0x02014b50) {
        cdOffset = i;
        break;
      }
    }

    int? compressedSize;
    int? localHeaderOffset;

    if (cdOffset != null) {
      compressedSize = view.getUint32(cdOffset + 20, Endian.little);
      localHeaderOffset = view.getUint32(cdOffset + 42, Endian.little);
    }

    var offset = localHeaderOffset ?? 0;
    if (offset + 30 <= data.length) {
      final signature = view.getUint32(offset, Endian.little);
      if (signature == 0x04034b50) {
        final compressionMethod = view.getUint16(offset + 8, Endian.little);
        var localCompressedSize = view.getUint32(offset + 18, Endian.little);
        final fileNameLength = view.getUint16(offset + 26, Endian.little);
        final extraLength = view.getUint16(offset + 28, Endian.little);

        // 若 Local Header 中的 compressedSize 是 0，则采用从 Central Directory 读回的真实大小
        if (localCompressedSize == 0 && compressedSize != null) {
          localCompressedSize = compressedSize;
        }

        final nameStart = offset + 30;
        final nameEnd = nameStart + fileNameLength;
        final contentStart = nameEnd + extraLength;
        final contentEnd = contentStart + localCompressedSize;

        if (nameEnd > data.length || contentEnd > data.length) {
          throw const FormatException('ZIP 文件结构不完整');
        }

        final name = utf8.decode(data.sublist(nameStart, nameEnd));
        final content = data.sublist(contentStart, contentEnd);
        if (name.toLowerCase().endsWith('.csv')) {
          final csvBytes = switch (compressionMethod) {
            0 => content,
            8 => ZLibCodec(raw: true).decode(content),
            _ => throw FormatException('ZIP CSV 使用了不支持的压缩方式: $compressionMethod'),
          };
          return _decodePlainText(csvBytes);
        }
      }
    }

    throw const FormatException('ZIP 中未找到 CSV 报表文件');
  }

  static String _decodePlainText(List<int> bytes) {
    if (_startsWith(bytes, [0xff, 0xfe])) {
      return _decodeUtf16(bytes.skip(2).toList(), littleEndian: true);
    }
    if (_startsWith(bytes, [0xfe, 0xff])) {
      return _decodeUtf16(bytes.skip(2).toList(), littleEndian: false);
    }
    return utf8.decode(bytes);
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final unit = littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1];
      codeUnits.add(unit);
    }
    return String.fromCharCodes(codeUnits);
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  static String _normalizeAppIdentifier(String raw, String productId) {
    return raw.trim();
  }
}

class CsvReader {
  const CsvReader();

  List<List<String>> read(String input) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        row.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        row.add(field.toString());
        field.clear();
        if (row.any((cell) => cell.trim().isNotEmpty)) {
          rows.add(List<String>.from(row));
        }
        row.clear();
      } else {
        field.write(char);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(List<String>.from(row));
      }
    }

    return rows;
  }
}

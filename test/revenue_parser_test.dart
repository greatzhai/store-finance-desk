import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:finance_manager/models/revenue_record.dart';
import 'package:finance_manager/services/revenue_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = RevenueParser();

  test('parses and aggregates Apple financial TSV rows', () {
    const tsv = '''
Apple Identifier\tDeveloper Identifier\tCountry of Sale\tQuantity\tPartner Share\tCustomer Price\tCustomer Currency\tPartner Share Currency\tExtended Partner Share\tSale or Return
6760221775\tcom.obdcan.monthly\tUS\t2\t7.00\t9.99\tUSD\tUSD\t14.00\tS
6760221775\tcom.obdcan.monthly\tUS\t1\t-7.00\t9.99\tUSD\tUSD\t-7.00\tR
''';

    final records = parser.parseAppleTsv(tsv, '2026-05');

    expect(records, hasLength(1));
    expect(records.first.platform, RevenuePlatform.apple);
    expect(records.first.appIdentifier, '6760221775');
    expect(records.first.grossAmountCents, 1998);
    expect(records.first.netAmountCents, 700);
    expect(records.first.refundsCount, 1);
    expect(records.first.refundsAmountCents, 700);
  });

  test('parses Google earnings CSV and skips account-level tax rows', () {
    const csv = '''
Description,Sku ID,Package ID,Buyer Country,Amount (Merchant Currency),Amount (Buyer Currency),Buyer Currency,Merchant Currency,Transaction Type
Monthly,com.obdcan.monthly,com.obdcan.scanner,US,7.00,9.99,USD,USD,Charge
Monthly,com.obdcan.monthly,com.obdcan.scanner,US,-7.00,-9.99,USD,USD,Charge refund
Withholding tax,,,US,-1.00,-1.00,USD,USD,Tax
''';

    final records = parser.parseGoogleCsv(csv, '2026-05');

    expect(records, hasLength(1));
    expect(records.first.platform, RevenuePlatform.google);
    expect(records.first.appIdentifier, 'com.obdcan.scanner');
    expect(records.first.grossAmountCents, 999);
    expect(records.first.netAmountCents, 0);
    expect(records.first.refundsCount, 1);
    expect(records.first.refundsAmountCents, 700);
  });

  test('returns empty list for empty or single header Google CSV', () {
    expect(parser.parseGoogleCsv('', '2026-05'), isEmpty);
    expect(
      parser.parseGoogleCsv(
        'Description,Sku ID,Package ID,Buyer Country,Amount (Merchant Currency),Amount (Buyer Currency),Buyer Currency,Merchant Currency,Transaction Type\n',
        '2026-05',
      ),
      isEmpty,
    );
  });

  test('converts decimal strings to cents with rounding', () {
    expect(RevenueParser.toCents('1.235'), 124);
    expect(RevenueParser.toCents('-7.00'), -700);
    expect(RevenueParser.toCents('1,234.56'), 123456);
  });

  test('imports Google earnings CSV from a ZIP file', () async {
    const csv = '''
Description,Sku ID,Package ID,Buyer Country,Amount (Merchant Currency),Amount (Buyer Currency),Buyer Currency,Merchant Currency,Transaction Type
Monthly,com.obdcan.monthly,com.obdcan.scanner,US,7.00,9.99,USD,USD,Charge
''';
    final tempDir = await Directory.systemTemp.createTemp('finance_zip_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final zipFile = File('${tempDir.path}/earnings_202605.zip');
    await zipFile.writeAsBytes(
      _storedZip('earnings_202605.csv', utf8.encode(csv)),
    );

    final records = await parser.importFile(
      platform: RevenuePlatform.google,
      reportMonth: '2026-05',
      path: zipFile.path,
    );

    expect(records, hasLength(1));
    expect(records.first.productId, 'com.obdcan.monthly');
    expect(records.first.grossAmountCents, 999);
  });
  test('imports Google earnings CSV from a ZIP file with Data Descriptor', () async {
    const csv = '''
Description,Sku ID,Package ID,Buyer Country,Amount (Merchant Currency),Amount (Buyer Currency),Buyer Currency,Merchant Currency,Transaction Type
Monthly,com.obdcan.monthly,com.obdcan.scanner,US,7.00,9.99,USD,USD,Charge
''';
    final tempDir = await Directory.systemTemp.createTemp('finance_zip_dd_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final zipFile = File('${tempDir.path}/earnings_202605_dd.zip');
    await zipFile.writeAsBytes(
      _storedZipWithDataDescriptor('earnings_202605.csv', utf8.encode(csv)),
    );

    final records = await parser.importFile(
      platform: RevenuePlatform.google,
      reportMonth: '2026-05',
      path: zipFile.path,
    );

    expect(records, hasLength(1));
    expect(records.first.productId, 'com.obdcan.monthly');
    expect(records.first.grossAmountCents, 999);
  });
}

List<int> _storedZip(String fileName, List<int> content) {
  final name = utf8.encode(fileName);
  final bytes = BytesBuilder();
  void u16(int value) {
    bytes.add([value & 0xff, (value >> 8) & 0xff]);
  }

  void u32(int value) {
    bytes.add([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  u32(0x04034b50);
  u16(20);
  u16(0);
  u16(0);
  u16(0);
  u16(0);
  u32(0);
  u32(content.length);
  u32(content.length);
  u16(name.length);
  u16(0);
  bytes.add(name);
  bytes.add(content);
  return bytes.toBytes();
}

List<int> _storedZipWithDataDescriptor(String fileName, List<int> content) {
  final name = utf8.encode(fileName);
  final bytes = BytesBuilder();
  void u16(int value) {
    bytes.add([value & 0xff, (value >> 8) & 0xff]);
  }

  void u32(int value) {
    bytes.add([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  final localHeaderOffset = 0;

  // Local File Header
  u32(0x04034b50);
  u16(20);
  u16(0x0008); // General Purpose Bit Flag (bit 3 set to 1)
  u16(0);      // Compression Method (0 = stored)
  u16(0);
  u16(0);
  u32(0);      // CRC-32 (0 when flag bit 3 is set)
  u32(0);      // Compressed Size
  u32(0);      // Uncompressed Size
  u16(name.length);
  u16(0);
  bytes.add(name);

  // File Data
  bytes.add(content);

  // Data Descriptor
  u32(0x08074b50);
  u32(0);
  u32(content.length);
  u32(content.length);

  final centralDirectoryOffset = bytes.length;

  // Central Directory Header
  u32(0x02014b50);
  u16(20);
  u16(20);
  u16(0x0008);
  u16(0);
  u16(0);
  u16(0);
  u32(0);
  u32(content.length);
  u32(content.length);
  u16(name.length);
  u16(0);
  u16(0);
  u16(0);
  u16(0);
  u32(0);
  u32(localHeaderOffset);
  bytes.add(name);

  final centralDirectorySize = bytes.length - centralDirectoryOffset;

  // End of Central Directory (EOCD)
  u32(0x06054b50);
  u16(0);
  u16(0);
  u16(1);
  u16(1);
  u32(centralDirectorySize);
  u32(centralDirectoryOffset);
  u16(0);

  return bytes.toBytes();
}

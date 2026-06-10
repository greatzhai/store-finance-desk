import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:pointycastle/signers/rsa_signer.dart';

import '../models/app_config.dart';
import '../models/revenue_record.dart';
import 'revenue_parser.dart';

class PlatformSyncResult {
  const PlatformSyncResult({
    required this.status,
    required this.records,
    this.reason,
  });

  final String status;
  final List<RevenueRecord> records;
  final String? reason;

  bool get success => status == 'success';
}

class OfficialSyncResult {
  const OfficialSyncResult({required this.apple, required this.google});

  final PlatformSyncResult apple;
  final PlatformSyncResult google;

  int get recordsCount => apple.records.length + google.records.length;

  String get overallStatus {
    final aStatus = apple.status;
    final gStatus = google.status;

    if (aStatus == 'success' && gStatus == 'success') {
      return 'success';
    }
    if (aStatus == 'not_available' && gStatus == 'not_available') {
      return 'not_available';
    }
    if (aStatus == 'error' && gStatus == 'error') {
      return 'error';
    }
    if (aStatus == 'success' || gStatus == 'success') {
      return 'partial';
    }
    return 'error';
  }

  String? get errorMessage {
    final messages = <String>[
      if (apple.reason != null) 'Apple: ${apple.reason}',
      if (google.reason != null) 'Google: ${google.reason}',
    ];
    return messages.isEmpty ? null : messages.join(' | ');
  }
}

class FinanceRemoteSyncService {
  FinanceRemoteSyncService({
    http.Client? client,
    RevenueParser? parser,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _parser = parser ?? const RevenueParser(),
       _now = now ?? DateTime.now;

  final http.Client _client;
  final RevenueParser _parser;
  final DateTime Function() _now;

  Future<OfficialSyncResult> syncMonth({
    required AppConfig config,
    required String reportMonth,
  }) async {
    final apple = await _runPlatformSync(
      () => _syncApple(config: config, reportMonth: reportMonth),
    );
    final google = await _runPlatformSync(
      () => _syncGoogle(config: config, reportMonth: reportMonth),
    );
    return OfficialSyncResult(apple: apple, google: google);
  }

  Future<void> testAppleConnection(AppConfig config) async {
    if (!config.hasAppleConfig) {
      throw const FormatException('Apple 配置不完整，请填写所有必填字段。');
    }

    String privateKey;
    try {
      privateKey = await File(config.applePrivateKeyPath).readAsString();
    } catch (e) {
      throw FormatException('无法读取私钥文件：请确保填写的 .p8 私钥文件绝对路径正确且可读。报错: $e');
    }

    String token;
    try {
      token = _appleJwt(
        issuerId: config.appleIssuerId,
        keyId: config.appleKeyId,
        privateKeyPem: privateKey,
      );
    } catch (e) {
      throw FormatException('私钥解析与 JWT 签名失败，请检查 Issuer ID、Key ID 是否匹配或私钥格式是否正确。报错: $e');
    }

    final testMonth = _calendarToAppleFiscal('2026-01');
    final uri =
        Uri.https('api.appstoreconnect.apple.com', '/v1/financeReports', {
          'filter[regionCode]': 'ZZ',
          'filter[reportDate]': testMonth,
          'filter[reportType]': 'FINANCIAL',
          'filter[vendorNumber]': config.appleVendorNumber,
        });

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/a-gzip',
      },
    );

    if (response.statusCode == 401) {
      throw const FormatException('身份验证失败：请检查 Issuer ID、Key ID 和私钥内容是否有效。');
    }
    if (response.statusCode == 403) {
      throw const FormatException('访问被拒绝：请确保该 API 密钥已在 App Store Connect 中被授予了“财务”角色权限。');
    }
    if (response.statusCode == 400) {
      if (response.body.contains('vendorNumber') || response.body.contains('VENDOR')) {
        throw const FormatException('无效的供应商编号：请检查 Vendor Number (供应商/商家编号) 是否填写正确。');
      }
    }
    // 200, 404 等代表鉴权通过但无数据，都是合法的 API 通信状态
  }

  Future<void> testGoogleConnection(AppConfig config) async {
    if (!config.hasGoogleConfig) {
      throw const FormatException('Google 配置不完整，请填写所有必填字段。');
    }

    String credentialsJson;
    try {
      credentialsJson = await File(config.googleServiceAccountPath).readAsString();
    } catch (e) {
      throw FormatException('无法读取 Service Account JSON 文件，请确保填写的绝对路径正确且可读。报错: $e');
    }

    Map<String, dynamic> serviceAccountJson;
    try {
      serviceAccountJson = jsonDecode(credentialsJson) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Service Account JSON 格式损坏，解析失败。报错: $e');
    }

    String token;
    try {
      token = await _googleAccessToken(serviceAccountJson);
    } catch (e) {
      throw FormatException('OAuth 2.0 身份验证失败，请确认服务账号 JSON 凭证有效。报错: $e');
    }

    final uri = Uri.https(
      'storage.googleapis.com',
      '/storage/v1/b/${config.googleBucketId}/o',
      {'maxResults': '1'},
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 404) {
      throw const FormatException('Bucket 不存在：请检查 Bucket ID (例如 pubsite_prod_rev_...) 是否填写正确。');
    }
    if (response.statusCode == 403) {
      throw const FormatException('访问被拒绝：服务账号未获得该 Bucket 的读取权限（需授予 Storage Object Viewer 权限）。若刚在 Play 授权用户，可能需要数小时至 24 小时才生效。');
    }
    if (response.statusCode != 200) {
      throw FormatException('存储桶连接测试失败 (HTTP ${response.statusCode})，详情: ${response.body}');
    }
  }


  Future<PlatformSyncResult> _runPlatformSync(
    Future<PlatformSyncResult> Function() action,
  ) async {
    try {
      return await action();
    } catch (error) {
      return PlatformSyncResult(
        status: 'error',
        records: const [],
        reason: '$error',
      );
    }
  }

  Future<PlatformSyncResult> _syncApple({
    required AppConfig config,
    required String reportMonth,
  }) async {
    if (!config.hasAppleConfig) {
      return const PlatformSyncResult(
        status: 'skipped',
        records: [],
        reason: 'Apple 配置不完整',
      );
    }

    final privateKey = await File(config.applePrivateKeyPath).readAsString();
    final token = _appleJwt(
      issuerId: config.appleIssuerId,
      keyId: config.appleKeyId,
      privateKeyPem: privateKey,
    );
    final appleReportMonth = _calendarToAppleFiscal(reportMonth);
    final uri =
        Uri.https('api.appstoreconnect.apple.com', '/v1/financeReports', {
          'filter[regionCode]': 'ZZ',
          'filter[reportDate]': appleReportMonth,
          'filter[reportType]': 'FINANCIAL',
          'filter[vendorNumber]': config.appleVendorNumber,
        });
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/a-gzip',
      },
    );
    if (response.statusCode == 404) {
      return PlatformSyncResult(
        status: 'not_available',
        records: const [],
        reason: 'Apple 暂无 $reportMonth 官方财务数据',
      );
    }
    if (response.statusCode != 200) {
      throw FormatException(
        'Apple financeReports HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final tsv = utf8.decode(gzip.decode(response.bodyBytes));
    final records = _parser.parseAppleTsv(tsv, reportMonth);
    if (records.isEmpty) {
      return PlatformSyncResult(
        status: 'not_available',
        records: const [],
        reason: 'Apple 报表无收入记录',
      );
    }
    return PlatformSyncResult(status: 'success', records: records);
  }

  Future<PlatformSyncResult> _syncGoogle({
    required AppConfig config,
    required String reportMonth,
  }) async {
    if (!config.hasGoogleConfig) {
      return const PlatformSyncResult(
        status: 'skipped',
        records: [],
        reason: 'Google 配置不完整',
      );
    }

    final serviceAccountJson =
        jsonDecode(await File(config.googleServiceAccountPath).readAsString())
            as Map<String, dynamic>;
    final token = await _googleAccessToken(serviceAccountJson);
    final compactMonth = reportMonth.replaceAll('-', '');
    final prefix = 'earnings/earnings_$compactMonth';
    final zipObjects = await _listGoogleZipObjects(
      bucketName: config.googleBucketId,
      prefix: prefix,
      token: token,
    );
    if (zipObjects.isEmpty) {
      return PlatformSyncResult(
        status: 'not_available',
        records: const [],
        reason: 'Google 暂无 $reportMonth earnings ZIP',
      );
    }

    final allRecords = <RevenueRecord>[];
    for (final objectName in zipObjects) {
      final bytes = await _downloadGoogleObject(
        bucketName: config.googleBucketId,
        objectName: objectName,
        token: token,
      );
      final csv = RevenueParser.extractFirstCsvFromZip(bytes);
      allRecords.addAll(_parser.parseGoogleCsv(csv, reportMonth));
    }

    final merged = _mergeRecords(allRecords);
    return PlatformSyncResult(status: 'success', records: merged);
  }

  Future<String> _googleAccessToken(Map<String, dynamic> serviceAccount) async {
    final clientEmail = serviceAccount['client_email'] as String?;
    final privateKeyPem = serviceAccount['private_key'] as String?;
    final tokenUri =
        serviceAccount['token_uri'] as String? ??
        'https://oauth2.googleapis.com/token';
    if (clientEmail == null || privateKeyPem == null) {
      throw const FormatException(
        'Google service account JSON 缺少 client_email/private_key',
      );
    }

    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final assertion = _googleJwt(
      clientEmail: clientEmail,
      privateKeyPem: privateKeyPem,
      tokenUri: tokenUri,
      issuedAt: nowSeconds,
      expiresAt: nowSeconds + 3600,
    );
    final response = await _client.post(
      Uri.parse(tokenUri),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': assertion,
      },
    );
    if (response.statusCode != 200) {
      throw FormatException(
        'Google OAuth HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final token = decoded['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const FormatException('Google OAuth 响应缺少 access_token');
    }
    return token;
  }

  Future<List<String>> _listGoogleZipObjects({
    required String bucketName,
    required String prefix,
    required String token,
  }) async {
    final names = <String>[];
    String? pageToken;
    do {
      final params = <String, String>{'prefix': prefix};
      if (pageToken != null) {
        params['pageToken'] = pageToken;
      }
      final uri = Uri.https(
        'storage.googleapis.com',
        '/storage/v1/b/$bucketName/o',
        params,
      );
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw FormatException(
          'Google GCS list HTTP ${response.statusCode}: ${response.body}',
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = decoded['items'] as List<dynamic>? ?? const [];
      for (final item in items.cast<Map<String, dynamic>>()) {
        final name = item['name'] as String?;
        if (name != null && name.endsWith('.zip')) {
          names.add(name);
        }
      }
      pageToken = decoded['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return names;
  }

  Future<List<int>> _downloadGoogleObject({
    required String bucketName,
    required String objectName,
    required String token,
  }) async {
    final uri = Uri.parse(
      'https://storage.googleapis.com/storage/v1/b/'
      '${Uri.encodeComponent(bucketName)}/o/'
      '${Uri.encodeComponent(objectName)}?alt=media',
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw FormatException(
        'Google GCS download HTTP ${response.statusCode}: ${response.body}',
      );
    }
    return response.bodyBytes;
  }

  String _appleJwt({
    required String issuerId,
    required String keyId,
    required String privateKeyPem,
  }) {
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final header = {'alg': 'ES256', 'kid': keyId, 'typ': 'JWT'};
    final payload = {
      'iss': issuerId,
      'exp': nowSeconds + 900,
      'aud': 'appstoreconnect-v1',
    };
    final signingInput = '${_base64UrlJson(header)}.${_base64UrlJson(payload)}';
    final privateKey = _parseEcPrivateKey(privateKeyPem);
    final signature = _signEs256(signingInput, privateKey);
    return '$signingInput.${_base64Url(signature)}';
  }

  String _googleJwt({
    required String clientEmail,
    required String privateKeyPem,
    required String tokenUri,
    required int issuedAt,
    required int expiresAt,
  }) {
    final header = {'alg': 'RS256', 'typ': 'JWT'};
    final payload = {
      'iss': clientEmail,
      'scope': 'https://www.googleapis.com/auth/devstorage.read_only',
      'aud': tokenUri,
      'iat': issuedAt,
      'exp': expiresAt,
    };
    final signingInput = '${_base64UrlJson(header)}.${_base64UrlJson(payload)}';
    final privateKey = _parseRsaPrivateKey(privateKeyPem);
    final signature = _signRs256(signingInput, privateKey);
    return '$signingInput.${_base64Url(signature)}';
  }

  Uint8List _signEs256(String signingInput, ECPrivateKey privateKey) {
    final signer = ECDSASigner(SHA256Digest())
      ..init(
        true,
        ParametersWithRandom(
          PrivateKeyParameter<ECPrivateKey>(privateKey),
          _secureRandom(),
        ),
      );
    final signature =
        signer.generateSignature(Uint8List.fromList(utf8.encode(signingInput)))
            as ECSignature;
    return Uint8List.fromList([
      ..._fixedLengthBytes(signature.r, 32),
      ..._fixedLengthBytes(signature.s, 32),
    ]);
  }

  Uint8List _signRs256(String signingInput, RSAPrivateKey privateKey) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(signingInput)),
    );
    return signature.bytes;
  }

  SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    final seed = Uint8List(32);
    final random = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  ECPrivateKey _parseEcPrivateKey(String pem) {
    final der = _pemToDer(pem);
    return ASN1Utils.ecPrivateKeyFromDerBytes(der, pkcs8: true);
  }

  RSAPrivateKey _parseRsaPrivateKey(String pem) {
    final der = _pemToDer(pem);
    final parser = ASN1Parser(der);
    final topLevel = parser.nextObject() as ASN1Sequence;
    final privateKeyOctets = topLevel.elements!.elementAt(2) as ASN1OctetString;
    final rsaParser = ASN1Parser(privateKeyOctets.valueBytes!);
    final rsaSequence = rsaParser.nextObject() as ASN1Sequence;
    final elements = rsaSequence.elements!;
    return RSAPrivateKey(
      (elements.elementAt(1) as ASN1Integer).integer!,
      (elements.elementAt(3) as ASN1Integer).integer!,
      (elements.elementAt(4) as ASN1Integer).integer!,
      (elements.elementAt(5) as ASN1Integer).integer!,
    );
  }

  Uint8List _pemToDer(String pem) {
    final body = pem
        .split('\n')
        .where((line) => !line.startsWith('-----'))
        .join()
        .trim();
    return Uint8List.fromList(base64Decode(body));
  }

  String _base64UrlJson(Map<String, Object> value) {
    return _base64Url(utf8.encode(jsonEncode(value)));
  }

  String _base64Url(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  List<int> _fixedLengthBytes(BigInt value, int length) {
    final hex = value.toRadixString(16).padLeft(length * 2, '0');
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    if (bytes.length > length) {
      return bytes.sublist(bytes.length - length);
    }
    return bytes;
  }

  String _calendarToAppleFiscal(String calendarMonth) {
    final parts = calendarMonth.split('-').map(int.parse).toList();
    final year = parts[0];
    final month = parts[1];
    if (month >= 10) {
      return '${year + 1}-${(month - 9).toString().padLeft(2, '0')}';
    }
    return '$year-${(month + 3).toString().padLeft(2, '0')}';
  }

  List<RevenueRecord> _mergeRecords(List<RevenueRecord> records) {
    final map = <String, RevenueRecord>{};
    for (final record in records) {
      final current = map[record.aggregateKey];
      if (current == null) {
        map[record.aggregateKey] = record;
        continue;
      }
      map[record.aggregateKey] = current.copyWith(
        grossAmountCents: current.grossAmountCents + record.grossAmountCents,
        netAmountCents: current.netAmountCents + record.netAmountCents,
        refundsCount: current.refundsCount + record.refundsCount,
        refundsAmountCents:
            current.refundsAmountCents + record.refundsAmountCents,
        settlementAmountCents:
            current.settlementAmountCents + record.settlementAmountCents,
      );
    }
    return map.values.toList();
  }
}

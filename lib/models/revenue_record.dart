enum RevenuePlatform { apple, google }

RevenuePlatform revenuePlatformFromName(String name) {
  return RevenuePlatform.values.firstWhere(
    (platform) => platform.name == name,
    orElse: () => throw FormatException('Unknown platform: $name'),
  );
}

class RevenueRecord {
  const RevenueRecord({
    required this.platform,
    required this.appIdentifier,
    required this.reportMonth,
    required this.productId,
    required this.countryCode,
    required this.rawCurrency,
    required this.settlementCurrency,
    required this.grossAmountCents,
    required this.netAmountCents,
    required this.refundsCount,
    required this.refundsAmountCents,
    required this.settlementAmountCents,
    this.quantity = 1,
  });

  final RevenuePlatform platform;
  final String appIdentifier;
  final String reportMonth;
  final String productId;
  final String countryCode;
  final String rawCurrency;
  final String settlementCurrency;
  final int grossAmountCents;
  final int netAmountCents;
  final int refundsCount;
  final int refundsAmountCents;
  final int settlementAmountCents;
  final int quantity;

  String get platformLabel =>
      platform == RevenuePlatform.apple ? 'Apple' : 'Google';

  RevenueRecord copyWith({
    int? grossAmountCents,
    int? netAmountCents,
    int? refundsCount,
    int? refundsAmountCents,
    int? settlementAmountCents,
    int? quantity,
  }) {
    return RevenueRecord(
      platform: platform,
      appIdentifier: appIdentifier,
      reportMonth: reportMonth,
      productId: productId,
      countryCode: countryCode,
      rawCurrency: rawCurrency,
      settlementCurrency: settlementCurrency,
      grossAmountCents: grossAmountCents ?? this.grossAmountCents,
      netAmountCents: netAmountCents ?? this.netAmountCents,
      refundsCount: refundsCount ?? this.refundsCount,
      refundsAmountCents: refundsAmountCents ?? this.refundsAmountCents,
      settlementAmountCents:
          settlementAmountCents ?? this.settlementAmountCents,
      quantity: quantity ?? this.quantity,
    );
  }

  String get aggregateKey {
    return [
      platform.name,
      appIdentifier,
      reportMonth,
      productId,
      countryCode,
      rawCurrency,
      settlementCurrency,
    ].join('|');
  }

  Map<String, Object> toJson() {
    return {
      'platform': platform.name,
      'appIdentifier': appIdentifier,
      'reportMonth': reportMonth,
      'productId': productId,
      'countryCode': countryCode,
      'rawCurrency': rawCurrency,
      'settlementCurrency': settlementCurrency,
      'grossAmountCents': grossAmountCents,
      'netAmountCents': netAmountCents,
      'refundsCount': refundsCount,
      'refundsAmountCents': refundsAmountCents,
      'settlementAmountCents': settlementAmountCents,
      'quantity': quantity,
    };
  }

  factory RevenueRecord.fromJson(Map<String, Object?> json) {
    return RevenueRecord(
      platform: revenuePlatformFromName(json['platform'] as String),
      appIdentifier: json['appIdentifier'] as String,
      reportMonth: json['reportMonth'] as String,
      productId: json['productId'] as String,
      countryCode: json['countryCode'] as String,
      rawCurrency: json['rawCurrency'] as String,
      settlementCurrency: json['settlementCurrency'] as String,
      grossAmountCents: json['grossAmountCents'] as int,
      netAmountCents: json['netAmountCents'] as int,
      refundsCount: json['refundsCount'] as int,
      refundsAmountCents: json['refundsAmountCents'] as int,
      settlementAmountCents: json['settlementAmountCents'] as int,
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}

class SyncRun {
  const SyncRun({
    required this.reportMonth,
    required this.source,
    required this.status,
    required this.appleStatus,
    required this.googleStatus,
    required this.recordsCount,
    required this.startedAt,
    this.errorMessage,
  });

  final String reportMonth;
  final String source;
  final String status;
  final String appleStatus;
  final String googleStatus;
  final int recordsCount;
  final DateTime startedAt;
  final String? errorMessage;

  Map<String, Object?> toJson() {
    return {
      'reportMonth': reportMonth,
      'source': source,
      'status': status,
      'appleStatus': appleStatus,
      'googleStatus': googleStatus,
      'recordsCount': recordsCount,
      'startedAt': startedAt.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory SyncRun.fromJson(Map<String, Object?> json) {
    return SyncRun(
      reportMonth: json['reportMonth'] as String,
      source: json['source'] as String,
      status: json['status'] as String,
      appleStatus: json['appleStatus'] as String,
      googleStatus: json['googleStatus'] as String,
      recordsCount: json['recordsCount'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class RevenueSummary {
  const RevenueSummary({
    required this.grossAmountCents,
    required this.netAmountCents,
    required this.refundsAmountCents,
    required this.refundsCount,
    required this.activeMonths,
  });

  final int grossAmountCents;
  final int netAmountCents;
  final int refundsAmountCents;
  final int refundsCount;
  final int activeMonths;
}

class DimensionTotal {
  const DimensionTotal({
    required this.label,
    required this.grossAmountCents,
    required this.netAmountCents,
    required this.refundsAmountCents,
    required this.refundsCount,
    required this.quantity,
  });

  final String label;
  final int grossAmountCents;
  final int netAmountCents;
  final int refundsAmountCents;
  final int refundsCount;
  final int quantity;
}

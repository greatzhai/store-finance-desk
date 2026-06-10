class AppConfig {
  static const String defaultAppMappings = '';

  static const Map<String, double> defaultFxRates = {
    'USD': 1.0,
    'CNY': 0.139,
    'EUR': 1.08,
    'GBP': 1.27,
    'CAD': 0.73,
    'AUD': 0.66,
    'JPY': 0.0067,
    'KRW': 0.00073,
    'HKD': 0.128,
    'SGD': 0.74,
    'TWD': 0.031,
    'HUF': 0.0028,
    'MXN': 0.055,
    'UAH': 0.024,
    'PLN': 0.25,
    'THB': 0.027,
    'SAR': 0.267,
    'ZAR': 0.054,
    'BRL': 0.18,
    'INR': 0.012,
    'TRY': 0.031,
    'AED': 0.272,
    'CZK': 0.043,
    'SEK': 0.095,
    'PHP': 0.017,
    'PYG': 0.00013,
  };

  const AppConfig({
    this.appleIssuerId = '',
    this.appleKeyId = '',
    this.appleVendorNumber = '',
    this.applePrivateKeyPath = '',
    this.googleBucketId = '',
    this.googleServiceAccountPath = '',
    this.appMappings = defaultAppMappings,
    this.customRates = defaultFxRates,
    this.language = 'zh',
    this.isLanguageUserSet = false,
  });

  final String appleIssuerId;
  final String appleKeyId;
  final String appleVendorNumber;
  final String applePrivateKeyPath;
  final String googleBucketId;
  final String googleServiceAccountPath;
  final String appMappings;
  final Map<String, double> customRates;
  final String language;
  final bool isLanguageUserSet;

  bool get hasAppleConfig {
    return appleIssuerId.isNotEmpty &&
        appleKeyId.isNotEmpty &&
        appleVendorNumber.isNotEmpty &&
        applePrivateKeyPath.isNotEmpty;
  }

  bool get hasGoogleConfig {
    return googleBucketId.isNotEmpty && googleServiceAccountPath.isNotEmpty;
  }

  bool get isEmpty {
    return appleIssuerId.isEmpty &&
        appleKeyId.isEmpty &&
        appleVendorNumber.isEmpty &&
        applePrivateKeyPath.isEmpty &&
        googleBucketId.isEmpty &&
        googleServiceAccountPath.isEmpty;
  }

  AppConfig copyWith({
    String? appleIssuerId,
    String? appleKeyId,
    String? appleVendorNumber,
    String? applePrivateKeyPath,
    String? googleBucketId,
    String? googleServiceAccountPath,
    String? appMappings,
    Map<String, double>? customRates,
    String? language,
    bool? isLanguageUserSet,
  }) {
    return AppConfig(
      appleIssuerId: appleIssuerId ?? this.appleIssuerId,
      appleKeyId: appleKeyId ?? this.appleKeyId,
      appleVendorNumber: appleVendorNumber ?? this.appleVendorNumber,
      applePrivateKeyPath: applePrivateKeyPath ?? this.applePrivateKeyPath,
      googleBucketId: googleBucketId ?? this.googleBucketId,
      googleServiceAccountPath:
          googleServiceAccountPath ?? this.googleServiceAccountPath,
      appMappings: appMappings ?? this.appMappings,
      customRates: customRates ?? this.customRates,
      language: language ?? this.language,
      isLanguageUserSet: isLanguageUserSet ?? this.isLanguageUserSet,
    );
  }

  AppConfig mergeMissing(AppConfig fallback) {
    return AppConfig(
      appleIssuerId: appleIssuerId.isNotEmpty
          ? appleIssuerId
          : fallback.appleIssuerId,
      appleKeyId: appleKeyId.isNotEmpty ? appleKeyId : fallback.appleKeyId,
      appleVendorNumber: appleVendorNumber.isNotEmpty
          ? appleVendorNumber
          : fallback.appleVendorNumber,
      applePrivateKeyPath: applePrivateKeyPath.isNotEmpty
          ? applePrivateKeyPath
          : fallback.applePrivateKeyPath,
      googleBucketId: googleBucketId.isNotEmpty
          ? googleBucketId
          : fallback.googleBucketId,
      googleServiceAccountPath: googleServiceAccountPath.isNotEmpty
          ? googleServiceAccountPath
          : fallback.googleServiceAccountPath,
      appMappings: appMappings.isNotEmpty ? appMappings : fallback.appMappings,
      customRates: customRates.isNotEmpty ? customRates : fallback.customRates,
      language: language.isNotEmpty ? language : fallback.language,
      isLanguageUserSet: isLanguageUserSet || fallback.isLanguageUserSet,
    );
  }

  Map<String, Object> toJson() {
    return {
      'appleIssuerId': appleIssuerId,
      'appleKeyId': appleKeyId,
      'appleVendorNumber': appleVendorNumber,
      'applePrivateKeyPath': applePrivateKeyPath,
      'googleBucketId': googleBucketId,
      'googleServiceAccountPath': googleServiceAccountPath,
      'appMappings': appMappings,
      'customRates': customRates,
      'language': language,
      'isLanguageUserSet': isLanguageUserSet,
    };
  }

  factory AppConfig.fromJson(Map<String, Object?> json) {
    return AppConfig(
      appleIssuerId: json['appleIssuerId'] as String? ?? '',
      appleKeyId: json['appleKeyId'] as String? ?? '',
      appleVendorNumber: json['appleVendorNumber'] as String? ?? '',
      applePrivateKeyPath: json['applePrivateKeyPath'] as String? ?? '',
      googleBucketId: json['googleBucketId'] as String? ?? '',
      googleServiceAccountPath:
          json['googleServiceAccountPath'] as String? ?? '',
      appMappings: json['appMappings'] as String? ?? defaultAppMappings,
      customRates: (json['customRates'] as Map<String, Object?>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ?? defaultFxRates,
      language: json['language'] as String? ?? 'zh',
      isLanguageUserSet: json['isLanguageUserSet'] as bool? ?? false,
    );
  }
}

import '../config/app_constants.dart';

/// Request data generated from one QR payload.
///
/// A QR can contain either the complete society endpoint URL or just the
/// barcode value. In both cases the value is sent as the `barcode` query
/// parameter; the original QR text remains separate in [ScanResult].
class SocietyLookupRequest {
  const SocietyLookupRequest({required this.barcode, required this.uri});

  static final Uri defaultEndpoint = Uri.parse(
    '${AppConstants.baseUrl}/society/getall',
  );

  final String barcode;
  final Uri uri;

  /// Creates a lookup for a QR payload, or returns null for an unrelated URL
  /// such as a normal website link.
  static SocietyLookupRequest? fromQrValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final scannedUri = Uri.tryParse(value);
    if (scannedUri != null && scannedUri.hasScheme) {
      try {
        final scheme = scannedUri.scheme.toLowerCase();
        if (scheme != 'http' && scheme != 'https') return null;
        if (!_isSocietyEndpoint(scannedUri)) return null;

        final barcode = _nonEmpty(scannedUri.queryParameters['barcode']);
        if (barcode == null) return null;

        return _build(
          scannedUri,
          barcode: barcode,
          type: _nonEmpty(scannedUri.queryParameters['type']) ?? '2',
          userId: _nonEmpty(scannedUri.queryParameters['userid']) ?? '1',
        );
      } on FormatException {
        return null;
      }
    }

    // A plain QR barcode, such as `dg/0025/mrcmpu`, uses the configured LAN
    // endpoint and is placed into its barcode query parameter.
    return _build(defaultEndpoint, barcode: value, type: '2', userId: '1');
  }

  static SocietyLookupRequest _build(
    Uri endpoint, {
    required String barcode,
    required String type,
    required String userId,
  }) {
    return SocietyLookupRequest(
      barcode: barcode,
      uri: endpoint.replace(
        queryParameters: <String, String>{
          'type': type,
          'barcode': barcode,
          'userid': userId,
        },
      ),
    );
  }

  static bool _isSocietyEndpoint(Uri uri) {
    final normalizedPath = uri.path.toLowerCase().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    return normalizedPath == '/society/getall' ||
        normalizedPath.endsWith('/society/getall');
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Parsed response from `/society/getall`.
class SocietyApiResponse {
  const SocietyApiResponse({
    required this.request,
    required this.success,
    required this.message,
    required this.data,
  });

  final SocietyLookupRequest request;
  final bool success;
  final String message;
  final List<SocietyRecord> data;

  /// True when any returned society record has already received food.
  bool get hasHadFood => data.any((record) => record.isFood == true);

  /// True when any returned society record has already received a gift.
  bool get hasHadGift => data.any((record) => record.isGift == true);

  factory SocietyApiResponse.fromJson({
    required SocietyLookupRequest request,
    required Map<String, dynamic> json,
  }) {
    final rawData = json['data'];
    final records = rawData is List
        ? rawData
              .whereType<Map>()
              .map(
                (item) =>
                    SocietyRecord.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <SocietyRecord>[];

    return SocietyApiResponse(
      request: request,
      success: json['success'] == true,
      message: json['message'] is String ? json['message'] as String : '',
      data: records,
    );
  }
}

/// A single society entry returned by the lookup endpoint.
class SocietyRecord {
  const SocietyRecord({
    required this.socCode,
    required this.societyName,
    required this.pi,
    required this.registrationLock,
    required this.isRegistered,
    required this.isLocked,
    required this.isGift,
    required this.isFood,
    required this.name,
    required this.roleType,
    required this.photo,
  });

  final String? socCode;
  final String? societyName;
  final String? pi;
  final String? registrationLock;
  final bool? isRegistered;
  final bool? isLocked;
  final bool? isGift;
  final bool? isFood;
  final String? name;
  final String? roleType;
  final String? photo;

  /// Converts the API photo URL into the URI used by the image widget.
  ///
  /// The photo endpoint is keyed by SocCode, so use the record's code when it
  /// is available. The API-provided photo value remains a fallback for records
  /// that do not include a code.
  Uri? get imageUri {
    final code = socCode;
    if (code != null && code.isNotEmpty) {
      return Uri.parse(
        '${AppConstants.baseUrl}/photo/photo',
      ).replace(queryParameters: <String, String>{'soccode': code});
    }

    final raw = photo;
    if (raw == null || raw.isEmpty) return null;

    final parsed = Uri.tryParse(raw);
    final scheme = parsed?.scheme.toLowerCase();
    if (parsed != null && (scheme == 'http' || scheme == 'https')) {
      return parsed;
    }
    if (raw.startsWith('//')) {
      return Uri.tryParse('http:$raw');
    }
    return null;
  }

  factory SocietyRecord.fromJson(Map<String, dynamic> json) {
    return SocietyRecord(
      socCode: _string(json['SocCode']),
      societyName: _string(json['SocietyName']),
      pi: _string(json['PI']),
      registrationLock: _string(json['registrationlock']),
      isRegistered: _bool(json['IsRegistered']),
      isLocked: _bool(json['IsLocked']),
      isGift: _bool(json['IsGift']),
      isFood: _bool(json['IsFood']),
      name: _string(json['Name']),
      roleType: _string(json['RoleType']),
      photo: _string(json['photo']),
    );
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final string = value.toString().trim();
    return string.isEmpty ? null : string;
  }

  static bool? _bool(dynamic value) => value is bool ? value : null;
}

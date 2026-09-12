import 'scan_result.dart';

const _barcodeKeys = <String>[
  'barcode',
  'bar_code',
  'qrCode',
  'qrcode',
  'qr_code',
  'value',
  'code',
  'soccode',
  'soc_code',
  'rawValue',
  'raw_value',
];

const _socCodeKeys = <String>[
  'soccode',
  'soc_code',
  'societyCode',
  'society_code',
];

const _societyNameKeys = <String>['societyName', 'society_name', 'society'];

const _dateKeys = <String>[
  'date',
  'createdAt',
  'created_at',
  'timestamp',
  'time',
  'scannedAt',
  'scanned_at',
  'updatedAt',
  'updated_at',
  'entryDate',
  'entry_date',
  'dateTime',
  'datetime',
];

const _labelKeys = <String>[
  'name',
  'society',
  'societyName',
  'society_name',
  'farmer',
  'farmerName',
  'farmer_name',
  'member',
  'memberName',
  'member_name',
  'center',
  'centre',
  'location',
  'description',
  'status',
  'service',
];

const _wrapperKeys = <String>[
  'data',
  'history',
  'items',
  'records',
  'result',
  'results',
  'rows',
  'list',
  'entries',
  'content',
  'payload',
];

/// Parsed response returned by the Food/Gift history endpoint.
class FoodGiftHistoryResponse {
  const FoodGiftHistoryResponse({required this.entries, required this.count});

  final List<FoodGiftHistoryEntry> entries;
  final int count;

  factory FoodGiftHistoryResponse.fromJson(dynamic payload) {
    final rawEntries = _extractEntries(payload);
    return FoodGiftHistoryResponse(
      entries: List<FoodGiftHistoryEntry>.unmodifiable(
        rawEntries.map(FoodGiftHistoryEntry.fromJson),
      ),
      count: _integerValue(payload, 'count') ?? rawEntries.length,
    );
  }
}

/// One server-side Food/Gift history record.
///
/// The endpoint does not have a documented response schema, so the original
/// JSON fields are retained. Known aliases are exposed through typed getters
/// and unknown fields remain available through [fields].
class FoodGiftHistoryEntry {
  FoodGiftHistoryEntry({required Map<String, dynamic> fields})
    : fields = Map<String, dynamic>.unmodifiable(fields);

  factory FoodGiftHistoryEntry.fromJson(dynamic payload) {
    if (payload is Map) {
      final fields = <String, dynamic>{};
      for (final entry in payload.entries) {
        if (entry.key is String) {
          fields[entry.key as String] = entry.value;
        }
      }
      return FoodGiftHistoryEntry(fields: fields);
    }

    return FoodGiftHistoryEntry(fields: <String, dynamic>{'value': payload});
  }

  /// All fields received for this record, including fields not recognized by
  /// the current display logic.
  final Map<String, dynamic> fields;

  /// The value that can be sent back through the scanner lookup flow.
  String? get barcode => _stringValue(fields, _barcodeKeys);

  /// The society code shown in server history rows.
  String? get socCode => _stringValue(fields, _socCodeKeys);

  /// The society name shown in server history rows.
  String? get societyName => _stringValue(fields, _societyNameKeys);

  /// A human-readable server-provided label, when one is available.
  String? get label => _stringValue(fields, _labelKeys);

  /// Best-effort timestamp parsed from common API field names.
  DateTime? get recordedAt => _dateValue(fields, _dateKeys);

  /// Text used as the primary title without exposing the QR barcode.
  String get displayTitle {
    final code = socCode;
    final name = societyName;
    if (code != null && name != null) return '$code · $name';
    return code ??
        name ??
        label ??
        barcode ??
        _firstScalarValue() ??
        'History entry';
  }

  /// Converts a record into the same result type used by local scan history.
  /// Records without a usable barcode stay visible but cannot be selected.
  ScanResult? toScanResult() {
    final value = barcode;
    if (value == null) return null;
    return ScanResult(value: value, scannedAt: recordedAt);
  }

  String? _firstScalarValue() {
    for (final entry in fields.entries) {
      if (_isKnownKey(entry.key)) continue;
      final value = _stringFromValue(entry.value);
      if (value != null) return value;
    }
    return null;
  }
}

List<dynamic> _extractEntries(dynamic payload) {
  final collection = _findCollection(payload);
  if (collection is List) return collection;
  if (collection is Map) return <dynamic>[collection];
  return const <dynamic>[];
}

dynamic _findCollection(dynamic payload, [int depth = 0]) {
  if (payload is List) return payload;
  if (payload is! Map || depth > 5) return null;

  final map = _asStringMap(payload);

  for (final key in _wrapperKeys) {
    final candidate = _valueForKey(map, key);
    if (candidate == null) continue;
    final found = _findCollection(candidate, depth + 1);
    if (found != null) return found;
  }

  if (_looksLikeRecord(map)) return map;

  // Some APIs use an undocumented wrapper name. Accommodate a list or a
  // nested record collection without treating ordinary metadata as a record.
  for (final value in map.values) {
    if (value is List) return value;
  }
  for (final value in map.values) {
    if (value is Map) {
      final found = _findCollection(value, depth + 1);
      if (found != null) return found;
    }
  }

  return null;
}

Map<String, dynamic> _asStringMap(Map<dynamic, dynamic> source) {
  final result = <String, dynamic>{};
  for (final entry in source.entries) {
    if (entry.key is String) result[entry.key as String] = entry.value;
  }
  return result;
}

dynamic _valueForKey(Map<String, dynamic> fields, String key) {
  final wanted = _normalizeKey(key);
  for (final entry in fields.entries) {
    if (_normalizeKey(entry.key) == wanted) return entry.value;
  }
  return null;
}

String? _stringValue(Map<String, dynamic> fields, Iterable<String> keys) {
  for (final key in keys) {
    final value = _stringFromValue(_valueForKey(fields, key));
    if (value != null) return value;
  }
  return null;
}

int? _integerValue(dynamic payload, String key) {
  if (payload is! Map) return null;
  final value = _valueForKey(_asStringMap(payload), key);
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String? _stringFromValue(dynamic value) {
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  if (value is num || value is bool) return value.toString();
  return null;
}

DateTime? _dateValue(Map<String, dynamic> fields, Iterable<String> keys) {
  final value = _valueForAliases(fields, keys);
  if (value is DateTime) return value;

  if (value is num) return _dateFromNumber(value);
  if (value is String) {
    final text = value.trim();
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
    final number = num.tryParse(text);
    if (number != null) return _dateFromNumber(number);
  }

  return null;
}

DateTime? _dateFromNumber(num value) {
  final integer = value.toInt();
  final milliseconds = integer.abs() < 100000000000 ? integer * 1000 : integer;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

dynamic _valueForAliases(Map<String, dynamic> fields, Iterable<String> keys) {
  for (final key in keys) {
    final value = _valueForKey(fields, key);
    if (value != null) return value;
  }
  return null;
}

bool _looksLikeRecord(Map<String, dynamic> fields) {
  const recordKeys = <String>[
    ..._barcodeKeys,
    ..._socCodeKeys,
    ..._dateKeys,
    ..._labelKeys,
    'id',
    '_id',
  ];
  return recordKeys.any((key) => _valueForKey(fields, key) != null);
}

bool _isKnownKey(String key) {
  final normalized = _normalizeKey(key);
  return <String>{
    ..._barcodeKeys,
    ..._socCodeKeys,
    ..._societyNameKeys,
    ..._dateKeys,
    ..._labelKeys,
  }.map(_normalizeKey).contains(normalized);
}

String _normalizeKey(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

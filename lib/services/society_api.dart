import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_constants.dart';
import '../models/app_type.dart';
import '../models/food_gift_history.dart';
import '../models/society.dart';

/// HTTP client for the society lookup and registration endpoints.
class SocietyApi {
  SocietyApi({required String token, http.Client? client})
    : _token = token,
      _client = client ?? http.Client();

  static const requestTimeout = Duration(seconds: 8);

  final String _token;
  final http.Client _client;
  bool _closed = false;

  Map<String, String> get _authHeaders => <String, String>{
    'Accept': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  Future<SocietyApiResponse> lookup(SocietyLookupRequest request) async {
    try {
      final response = await _client
          .get(request.uri, headers: _authHeaders)
          .timeout(requestTimeout);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (error) {
        throw SocietyApiException(
          'The society server returned invalid JSON.',
          statusCode: response.statusCode,
          cause: error,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SocietyApiException(
          _serverMessage(decoded) ??
              'Society lookup failed (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
          payload: decoded,
        );
      }

      if (decoded is! Map) {
        throw SocietyApiException(
          'The society server returned an unexpected response.',
          statusCode: response.statusCode,
          payload: decoded,
        );
      }

      final json = Map<String, dynamic>.from(decoded);
      return SocietyApiResponse.fromJson(request: request, json: json);
    } on SocietyApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw SocietyApiException(
        'The society server took too long to respond.',
        cause: error,
      );
    } on Object catch (error) {
      throw SocietyApiException(
        'Could not reach the society server. Check the device is on the same network.',
        cause: error,
      );
    }
  }

  /// Loads authenticated server history for the selected Food/Gift mode.
  ///
  /// The endpoint uses type 1 for Gift and type 2 for Food. Entry history is
  /// intentionally not mapped here because the server provides no Entry type
  /// for this endpoint.
  Future<FoodGiftHistoryResponse> fetchFoodGiftHistory(AppType appType) async {
    final type = switch (appType) {
      AppType.gift => '1',
      AppType.food => '2',
      AppType.entry => throw ArgumentError(
        'Food/Gift history is not available for Entry mode.',
      ),
    };
    final uri = AppConstants.foodGiftHistoryUri.replace(
      queryParameters: <String, String>{'type': type},
    );

    try {
      final response = await _client
          .get(uri, headers: _authHeaders)
          .timeout(requestTimeout);

      if (response.body.trim().isEmpty) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw SocietyApiException(
            'History request failed (HTTP ${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
        return const FoodGiftHistoryResponse(
          entries: <FoodGiftHistoryEntry>[],
          count: 0,
        );
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (error) {
        throw SocietyApiException(
          'The society server returned invalid JSON.',
          statusCode: response.statusCode,
          cause: error,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SocietyApiException(
          _serverMessage(decoded) ??
              'History request failed (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
          payload: decoded,
        );
      }

      return FoodGiftHistoryResponse.fromJson(decoded);
    } on SocietyApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw SocietyApiException(
        'The society server took too long to respond while loading history.',
        cause: error,
      );
    } on Object catch (error) {
      throw SocietyApiException(
        'Could not load society history. Check the device is on the same network.',
        cause: error,
      );
    }
  }

  /// Marks the scanned society barcode for the Food service. The request is
  /// separate from [lookup], so the user can review the response first.
  Future<void> markFood(SocietyLookupRequest request) => _markRegistration(
    request,
    service: 'food',
    endpoint: AppConstants.foodRegistrationUri,
  );

  /// Registers the scanned society barcode for the Gift service.
  Future<void> markGift(SocietyLookupRequest request) => _markRegistration(
    request,
    service: 'gift',
    endpoint: AppConstants.giftRegistrationUri,
  );

  /// Registers the scanned society barcode for the Entry service.
  Future<void> punchEntry(SocietyLookupRequest request) => _markRegistration(
    request,
    service: 'entry',
    endpoint: AppConstants.entryRegistrationUri,
    usePost: true,
  );

  /// All registration endpoints come from [AppConstants] so that a base URL
  /// with a path prefix (for example `https://host/agbback`) is preserved.
  /// Rebuilding the URL from the scanned QR host would silently drop it.
  Future<void> _markRegistration(
    SocietyLookupRequest request, {
    required Uri endpoint,
    required String service,
    bool usePost = false,
  }) async {
    final registrationUri = endpoint;

    final headers = <String, String>{
      ..._authHeaders,
      'Content-Type': 'application/json',
    };
    final body = jsonEncode(<String, String>{'barcode': request.barcode});

    try {
      final send = usePost
          ? _client.post(registrationUri, headers: headers, body: body)
          : _client.put(registrationUri, headers: headers, body: body);
      final response = await send.timeout(requestTimeout);

      dynamic decoded;
      if (response.body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          // The status code remains authoritative for this command endpoint.
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SocietyApiException(
          _serverMessage(decoded) ??
              '${_title(service)} update failed (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
          payload: decoded,
        );
      }
    } on SocietyApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw SocietyApiException(
        'The ${service.toLowerCase()} update server took too long to respond.',
        cause: error,
      );
    } on Object catch (error) {
      throw SocietyApiException(
        'Could not submit the ${service.toLowerCase()} update. Check the device is on the same network.',
        cause: error,
      );
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }

  static String _title(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  static String? _serverMessage(dynamic payload) {
    if (payload is! Map) return null;
    final message = payload['message'];
    return message is String && message.trim().isNotEmpty
        ? message.trim()
        : null;
  }
}

/// Error produced by the society transport or by an invalid server response.
class SocietyApiException implements Exception {
  const SocietyApiException(
    this.message, {
    this.statusCode,
    this.payload,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final dynamic payload;
  final Object? cause;

  @override
  String toString() => message;
}

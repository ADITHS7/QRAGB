/// Application-wide API configuration.
abstract final class AppConstants {
  // static const baseUrl = 'http://192.168.101.17:5005';
  static const baseUrl = 'https://backend.mrcmpu.com/agbback';
  static final Uri loginUri = Uri.parse('$baseUrl/Auth/login');
  static final Uri foodRegistrationUri = Uri.parse('$baseUrl/society/food');
  static final Uri giftRegistrationUri = Uri.parse('$baseUrl/society/gift');

  /// History endpoints, one per mode.
  ///
  /// The backend currently exposes a single route selected by a `type` query
  /// (1 = Gift, 2 = Food). Keeping a separate entry per mode means that if the
  /// server ever splits these into distinct paths, only these two lines change.
  static final Uri giftHistoryUri = Uri.parse(
    '$baseUrl/routes/report?type=1',
  );
  static final Uri foodHistoryUri = Uri.parse(
    '$baseUrl/routes/report?type=2',
  );
  static final Uri entryRegistrationUri = Uri.parse(
    '$baseUrl/society/Punchcheck',
  );
}

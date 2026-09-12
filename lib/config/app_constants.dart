/// Application-wide API configuration.
abstract final class AppConstants {
  static const baseUrl = 'http://192.168.101.17:5005';
  static final Uri loginUri = Uri.parse('$baseUrl/Auth/login');
  static final Uri giftRegistrationUri = Uri.parse('$baseUrl/society/gift');
  static final Uri foodGiftHistoryUri = Uri.parse('$baseUrl/routes/foodgift');
  static final Uri entryRegistrationUri = Uri.parse(
    '$baseUrl/society/Punchcheck',
  );
}

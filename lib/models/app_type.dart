/// The three operating modes available in this application.
enum AppType {
  food(label: 'Food', storageValue: 'food'),
  gift(label: 'Gift', storageValue: 'gift'),
  entry(label: 'Entry', storageValue: 'entry');

  const AppType({required this.label, required this.storageValue});

  final String label;
  final String storageValue;

  static AppType? fromStorage(String? value) {
    for (final type in values) {
      if (type.storageValue == value) return type;
    }
    return null;
  }
}

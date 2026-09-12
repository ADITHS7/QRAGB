import 'package:flutter/material.dart';

/// The kind of payload a scanned QR code carries.
///
/// Detected with cheap string checks only, so it never adds latency to the
/// scan path.
enum ScanKind {
  url(Icons.link_rounded, 'Link'),
  email(Icons.alternate_email_rounded, 'Email'),
  phone(Icons.call_rounded, 'Phone'),
  sms(Icons.sms_rounded, 'SMS'),
  wifi(Icons.wifi_rounded, 'Wi-Fi'),
  geo(Icons.place_rounded, 'Location'),
  contact(Icons.contact_page_rounded, 'Contact'),
  text(Icons.notes_rounded, 'Text');

  const ScanKind(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// An immutable record of a single successful scan.
@immutable
class ScanResult {
  ScanResult({required this.value, DateTime? scannedAt})
    : scannedAt = scannedAt ?? DateTime.now(),
      kind = _classify(value);

  final String value;
  final DateTime scannedAt;
  final ScanKind kind;

  /// True when the payload can be handed off to the OS (browser, dialer, ...).
  bool get isLaunchable => switch (kind) {
    ScanKind.url || ScanKind.email || ScanKind.phone || ScanKind.sms => true,
    ScanKind.geo => true,
    _ => false,
  };

  /// The URI to hand to `url_launcher`, or null when the payload is plain data.
  Uri? get launchUri {
    if (!isLaunchable) return null;
    final raw = value.trim();
    return switch (kind) {
      // Bare domains such as `example.com` need a scheme added.
      ScanKind.url when !raw.contains('://') => Uri.tryParse('https://$raw'),
      _ => Uri.tryParse(raw),
    };
  }

  static ScanKind _classify(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return ScanKind.text;
    final lower = value.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return ScanKind.url;
    }
    if (lower.startsWith('mailto:')) return ScanKind.email;
    if (lower.startsWith('tel:')) return ScanKind.phone;
    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) {
      return ScanKind.sms;
    }
    if (lower.startsWith('wifi:')) return ScanKind.wifi;
    if (lower.startsWith('geo:')) return ScanKind.geo;
    if (lower.startsWith('begin:vcard') || lower.startsWith('mecard:')) {
      return ScanKind.contact;
    }
    // Bare email, e.g. `someone@example.com`.
    if (!value.contains(' ') &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return ScanKind.email;
    }
    // Bare domain / www host, e.g. `example.com/path`.
    if (!value.contains(' ') &&
        RegExp(r'^(www\.)?[\w-]+(\.[\w-]+)+(/\S*)?$').hasMatch(value)) {
      return ScanKind.url;
    }
    return ScanKind.text;
  }
}

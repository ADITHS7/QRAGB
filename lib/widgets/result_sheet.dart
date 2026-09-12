import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_type.dart';
import '../models/scan_result.dart';
import '../models/society.dart';

/// Bottom sheet that presents a scan result and, when applicable, its society
/// API response.
///
/// Closing the sheet (via the primary button, a drag, or the back gesture) is
/// what resumes scanning, so the caller only needs to await [show].
class ResultSheet extends StatelessWidget {
  const ResultSheet({
    required this.result,
    this.appType = AppType.food,
    this.lookupRequest,
    this.lookupFuture,
    this.onContinue,
    super.key,
  });

  final ScanResult result;
  final AppType appType;
  final SocietyLookupRequest? lookupRequest;
  final Future<SocietyApiResponse>? lookupFuture;
  final Future<void> Function()? onContinue;

  static Future<void> show(
    BuildContext context,
    ScanResult result, {
    AppType appType = AppType.food,
    SocietyLookupRequest? lookupRequest,
    Future<SocietyApiResponse>? lookupFuture,
    Future<void> Function()? onContinue,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ResultSheet(
        result: result,
        appType: appType,
        lookupRequest: lookupRequest,
        lookupFuture: lookupFuture,
        onContinue: onContinue,
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = result.launchUri;
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing on this device can open that.')),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: result.value));
    messenger.showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _continueToNextScan(BuildContext context) {
    final callback = onContinue;
    if (callback != null) unawaited(callback());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxValueHeight = screenHeight * 0.2;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(result: result, onCopy: () => _copy(context)),
            const SizedBox(height: 12),
            _ValuePanel(value: result.value, maxHeight: maxValueHeight),
            if (lookupFuture != null && lookupRequest != null) ...[
              const SizedBox(height: 16),
              _SocietyLookupPanel(
                request: lookupRequest!,
                future: lookupFuture!,
                appType: appType,
              ),
            ],
            const SizedBox(height: 20),
            if (result.isLaunchable) ...[
              OutlinedButton.icon(
                onPressed: () => _open(context),
                icon: Icon(result.kind.icon),
                label: Text(switch (result.kind) {
                  ScanKind.url => 'Open link',
                  ScanKind.email => 'Send email',
                  ScanKind.phone => 'Call',
                  ScanKind.sms => 'Send message',
                  ScanKind.geo => 'Open in maps',
                  _ => 'Open',
                }),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: () => _continueToNextScan(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                onContinue == null
                    ? 'OK, scan next'
                    : 'OK, submit ${appType.label.toLowerCase()} & scan next',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.result, required this.onCopy});

  final ScanResult result;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.circle,
          ),
          child: Icon(result.kind.icon, color: colors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            result.kind.label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Copy scanned value',
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded),
        ),
      ],
    );
  }
}

class _ValuePanel extends StatelessWidget {
  const _ValuePanel({required this.value, required this.maxHeight});

  final String value;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          value,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
      ),
    );
  }
}

class _SocietyLookupPanel extends StatelessWidget {
  const _SocietyLookupPanel({
    required this.request,
    required this.future,
    required this.appType,
  });

  final SocietyLookupRequest request;
  final Future<SocietyApiResponse> future;
  final AppType appType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: FutureBuilder<SocietyApiResponse>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.active) {
            return _LookupLoading(barcode: request.barcode);
          }
          if (snapshot.hasError) {
            return _LookupError(
              barcode: request.barcode,
              error: snapshot.error,
            );
          }

          final response = snapshot.data;
          if (response == null) {
            return const _LookupError(
              barcode: '',
              error: 'The society server returned no data.',
            );
          }
          return _LookupSuccess(response: response, appType: appType);
        },
      ),
    );
  }
}

class _LookupLoading extends StatelessWidget {
  const _LookupLoading({required this.barcode});

  final String barcode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Loading society response for $barcode…',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _LookupError extends StatelessWidget {
  const _LookupError({required this.barcode, required this.error});

  final String barcode;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Society lookup failed',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                error?.toString() ?? 'Unknown server error.',
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
              if (barcode.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Barcode: $barcode',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LookupSuccess extends StatelessWidget {
  const _LookupSuccess({required this.response, required this.appType});

  final SocietyApiResponse response;
  final AppType appType;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duplicateMessage = switch (appType) {
      AppType.food when response.hasHadFood => 'Already had food',
      AppType.gift when response.hasHadGift => 'Already bought the gift',
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              response.success
                  ? Icons.check_circle_rounded
                  : Icons.info_rounded,
              color: response.success ? colors.primary : Colors.orangeAccent,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Society response',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          response.message.isEmpty ? 'Response received.' : response.message,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Text(
          'barcode = ${response.request.barcode}',
          style: TextStyle(
            color: colors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (duplicateMessage != null) ...[
          const SizedBox(height: 18),
          _AlreadyRegisteredMessage(message: duplicateMessage),
        ],
        if (response.data.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final record in response.data)
            _SocietyRecordCard(record: record),
        ],
      ],
    );
  }
}

class _AlreadyRegisteredMessage extends StatelessWidget {
  const _AlreadyRegisteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.error.withValues(alpha: 0.65)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.error, size: 42),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.error,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocietyRecordCard extends StatelessWidget {
  const _SocietyRecordCard({required this.record});

  final SocietyRecord record;

  @override
  Widget build(BuildContext context) {
    final title = record.societyName ?? record.name ?? 'Society';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SocietyPhoto(uri: record.imageUri),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RecordRow(label: 'Name', value: record.name),
          _RecordRow(label: 'Code', value: record.socCode),
          _RecordRow(label: 'Role', value: record.roleType),
          _RecordRow(label: 'PI', value: record.pi),
          _RecordRow(label: 'Registered', value: _yesNo(record.isRegistered)),
          _RecordRow(label: 'Locked', value: _yesNo(record.isLocked)),
          _RecordRow(label: 'Gift', value: _yesNo(record.isGift)),
          _RecordRow(label: 'Food', value: _yesNo(record.isFood)),
        ],
      ),
    );
  }

  static String? _yesNo(bool? value) => value == null
      ? null
      : value
      ? 'Yes'
      : 'No';
}

class _SocietyPhoto extends StatelessWidget {
  const _SocietyPhoto({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final image = uri;
    final content = image == null
        ? const _PhotoPlaceholder()
        : Image.network(
            image.toString(),
            headers: const <String, String>{'Accept': 'image/*'},
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Society photo failed: $image - $error');
              return const _PhotoPlaceholder(message: 'Photo unavailable');
            },
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const _PhotoPlaceholder(message: 'Loading photo…'),
          );

    return SizedBox(
      width: 72,
      height: 72,
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: content),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final content = message == null
        ? const Icon(Icons.person_rounded, color: Colors.white38, size: 34)
        : Tooltip(
            message: message!,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.white38,
              size: 28,
            ),
          );
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(child: content),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

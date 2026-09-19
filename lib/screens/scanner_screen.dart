import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/scan_result.dart';
import '../models/app_type.dart';
import '../models/society.dart';
import '../services/society_api.dart';
import '../widgets/result_sheet.dart';
import '../widgets/scanner_overlay.dart';
import 'history_screen.dart';

/// Full screen QR scanner.
///
/// Speed notes, in order of impact:
///  * `formats` is limited to QR only, so the detector does not spend time
///    probing for a dozen 1D symbologies on every frame.
///  * `DetectionSpeed.unrestricted` + `detectionTimeoutMs: 0` analyses every
///    frame instead of throttling, which minimises time-to-first-hit. Nothing
///    is wasted afterwards because the camera is paused the instant a code is
///    read.
///  * `returnImage: false` avoids shipping full frame bytes over the platform
///    channel.
///  * 720p analysis resolution: plenty of detail for QR, far cheaper than 1080p.
///  * No `scanWindow`, so a code anywhere in the frame is accepted; the drawn
///    frame is only an aiming guide.
///  * Resuming uses `pause()`/`start()` rather than `stop()`/`start()`, keeping
///    the native camera session alive so "scan next" is immediate.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    required this.token,
    this.appType = AppType.food,
    this.onLogout,
    super.key,
  });

  final String token;
  final AppType appType;
  final Future<void> Function()? onLogout;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.unrestricted,
    detectionTimeoutMs: 0,
    cameraResolution: const Size(1280, 720),
    returnImage: false,
    autoZoom: true,
    autoStart: false,
  );

  late final SocietyApi _societyApi;
  StreamSubscription<BarcodeCapture>? _subscription;
  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  /// Set while a result is on screen, so extra detections from frames already
  /// in flight are dropped instead of stacking up sheets.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _societyApi = SocietyApi(token: widget.token);
    WidgetsBinding.instance.addObserver(this);
    _subscription = _controller.barcodes.listen(
      _onDetect,
      onError: (_) {},
      cancelOnError: false,
    );
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission prompts emit lifecycle events before the camera is ready.
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        // Don't fight the result sheet for the camera.
        if (!_busy) unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    _societyApi.close();
    _manualController.dispose();
    _manualFocus.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || !mounted) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue ?? b.displayValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    _busy = true;
    // Feedback first, everything else after: the user should feel the hit on
    // the same frame it happened.
    unawaited(HapticFeedback.mediumImpact());
    unawaited(SystemSound.play(SystemSoundType.click));
    unawaited(_controller.pause());
    setState(() {}); // Freeze the overlay animation.

    await _presentResultFor(raw);
  }

  /// Runs a typed barcode through the same lookup and registration flow as a
  /// scan, for QR codes that are damaged or unreadable.
  Future<void> _searchManualEntry() async {
    final raw = _manualController.text.trim();
    if (raw.isEmpty || _busy || !mounted) return;

    _manualFocus.unfocus();
    _busy = true;
    unawaited(_controller.pause());
    setState(() {}); // Freeze the overlay animation.

    await _presentResultFor(raw);
    if (mounted) _manualController.clear();
  }

  /// Shared result flow for a scanned or manually typed barcode.
  Future<void> _presentResultFor(String raw) async {
    final result = ScanResult(value: raw);

    // Start the lookup immediately after pausing the camera. The result sheet
    // can be dismissed while this future is still loading, so scan-next never
    // waits for the LAN server.
    final lookupRequest = SocietyLookupRequest.fromQrValue(raw);
    final lookupFuture = lookupRequest == null
        ? null
        : _societyApi.lookup(lookupRequest);

    try {
      await ResultSheet.show(
        context,
        result,
        appType: widget.appType,
        lookupRequest: lookupRequest,
        lookupFuture: lookupFuture,
        onContinue: lookupRequest == null
            ? null
            : () => _submitRegistration(lookupRequest, lookupFuture),
      );
    } finally {
      await _resume();
    }
  }

  Future<void> _submitRegistration(
    SocietyLookupRequest request,
    Future<SocietyApiResponse>? lookupFuture,
  ) async {
    final appType = widget.appType;

    print('========================================');
    print('SUBMIT REGISTRATION CALLED');
    print('APP TYPE: $appType');
    print('BARCODE: ${request.barcode}');
    print('========================================');

    try {
      if (lookupFuture != null &&
          (appType == AppType.food || appType == AppType.gift)) {
        final response = await lookupFuture;
        final duplicateMessage = switch (appType) {
          AppType.food when response.hasHadFood => 'Already had food',
          AppType.gift when response.hasHadGift => 'Already bought the gift',
          _ => null,
        };
        if (duplicateMessage != null) {
          await _showAlreadyRegisteredDialog(duplicateMessage);
          return;
        }
      }

      switch (appType) {
        case AppType.food:
          await _societyApi.markFood(request);
        case AppType.gift:
          await _societyApi.markGift(request);
        case AppType.entry:
          await _societyApi.punchEntry(request);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Qrcode submitted to ${appType.label.toLowerCase()} service.',
          ),
        ),
      );
    } on SocietyApiException catch (error) {
      if (!mounted) return;
      if (appType == AppType.entry && error.statusCode == 403) {
        await _showEntryForbiddenDialog(error.message);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showEntryForbiddenDialog(String message) async {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.block_rounded, color: colors.error, size: 48),
        title: Text(
          'Entry registration denied',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.error, fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlreadyRegisteredDialog(String message) async {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.error_outline_rounded, color: colors.error, size: 48),
        title: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.error, fontWeight: FontWeight.w800),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _requestLogout() {
    unawaited(_confirmLogout());
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Your current session will be cleared from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;
    await _controller.pause();
    final onLogout = widget.onLogout;
    if (onLogout != null) await onLogout();
  }

  Future<void> _resume() async {
    if (!mounted) return;
    _busy = false;
    setState(() {});
    await _controller.start();
  }

  Future<void> _openHistory() async {
    await _controller.pause();
    _busy = true;
    if (!mounted) return;

    try {
      final selected = await Navigator.of(context).push<ScanResult>(
        MaterialPageRoute(
          builder: (_) => HistoryScreen(
            appType: widget.appType,
            loadRemoteHistory: widget.appType == AppType.entry
                ? null
                : () => _societyApi.fetchFoodGiftHistory(widget.appType),
          ),
        ),
      );
      if (!mounted || selected == null) return;

      final lookupRequest = SocietyLookupRequest.fromQrValue(selected.value);
      final lookupFuture = lookupRequest == null
          ? null
          : _societyApi.lookup(lookupRequest);
      await ResultSheet.show(
        context,
        selected,
        appType: widget.appType,
        lookupRequest: lookupRequest,
        lookupFuture: lookupFuture,
        onContinue: lookupRequest == null
            ? null
            : () => _submitRegistration(lookupRequest, lookupFuture),
      );
    } finally {
      await _resume();
    }
  }

  /// Square viewfinder sized to the layout, biased slightly above centre so the
  /// controls do not cover it.
  Rect _cutoutFor(Size size) {
    final side = (size.shortestSide * 0.72).clamp(160.0, 340.0);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - size.height * 0.05),
      width: side,
      height: side,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            tapToFocus: true,
            placeholderBuilder: (_) => const ColoredBox(color: Colors.black),
            errorBuilder: (context, error) =>
                _CameraError(error: error, onRetry: () => _controller.start()),
            overlayBuilder: (context, constraints) => ScannerOverlay(
              cutout: _cutoutFor(constraints.biggest),
              accent: Theme.of(context).colorScheme.primary,
              paused: _busy,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  controller: _controller,
                  onHistory: _openHistory,
                  onLogout: widget.onLogout == null ? null : _requestLogout,
                  appType: widget.appType,
                ),
                _ManualEntryBar(
                  controller: _manualController,
                  focusNode: _manualFocus,
                  onSearch: _searchManualEntry,
                ),
                const Spacer(),
                const _Hint(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.onHistory,
    required this.onLogout,
    required this.appType,
  });

  final MobileScannerController controller;
  final VoidCallback onHistory;
  final VoidCallback? onLogout;
  final AppType appType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Text(
            '${appType.label} QR',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          // Scoped to the torch state only, so toggling it never rebuilds the
          // preview or the overlay.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return _CircleButton(
                icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                active: on,
                tooltip: 'Flashlight',
                onPressed: state.torchState == TorchState.unavailable
                    ? null
                    : controller.toggleTorch,
              );
            },
          ),
          const SizedBox(width: 8),
          _CircleButton(
            icon: Icons.cameraswitch_rounded,
            tooltip: 'Switch camera',
            onPressed: controller.switchCamera,
          ),
          const SizedBox(width: 8),
          _CircleButton(
            icon: Icons.history_rounded,
            tooltip: 'History',
            onPressed: onHistory,
          ),
          const SizedBox(width: 8),
          _CircleButton(
            icon: Icons.logout_rounded,
            tooltip: 'Log out',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

/// Manual barcode entry, for QR codes that cannot be scanned reliably.
class _ManualEntryBar extends StatelessWidget {
  const _ManualEntryBar({
    required this.controller,
    required this.focusNode,
    required this.onSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => unawaited(onSearch()),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.black54,
                hintText: 'Type barcode manually',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(
                  Icons.keyboard_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final enabled = value.text.trim().isNotEmpty;
              return _CircleButton(
                icon: Icons.search_rounded,
                tooltip: 'Search barcode',
                active: enabled,
                onPressed: enabled ? () => unawaited(onSearch()) : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: active ? accent : Colors.black45,
        foregroundColor: active ? Colors.black : Colors.white,
        disabledForegroundColor: Colors.white38,
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'Point at a QR code',
        style: TextStyle(fontSize: 14, color: Colors.white70),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied ? Icons.no_photography_rounded : Icons.error_outline,
                size: 48,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Camera access is needed to scan QR codes. Enable it in '
                          'Settings, then try again.'
                    : error.errorCode.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

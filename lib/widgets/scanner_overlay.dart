import 'package:flutter/material.dart';

import '../theme.dart';

/// Dimmed viewfinder with a bright cutout, corner brackets and a sweeping line.
///
/// Painting happens inside a [RepaintBoundary] and is driven by a single
/// [AnimationController], so the animation never triggers a widget rebuild of
/// the camera preview underneath it.
class ScannerOverlay extends StatefulWidget {
  const ScannerOverlay({
    required this.cutout,
    required this.accent,
    this.paused = false,
    super.key,
  });

  /// The transparent window, in the same coordinate space as this widget.
  final Rect cutout;

  /// Mode-specific highlight color.
  final Color accent;

  /// When true the sweep animation is stopped to save frames (e.g. while the
  /// result sheet is open).
  final bool paused;

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.paused) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ScannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        _controller.stop();
      } else {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _OverlayPainter(
            cutout: widget.cutout,
            accent: widget.accent,
            sweep: widget.paused ? null : _controller.value,
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.cutout,
    required this.accent,
    this.sweep,
  });

  final Rect cutout;
  final Color accent;

  /// 0..1 position of the sweep line, or null when hidden.
  final double? sweep;

  static const _radius = Radius.circular(24);

  @override
  void paint(Canvas canvas, Size size) {
    final window = RRect.fromRectAndRadius(cutout, _radius);

    // Dim everything except the cutout in one difference pass.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(window),
      ),
      Paint()..color = AppColors.scrim,
    );

    canvas.drawRRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white24,
    );

    _paintCorners(canvas);

    final sweepValue = sweep;
    if (sweepValue != null) {
      final y = cutout.top + cutout.height * sweepValue;
      final inset = cutout.deflate(10);
      canvas.drawRect(
        Rect.fromLTRB(inset.left, y - 22, inset.right, y + 2),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, accent],
          ).createShader(Rect.fromLTRB(inset.left, y - 22, inset.right, y + 2))
          ..blendMode = BlendMode.plus,
      );
      canvas.drawLine(
        Offset(inset.left, y),
        Offset(inset.right, y),
        Paint()
          ..strokeWidth = 2
          ..color = accent,
      );
    }
  }

  void _paintCorners(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = accent;
    const arm = 30.0;
    final r = _radius.x;
    final path = Path()
      // Top-left.
      ..moveTo(cutout.left, cutout.top + arm + r)
      ..lineTo(cutout.left, cutout.top + r)
      ..quadraticBezierTo(cutout.left, cutout.top, cutout.left + r, cutout.top)
      ..lineTo(cutout.left + arm + r, cutout.top)
      // Top-right.
      ..moveTo(cutout.right - arm - r, cutout.top)
      ..lineTo(cutout.right - r, cutout.top)
      ..quadraticBezierTo(
        cutout.right,
        cutout.top,
        cutout.right,
        cutout.top + r,
      )
      ..lineTo(cutout.right, cutout.top + arm + r)
      // Bottom-right.
      ..moveTo(cutout.right, cutout.bottom - arm - r)
      ..lineTo(cutout.right, cutout.bottom - r)
      ..quadraticBezierTo(
        cutout.right,
        cutout.bottom,
        cutout.right - r,
        cutout.bottom,
      )
      ..lineTo(cutout.right - arm - r, cutout.bottom)
      // Bottom-left.
      ..moveTo(cutout.left + arm + r, cutout.bottom)
      ..lineTo(cutout.left + r, cutout.bottom)
      ..quadraticBezierTo(
        cutout.left,
        cutout.bottom,
        cutout.left,
        cutout.bottom - r,
      )
      ..lineTo(cutout.left, cutout.bottom - arm - r);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) =>
      oldDelegate.sweep != sweep ||
      oldDelegate.cutout != cutout ||
      oldDelegate.accent != accent;
}

import 'dart:async';
import 'dart:math' as math;

import 'package:bett_box/common/common.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

/// A procedurally drawn wallpaper that sits underneath the whole application.
///
/// Liquid glass only reads as glass when there is something behind it to
/// refract. Bettbox used to paint every screen with an opaque
/// `surfaceContainer`, which flattens every glass surface into a plain grey
/// rectangle. This widget replaces that flat fill with a soft, slowly drifting
/// "aurora" field derived from the active [ColorScheme], so the frosted panels
/// above it pick up real colour and light.
///
/// The whole backdrop is four radial gradients plus one base gradient — no
/// bitmaps, no runtime blur filters — and it is wrapped in a
/// [RepaintBoundary] so the cost stays constant while content scrolls.
class SkyBackdrop extends StatefulWidget {
  const SkyBackdrop({
    super.key,
    this.animate = true,
    this.intensity = 1.0,
  });

  /// When false the field is rendered frozen at phase 0.
  ///
  /// Callers pass `globalState.animationEnabled` so the backdrop stops
  /// consuming raster time whenever the user disabled animations.
  final bool animate;

  /// Multiplier for the accent blobs. `0` gives a plain gradient wash, which
  /// is what reduced-transparency users should see.
  final double intensity;

  @override
  State<SkyBackdrop> createState() => _SkyBackdropState();
}

class _SkyBackdropState extends State<SkyBackdrop> {
  /// Animation phase in `0..1`; one full loop takes [_loopDuration].
  ///
  /// A [ValueNotifier] rather than setState: the wallpaper must not rebuild the
  /// widget tree several times a second, it only needs to repaint itself.
  final ValueNotifier<double> _phase = ValueNotifier(0);

  static const _tick = Duration(milliseconds: 260);
  static const _loopDuration = Duration(seconds: 64);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SkyBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!widget.animate) return;
    final stepsPerLoop =
        _loopDuration.inMilliseconds / _tick.inMilliseconds;
    final step = 1 / stepsPerLoop;
    // ~4 repaints per second. The drift is slow enough that a full 60 fps
    // repaint of four full-screen radial gradients would be pure waste; this
    // keeps the wallpaper off the raster budget while still reading as motion.
    _timer = Timer.periodic(_tick, (_) {
      _phase.value = (_phase.value + step) % 1.0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final palette = _BackdropPalette.of(
      colorScheme,
      intensity: widget.intensity,
    );
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(palette: palette, phase: _phase),
        willChange: widget.animate,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Colour set for one backdrop render.
///
/// Wallpapers are the one place in the app that is allowed to use saturated
/// colour; every surface above it is translucent so the field bleeds through.
@immutable
class _BackdropPalette {
  const _BackdropPalette({
    required this.base,
    required this.baseBottom,
    required this.blobs,
  });

  final Color base;
  final Color baseBottom;

  /// `(alignment, radiusFactor, color)` — radiusFactor is relative to the
  /// shorter viewport edge.
  final List<(Alignment, double, Color)> blobs;

  @override
  bool operator ==(Object other) {
    return other is _BackdropPalette &&
        other.base == base &&
        other.baseBottom == baseBottom &&
        listEquals(other.blobs, blobs);
  }

  @override
  int get hashCode => Object.hash(base, baseBottom, Object.hashAll(blobs));

  static _BackdropPalette of(ColorScheme scheme, {double intensity = 1.0}) {    final isDark = scheme.brightness == Brightness.dark;
    // Light mode washes the accents towards white so text keeps its contrast;
    // dark mode keeps them deep and glowy.
    final wash = isDark ? scheme.surface : Colors.white;
    final washAmount = isDark ? 0.12 : 0.46;
    final blobAlpha = (isDark ? 0.30 : 0.34) * intensity;

    Color accent(Color color, [double extraWash = 0]) {
      return Color.lerp(color, wash, washAmount + extraWash)!
          .withValues(alpha: blobAlpha);
    }

    return _BackdropPalette(
      base: isDark
          ? Color.lerp(scheme.surface, const Color(0xFF05070C), 0.55)!
          : Color.lerp(scheme.surface, Colors.white, 0.34)!,
      baseBottom: isDark
          ? Color.lerp(scheme.surface, const Color(0xFF0B0D14), 0.30)!
          : Color.lerp(scheme.surfaceContainerLow, Colors.white, 0.16)!,
      blobs: [
        (
          const Alignment(-0.78, -0.86),
          0.92,
          accent(scheme.primary, isDark ? 0.0 : 0.06),
        ),
        (
          const Alignment(0.92, -0.58),
          0.78,
          accent(scheme.tertiary, isDark ? 0.05 : 0.12),
        ),
        (
          const Alignment(0.55, 0.86),
          0.95,
          accent(scheme.secondary, isDark ? 0.0 : 0.10),
        ),
        (
          const Alignment(-0.86, 0.62),
          0.66,
          accent(scheme.primaryContainer, isDark ? 0.18 : 0.24),
        ),
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.palette,
    required ValueNotifier<double> phase,
  }) : _phase = phase,
       super(repaint: phase);

  final _BackdropPalette palette;

  /// Driving phase; the notifier doubles as the painter's repaint signal so the
  /// wallpaper repaints without rebuilding any widgets.
  final ValueNotifier<double> _phase;

  double get phase => _phase.value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.base, palette.baseBottom],
        ).createShader(rect),
    );

    final shortest = math.min(size.width, size.height);
    final tau = math.pi * 2;

    for (var i = 0; i < palette.blobs.length; i++) {
      final (alignment, radiusFactor, color) = palette.blobs[i];
      // Each blob drifts on its own slow orbit so the field never repeats
      // visibly, while staying well below the threshold that would distract
      // from the content.
      final driftX = math.sin(phase * tau + i * 1.9) * 0.045;
      final driftY = math.cos(phase * tau * 0.78 + i * 2.4) * 0.038;
      final center = Offset(
        (alignment.x + driftX + 1) * size.width / 2,
        (alignment.y + driftY + 1) * size.height / 2,
      );
      final radius = shortest * radiusFactor * 0.92;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: radius),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}

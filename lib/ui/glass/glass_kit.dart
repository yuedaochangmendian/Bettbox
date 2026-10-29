import 'package:bett_box/common/common.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Shared optical presets for every glass surface in Bettbox.
///
/// Three tiers only, because more than three is impossible to keep coherent:
///
/// * [chrome] — navigation bars, docks, toolbars. Thickest, most refractive,
///   and promoted to [GlassQuality.premium] by the caller. This is the layer
///   the user actually touches, so it gets the full iOS 26 treatment.
/// * [panel] — content cards and grouped sections. Softer, cheaper, standard
///   quality. Cards repeat dozens of times per screen; they must not each
///   request the multi-pass shader.
/// * [pill] — small floating affordances (chips, badges, mini buttons).
abstract final class SkyGlass {
  const SkyGlass._();

  /// Corner radius tokens, aligned with the app's existing card geometry.
  static const double radiusPanel = 22;
  static const double radiusCard = 26;
  static const double radiusChrome = 26;
  static const double radiusPill = 18;

  static LiquidRoundedSuperellipse squircle(double radius) {
    return LiquidRoundedSuperellipse(borderRadius: radius);
  }

  /// Bottom-rounded squircle — the shape of a bar docked at the top edge.
  static LiquidVerticalRoundedSuperellipse topBar(double radius) {
    return LiquidVerticalRoundedSuperellipse(
      topRadius: 0,
      bottomRadius: radius,
    );
  }

  /// Top-rounded squircle — the shape of a bar or sheet attached to the bottom
  /// edge of the viewport.
  static LiquidVerticalRoundedSuperellipse bottomBar(double radius) {
    return LiquidVerticalRoundedSuperellipse(
      topRadius: radius,
      bottomRadius: 0,
    );
  }

  static LiquidGlassSettings chrome(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return LiquidGlassSettings(
      thickness: 26,
      blur: 14,
      // Chromatic dispersion is what sells "glass" versus "frosted plastic";
      // keep it above the noise floor but below a rainbow fringe.
      chromaticAberration: 0.018,
      lightAngle: 1.15,
      lightIntensity: 0.62,
      refractiveIndex: 1.26,
      saturation: 1.62,
      glowIntensity: 0.85,
      glassColor: isDark
          ? const Color(0x8C0D1017)
          : const Color(0x9EFFFFFF),
      shadowElevation: 1.4,
      whitenStrength: isDark ? 0.0 : 0.06,
      whitenGated: true,
    );
  }

  static LiquidGlassSettings panel(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return LiquidGlassSettings(
      thickness: 18,
      blur: 10,
      chromaticAberration: 0.012,
      lightAngle: 1.15,
      lightIntensity: 0.45,
      refractiveIndex: 1.18,
      saturation: 1.38,
      glowIntensity: 0.55,
      glassColor: isDark
          ? const Color(0x6610141B)
          : const Color(0x7DFFFFFF),
      shadowElevation: 1.0,
      whitenStrength: isDark ? 0.0 : 0.10,
      whitenGated: true,
    );
  }

  static LiquidGlassSettings pill(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return LiquidGlassSettings(
      thickness: 14,
      blur: 9,
      chromaticAberration: 0.014,
      lightIntensity: 0.5,
      refractiveIndex: 1.2,
      saturation: 1.45,
      glowIntensity: 0.7,
      glassColor: isDark
          ? const Color(0x7311161F)
          : const Color(0x8FFFFFFF),
      shadowElevation: 0.9,
    );
  }
}

/// A glass panel: the app's one true content surface.
///
/// Replaces the opaque [Card]s the original UI used everywhere. It is a thin
/// wrapper over [AdaptiveGlass] so that the optical preset, corner geometry and
/// clipping rules are defined once instead of at 90+ call sites.
class SkyGlassPanel extends StatelessWidget {
  const SkyGlassPanel({
    super.key,
    required this.child,
    this.radius = SkyGlass.radiusPanel,
    this.settings,
    this.padding,
    this.margin,
    this.quality = GlassQuality.standard,
    this.clipBehavior = Clip.antiAlias,
    this.useOwnLayer = false,
    this.shape,
  });

  final Widget child;
  final double radius;

  /// Overrides [SkyGlass.panel] for this surface only.
  final LiquidGlassSettings? settings;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final GlassQuality quality;
  final Clip clipBehavior;

  /// `false` (default) joins the ambient shared layer, which is far cheaper
  /// than giving every card its own backdrop capture.
  final bool useOwnLayer;
  final LiquidShape? shape;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final effectiveSettings = settings ?? SkyGlass.panel(brightness);
    Widget surface = AdaptiveGlass(
      shape: shape ?? SkyGlass.squircle(radius),
      settings: effectiveSettings,
      quality: quality,
      useOwnLayer: useOwnLayer,
      clipBehavior: clipBehavior,
      child: _GlassHost(
        settings: effectiveSettings,
        quality: quality,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

/// Marks a subtree as living *inside* a refractive surface.
///
/// Nesting one glass surface in another is the one thing the underlying library
/// forbids: a second [BackdropFilter] under an existing glass layer makes
/// Impeller thrash GPU tile memory and can drop whole surfaces. Bettbox nests
/// glass constantly — settings rows sit inside section cards, and section cards
/// sit inside the glass bottom sheets — so every surface built here publishes
/// `avoidsRefraction`, exactly as the library's own `GlassContainer` does.
///
/// Descendants that honour the flag render as a tinted vibrancy fill: same rim,
/// same specular highlight, no second backdrop read. That is also what iOS 26
/// does with a `UIVibrancyEffect` inside a `UIVisualEffectView`.
class _GlassHost extends StatelessWidget {
  const _GlassHost({
    required this.settings,
    required this.quality,
    required this.child,
  });

  final LiquidGlassSettings settings;
  final GlassQuality quality;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InheritedLiquidGlass(
      settings: settings,
      quality: quality,
      avoidsRefraction: true,
      child: child,
    );
  }
}

/// Glass chrome for a bar attached to a viewport edge.
///
/// Unlike [SkyGlassPanel] the surface is a single continuous sheet — the
/// app bar and the bottom dock are the two places where the iOS 26 language
/// expects a full-bleed refractive bar rather than a floating card.
class SkyGlassChrome extends StatelessWidget {
  const SkyGlassChrome({
    super.key,
    required this.child,
    this.dockedAtTop = true,
    this.radius = SkyGlass.radiusChrome,
    this.settings,
    this.quality = GlassQuality.premium,
    this.shape,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;

  /// `true` rounds the bottom corners (top app bar), `false` rounds the top
  /// corners (bottom dock).
  final bool dockedAtTop;
  final double radius;
  final LiquidGlassSettings? settings;
  final GlassQuality quality;
  final LiquidShape? shape;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final effectiveSettings = settings ?? SkyGlass.chrome(brightness);
    return AdaptiveGlass(
      shape: shape ??
          (dockedAtTop
              ? SkyGlass.topBar(radius)
              : SkyGlass.bottomBar(radius)),
      settings: effectiveSettings,
      quality: quality,
      useOwnLayer: false,
      clipBehavior: clipBehavior,
      child: _GlassHost(
        settings: effectiveSettings,
        quality: quality,
        child: child,
      ),
    );
  }
}

/// A circular glass button surface, used by floating actions and close
/// affordances that are already wired to their own gesture handling.
class SkyGlassCircle extends StatelessWidget {
  const SkyGlassCircle({
    super.key,
    required this.child,
    this.size = 44,
    this.settings,
    this.quality = GlassQuality.standard,
  });

  final Widget child;
  final double size;
  final LiquidGlassSettings? settings;
  final GlassQuality quality;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final effectiveSettings = settings ?? SkyGlass.pill(brightness);
    return AdaptiveGlass(
      shape: const LiquidOval(),
      settings: effectiveSettings,
      quality: quality,
      useOwnLayer: false,
      clipBehavior: Clip.antiAlias,
      child: _GlassHost(
        settings: effectiveSettings,
        quality: quality,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Convenience: a brightness-aware hairline that reads as the rim of a glass
/// edge. Used where a widget paints its own decoration instead of using
/// [AdaptiveGlass].
BorderSide skyGlassRim(BuildContext context, {double alpha = 0.55}) {
  final isDark = context.colorScheme.brightness == Brightness.dark;
  return BorderSide(
    color: isDark
        ? Colors.white.withValues(alpha: 0.14 * alpha)
        : Colors.white.withValues(alpha: 0.55 * alpha),
    width: 1,
    strokeAlign: BorderSide.strokeAlignInside,
  );
}

extension SkyGlassColorScheme on ColorScheme {  /// Returns a copy of this scheme whose surface family is translucent.
  ///
  /// Every widget in Bettbox reaches its background colour through
  /// `context.colorScheme.surfaceContainer*`, so softening the scheme here
  /// turns the entire app translucent in one shot — the [SkyBackdrop] bleeds
  /// through panels, and the real glass widgets on top of them have something
  /// to refract. Elevation is still expressed: the higher the container tier,
  /// the more opaque it is, exactly like iOS materials.
  ///
  /// A scheme that has already been flattened to pure black (OLED mode) is
  /// returned unchanged — those users explicitly asked for opaque black.
  ColorScheme get glassSurfaces {
    if (surface.computeLuminance() == 0) return this;

    final isDark = brightness == Brightness.dark;
    // Dark glass needs to be a touch more opaque: a translucent dark panel over
    // a bright wallpaper reads as washed-out grey and kills text contrast.
    final base = isDark ? 0.62 : 0.56;

    Color veil(Color color, double tier) {
      return color.withValues(alpha: (base + tier).clamp(0.0, 0.94));
    }

    return copyWith(
      surface: veil(surface, -0.22),
      surfaceDim: veil(surfaceDim, -0.10),
      surfaceBright: veil(surfaceBright, 0.10),
      surfaceContainerLowest: veil(surfaceContainerLowest, -0.16),
      surfaceContainerLow: veil(surfaceContainerLow, -0.08),
      surfaceContainer: veil(surfaceContainer, 0.0),
      surfaceContainerHigh: veil(surfaceContainerHigh, 0.08),
      surfaceContainerHighest: veil(surfaceContainerHighest, 0.14),
    );
  }
}

/// [Card] styling for the parts of the app that still use Material's card.
///
/// Material cards cannot blur — [Card] paints a flat fill and a shadow — so
/// instead of faking it they are tuned to read as a pane of glass: translucent
/// body, no elevation tint, and a bright hairline where the bevel would catch
/// the light. The real refractive surfaces are the [SkyGlassPanel]s.
CardThemeData glassCardTheme(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  return CardThemeData(
    color: scheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
    elevation: 0,
    shape: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.62),
        width: 1,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    ),
  );
}

/// Floating snack bars get the same treatment as the in-app glass toast.
SnackBarThemeData glassSnackBarTheme(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  return SnackBarThemeData(
    backgroundColor: isDark
        ? const Color(0xE6101419)
        : const Color(0xF2FFFFFF),
    actionTextColor: scheme.primary,
    contentTextStyle: TextStyle(color: scheme.onSurface, fontSize: 14),
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    shape: RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.70),
        width: 1,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    ),
  );
}


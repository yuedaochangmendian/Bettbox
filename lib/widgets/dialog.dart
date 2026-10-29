import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/app.dart';
import 'package:bett_box/ui/glass/glass_kit.dart';
import 'package:bett_box/widgets/pop_scope.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bett_box/state.dart';
import 'text.dart';

/// The app's standard modal dialog.
///
/// The layout still mirrors [AlertDialog] — same paddings, same title metrics,
/// same overflow behaviour for actions — but the surface is a real refractive
/// glass panel instead of an opaque card. [AlertDialog] cannot carry a
/// backdrop blur because it paints its own opaque background *inside* its
/// shape, so the chrome is rebuilt on top of [SkyGlassPanel] here. Keeping the
/// geometry identical means the 70-odd call sites that size their own content
/// keep working untouched.
class CommonDialog extends ConsumerWidget {
  final String title;
  final Widget? titleTrailing;
  final Widget? child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Color? backgroundColor;

  const CommonDialog({
    super.key,
    required this.title,
    this.titleTrailing,
    this.actions,
    this.child,
    this.padding,
    this.overrideScroll = false,
    this.backgroundColor,
  });

  List<Widget>? _buildActions(BuildContext context) {
    final actions = this.actions;
    if (actions == null || actions.isEmpty) {
      return actions;
    }
    final colorScheme = context.colorScheme;
    final backgroundColor = colorScheme.primary.opacity12;
    return [
      ...actions.take(actions.length - 1),
      FilledButtonTheme(
        data: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: colorScheme.primary,
            elevation: 0,
          ),
        ),
        child: TextButtonTheme(
          data: TextButtonThemeData(
            style: TextButton.styleFrom(
              backgroundColor: backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
          child: actions.last,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    final isTv = globalState.isAndroidTV;
    final theme = Theme.of(context);
    final colorScheme = context.colorScheme;
    final actions = _buildActions(context);

    final titleStyle =
        context.textTheme.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(fontSize: 19, fontWeight: FontWeight.w600);

    final contentStyle =
        context.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(color: colorScheme.onSurfaceVariant);

    final Widget content = Container(
      constraints: BoxConstraints(
        maxHeight: min(size.height - 40, 500),
        maxWidth: 300,
      ),
      width: size.width - 40,
      child: overrideScroll ? child : SingleChildScrollView(child: child),
    );

    return PopScope(
      canPop: !isTv,
      onPopInvokedWithResult: !isTv
          ? null
          : (didPop, result) {
              if (didPop) return;
              if (dismissTvInputFocus()) return;
              if (ModalRoute.of(context)?.isCurrent != true) return;
              Navigator.of(context).pop();
            },
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: max(24, size.height * 0.06),
        ),
        child: SkyGlassPanel(
          radius: 30,
          quality: GlassQuality.premium,
          settings: SkyGlass.chrome(theme.brightness).copyWith(
            // Modal surfaces sit over live content, so they need more body than
            // an app bar: denser tint keeps 15px body text legible over a
            // saturated wallpaper while the rim still catches the light.
            glassColor:
                backgroundColor ??
                (theme.brightness == Brightness.dark
                    ? const Color(0xB8111419)
                    : const Color(0xC7FFFFFF)),
            shadowElevation: 2.2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                child: DefaultTextStyle(
                  style: titleStyle,
                  child: titleTrailing == null
                      ? EmojiText(title)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(child: EmojiText(title)),
                            const SizedBox(width: 8),
                            titleTrailing!,
                          ],
                        ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding:
                      padding ?? const EdgeInsets.fromLTRB(22, 14, 22, 18),
                  child: Theme(
                    data: theme.copyWith(
                      inputDecorationTheme: theme.inputDecorationTheme
                          .copyWith(
                            fillColor: theme.brightness == Brightness.light
                                ? theme.colorScheme.surfaceContainer
                                : null,
                          ),
                    ),
                    child: DefaultTextStyle.merge(
                      style: contentStyle,
                      child: content,
                    ),
                  ),
                ),
              ),
              if (actions != null && actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: actions,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommonModal extends ConsumerWidget {
  final Widget? child;

  const CommonModal({super.key, this.child});

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    return Center(
      child: SizedBox(
        width: size.width * 0.85,
        height: size.height * 0.85,
        child: SkyGlassPanel(
          radius: 26,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: child,
          ),
        ),
      ),
    );
  }
}

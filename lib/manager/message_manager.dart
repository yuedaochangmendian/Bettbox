import 'dart:async';
import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/ui/glass/glass_kit.dart';
import 'package:bett_box/widgets/fade_box.dart';
import 'package:bett_box/widgets/text.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';

class MessageManager extends StatefulWidget {
  final Widget child;

  const MessageManager({super.key, required this.child});

  @override
  State<MessageManager> createState() => MessageManagerState();
}

class MessageManagerState extends State<MessageManager> {
  final _messagesNotifier = ValueNotifier<List<CommonMessage>>([]);
  final List<CommonMessage> _bufferMessages = [];
  bool _pushing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messagesNotifier.dispose();
    super.dispose();
  }

  Future<void> message(
    String text, {
    VoidCallback? onAction,
    String? actionLabel,
    bool showCountdown = false,
  }) async {
    if (_messagesNotifier.value.any((m) => m.text == text) ||
        _bufferMessages.any((m) => m.text == text)) {
      return;
    }

    final commonMessage = CommonMessage(
      id: utils.uuidV4,
      text: text,
      onAction: onAction,
      actionLabel: actionLabel,
      showCountdown: showCountdown,
    );
    _bufferMessages.add(commonMessage);
    await _showMessage();
  }

  Future<void> _showMessage() async {
    if (_pushing) return;
    _pushing = true;
    while (_bufferMessages.isNotEmpty) {
      final commonMessage = _bufferMessages.removeAt(0);
      _messagesNotifier.value = List.from(_messagesNotifier.value)..add(commonMessage);
      await Future.delayed(const Duration(seconds: 1));
      Future.delayed(commonMessage.duration, () => _handleRemove(commonMessage));
      if (_bufferMessages.isEmpty) _pushing = false;
    }
  }

  void _handleRemove(CommonMessage commonMessage) {
    _messagesNotifier.value = List<CommonMessage>.from(_messagesNotifier.value)
      ..remove(commonMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder(
          valueListenable: _messagesNotifier,
          builder: (_, messages, _) {
            return FadeThroughBox(
              margin: EdgeInsets.only(
                top: kToolbarHeight + 8,
                left: 12,
                right: 12,
              ),
              alignment: Alignment.topCenter,
              child: messages.isEmpty
                  ? SizedBox()
                  : LayoutBuilder(
                      key: Key(messages.last.id),
                      builder: (_, constraints) {
                        final message = messages.last;
                        return SizedBox(
                          width: min(constraints.maxWidth, 500),
                          child: SkyGlassPanel(
                            radius: 18,
                            quality: GlassQuality.premium,
                            settings: SkyGlass.chrome(
                              context.colorScheme.brightness,
                            ).copyWith(
                              // Toasts float over arbitrary content, so they
                              // need a denser body than the app chrome to stay
                              // readable, while keeping the refractive rim.
                              glassColor:
                                  context.colorScheme.brightness ==
                                      Brightness.dark
                                  ? const Color(0xD9101419)
                                  : const Color(0xE0FFFFFF),
                              shadowElevation: 2.0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (message.showCountdown)
                                  _CountdownWidget(
                                    duration: message.duration,
                                  ),
                                Expanded(
                                  child: EmojiText(
                                    message.text,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (message.actionLabel != null &&
                                    message.onAction != null) ...[
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      _handleRemove(message);
                                      message.onAction?.call();
                                    },
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      foregroundColor:
                                          context.colorScheme.primary,
                                    ),
                                    child: Text(message.actionLabel!),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _CountdownWidget extends StatefulWidget {
  final Duration duration;

  const _CountdownWidget({required this.duration});

  @override
  State<_CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<_CountdownWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _totalSeconds;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.duration.inSeconds;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 24,
        height: 24,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final remaining = (_totalSeconds * (1 - _controller.value)).ceil();
            final currentSecond = remaining > 0 ? remaining : 1;

            return Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1 - _controller.value,
                  strokeWidth: 2,
                  backgroundColor: primaryColor.withAlpha(26),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
                Text(
                  '$currentSecond',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

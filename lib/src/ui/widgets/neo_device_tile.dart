import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'device_icon_view.dart';
import 'glass_panel.dart';
import 'neo_icon_well.dart';

/// Vlak kader (geen effect). Enkel de icooncirkel toont het duw-effect
/// en de aan/uit-staat. Hele tegel is tikbaar.
class NeoDeviceTile extends StatefulWidget {
  const NeoDeviceTile({
    super.key,
    required this.name,
    required this.active,
    required this.onToggle,
    this.status,
    this.iconType,
    this.icon,
    this.dimmable = false,
    this.level = 0,
    this.glowColor,
    this.iconTint,
    this.onDimPreview,
    this.onDimEnd,
    this.onLongPress,
    this.compact = false,
    this.glowWhenOff = false,
    this.showToggleLed = false,
    this.gesturesEnabled = true,
    this.pulse = false,
  });

  final String name;
  final String? status;
  final String? iconType;
  final Widget? icon;
  final bool active;
  final bool dimmable;
  final int level;
  final Color? glowColor;

  /// Glyphkleur zonder gloed (uit-cirkels).
  final Color? iconTint;
  final VoidCallback onToggle;
  final ValueChanged<int>? onDimPreview;
  final ValueChanged<int>? onDimEnd;
  final VoidCallback? onLongPress;
  final bool compact;
  final bool glowWhenOff;

  /// Toggle-loads: LED op de naamregel, zelfde inset als dim-slider-max.
  final bool showToggleLed;
  final bool gesturesEnabled;

  /// Macro/scene: momentane pulse — cirkel zakt en veert terug.
  final bool pulse;

  @override
  State<NeoDeviceTile> createState() => _NeoDeviceTileState();
}

class _NeoDeviceTileState extends State<NeoDeviceTile> {
  static const _nameColor = Neo.text;
  static const _statusColor = Neo.textDim;
  static const _well = 40.0;
  static const _labelGap = 14.0;
  static const _endInset = 12.0;
  static const _ledSize = 7.0;
  static const _thumbRadius = 4.5;
  bool _sliding = false;
  Timer? _pulseHold;
  DateTime? _downAt;
  Offset? _downPos;
  bool _skipTap = false;
  final _held = ValueNotifier(false);

  static const _pulseMin = Duration(milliseconds: 280);
  static const _tapSlop = 24.0;

  void _setHeld(bool value) {
    if (!widget.gesturesEnabled || _held.value == value) return;
    _held.value = value;
  }

  void _pressDown(Offset pos) {
    _pulseHold?.cancel();
    _downAt = DateTime.now();
    _downPos = pos;
    _skipTap = false;
    _setHeld(true);
  }

  void _pressUp() {
    if (!widget.pulse) {
      _setHeld(false);
      return;
    }
    final elapsed = DateTime.now().difference(_downAt ?? DateTime.now());
    final remain = _pulseMin - elapsed;
    _pulseHold?.cancel();
    if (remain <= Duration.zero) {
      _setHeld(false);
    } else {
      _pulseHold = Timer(remain, () {
        if (mounted) _setHeld(false);
      });
    }
  }

  void _tryToggle(Offset upPos) {
    if (!widget.gesturesEnabled || _skipTap) return;
    final down = _downPos;
    if (down != null && (upPos - down).distance > _tapSlop) return;
    widget.onToggle();
  }

  @override
  void dispose() {
    _pulseHold?.cancel();
    _held.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NeoDeviceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.gesturesEnabled && _held.value) {
      _held.value = false;
    }
  }

  String get _status {
    if (widget.status != null) return widget.status!;
    if (widget.dimmable) {
      return widget.active ? '${widget.level.clamp(0, 100)}%' : 'Uit';
    }
    return widget.active ? 'Aan' : 'Uit';
  }

  Widget _glowIcon(Widget glyph, Color? glow) {
    if (glow == null) return glyph;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(glow, BlendMode.srcATop),
            child: glyph,
          ),
        ),
        glyph,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    const iconSize = 22.0;
    final level = widget.level.clamp(0, 100);
    final glow = (widget.active || widget.glowWhenOff) ? widget.glowColor : null;
    final tint = glow ?? widget.iconTint;
    final live = widget.gesturesEnabled;
    final lit = widget.active || _sliding;
    const accent = Neo.accent;

    final glyph = widget.icon ??
        DeviceIconView(
          typeId: widget.iconType,
          isOn: widget.active || tint != null,
          size: deviceIconRemoteSize(iconSize),
          inset: 0.04,
          whiteAsset: tint == null,
          color: tint ??
              Colors.white.withValues(alpha: widget.active ? 1 : 0.40),
        );

    final glowChild = _glowIcon(glyph, glow);
    final showStatus = _status.isNotEmpty;

    final nameRow = Row(
      children: [
        Expanded(
          child: Text(
            widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _nameColor.withValues(alpha: widget.active ? 1 : 0.9),
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.15,
            ),
          ),
        ),
        if (showStatus) ...[
          const SizedBox(width: 8),
          Text(
            _status,
            maxLines: 1,
            style: TextStyle(
              color: (widget.active ? accent : _statusColor)
                  .withValues(alpha: widget.active ? 0.95 : 0.85),
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
        if (widget.showToggleLed)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _TileLed(color: accent, on: widget.active),
          ),
      ],
    );

    final slider = widget.dimmable
        ? SizedBox(
            height: 16,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                year2023: false,
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: _thumbRadius,
                ),
                overlayShape: SliderComponentShape.noOverlay,
                padding: EdgeInsets.zero,
                trackShape: const _FlushTrack(),
                showValueIndicator: ShowValueIndicator.never,
                activeTrackColor: accent.withValues(alpha: lit ? 0.95 : 0.22),
                inactiveTrackColor:
                    Colors.white.withValues(alpha: lit ? 0.22 : 0.12),
                thumbColor: Colors.white.withValues(alpha: lit ? 1 : 0.45),
              ),
              child: Slider(
                year2023: false,
                min: 0,
                max: 100,
                value: level.toDouble(),
                onChangeStart:
                    live ? (_) => setState(() => _sliding = true) : null,
                onChanged:
                    live ? (v) => widget.onDimPreview?.call(v.round()) : null,
                onChangeEnd: live
                    ? (v) {
                        setState(() => _sliding = false);
                        widget.onDimEnd?.call(v.round());
                      }
                    : null,
              ),
            ),
          )
        : null;

    Widget tapWrap(Widget child) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: live ? (e) => _pressDown(e.position) : null,
        onPointerUp: live
            ? (e) {
                _pressUp();
                _tryToggle(e.position);
              }
            : null,
        onPointerCancel: live ? (_) => _pressUp() : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: live && widget.onLongPress != null
              ? () {
                  _skipTap = true;
                  widget.onLongPress!();
                }
              : null,
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 68,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Neo.radius),
          color: Neo.surface,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 14,
            10,
            compact ? 10 : _endInset,
            10,
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: _held,
            builder: (context, held, _) {
              return Row(
                children: [
                  tapWrap(
                    NeoIconWell(
                      size: _well,
                      pressed: widget.active || held,
                      child: glowChild,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: _labelGap),
                      child: SizedBox(
                        width: double.infinity,
                        height: _well,
                        child: slider == null
                            ? Align(
                                alignment: Alignment.center,
                                child: tapWrap(nameRow),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  tapWrap(nameRow),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: slider,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dunne track tot de rand; geen extra dikte bij aan — alleen andere kleur.
class _FlushTrack extends RoundedRectSliderTrackShape {
  const _FlushTrack();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final height = sliderTheme.trackHeight ?? 3;
    final top = offset.dy + (parentBox.size.height - height) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
  }
}

/// Kleine LED op de naamregel. Aan = icoonkleur + gloed.
class _TileLed extends StatelessWidget {
  const _TileLed({required this.color, required this.on});

  final Color color;
  final bool on;

  static const _size = _NeoDeviceTileState._ledSize;

  @override
  Widget build(BuildContext context) {
    final lit = on ? color : const Color(0xFF454A52);
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit,
        boxShadow: on
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.7),
                  blurRadius: 5,
                ),
              ]
            : null,
      ),
    );
  }
}

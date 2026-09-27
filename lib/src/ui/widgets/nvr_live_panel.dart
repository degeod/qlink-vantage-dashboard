import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// IvyIo [VideoSurfaceViewNVR] via het officiële Android-SDK.
class NvrLivePanel extends StatelessWidget {
  const NvrLivePanel({
    super.key,
    required this.selected,
    required this.ready,
    this.message,
    this.channels = const [],
    this.onSelect,
    this.onSelectAll,
  });

  final List<int> selected;
  final bool ready;
  final String? message;
  final List<Map<String, dynamic>> channels;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onSelectAll;

  int? _idAt(int i) {
    if (i < 0 || i >= channels.length) return null;
    final raw = channels[i]['channel'];
    return raw is num ? raw.toInt() : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return ColoredBox(
        color: const Color(0xFF1A1E24),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              message ?? 'NVR: zoek en log in bij Settings',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ),
      );
    }
    final views = selected.isNotEmpty
        ? selected
        : [
            for (var i = 0; i < channels.length; i++)
              if (_idAt(i) != null) _idAt(i)!,
          ];
    return ColoredBox(
      color: const Color(0xFF1A1E24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _NvrGrid(
            channels: views,
            useSub: views.length > 1,
          ),
          if (channels.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: _CameraBar(
                count: channels.length,
                selected: views,
                idAt: _idAt,
                onSelect: onSelect,
                onSelectAll: onSelectAll,
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraBar extends StatelessWidget {
  const _CameraBar({
    required this.count,
    required this.selected,
    required this.idAt,
    this.onSelect,
    this.onSelectAll,
  });

  final int count;
  final List<int> selected;
  final int? Function(int i) idAt;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onSelectAll;

  static const _cyan = Color(0xFF2EE8E0);
  static const _bar = Color(0xCC12151A);

  @override
  Widget build(BuildContext context) {
    final allOn = count > 1 && selected.length >= count;
    return ColoredBox(
      color: _bar,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 10, right: 6),
              child: Text(
                'CAM',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (var i = 0; i < count; i++)
              Expanded(
                child: _BarBtn(
                  label: '${i + 1}',
                  selected: selected.contains(idAt(i)) && !allOn,
                  onTap: () {
                    final id = idAt(i);
                    if (id != null) onSelect?.call(id);
                  },
                ),
              ),
            if (count > 1)
              Expanded(
                child: _BarBtn(
                  label: 'alle',
                  selected: allOn,
                  onTap: () => onSelectAll?.call(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  const _BarBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _cyan = Color(0xFF2EE8E0);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _cyan : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF12151A) : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _NvrGrid extends StatelessWidget {
  const _NvrGrid({required this.channels, required this.useSub});

  final List<int> channels;
  final bool useSub;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const Center(
        child: Text(
          'Geen kanaal gekozen',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }
    if (channels.length == 1) {
      return _NvrSurface(channel: channels.first, useSub: useSub);
    }
    const cols = 2;
    final rows = (channels.length + cols - 1) ~/ cols;
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < cols; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _cell(row * cols + col),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int i) {
    if (i >= channels.length) return const SizedBox.expand();
    return _NvrSurface(channel: channels[i], useSub: useSub);
  }
}

class _NvrSurface extends StatelessWidget {
  const _NvrSurface({required this.channel, required this.useSub});

  final int channel;
  final bool useSub;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const ratio = 16 / 9;
        var w = box.maxWidth;
        var h = w / ratio;
        if (h < box.maxHeight) {
          h = box.maxHeight;
          w = h * ratio;
        }
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: w,
            maxWidth: w,
            minHeight: h,
            maxHeight: h,
            child: SizedBox(
              width: w,
              height: h,
              child: AndroidView(
                key: ValueKey<String>('nvr-$channel-$useSub'),
                viewType: 'vantage_nvr/surface',
                creationParams: {
                  'channel': channel,
                  'sub': useSub,
                },
                creationParamsCodec: const StandardMessageCodec(),
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
                hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              ),
            ),
          ),
        );
      },
    );
  }
}

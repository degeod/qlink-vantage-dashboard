import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/weather_service.dart';
import '../theme/app_theme.dart';

/// Vaste smalle weer-balk: vandaag | 6 dagen (of uur) | memo.
/// Los van het tile-raster; altijd volle breedte.
class HaWeatherCard extends StatefulWidget {
  const HaWeatherCard({
    super.key,
    required this.cardColor,
    required this.loading,
    required this.weather,
    required this.error,
    required this.animation,
    required this.onRefresh,
    required this.memoNote,
    required this.onMemoChanged,
    this.placeName,
    this.now,
    this.onPlaceTap,
  });

  final Color cardColor;
  final bool loading;
  final WeatherSnapshot? weather;
  final String? error;
  final Animation<double> animation;
  final VoidCallback onRefresh;
  final String memoNote;
  final ValueChanged<String> onMemoChanged;
  final String? placeName;
  final DateTime? now;
  final VoidCallback? onPlaceTap;

  @override
  State<HaWeatherCard> createState() => _HaWeatherCardState();
}

class _HaWeatherCardState extends State<HaWeatherCard> {
  static const bandHeight = 124.0;

  bool _hourly = false;
  late final TextEditingController _memoCtrl;
  Timer? _memoDebounce;

  @override
  void initState() {
    super.initState();
    _memoCtrl = TextEditingController(text: widget.memoNote);
  }

  @override
  void didUpdateWidget(covariant HaWeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoNote != widget.memoNote && widget.memoNote != _memoCtrl.text) {
      _memoCtrl.text = widget.memoNote;
    }
  }

  @override
  void dispose() {
    _memoDebounce?.cancel();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _onMemoTyped(String value) {
    _memoDebounce?.cancel();
    _memoDebounce = Timer(const Duration(milliseconds: 450), () {
      widget.onMemoChanged(value);
    });
  }

  void _clearMemo() {
    _memoDebounce?.cancel();
    _memoCtrl.clear();
    widget.onMemoChanged('');
  }

  IconData _icon(int code) {
    switch (WeatherService.iconKind(code)) {
      case IconKind.clear:
        return Icons.wb_sunny_outlined;
      case IconKind.cloudy:
        return Icons.cloud_outlined;
      case IconKind.fog:
        return Icons.blur_on;
      case IconKind.rain:
        return Icons.water_drop_outlined;
      case IconKind.snow:
        return Icons.ac_unit;
      case IconKind.storm:
        return Icons.thunderstorm_outlined;
    }
  }

  String _fmtSun(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmtClock(DateTime now) =>
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime now) {
    const days = ['zo', 'ma', 'di', 'wo', 'do', 'vr', 'za'];
    const months = [
      'jan', 'feb', 'mrt', 'apr', 'mei', 'jun',
      'jul', 'aug', 'sep', 'okt', 'nov', 'dec',
    ];
    return '${days[now.weekday % 7]} ${now.day} ${months[now.month - 1]}';
  }

  List<WeatherSlot> _midSlots(WeatherSnapshot? w) {
    if (w == null) return const [];
    if (_hourly) return w.hourly.take(12).toList();
    // Skip vandaag in daily → 6 volgende dagen.
    final days = w.daily;
    if (days.length <= 1) return days.take(6).toList();
    return days.skip(1).take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.weather;
    final code = w?.weatherCode ?? 3;
    final now = widget.now;
    final slots = _midSlots(w);

    return SizedBox(
      height: bandHeight,
      width: double.infinity,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _SimpleEffects(
                  kind: WeatherService.iconKind(code),
                  animation: widget.animation,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Links: vandaag + 6 dagen compact aan elkaar
                  SizedBox(
                    width: 250,
                    child: _TodayBlock(
                      loading: widget.loading,
                      error: widget.error,
                      weather: w,
                      placeName: widget.placeName,
                      now: now,
                      icon: _icon(code),
                      fmtClock: _fmtClock,
                      fmtDate: _fmtDate,
                      fmtSun: _fmtSun,
                      onPlaceTap: widget.onPlaceTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _hourly ? 'Uur' : '6 dagen',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ),
                            _TinyIconBtn(
                              icon: _hourly ? Icons.calendar_view_week : Icons.schedule,
                              tooltip: _hourly ? 'Dagen' : 'Uur',
                              onTap: () => setState(() => _hourly = !_hourly),
                            ),
                            _TinyIconBtn(
                              icon: Icons.refresh,
                              tooltip: 'Vernieuwen',
                              onTap: widget.onRefresh,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: w == null || slots.isEmpty
                              ? const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('—', style: TextStyle(color: Colors.white24)),
                                )
                              : Row(
                                  children: [
                                    for (var i = 0; i < slots.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 4),
                                      Expanded(
                                        child: _ForecastSlotTile(
                                          slot: slots[i],
                                          icon: _icon(slots[i].weatherCode),
                                          hourly: _hourly,
                                          maxPrecip: slots
                                              .map((s) => s.precipitationMm)
                                              .fold<double>(0.1, math.max),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Zelfde zachte streep als elders in de topband
                  const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                  Expanded(
                    child: _MemoBlock(
                      controller: _memoCtrl,
                      onChanged: _onMemoTyped,
                      onClear: _clearMemo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayBlock extends StatelessWidget {
  const _TodayBlock({
    required this.loading,
    required this.error,
    required this.weather,
    required this.placeName,
    required this.now,
    required this.icon,
    required this.fmtClock,
    required this.fmtDate,
    required this.fmtSun,
    this.onPlaceTap,
  });

  final bool loading;
  final String? error;
  final WeatherSnapshot? weather;
  final String? placeName;
  final DateTime? now;
  final IconData icon;
  final String Function(DateTime) fmtClock;
  final String Function(DateTime) fmtDate;
  final String Function(DateTime?) fmtSun;
  final VoidCallback? onPlaceTap;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (now != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtClock(now!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    fmtDate(now!),
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
        if (loading)
          const Text('Weer laden…', style: TextStyle(color: Colors.white54, fontSize: 13))
        else if (error != null)
          Text(error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.redAccent, fontSize: 12))
        else if (w == null)
          const Text('Geen weer', style: TextStyle(color: Colors.white54, fontSize: 13))
        else
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.amber, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (placeName != null && placeName!.trim().isNotEmpty)
                        InkWell(
                          onTap: onPlaceTap,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    placeName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ),
                                if (onPlaceTap != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.place_outlined, size: 14, color: AppColors.amber),
                                ],
                              ],
                            ),
                          ),
                        ),
                      Text(
                        '${w.temperatureC.round()}°  ${w.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        [
                          if (w.feelsLikeC != null) 'Voelt ${w.feelsLikeC!.round()}°',
                          'Wind ${w.windKmh.round()}',
                          if (w.humidity != null) '${w.humidity}%',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      if (w.sunrise != null || w.sunset != null)
                        Text(
                          'Zon ${fmtSun(w.sunrise)} / ${fmtSun(w.sunset)}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MemoBlock extends StatelessWidget {
  const _MemoBlock({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Memo', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, size: 18, color: Colors.white54),
              ),
            ),
          ],
        ),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.25),
            cursorColor: AppColors.amber,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Notitie…',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              contentPadding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TinyIconBtn extends StatelessWidget {
  const _TinyIconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: Colors.white54),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _ForecastSlotTile extends StatelessWidget {
  const _ForecastSlotTile({
    required this.slot,
    required this.icon,
    required this.hourly,
    required this.maxPrecip,
  });

  final WeatherSlot slot;
  final IconData icon;
  final bool hourly;
  final double maxPrecip;

  @override
  Widget build(BuildContext context) {
    final barH = (slot.precipitationMm / maxPrecip).clamp(0.0, 1.0) * 12;
    final high = slot.tempMaxC ?? slot.tempC;
    final low = slot.tempMinC;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
          Icon(icon, color: Colors.white70, size: 16),
          Text(
            hourly ? '${slot.tempC.round()}°' : '${high.round()}°',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          ),
          if (!hourly && low != null)
            Text('${low.round()}°', style: const TextStyle(color: Colors.white38, fontSize: 9)),
          const Spacer(),
          Container(
            width: 7,
            height: math.max(2, barH),
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleEffects extends StatelessWidget {
  const _SimpleEffects({required this.kind, required this.animation});
  final IconKind kind;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (kind != IconKind.rain && kind != IconKind.storm && kind != IconKind.snow) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => CustomPaint(
        painter: _RainSnowPainter(kind: kind, t: animation.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RainSnowPainter extends CustomPainter {
  _RainSnowPainter({required this.kind, required this.t});
  final IconKind kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    if (kind == IconKind.rain || kind == IconKind.storm) {
      final paint = Paint()
        ..color = const Color(0x334FC3F7)
        ..strokeWidth = 1;
      for (var i = 0; i < 10; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = (rnd.nextDouble() * size.height + t * size.height) % size.height;
        canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + 6), paint);
      }
    } else if (kind == IconKind.snow) {
      final paint = Paint()..color = const Color(0x44FFFFFF);
      for (var i = 0; i < 10; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = (rnd.nextDouble() * size.height + t * size.height) % size.height;
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainSnowPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.kind != kind;
}

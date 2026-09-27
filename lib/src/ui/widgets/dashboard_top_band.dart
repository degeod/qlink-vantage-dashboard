import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/weather_service.dart';
import '../../state/dashboard_config.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';
import 'weather_icon.dart';

/// Vaste Dashboard-balk: weer (eigen kader) | kalender + memo (samen).
///
/// State (niet opnieuw verzinnen):
/// - Boodschappenlijst: [memoNote] via [onMemoChanged] → `setDashboardMemoNote`
/// - Afspraken: [dayMemos] via [onDayMemoChanged] → `setDashboardDayMemo` → `setMemoForDay`
/// - Selectie: `_selectDay`; ruststand: `_returnToDefaultMemo`
///   (op de dag van een afspraak: toon afspraak; na **C**: boodschappenlijst)
///
/// Alleen visuele chrome wijzigen in [GlassPanel]; kalender/memo-logica intact laten.
class DashboardTopBand extends StatefulWidget {
  const DashboardTopBand({
    super.key,
    required this.cardColor,
    required this.memoNote,
    required this.onMemoChanged,
    required this.dayMemos,
    required this.onDayMemoChanged,
    required this.weatherLat,
    required this.weatherLon,
    required this.placeName,
    this.onPlaceTap,
    this.now,
  });

  final Color cardColor;
  final String memoNote;
  final ValueChanged<String> onMemoChanged;
  final Map<String, String> dayMemos;
  final void Function(DateTime day, String note) onDayMemoChanged;
  final double weatherLat;
  final double weatherLon;
  final String placeName;
  final VoidCallback? onPlaceTap;
  final DateTime? now;

  @override
  State<DashboardTopBand> createState() => _DashboardTopBandState();
}

class _DashboardTopBandState extends State<DashboardTopBand>
    with SingleTickerProviderStateMixin {
  static const bandHeight = 186.0;
  static const _todayMark = Color(0xFFCC5500);
  static const _frame = Neo.surface;

  late final TextEditingController _memoCtrl;
  late final AnimationController _weatherAnim;
  late DateTime _month;

  /// Lokale kopie van het vrije memoblok — nooit vermengen met dagnotities.
  late String _generalMemo;

  /// null = vrij memoblok; anders bekijken/bewerken van die dag.
  DateTime? _viewDay;
  Timer? _memoDebounce;
  Timer? _autoBack;
  Timer? _midnight;

  WeatherSnapshot? _weather;
  String? _weatherError;
  bool _weatherLoading = false;
  bool _hourly = false;

  /// Blokkeer per ongeluk opslaan van dagtekst naar algemeen memo.
  bool _ignoreNextFieldSync = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isMarked(DateTime d) =>
      (widget.dayMemos[DashboardConfig.dayKey(d)] ?? '').trim().isNotEmpty;

  bool get _dayMode => _viewDay != null;

  DateTime get _today => _dateOnly(widget.now ?? DateTime.now());

  bool get _viewingTodayAppointment {
    final day = _viewDay;
    return day != null && day == _today && _isMarked(day);
  }

  /// Rond opsomteken (~25% van hoofdletterhoogte bij font 16).
  static const _bulletChar = '•';
  static const _bulletPrefix = '$_bulletChar ';

  String _dayNote(DateTime d) =>
      widget.dayMemos[DashboardConfig.dayKey(d)] ?? '';

  /// Elke regel begint met • ; na Enter komt meteen een nieuw bolletje.
  static String _normalizeMemoBullets(String text) {
    if (text.isEmpty) return text;
    final lines = text.split('\n');
    final out = <String>[];
    for (final line in lines) {
      final stripped = line.replaceFirst(RegExp(r'^[•●◦▪▫·]\s*'), '');
      out.add('$_bulletPrefix$stripped');
    }
    return out.join('\n');
  }

  static bool _isBlankMemo(String text) =>
      text.replaceAll(RegExp(r'[•●◦▪▫·\s]'), '').isEmpty;

  void _setField(String text) {
    _ignoreNextFieldSync = true;
    final normalized =
        _isBlankMemo(text) ? '' : _normalizeMemoBullets(text);
    _memoCtrl.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  void _ensureMemoBullet() {
    if (_memoCtrl.text.isNotEmpty) return;
    _memoCtrl.value = const TextEditingValue(
      text: _bulletPrefix,
      selection: TextSelection.collapsed(offset: _bulletPrefix.length),
    );
  }

  void _onMemoUnfocus() {
    if (!_isBlankMemo(_memoCtrl.text)) return;
    _setField('');
    if (!_dayMode) _persistGeneral('');
  }

  /// Houd cursor bij wanneer we • invoegen (typisch na Enter).
  void _applyMemoBulletsFromController() {
    final v = _memoCtrl.value;
    final raw = v.text;
    if (raw.isEmpty) return;
    final normalized = _normalizeMemoBullets(raw);
    if (normalized == raw) return;

    final oldSel = v.selection.isValid ? v.selection.baseOffset : raw.length;
    var newSel = oldSel + (normalized.length - raw.length);
    if (newSel < 0) newSel = 0;
    if (newSel > normalized.length) newSel = normalized.length;
    // Na Enter: cursor altijd ná het nieuwe bolletje.
    if (raw.endsWith('\n') && normalized.endsWith(_bulletPrefix)) {
      newSel = normalized.length;
    }

    _memoCtrl.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: newSel),
    );
  }

  void _persistGeneral(String text) {
    _generalMemo = text;
    widget.onMemoChanged(text);
  }

  void _returnToGeneralMemo() {
    _autoBack?.cancel();
    _memoDebounce?.cancel();
    _viewDay = null;
    _setField(_generalMemo);
  }

  /// Ruststand: afspraak van *vandaag* als die er is, anders boodschappenlijst.
  void _returnToDefaultMemo() {
    _autoBack?.cancel();
    _memoDebounce?.cancel();
    final now = _today;
    if (_isMarked(now)) {
      _viewDay = now;
      _month = DateTime(now.year, now.month);
      _setField(_dayNote(now));
      return;
    }
    _viewDay = null;
    _setField(_generalMemo);
  }

  void _restartAutoBack() {
    _autoBack?.cancel();
    if (_viewDay == null || _viewingTodayAppointment) return;
    _autoBack = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      setState(_returnToDefaultMemo);
    });
  }

  void _scheduleMidnightRefresh() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 2);
    _midnight = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(_returnToDefaultMemo);
      _scheduleMidnightRefresh();
    });
  }

  Future<void> _loadWeather() async {
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });
    try {
      final snap = await WeatherService.fetch(
        lat: widget.weatherLat,
        lon: widget.weatherLon,
      );
      if (!mounted) return;
      setState(() {
        _weather = snap;
        _weatherLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherError = '$e';
        _weatherLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final now = _dateOnly(widget.now ?? DateTime.now());
    _month = DateTime(now.year, now.month);
    _generalMemo = widget.memoNote.isEmpty
        ? ''
        : _normalizeMemoBullets(widget.memoNote);
    if (_isMarked(now)) {
      _viewDay = now;
      _memoCtrl = TextEditingController(
        text: _normalizeMemoBullets(_dayNote(now)),
      );
    } else {
      _memoCtrl = TextEditingController(text: _generalMemo);
    }
    _weatherAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeather());
    _scheduleMidnightRefresh();
  }

  @override
  void didUpdateWidget(covariant DashboardTopBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherLat != widget.weatherLat ||
        oldWidget.weatherLon != widget.weatherLon) {
      _loadWeather();
    }
    // Sync algemeen memo van buitenaf, nooit tijdens dagmodus.
    if (!_dayMode &&
        oldWidget.memoNote != widget.memoNote &&
        widget.memoNote != _generalMemo) {
      _generalMemo = widget.memoNote;
      _setField(_generalMemo);
    }
  }

  @override
  void dispose() {
    _memoDebounce?.cancel();
    _autoBack?.cancel();
    _midnight?.cancel();
    _memoCtrl.dispose();
    _weatherAnim.dispose();
    super.dispose();
  }

  void _selectDay(int day) {
    final now = _today;
    final d = _dateOnly(DateTime(_month.year, _month.month, day));

    // Tik op vandaag: afspraak van vandaag tonen als die er is, anders boodschappenlijst.
    if (d == now) {
      if (_isMarked(now)) {
        if (!_dayMode) {
          _memoDebounce?.cancel();
          _persistGeneral(_memoCtrl.text);
        }
        setState(() {
          _month = DateTime(now.year, now.month);
          _viewDay = now;
          _setField(_dayNote(now));
        });
        _autoBack?.cancel();
        return;
      }
      if (!_dayMode) {
        setState(() => _month = DateTime(now.year, now.month));
        return;
      }
      setState(() {
        _month = DateTime(now.year, now.month);
        _returnToGeneralMemo();
      });
      return;
    }

    // Bewaar vrij memo voordat het veld wisselt (nooit de dagtekst).
    if (!_dayMode) {
      _memoDebounce?.cancel();
      _persistGeneral(_memoCtrl.text);
    }

    setState(() {
      _viewDay = d;
      _setField(_dayNote(d));
    });
    _restartAutoBack();
  }

  /// ✓ bevestig dagnotitie → alleen cirkel-markering; terug naar vrij memo.
  void _confirmDay() {
    final day = _viewDay;
    if (day == null) return;
    final text = _memoCtrl.text.trimRight();
    if (text.trim().isEmpty) return;
    _memoDebounce?.cancel();
    widget.onDayMemoChanged(day, text);
    setState(() {
      if (day == _today) {
        _autoBack?.cancel();
        _viewDay = day;
        _setField(text);
      } else {
        _returnToDefaultMemo();
      }
    });
  }

  /// C: wis markering van bekeken dag.
  void _clearMark() {
    final day = _viewDay;
    if (day == null || !_isMarked(day)) return;
    _memoDebounce?.cancel();
    widget.onDayMemoChanged(day, '');
    final now = _today;
    setState(() {
      if (day == now) {
        // Afspraak van vandaag weg → boodschappenlijst.
        _returnToGeneralMemo();
      } else {
        _returnToDefaultMemo();
      }
    });
  }

  /// Prullenbak: wis alleen het vrije memoblok.
  void _clearGeneralMemo() {
    _memoDebounce?.cancel();
    _persistGeneral('');
    if (!_dayMode) {
      _setField('');
    }
    setState(() {});
  }

  void _onMemoChanged(String text) {
    if (_ignoreNextFieldSync) {
      _ignoreNextFieldSync = false;
      return;
    }
    _applyMemoBulletsFromController();
    final current = _memoCtrl.text;
    final persist = _isBlankMemo(current) ? '' : current;
    if (_dayMode) {
      if (!_viewingTodayAppointment) _restartAutoBack();
      setState(() {}); // ✓ actief maken
      return; // dagtekst NOOIT naar algemeen memo
    }
    _generalMemo = persist;
    _memoDebounce?.cancel();
    _memoDebounce = Timer(const Duration(milliseconds: 350), () {
      widget.onMemoChanged(persist);
    });
  }

  void _goTodayHeader() {
    final now = _today;
    setState(() {
      _month = DateTime(now.year, now.month);
      _returnToDefaultMemo();
    });
  }

  List<WeatherSlot> _forecastSlots() {
    final w = _weather;
    if (w == null) return const [];
    if (_hourly) return w.hourly.take(12).toList();
    final days = w.daily;
    if (days.length <= 1) return days.take(5).toList();
    return days.skip(1).take(5).toList();
  }

  /// Eigen vector-weericonenset (`assets/weather/*.svg`). [night] bepaalt de
  /// dag/nacht-variant voor helder/bewolkt; alleen relevant voor "vandaag"
  /// (de 6-dagen/uur-strook toont altijd de dagvariant).
  WeatherGlyph _glyph(int code, {bool night = false}) {
    switch (WeatherService.iconKind(code)) {
      case IconKind.clear:
        return night ? WeatherGlyph.nightClear : WeatherGlyph.daySunny;
      case IconKind.cloudy:
        return night ? WeatherGlyph.nightAltCloudy : WeatherGlyph.cloudy;
      case IconKind.fog:
        return WeatherGlyph.cloud;
      case IconKind.rain:
        return WeatherGlyph.rain;
      case IconKind.snow:
        return WeatherGlyph.snow;
      case IconKind.storm:
        return WeatherGlyph.thunderstormRain;
    }
  }

  bool _isNight(DateTime at) {
    final w = _weather;
    if (w?.sunrise != null && w?.sunset != null) {
      return at.isBefore(w!.sunrise!) || at.isAfter(w.sunset!);
    }
    return at.hour < 6 || at.hour >= 21;
  }

  String _fmtSun(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = _dateOnly(widget.now ?? DateTime.now());
    final w = _weather;
    final code = w?.weatherCode ?? 3;
    final slots = _forecastSlots();
    final canConfirm = _dayMode && !_isBlankMemo(_memoCtrl.text);
    final canClearMark = _dayMode && _isMarked(_viewDay!);

    return SizedBox(
      height: bandHeight,
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: GlassPanel(
              fillColor: _frame,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _SimpleEffects(
                        weatherCode: code,
                        animation: _weatherAnim,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TodayRow(
                          loading: _weatherLoading,
                          error: _weatherError,
                          weather: w,
                          placeName: widget.placeName,
                          glyph: _glyph(code, night: _isNight(widget.now ?? DateTime.now())),
                          rainProbability:
                              w != null && w.daily.isNotEmpty ? w.daily.first.precipProbability : null,
                          fmtSun: _fmtSun,
                          onRefresh: _loadWeather,
                          hourly: _hourly,
                          onToggleHourly: () => setState(() => _hourly = !_hourly),
                          onPlaceTap: widget.onPlaceTap,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: w == null || slots.isEmpty
                              ? const Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Text('—', style: TextStyle(color: Colors.white24)),
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0; i < slots.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 2),
                                      Expanded(
                                        child: _ForecastSlotTile(
                                          slot: slots[i],
                                          glyph: _glyph(slots[i].weatherCode),
                                          hourly: _hourly,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 9,
            child: GlassPanel(
              fillColor: _frame,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _MonthCalendar(
                      month: _month,
                      today: now,
                      clock: widget.now ?? DateTime.now(),
                      selected: _viewDay,
                      isMarked: _isMarked,
                      todayColor: _todayMark,
                      onPrev: () => setState(() =>
                          _month = DateTime(_month.year, _month.month - 1)),
                      onNext: () => setState(() =>
                          _month = DateTime(_month.year, _month.month + 1)),
                      onToday: _goTodayHeader,
                      onSelectDay: _selectDay,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: _MemoPane(
                      controller: _memoCtrl,
                      viewDay: _viewDay,
                      canConfirm: canConfirm,
                      canClearMark: canClearMark,
                      onChanged: _onMemoChanged,
                      onConfirm: _confirmDay,
                      onClearMark: _clearMark,
                      onClearMemo: _clearGeneralMemo,
                      onEnsureBullet: _ensureMemoBullet,
                      onUnfocus: _onMemoUnfocus,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.loading,
    required this.error,
    required this.weather,
    required this.placeName,
    required this.glyph,
    required this.rainProbability,
    required this.fmtSun,
    required this.onRefresh,
    required this.hourly,
    required this.onToggleHourly,
    this.onPlaceTap,
  });

  final bool loading;
  final String? error;
  final WeatherSnapshot? weather;
  final String placeName;
  final WeatherGlyph glyph;
  final int? rainProbability;
  final String Function(DateTime?) fmtSun;
  final VoidCallback onRefresh;
  final bool hourly;
  final VoidCallback onToggleHourly;
  final VoidCallback? onPlaceTap;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onPlaceTap,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onPlaceTap != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.place_outlined,
                            size: 14, color: Colors.white70),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Text(
              hourly ? 'Uur' : '5 dagen',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            _TinyIconBtn(
              icon: hourly ? Icons.calendar_view_week : Icons.schedule,
              onTap: onToggleHourly,
            ),
            _TinyIconBtn(icon: Icons.refresh, onTap: onRefresh),
          ],
        ),
        const SizedBox(height: 2),
        if (loading && w == null)
          const Text('Weer laden…', style: TextStyle(color: Colors.white54, fontSize: 12))
        else if (error != null && w == null)
          Text(
            error!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
          )
        else if (w == null)
          const Text('Geen weer', style: TextStyle(color: Colors.white54, fontSize: 12))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeatherIcon(glyph, size: 42, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                '${w.temperatureC.round()}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      [
                        if (w.feelsLikeC != null) 'Voelt ${w.feelsLikeC!.round()}°',
                        'Wind ${w.windKmh.round()}',
                        if (rainProbability != null) 'Rain $rainProbability%',
                        if (w.humidity != null) 'humidity ${w.humidity}%',
                        if (w.sunrise != null || w.sunset != null)
                          'Zon ${fmtSun(w.sunrise)} / ${fmtSun(w.sunset)}',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.clock,
    required this.selected,
    required this.isMarked,
    required this.todayColor,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime today;
  final DateTime clock;
  final DateTime? selected;
  final bool Function(DateTime day) isMarked;
  final Color todayColor;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<int> onSelectDay;

  static const _monthsEn = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];
  static const _dow = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _sunday = Color(0xFFC38578);

  /// Federale Belgische feestdagen (geen kalenderlogica — alleen kleur).
  static bool _isBelgianHoliday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.month == 1 && day.day == 1) return true;
    if (day.month == 5 && day.day == 1) return true;
    if (day.month == 7 && day.day == 21) return true;
    if (day.month == 8 && day.day == 15) return true;
    if (day.month == 11 && day.day == 1) return true;
    if (day.month == 11 && day.day == 11) return true;
    if (day.month == 12 && day.day == 25) return true;
    final easter = _easterSunday(d.year);
    if (_sameDay(day, easter.add(const Duration(days: 1)))) return true;
    if (_sameDay(day, easter.add(const Duration(days: 39)))) return true;
    if (_sameDay(day, easter.add(const Duration(days: 50)))) return true;
    return false;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  static const _stampGray = Color(0xFFB4B8BE);

  static String _dateStamp(DateTime t) {
    final wd = _dow[t.weekday - 1];
    final mo = _monthsEn[t.month - 1];
    return '$wd ${t.day} $mo ${t.year}';
  }

  static String _timeStamp(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final startCol = first.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <int?>[
      for (var i = 0; i < startCol; i++) null,
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final rows = cells.length ~/ 7;

    final currentMonth =
        month.year == today.year && month.month == today.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: onPrev,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Icon(Icons.chevron_left, size: 16, color: Colors.white54),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onToday,
                  child: currentMonth
                      ? Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _dateStamp(clock),
                                style: const TextStyle(
                                  color: _stampGray,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              TextSpan(
                                text: '    ${_timeStamp(clock)}',
                                style: const TextStyle(
                                  color: _stampGray,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          '${_monthsEn[month.month - 1]} ${month.year}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _stampGray,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
                ),
              ),
              InkWell(
                onTap: onNext,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Icon(Icons.chevron_right, size: 16, color: Colors.white54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Row(
            children: [
              for (var i = 0; i < _dow.length; i++)
                Expanded(
                  child: Text(
                    _dow[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i == 6 ? _sunday : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final cellH = c.maxHeight / rows;
                return Column(
                  children: [
                    for (var r = 0; r < rows; r++)
                      SizedBox(
                        height: cellH,
                        child: Row(
                          children: [
                            for (var col = 0; col < 7; col++)
                              Expanded(child: _dayCell(cells[r * 7 + col], cellH)),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int? day, double h) {
    if (day == null) return const SizedBox.shrink();
    final date = DateTime(month.year, month.month, day);
    final isToday = today.year == date.year && today.month == date.month && today.day == date.day;
    final isSunday = date.weekday == DateTime.sunday;
    final isHoliday = _isBelgianHoliday(date);
    final isSelected = selected != null &&
        selected!.year == date.year &&
        selected!.month == date.month &&
        selected!.day == date.day;
    final marked = isMarked(date);

    // Vandaag wint. Zondag + Belgische feestdag = zelfde terracotta.
    final Color textColor;
    if (isToday) {
      textColor = Colors.white;
    } else if (isSunday || isHoliday) {
      textColor = _sunday;
    } else {
      textColor = Colors.white70;
    }
    final size = h - 2;

    Decoration? decoration;
    if (isToday) {
      decoration = BoxDecoration(
        color: todayColor,
        shape: BoxShape.circle,
      );
    } else if (marked) {
      // Gewone, strakke cirkel (fijne witte rand) — geen gloed/kleur.
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1.2,
        ),
      );
    } else if (isSelected) {
      decoration = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      );
    }

    return InkWell(
      onTap: () => onSelectDay(day),
      borderRadius: BorderRadius.circular(8),
      child: Center(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: decoration,
          child: Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoPane extends StatefulWidget {
  const _MemoPane({
    required this.controller,
    required this.viewDay,
    required this.canConfirm,
    required this.canClearMark,
    required this.onChanged,
    required this.onConfirm,
    required this.onClearMark,
    required this.onClearMemo,
    required this.onEnsureBullet,
    required this.onUnfocus,
  });

  final TextEditingController controller;
  final DateTime? viewDay;
  final bool canConfirm;
  final bool canClearMark;
  final ValueChanged<String> onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onClearMark;
  final VoidCallback onClearMemo;
  final VoidCallback onEnsureBullet;
  final VoidCallback onUnfocus;

  @override
  State<_MemoPane> createState() => _MemoPaneState();
}

class _MemoPaneState extends State<_MemoPane> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      widget.onEnsureBullet();
    } else {
      widget.onUnfocus();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  static const _monthsNl = [
    'jan', 'feb', 'mrt', 'apr', 'mei', 'jun',
    'jul', 'aug', 'sep', 'okt', 'nov', 'dec',
  ];

  @override
  Widget build(BuildContext context) {
    final dayMode = widget.viewDay != null;
    final label = dayMode
        ? '  ${widget.viewDay!.day} ${_monthsNl[widget.viewDay!.month - 1]}'
        : '  Memo';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Neo.radius, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (dayMode) ...[
                Tooltip(
                  message: 'Dagnotitie bevestigen',
                  child: InkWell(
                    onTap: widget.canConfirm ? widget.onConfirm : null,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.canConfirm ? const Color(0xFF66BB6A) : Colors.white24,
                          width: 1.3,
                        ),
                        color: widget.canConfirm
                            ? const Color(0xFF66BB6A).withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: widget.canConfirm ? const Color(0xFF66BB6A) : Colors.white24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Tooltip(
                  message: 'Markering wissen',
                  child: InkWell(
                    onTap: widget.canClearMark ? widget.onClearMark : null,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.canClearMark ? AppColors.amber : Colors.white24,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        'C',
                        style: TextStyle(
                          color: widget.canClearMark ? AppColors.amber : Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Tooltip(
                message: 'Memo wissen',
                child: InkWell(
                  onTap: widget.onClearMemo,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.delete_outline, size: 18, color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              onTap: widget.onEnsureBullet,
              maxLines: null,
              expands: true,
              showCursor: _focus.hasFocus,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              cursorColor: Neo.accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: '',
                filled: true,
                fillColor: const Color(0x08FFFFFF),
                contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyIconBtn extends StatelessWidget {
  const _TinyIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, size: 14, color: Colors.white54),
      ),
    );
  }
}

class _ForecastSlotTile extends StatelessWidget {
  const _ForecastSlotTile({
    required this.slot,
    required this.glyph,
    required this.hourly,
  });

  final WeatherSlot slot;
  final WeatherGlyph glyph;
  final bool hourly;

  @override
  Widget build(BuildContext context) {
    // Enkel rain% — zelfde tekstkleur, geen humidity, geen blauwe grafiekbalk.
    final rainPct = slot.precipProbability.clamp(0, 100);
    final high = slot.tempMaxC ?? slot.tempC;
    final low = slot.tempMinC;
    return SizedBox.expand(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            slot.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.0),
          ),
          WeatherIcon(glyph, size: 16, color: Colors.white70),
          Text(
            hourly ? '${slot.tempC.round()}°' : '${high.round()}°',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.0,
            ),
          ),
          if (!hourly && low != null)
            Text(
              '${low.round()}°',
              style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.0),
            ),
          if (!hourly)
            Text(
              'rain $rainPct%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
        ],
      ),
    );
  }
}

class _SimpleEffects extends StatelessWidget {
  const _SimpleEffects({required this.weatherCode, required this.animation});
  final int weatherCode;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final kind = WeatherService.iconKind(weatherCode);
    if (kind != IconKind.rain && kind != IconKind.storm && kind != IconKind.snow) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => CustomPaint(
        painter: _RainSnowPainter(
          kind: kind,
          weatherCode: weatherCode,
          t: animation.value,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RainSnowPainter extends CustomPainter {
  _RainSnowPainter({
    required this.kind,
    required this.weatherCode,
    required this.t,
  });
  final IconKind kind;
  final int weatherCode;
  final double t;

  /// WMO: lichte mistregen/regen → weinig druppels; gietende regen → dicht gordijn.
  _RainLook get _look {
    final code = weatherCode;
    // Gietende / hevige buien / onweer met zware regen
    if (code == 65 || code == 67 || code == 82 || code >= 96) {
      return const _RainLook(count: 70, stroke: 2.0, length: 16, alpha: 0xAA, speed: 1.8, slant: 3.5);
    }
    // Matige regen / stevige buien / onweer
    if (code == 63 || code == 81 || code == 95) {
      return const _RainLook(count: 42, stroke: 1.6, length: 12, alpha: 0x88, speed: 1.35, slant: 2.5);
    }
    // Lichte regen / motregen / lichte buien
    if ((code >= 51 && code <= 67) || code == 80 || kind == IconKind.rain) {
      return const _RainLook(count: 22, stroke: 1.4, length: 9, alpha: 0x77, speed: 1.0, slant: 1.8);
    }
    // Storm zonder zware regen-code
    if (kind == IconKind.storm) {
      return const _RainLook(count: 50, stroke: 1.7, length: 14, alpha: 0x90, speed: 1.55, slant: 3.0);
    }
    return const _RainLook(count: 22, stroke: 1.4, length: 9, alpha: 0x77, speed: 1.0, slant: 1.8);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    if (kind == IconKind.rain || kind == IconKind.storm) {
      final look = _look;
      final paint = Paint()
        ..color = const Color(0xFF4FC3F7).withValues(alpha: look.alpha / 255)
        ..strokeWidth = look.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < look.count; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = (rnd.nextDouble() * size.height + t * size.height * look.speed) % size.height;
        canvas.drawLine(
          Offset(x, y),
          Offset(x - look.slant, y + look.length),
          paint,
        );
      }
    } else if (kind == IconKind.snow) {
      final paint = Paint()..color = const Color(0x88FFFFFF);
      for (var i = 0; i < 18; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = (rnd.nextDouble() * size.height + t * size.height * 0.55) % size.height;
        canvas.drawCircle(Offset(x, y), 1.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainSnowPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.kind != kind ||
      oldDelegate.weatherCode != weatherCode;
}

class _RainLook {
  const _RainLook({
    required this.count,
    required this.stroke,
    required this.length,
    required this.alpha,
    required this.speed,
    required this.slant,
  });
  final int count;
  final double stroke;
  final double length;
  final int alpha;
  final double speed;
  final double slant;
}

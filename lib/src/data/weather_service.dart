import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherSlot {
  const WeatherSlot({
    required this.label,
    required this.weatherCode,
    required this.tempC,
    this.tempMaxC,
    this.tempMinC,
    this.precipitationMm = 0,
    this.precipProbability = 0,
    this.humidity,
  });

  final String label;
  final int weatherCode;
  /// Point temperature (hourly) or mid of day range.
  final double tempC;
  final double? tempMaxC;
  final double? tempMinC;
  final double precipitationMm;
  final int precipProbability;
  /// Gemiddelde/relatieve vochtigheid (%), indien beschikbaar.
  final int? humidity;
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.windKmh,
    required this.weatherCode,
    required this.description,
    this.feelsLikeC,
    this.humidity,
    this.daily = const [],
    this.hourly = const [],
    this.sunrise,
    this.sunset,
  });

  final double temperatureC;
  final double windKmh;
  final int weatherCode;
  final String description;
  final double? feelsLikeC;
  final int? humidity;
  final List<WeatherSlot> daily;
  final List<WeatherSlot> hourly;
  final DateTime? sunrise;
  final DateTime? sunset;

  /// Back-compat for older UI.
  List<WeatherSlot> get days => daily;
}

/// Open-Meteo (no API key) — HA-style forecast data.
class WeatherService {
  static Future<WeatherSnapshot> fetch({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current':
          'temperature_2m,weather_code,wind_speed_10m,apparent_temperature,relative_humidity_2m',
      'hourly':
          'temperature_2m,weather_code,precipitation,precipitation_probability',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,relative_humidity_2m_mean,sunrise,sunset',
      'forecast_days': '7',
      'timezone': 'auto',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw StateError('Weather HTTP ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;

    final daily = json['daily'] as Map<String, dynamic>? ?? {};
    final dTimes = _strList(daily['time']);
    final dCodes = _intList(daily['weather_code']);
    final dMax = _dblList(daily['temperature_2m_max']);
    final dMin = _dblList(daily['temperature_2m_min']);
    final dPrecip = _dblList(daily['precipitation_sum']);
    final dProb = _intList(daily['precipitation_probability_max']);
    final dHum = _intList(daily['relative_humidity_2m_mean']);
    final sunrises = _strList(daily['sunrise']);
    final sunsets = _strList(daily['sunset']);

    final daySlots = <WeatherSlot>[];
    for (var i = 0; i < dTimes.length && i < 7; i++) {
      final dt = DateTime.tryParse(dTimes[i]);
      final label = dt == null
          ? dTimes[i]
          : const ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][dt.weekday % 7];
      final max = i < dMax.length ? dMax[i] : 0.0;
      final min = i < dMin.length ? dMin[i] : 0.0;
      daySlots.add(
        WeatherSlot(
          label: label,
          weatherCode: i < dCodes.length ? dCodes[i] : 0,
          tempC: (max + min) / 2,
          tempMaxC: max,
          tempMinC: min,
          precipitationMm: i < dPrecip.length ? dPrecip[i] : 0,
          precipProbability: i < dProb.length ? dProb[i] : 0,
          humidity: i < dHum.length ? dHum[i] : null,
        ),
      );
    }

    final hourly = json['hourly'] as Map<String, dynamic>? ?? {};
    final hTimes = _strList(hourly['time']);
    final hTemps = _dblList(hourly['temperature_2m']);
    final hCodes = _intList(hourly['weather_code']);
    final hPrecip = _dblList(hourly['precipitation']);
    final hProb = _intList(hourly['precipitation_probability']);
    final now = DateTime.now();
    final hourSlots = <WeatherSlot>[];
    for (var i = 0; i < hTimes.length && hourSlots.length < 24; i++) {
      final dt = DateTime.tryParse(hTimes[i]);
      if (dt == null || dt.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      hourSlots.add(
        WeatherSlot(
          label: '${dt.hour.toString().padLeft(2, '0')}u',
          weatherCode: i < hCodes.length ? hCodes[i] : 0,
          tempC: i < hTemps.length ? hTemps[i] : 0,
          precipitationMm: i < hPrecip.length ? hPrecip[i] : 0,
          precipProbability: i < hProb.length ? hProb[i] : 0,
        ),
      );
    }

    return WeatherSnapshot(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      windKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      weatherCode: code,
      description: describe(code),
      feelsLikeC: (current['apparent_temperature'] as num?)?.toDouble(),
      humidity: (current['relative_humidity_2m'] as num?)?.toInt(),
      daily: daySlots,
      hourly: hourSlots,
      sunrise: sunrises.isNotEmpty ? DateTime.tryParse(sunrises.first) : null,
      sunset: sunsets.isNotEmpty ? DateTime.tryParse(sunsets.first) : null,
    );
  }

  static List<String> _strList(dynamic v) =>
      (v as List? ?? const []).map((e) => e.toString()).toList();

  static List<int> _intList(dynamic v) =>
      (v as List? ?? const []).map((e) => (e as num).toInt()).toList();

  static List<double> _dblList(dynamic v) =>
      (v as List? ?? const []).map((e) => (e as num).toDouble()).toList();

  static String describe(int code) {
    if (code == 0) return 'Helder';
    if (code <= 3) return 'Bewolkt';
    if (code <= 48) return 'Mist';
    if (code == 51 || code == 53 || code == 56) return 'Motregen';
    if (code == 55 || code == 57) return 'Stevige motregen';
    if (code == 61 || code == 66 || code == 80) return 'Lichte regen';
    if (code == 63 || code == 81) return 'Regen';
    if (code == 65 || code == 67 || code == 82) return 'Gietende regen';
    if (code <= 67) return 'Regen';
    if (code <= 77) return 'Sneeuw';
    if (code <= 82) return 'Buien';
    if (code <= 99) return 'Onweer';
    return 'Onbekend';
  }

  static IconKind iconKind(int code) {
    if (code == 0) return IconKind.clear;
    if (code <= 3) return IconKind.cloudy;
    if (code <= 48) return IconKind.fog;
    if (code <= 67) return IconKind.rain;
    if (code <= 77) return IconKind.snow;
    if (code <= 82) return IconKind.rain;
    return IconKind.storm;
  }
}

enum IconKind { clear, cloudy, fog, rain, snow, storm }

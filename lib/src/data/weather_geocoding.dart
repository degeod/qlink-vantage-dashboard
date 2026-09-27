import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherPlace {
  const WeatherPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1,
    this.country,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? admin1;
  final String? country;

  String get label {
    final parts = <String>[name];
    if (admin1 != null && admin1!.isNotEmpty) parts.add(admin1!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }
}

class WeatherGeocoding {
  /// Open-Meteo geocoding (no API key).
  static Future<List<WeatherPlace>> search(String query, {int count = 6}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '$count',
      'language': 'nl',
      'format': 'json',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return const [];
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'] as List? ?? const [];
    return [
      for (final e in results)
        if (e is Map)
          WeatherPlace(
            name: e['name']?.toString() ?? q,
            latitude: (e['latitude'] as num).toDouble(),
            longitude: (e['longitude'] as num).toDouble(),
            admin1: e['admin1']?.toString(),
            country: e['country']?.toString(),
          ),
    ];
  }

  static Future<WeatherPlace?> reverse(double lat, double lon) async {
    // Open-Meteo has no reverse API; approximate via nearby search using lat/lon as name fails.
    // Use BigDataCloud free reverse (no key) as lightweight fallback.
    final uri = Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'localityLanguage': 'nl',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return WeatherPlace(name: 'Mijn locatie', latitude: lat, longitude: lon);
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final city = (json['city'] ?? json['locality'] ?? json['principalSubdivision'] ?? 'Mijn locatie')
          .toString();
      final country = json['countryName']?.toString();
      return WeatherPlace(
        name: city,
        latitude: lat,
        longitude: lon,
        admin1: json['principalSubdivision']?.toString(),
        country: country,
      );
    } catch (_) {
      return WeatherPlace(name: 'Mijn locatie', latitude: lat, longitude: lon);
    }
  }
}

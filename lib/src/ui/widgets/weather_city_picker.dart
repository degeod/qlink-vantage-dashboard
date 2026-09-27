import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WeatherCity {
  const WeatherCity(this.name, this.lat, this.lon);
  final String name;
  final double lat;
  final double lon;
}

/// Preset steden voor de Dashboard weer-balk (BE kust + grootsteden).
const kWeatherCities = <WeatherCity>[
  WeatherCity('Zeebrugge', 51.3306, 3.2061),
  WeatherCity('Brugge', 51.2093, 3.2247),
  WeatherCity('Knokke-Heist', 51.3511, 3.2875),
  WeatherCity('Oostende', 51.2300, 2.9167),
  WeatherCity('Blankenberge', 51.3131, 3.1323),
  WeatherCity('Gent', 51.0543, 3.7174),
  WeatherCity('Antwerpen', 51.2194, 4.4025),
  WeatherCity('Brussel', 50.8503, 4.3517),
  WeatherCity('Kortrijk', 50.8270, 3.2649),
  WeatherCity('Leuven', 50.8798, 4.7005),
];

Future<WeatherCity?> showWeatherCityPicker(
  BuildContext context, {
  String? currentName,
}) {
  return showModalBottomSheet<WeatherCity>(
    context: context,
    backgroundColor: AppColors.charcoalElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Weer-locatie',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kies een stad voor de Dashboard weer-balk',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: kWeatherCities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (_, i) {
                    final c = kWeatherCities[i];
                    final selected = currentName != null &&
                        currentName.toLowerCase() == c.name.toLowerCase();
                    return ListTile(
                      dense: true,
                      title: Text(
                        c.name,
                        style: TextStyle(
                          color: selected ? AppColors.amber : Colors.white,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check, color: AppColors.amber, size: 20)
                          : null,
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

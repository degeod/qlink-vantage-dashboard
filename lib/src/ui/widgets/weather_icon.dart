import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Eigen vector-weericonenset (`assets/weather/*.svg`, dunne "flat line"
/// stijl). Elke glyph is een silhouet — altijd getekend in de opgegeven
/// [WeatherIcon.color], dus nooit een eigen "gekleurde" variant.
enum WeatherGlyph {
  daySunny,
  nightClear,
  cloud,
  cloudy,
  dayCloudy,
  nightAltCloudy,
  rain,
  snow,
  thunderstorm,
  thunderstormRain,
}

const Map<WeatherGlyph, String> _weatherGlyphAsset = {
  WeatherGlyph.daySunny: 'assets/weather/day_sunny.svg',
  WeatherGlyph.nightClear: 'assets/weather/night_clear.svg',
  WeatherGlyph.cloud: 'assets/weather/cloud.svg',
  WeatherGlyph.cloudy: 'assets/weather/cloudy.svg',
  WeatherGlyph.dayCloudy: 'assets/weather/day_cloudy.svg',
  WeatherGlyph.nightAltCloudy: 'assets/weather/night_alt_cloudy.svg',
  WeatherGlyph.rain: 'assets/weather/rain.svg',
  WeatherGlyph.snow: 'assets/weather/snow.svg',
  WeatherGlyph.thunderstorm: 'assets/weather/thunderstorm.svg',
  WeatherGlyph.thunderstormRain: 'assets/weather/thunderstorm_rain.svg',
};

/// Eén weericoon, altijd monochroom geverfd in [color] (zelfde kleur als de
/// omringende tekst/cijfers).
class WeatherIcon extends StatelessWidget {
  const WeatherIcon(this.glyph, {super.key, required this.size, required this.color});

  final WeatherGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _weatherGlyphAsset[glyph]!,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

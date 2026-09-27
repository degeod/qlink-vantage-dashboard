import 'package:flutter/material.dart';

import '../device_icons.dart';

/// Renders a load/macro icon: wit-getinte PNG of Material icon.
class DeviceIconView extends StatelessWidget {
  const DeviceIconView({
    super.key,
    required this.typeId,
    required this.isOn,
    this.size = 24,
    this.color,
    this.inset = 0.08,
    /// PNG altijd wit op Remote/Dashboard (negeert [color]).
    this.whiteAsset = false,
  });

  final String? typeId;
  final bool isOn;
  final double size;
  final Color? color;
  final double inset;
  final bool whiteAsset;

  @override
  Widget build(BuildContext context) {
    final type = DeviceIcons.byId(typeId);
    final asset = type.asset;
    if (asset != null && asset.isNotEmpty) {
      final pad = size * inset;
      final inner = size - pad * 2;
      final cache = (inner * MediaQuery.devicePixelRatioOf(context)).round().clamp(32, 128);
      final tint = whiteAsset
          ? (isOn ? Colors.white : Colors.white.withValues(alpha: 0.58))
          : (color ?? Colors.white);
      final effective = isOn ? tint : tint.withValues(alpha: 0.55);
      return SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(effective, BlendMode.srcIn),
            child: Image.asset(
              asset,
              width: inner,
              height: inner,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              cacheWidth: cache,
              cacheHeight: cache,
            ),
          ),
        ),
      );
    }
    return Icon(
      DeviceIcons.iconFor(typeId, isOn: isOn),
      size: size,
      color: color,
    );
  }
}

/// Schermgrootte +5% t.o.v. vorige Remote/Dashboard-waarden.
double deviceIconRemoteSize(double base) => base * 1.05;

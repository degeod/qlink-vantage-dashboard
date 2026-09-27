import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../state/dashboard_config.dart';
import 'standby_analog_clock.dart';

/// Muur-tablet: na 3 min geen aanraking → standby.
/// Zwart scherm met analoge klok in het midden; backlight gedimd (niet 0,
/// anders is de klok onzichtbaar). Het venster blijft wakker (wakelock)
/// zodat de camera beweging kan zien — écht Android-slaap zou de camera stoppen.
/// Camera alleen in standby → beweging of tik → wakker + [onWake].
class WallTabletPresence extends StatefulWidget {
  const WallTabletPresence({
    super.key,
    required this.enabled,
    required this.sensitivity,
    required this.onWake,
    required this.child,
  });

  final bool enabled;
  /// 0 = minst gevoelig, 100 = meest gevoelig.
  final int sensitivity;
  final Future<void> Function() onWake;
  final Widget child;

  @override
  State<WallTabletPresence> createState() => _WallTabletPresenceState();
}

class _WallTabletPresenceState extends State<WallTabletPresence> with WidgetsBindingObserver {
  static const _display = MethodChannel('vantage/display');
  static const _standbyBacklight = 0.16;

  Timer? _idle;
  bool _standby = false;
  bool _waking = false;

  CameraController? _cam;
  bool _streamOn = false;
  Uint8List? _prevY;
  int _frameSkip = 0;
  int _motionHits = 0;
  DateTime _armedAt = DateTime.fromMillisecondsSinceEpoch(0);

  double get _t => (widget.sensitivity.clamp(0, 100)) / 100.0;

  double get _meanThreshold => 14.0 - 11.5 * _t;

  double get _changeRatioThreshold => 0.048 - 0.034 * _t;

  int get _pixelDelta => (18 - 12 * _t).round().clamp(4, 24);

  int get _hitsNeeded => _t >= 0.85 ? 1 : (_t >= 0.4 ? 2 : 3);

  int get _frameMod => _t >= 0.65 ? 2 : 3;

  Duration get _armDelay => Duration(milliseconds: (2200 - 900 * _t).round());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncMode();
  }

  @override
  void didUpdateWidget(covariant WallTabletPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _syncMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle?.cancel();
    unawaited(_stopCamera());
    unawaited(_restoreSystemUi());
    unawaited(_setBacklight(null));
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    if (state == AppLifecycleState.resumed) {
      _bumpActivity();
      if (_standby) unawaited(_startCamera());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_stopCamera());
    }
  }

  Future<void> _syncMode() async {
    if (widget.enabled) {
      await WakelockPlus.enable();
      _bumpActivity();
    } else {
      _idle?.cancel();
      _idle?.cancel();
      if (_standby && mounted) setState(() => _standby = false);
      await _stopCamera();
      await _restoreSystemUi();
      await _setBacklight(null);
      await WakelockPlus.disable();
    }
  }

  void _bumpActivity() {
    if (!widget.enabled) return;
    _idle?.cancel();
    if (_standby) {
      // Touch during standby also wakes.
      unawaited(_wake(fromTouch: true));
      return;
    }
    _idle = Timer(DashboardConfig.wallStandbyTimeout, _enterStandby);
  }

  Future<void> _enterStandby() async {
    if (!mounted || !widget.enabled || _standby) return;
    setState(() {
      _standby = true;
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await _setBacklight(_standbyBacklight);
    _armedAt = DateTime.now().add(_armDelay);
    _motionHits = 0;
    await _startCamera();
  }

  Future<void> _restoreSystemUi() async {
    // Fullscreen aanhouden na wakker worden: balken blijven verborgen.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _wake({bool fromTouch = false}) async {
    if (_waking) return;
    _waking = true;
    try {
      await _stopCamera();
      await _setBacklight(null);
      await _restoreSystemUi();
      if (mounted) {
        setState(() {
          _standby = false;
        });
      }
      try {
        await widget.onWake();
      } catch (_) {}
      _bumpActivity();
    } finally {
      _waking = false;
    }
  }

  /// `0..1` = vensterhelderheid. `null` = systeemhelderheid terug.
  Future<void> _setBacklight(double? value) async {
    try {
      await _display.invokeMethod<void>('setBrightness', {
        'value': value ?? -1.0,
      });
    } catch (_) {}
  }

  Future<void> _startCamera() async {
    if (_cam != null) return;
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      return;
    }
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        return;
      }
      CameraDescription chosen = cams.first;
      for (final c in cams) {
        if (c.lensDirection == CameraLensDirection.front) {
          chosen = c;
          break;
        }
      }
      final ctrl = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();
      if (!mounted || !_standby) {
        await ctrl.dispose();
        return;
      }
      _cam = ctrl;
      _prevY = null;
      _frameSkip = 0;
      _motionHits = 0;
      await ctrl.startImageStream(_onFrame);
      _streamOn = true;
      if (mounted) setState(() {});
    } catch (_) {
      await _stopCamera();
    }
  }

  Future<void> _stopCamera() async {
    final ctrl = _cam;
    _cam = null;
    _prevY = null;
    if (ctrl == null) return;
    try {
      if (_streamOn) {
        await ctrl.stopImageStream();
      }
    } catch (_) {}
    _streamOn = false;
    try {
      await ctrl.dispose();
    } catch (_) {}
  }

  void _onFrame(CameraImage image) {
    if (!_standby || _waking) return;
    if (DateTime.now().isBefore(_armedAt)) return;
    // Sample frames — interval depends on sensitivity.
    _frameSkip = (_frameSkip + 1) % _frameMod;
    if (_frameSkip != 0) return;

    final plane = image.planes.first;
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final h = image.height;
    final w = image.width;
    const grid = 28;
    final sample = Uint8List(grid * grid);
    var si = 0;
    for (var gy = 0; gy < grid; gy++) {
      final y = (gy * (h - 1) / (grid - 1)).round().clamp(0, h - 1);
      for (var gx = 0; gx < grid; gx++) {
        final x = (gx * (w - 1) / (grid - 1)).round().clamp(0, w - 1);
        final idx = y * rowStride + x;
        sample[si++] = idx < bytes.length ? bytes[idx] : 0;
      }
    }

    final prev = _prevY;
    _prevY = sample;
    if (prev == null || prev.length != sample.length) {
      _motionHits = 0;
      return;
    }

    var absSum = 0;
    var changed = 0;
    final n = sample.length;
    for (var i = 0; i < n; i++) {
      final d = (sample[i] - prev[i]).abs();
      absSum += d;
      if (d >= _pixelDelta) changed++;
    }
    final mean = absSum / n;
    final ratio = changed / n;
    final motion = mean >= _meanThreshold || ratio >= _changeRatioThreshold;

    if (motion) {
      _motionHits++;
      if (_motionHits >= _hitsNeeded) {
        _motionHits = 0;
        unawaited(_wake());
      }
    } else {
      _motionHits = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (widget.enabled) _bumpActivity();
      },
      child: widget.child,
    );

    if (!widget.enabled) return body;

    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        // Hidden but real-size preview — 1×1 was te klein op sommige tablets.
        if (_standby && _cam != null && _cam!.value.isInitialized)
          Positioned(
            left: 0,
            top: 0,
            width: 160,
            height: 120,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0,
                child: CameraPreview(_cam!),
              ),
            ),
          ),
        // Zwart + analoge klok midden. Camera blijft actief op de achtergrond.
        if (_standby)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _wake(fromTouch: true),
              child: const ColoredBox(
                color: Colors.black,
                child: Center(child: StandbyAnalogClock()),
              ),
            ),
          ),
      ],
    );
  }
}

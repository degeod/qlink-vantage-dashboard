import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef LineHandler = void Function(String line);

/// TCP VCommand client for Vantage IPE / Master (port 3041).
///
/// Frames on CR/LF. Sends WebPoint-style hashed verbs where observed
/// (`VLS#`, `VGB#`, `VSW#`) and plain `VLB` for loads.
class VCommandClient {
  Socket? _socket;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  final StreamController<String> _lines = StreamController<String>.broadcast();
  final StreamController<String> _log = StreamController<String>.broadcast();
  Timer? _keepalive;
  bool _connecting = false;

  Stream<String> get lines => _lines.stream;
  Stream<String> get log => _log.stream;

  bool get isConnected => _socket != null;

  Future<void> connect(String host, int port, {Duration timeout = const Duration(seconds: 8)}) async {
    if (_connecting) return;
    _connecting = true;
    try {
      await disconnect();
      _emitLog('Connecting to $host:$port …');
      final socket = await Socket.connect(host, port, timeout: timeout);
      _socket = socket;
      socket.listen(
        _onData,
        onError: (Object e) {
          _emitLog('Socket error: $e');
          unawaited(disconnect());
        },
        onDone: () {
          _emitLog('Connection closed by remote');
          unawaited(disconnect());
        },
        cancelOnError: true,
      );
      _keepalive = Timer.periodic(const Duration(seconds: 25), (_) {
        unawaited(sendRaw('\r'));
      });
      _emitLog('Connected');
      // Open session / request object status like WebPoint.
      await send('VOS 0 1');
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    _keepalive?.cancel();
    _keepalive = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  Future<void> send(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    await sendRaw('$trimmed\r');
    _emitLog('--> $trimmed');
  }

  Future<void> sendRaw(String payload) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Not connected');
    }
    socket.add(utf8.encode(payload));
    await socket.flush();
  }

  Future<void> requestStationList(int master, int station) => send('VLS# $master $station');

  Future<void> requestLoad(int master, int enclosure, int module, int load) =>
      send('VGB# $master $enclosure $module $load');

  Future<void> setLoad({
    required int master,
    required int enclosure,
    required int module,
    required int load,
    required int level,
    double fadeSeconds = 0,
  }) {
    final fade = fadeSeconds > 0 ? ' ${fadeSeconds.toStringAsFixed(fadeSeconds.truncateToDouble() == fadeSeconds ? 0 : 1)}' : '';
    return send('VLB $master $enclosure $module $load $level$fade');
  }

  /// Simulate a programmed keypad button.
  ///
  /// WebPoint on VCommand (3041) activates buttons with `VSW# … 6`.
  /// A too-short VSW press/release often only completes one half of a Dim
  /// toggle (off works, on does not) — so we prefer the WebPoint pulse.
  Future<void> pressButton({
    required int master,
    required int station,
    required int switchNumber,
  }) async {
    await send('VSW# $master $station $switchNumber 6');
  }

  Future<void> runMacro({required int master, required int index}) =>
      send('VMA $master $index');

  Future<void> setScheduleEnabled({
    required int master,
    required int index,
    required bool enabled,
  }) =>
      send('VSC $master $index ${enabled ? 1 : 0}');

  Future<void> setThermostatSetpoint({
    required int master,
    required int station,
    required double celsius,
  }) =>
      send('VHT $master $station ${celsius.round()}');

  Future<void> querySystemTime() => send('VGT 0');

  Future<void> setSystemTime(DateTime dt) {
    // Best-effort controller clock sync; unsupported controllers report via log.
    final stamp =
        '${dt.year.toString().padLeft(4, '0')}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        '${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}';
    return send('VST $stamp');
  }

  void _onData(List<int> data) {
    _buffer.add(data);
    final bytes = _buffer.takeBytes();
    var start = 0;
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if (b == 0x0d || b == 0x0a) {
        if (i > start) {
          final line = utf8.decode(bytes.sublist(start, i), allowMalformed: true).trim();
          if (line.isNotEmpty) {
            _emitLog('<-- $line');
            if (!_lines.isClosed) _lines.add(line);
          }
        }
        start = i + 1;
      }
    }
    if (start < bytes.length) {
      _buffer.add(bytes.sublist(start));
    }
  }

  void _emitLog(String message) {
    if (!_log.isClosed) _log.add(message);
  }

  Future<void> dispose() async {
    await disconnect();
    await _lines.close();
    await _log.close();
  }
}

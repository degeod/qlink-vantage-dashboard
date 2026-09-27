import 'package:flutter/services.dart';

/// Calls the official IvyIo Android SDK (same path as Foscam app / Ivy demo).
class IvyNvrClient {
  IvyNvrClient._();

  static const _ch = MethodChannel('vantage/nvr');

  static Future<List<Map<String, dynamic>>> discover() async {
    final raw = await _ch.invokeMethod<List<dynamic>>('discover');
    return [
      for (final e in raw ?? const [])
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static Future<List<Map<String, dynamic>>> login({
    required String uid,
    required String user,
    required String password,
  }) async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('login', {
        'uid': uid,
        'user': user,
        'password': password,
      });
      return [
        for (final e in raw ?? const [])
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: e.message ?? e.code,
      );
    }
  }

  static Future<void> setChannel(int channel) async {
    await _ch.invokeMethod<void>('setChannel', {'channel': channel});
  }

  static Future<void> logout() => _ch.invokeMethod<void>('logout');
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const _prefKey = 'device_unique_id';
  static String? _cached;

  static Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;
    // On web and all other platforms use SharedPreferences fallback
    // (avoids dart:io Platform crash on Chrome)
    _cached = await _getOrCreateFallbackId();
    return _cached!;
  }

  static Future<String> _getOrCreateFallbackId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = const Uuid().v4();
    await prefs.setString(_prefKey, newId);
    return newId;
  }
}
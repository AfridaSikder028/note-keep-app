import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Ringtone options ──────────────────────────────────────────
  static const List<Map<String, String?>> ringtones = [
    {'label': 'Default', 'sound': null},
    {'label': 'Chime', 'sound': 'chime'},
    {'label': 'Bell', 'sound': 'bell'},
    {'label': 'Ping', 'sound': 'ping'},
    {'label': 'Soft', 'sound': 'soft'},
  ];

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create default notification channel
    await _ensureChannel(soundFile: null, highPriority: false);

    _initialized = true;
  }

  Future<void> _ensureChannel({
    required String? soundFile,
    required bool highPriority,
  }) async {
    if (kIsWeb) return;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation
            <AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    final AndroidNotificationSound? sound = soundFile != null
        ? RawResourceAndroidNotificationSound(soundFile)
        : null;

    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'note_reminders',
      'Note Reminders',
      description: 'Reminders for your notes',
      importance: highPriority ? Importance.max : Importance.high,
      playSound: true,
      sound: sound,
      enableVibration: true,
    );

    await androidPlugin.createNotificationChannel(channel);
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  Future<void> scheduleReminder({
    required String noteId,
    required String noteTitle,
    required DateTime scheduledTime,
    required bool highPriority,
    String? soundFile,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    // Re-create channel with the chosen sound/priority
    await _ensureChannel(soundFile: soundFile, highPriority: highPriority);

    final int id = noteId.hashCode.abs() % 100000;

    final tz.TZDateTime tzTime =
        tz.TZDateTime.from(scheduledTime, tz.local);

    // Don't schedule if time is already in the past
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    final AndroidNotificationSound? sound = soundFile != null
        ? RawResourceAndroidNotificationSound(soundFile)
        : null;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'note_reminders',
      'Note Reminders',
      channelDescription: 'Reminders for your notes',
      importance: highPriority ? Importance.max : Importance.high,
      priority: highPriority ? Priority.max : Priority.high,
      playSound: true,
      sound: sound,
      enableVibration: true,
      fullScreenIntent: highPriority,
      category: AndroidNotificationCategory.alarm,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      noteTitle.isEmpty ? 'Note Reminder' : noteTitle,
      'Your reminder is due',
      tzTime,
      details,
      androidScheduleMode: highPriority
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(String noteId) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    final int id = noteId.hashCode.abs() % 100000;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }
}
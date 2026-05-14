import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles local (device-side) notifications for geofence POI triggers.
/// No backend required — notifications are generated entirely on-device.
///
/// Usage:
///   await NotificationService.instance.initialize();  // once at app start
///   await NotificationService.instance.requestPermission();  // on tour start
///   NotificationService.instance.showPOIEnteredNotification(poiName: '...');
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // asked separately at tour start
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(iOS: iosSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
    print('🔔 NotificationService initialised');
  }

  /// Request iOS notification permission.
  /// Returns true if granted.
  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: false,
      sound: true,
    );
    print('🔔 Notification permission: ${granted == true ? "granted" : "denied"}');
    return granted ?? false;
  }

  /// Show a native notification banner when the user enters a POI geofence.
  /// Works when the app is in the foreground OR background.
  /// Uses a fixed id=1 so rapid re-entries replace rather than stack.
  Future<void> showPOIEnteredNotification({
    required String poiName,
  }) async {
    if (!_initialized) return;

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    const details = NotificationDetails(iOS: iosDetails);

    await _plugin.show(
      1, // id — fixed so repeated triggers replace the previous banner
      'Audio guide starting',
      poiName,
      details,
    );
    print('🔔 Notification shown: $poiName');
  }
}

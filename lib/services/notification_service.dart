import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import 'storage_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelIdTrips = 'wildpath_trips';
  static const _channelIdWeather = 'wildpath_weather';
  static const _tzKey = 'wildpath_local_tz';

  // Notification ID bands
  // Trip reminders: tripId hashCode & 0xFFFF, shifted by 0 or 1 for -2/-1 day
  // Weather alerts: 90000 + sequential

  Future<void> init() async {
    tz_data.initializeTimeZones();

    // Persist timezone name for background isolate use
    final prefs = await SharedPreferences.getInstance();
    // Store the UTC offset in minutes — timezone package needs a named zone
    // We use the device UTC offset and map to a fixed-offset zone
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    await prefs.setInt(_tzKey, offsetMinutes);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    await _createChannels();
  }

  Future<void> _createChannels() async {
    const trips = AndroidNotificationChannel(
      _channelIdTrips,
      'Trip Reminders',
      description: 'Reminders before your camping trips',
      importance: Importance.high,
    );
    const weather = AndroidNotificationChannel(
      _channelIdWeather,
      'Severe Weather Alerts',
      description: 'NWS severe weather alerts for your campsite',
      importance: Importance.max,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(trips);
    await androidPlugin?.createNotificationChannel(weather);
  }

  Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestNotificationsPermission() ?? false;
  }

  // ── Trip Reminders ────────────────────────────────────────────────────────

  Future<void> scheduleTripReminders(TripModel trip) async {
    if (trip.startDate.isEmpty) return;
    DateTime start;
    try {
      start = DateTime.parse(trip.startDate);
    } catch (_) {
      return;
    }

    // Cancel any existing reminders for this trip first
    await cancelTripReminders(trip.id);

    final now = DateTime.now();
    final tripName = trip.name.isNotEmpty
        ? trip.name
        : (trip.locationDisplay.isNotEmpty
            ? trip.locationDisplay
            : 'your trip');

    for (final daysBefore in [2, 1]) {
      final reminderDate = start.subtract(Duration(days: daysBefore));
      final scheduledAt = DateTime(
          reminderDate.year, reminderDate.month, reminderDate.day, 8, 0);
      if (scheduledAt.isBefore(now)) continue;

      final id = _tripNotifId(trip.id, daysBefore);
      final title = daysBefore == 1
          ? 'Tomorrow is the day! 🏕'
          : '$daysBefore days until your trip!';
      final body = daysBefore == 1
          ? '$tripName starts tomorrow — check your gear and weather.'
          : '$tripName starts in $daysBefore days — time to pack up!';

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _toTZ(scheduledAt),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelIdTrips,
            'Trip Reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelTripReminders(String tripId) async {
    await _plugin.cancel(_tripNotifId(tripId, 2));
    await _plugin.cancel(_tripNotifId(tripId, 1));
  }

  Future<void> cancelAllTripReminders(List<TripModel> trips) async {
    for (final t in trips) {
      await cancelTripReminders(t.id);
    }
  }

  Future<void> rescheduleAllSavedTrips(StorageService storage) async {
    if (!storage.notifTrips) return;
    final trips = storage.loadSavedTrips();
    for (final t in trips) {
      await scheduleTripReminders(t);
    }
  }

  // ── Weather Alert Notifications ───────────────────────────────────────────

  static Future<void> showWeatherAlertNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdWeather,
          'Severe Weather Alerts',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _tripNotifId(String tripId, int daysBefore) {
    // Stable int from tripId + offset, fits in 32-bit signed int range
    final base = tripId.hashCode & 0x7FFF;
    return base * 10 + daysBefore;
  }

  tz.TZDateTime _toTZ(DateTime dt) {
    // Use UTC offset stored at init time to build a fixed-offset location
    return tz.TZDateTime.from(dt, tz.local);
  }
}

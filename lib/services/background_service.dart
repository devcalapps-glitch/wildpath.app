import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';

const _weatherTaskName = 'wildpath_weather_check';
const _seenAlertsKey = 'wildpath_seen_alert_ids';
const _notifWeatherKey = 'wildpath_notif_weather';
const _tripKey = 'wildpath_current_trip_v2';

/// Top-level entry point — must NOT be a closure or instance method.
/// The @pragma annotation prevents tree-shaking on release builds.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _weatherTaskName) {
      await _runWeatherCheck();
    }
    return true;
  });
}

Future<void> _runWeatherCheck() async {
  final prefs = await SharedPreferences.getInstance();

  // Respect user preference — checked here in background isolate
  final enabled = prefs.getBool(_notifWeatherKey) ?? true;
  if (!enabled) return;

  // Load current trip to get lat/lng
  final tripJson = prefs.getString(_tripKey);
  if (tripJson == null) return;

  double? lat, lng;
  String locationName = 'your campsite';
  try {
    final map = jsonDecode(tripJson) as Map<String, dynamic>;
    lat = (map['lat'] as num?)?.toDouble();
    lng = (map['lng'] as num?)?.toDouble();
    final campsite = map['campsite'] as String? ?? '';
    if (campsite.isNotEmpty) {
      final parts = campsite.split(',');
      locationName = parts.length > 1
          ? '${parts[0].trim()}, ${parts[1].trim()}'
          : parts[0].trim();
    }
  } catch (_) {
    return;
  }

  if (lat == null || lng == null) return;

  // Fetch NWS alerts
  List<Map<String, dynamic>> features = [];
  try {
    final uri = Uri.parse(
        'https://api.weather.gov/alerts/active?point=${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}');
    final res = await http.get(uri, headers: {'User-Agent': 'WildPath/1.0'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      features = (body['features'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
    }
  } catch (_) {
    return;
  }

  if (features.isEmpty) return;

  // Load seen alert IDs to avoid duplicate notifications
  final seenIds = prefs.getStringList(_seenAlertsKey) ?? [];
  final newSeenIds = List<String>.from(seenIds);
  int notifId = 90000;

  for (final feature in features.take(3)) {
    final props = feature['properties'] as Map<String, dynamic>?;
    if (props == null) continue;

    final alertId = feature['id'] as String? ?? '';
    if (alertId.isEmpty || seenIds.contains(alertId)) continue;

    final event = props['event'] as String? ?? 'Weather Alert';
    final severity = (props['severity'] as String? ?? '').toLowerCase();
    final headline = props['headline'] as String? ?? event;

    // Only notify for severe or extreme
    if (severity != 'severe' && severity != 'extreme') continue;

    final emoji = severity == 'extreme' ? '🆘' : '⛈';
    await NotificationService.showWeatherAlertNotification(
      id: notifId++,
      title: '$emoji $event — $locationName',
      body: headline.length > 100 ? '${headline.substring(0, 97)}…' : headline,
    );

    newSeenIds.add(alertId);
  }

  // Cap stored IDs at 100 to avoid unbounded growth
  if (newSeenIds.length > 100) {
    newSeenIds.removeRange(0, newSeenIds.length - 100);
  }
  await prefs.setStringList(_seenAlertsKey, newSeenIds);
}

/// Call once at app startup to register the periodic weather check worker.
Future<void> startWeatherAlertWorker() async {
  await Workmanager().registerPeriodicTask(
    _weatherTaskName,
    _weatherTaskName,
    frequency: const Duration(hours: 3),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

/// Call when the user disables weather alerts.
Future<void> stopWeatherAlertWorker() async {
  await Workmanager().cancelByUniqueName(_weatherTaskName);
}

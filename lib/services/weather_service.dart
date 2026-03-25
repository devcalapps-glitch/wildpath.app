import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Update this to your actual Cloudflare Worker URL
const String kWorkerUrl = 'https://your-worker.workers.dev';

class WeatherData {
  final double tempF;
  final double tempC;
  final double feelsLikeF;
  final int humidity;
  final double windMph;
  final String condition;
  final String icon;
  final double precipMm;
  final List<ForecastDay> forecast;
  final List<WeatherAlert> alerts;

  const WeatherData({
    required this.tempF,
    required this.tempC,
    required this.feelsLikeF,
    required this.humidity,
    required this.windMph,
    required this.condition,
    required this.icon,
    required this.precipMm,
    required this.forecast,
    required this.alerts,
  });

  factory WeatherData.fromOpenMeteo(
      Map<String, dynamic> json, List<WeatherAlert> alerts) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    final tempC = (current['temperature_2m'] as num).toDouble();
    final windKph = (current['wind_speed_10m'] as num).toDouble();
    final wmo = current['weather_code'] as int? ?? 0;
    final dates = daily['time'] as List;

    final List<ForecastDay> days = [];
    for (int i = 0; i < dates.length && i < 7; i++) {
      days.add(ForecastDay(
        date: dates[i] as String,
        maxTempC: (daily['temperature_2m_max'][i] as num).toDouble(),
        minTempC: (daily['temperature_2m_min'][i] as num).toDouble(),
        precipMm: (daily['precipitation_sum'][i] as num).toDouble(),
        wmoCode: daily['weather_code'][i] as int? ?? 0,
      ));
    }

    return WeatherData(
      tempC: tempC,
      tempF: tempC * 9 / 5 + 32,
      feelsLikeF:
          ((current['apparent_temperature'] as num?)?.toDouble() ?? tempC) *
                  9 /
                  5 +
              32,
      humidity: current['relative_humidity_2m'] as int? ?? 0,
      windMph: windKph * 0.621371,
      condition: _wmoCondition(wmo),
      icon: _wmoEmoji(wmo),
      precipMm: (current['precipitation'] as num?)?.toDouble() ?? 0,
      forecast: days,
      alerts: alerts,
    );
  }

  static String _wmoCondition(int c) {
    if (c == 0) return 'Clear Sky';
    if (c <= 2) return 'Partly Cloudy';
    if (c == 3) return 'Overcast';
    if (c <= 49) return 'Fog';
    if (c <= 57) return 'Drizzle';
    if (c <= 67) return 'Rain';
    if (c <= 77) return 'Snow';
    if (c <= 82) return 'Rain Showers';
    if (c <= 86) return 'Snow Showers';
    if (c <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  static String _wmoEmoji(int c) {
    if (c == 0) return '☀';
    if (c <= 2) return '⛅';
    if (c == 3) return '☁';
    if (c <= 49) return '🌫';
    if (c <= 67) return '🌧';
    if (c <= 77) return '❄';
    if (c <= 82) return '🌦';
    if (c <= 86) return '🌨';
    if (c <= 99) return '⛈';
    return '🌡';
  }
}

class ForecastDay {
  final String date;
  final double maxTempC;
  final double minTempC;
  final double precipMm;
  final int wmoCode;

  const ForecastDay({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.precipMm,
    required this.wmoCode,
  });

  double get maxTempF => maxTempC * 9 / 5 + 32;
  double get minTempF => minTempC * 9 / 5 + 32;
  String get emoji => WeatherData._wmoEmoji(wmoCode);
  String get condition => WeatherData._wmoCondition(wmoCode);
}

class WeatherAlert {
  final String title;
  final String description;
  final String severity;
  final String emoji;

  const WeatherAlert({
    required this.title,
    required this.description,
    this.severity = 'moderate',
    this.emoji = '⚠',
  });
}

class LocationResult {
  final double? lat;
  final double? lng;
  final String displayName;
  final String? placeId;
  const LocationResult(
      {this.lat, this.lng, required this.displayName, this.placeId});

  bool get hasCoordinates => lat != null && lng != null;
}

class WeatherService {
  static http.Client? _activeSearchClient;
  static int _activeSearchId = 0;
  static String get googleGeocodingApiKey =>
      dotenv.env['MAPS_API_KEY']?.trim() ?? '';
  static bool get hasGoogleGeocodingApiKey => googleGeocodingApiKey.isNotEmpty;

  static Future<List<LocationResult>> searchLocations(String query,
      {int limit = 5, String? sessionToken}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || !hasGoogleGeocodingApiKey) {
      return const [];
    }

    _activeSearchClient?.close();
    final client = http.Client();
    _activeSearchClient = client;
    final requestId = ++_activeSearchId;

    try {
      final url =
          Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
      final resp = await client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': googleGeocodingApiKey,
            },
            body: jsonEncode({
              'input': trimmed,
              'sessionToken': sessionToken,
              'includeQueryPredictions': false,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (requestId != _activeSearchId) {
        return const [];
      }
      if (resp.statusCode != 200) {
        final errBody = resp.body;
        dev.log('[Places] searchLocations error ${resp.statusCode}: $errBody',
            name: 'WeatherService');
        // Surface error so caller can show it to the user
        throw Exception('Places API ${resp.statusCode}: $errBody');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List?) ?? const [];
      return suggestions
          .map((item) => item['placePrediction'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map((prediction) => LocationResult(
                placeId: prediction['placeId'] as String?,
                displayName: prediction['text']?['text'] as String? ?? '',
              ))
          .where((item) => item.displayName.isNotEmpty && item.placeId != null)
          .take(limit)
          .toList();
    } catch (e) {
      dev.log('[Places] searchLocations exception: $e', name: 'WeatherService');
      rethrow;
    } finally {
      if (identical(_activeSearchClient, client)) {
        _activeSearchClient = null;
      }
      client.close();
    }
  }

  static Future<LocationResult?> geocode(String query) async {
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    final results = await searchLocations(query, limit: 1, sessionToken: token);
    return results.isEmpty ? null : results.first;
  }

  static Future<LocationResult?> resolvePlace(
    String placeId, {
    String? sessionToken,
  }) async {
    if (!hasGoogleGeocodingApiKey || placeId.trim().isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': googleGeocodingApiKey,
          'X-Goog-FieldMask': 'formattedAddress,location,id',
          if (sessionToken != null && sessionToken.isNotEmpty)
            'X-Goog-Session-Token': sessionToken,
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        dev.log('[Places] resolvePlace error ${resp.statusCode}: ${resp.body}',
            name: 'WeatherService');
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>?;
      if (location == null) {
        return null;
      }

      return LocationResult(
        placeId: data['id'] as String?,
        displayName: data['formattedAddress'] as String? ?? '',
        lat: (location['latitude'] as num).toDouble(),
        lng: (location['longitude'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<WeatherData?> fetchWeather(double lat, double lng) async {
    // Try Cloudflare Worker first
    if (kWorkerUrl != 'https://your-worker.workers.dev') {
      try {
        final resp = await http
            .get(Uri.parse('$kWorkerUrl/weather?lat=$lat&lng=$lng'))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          return WeatherData.fromOpenMeteo(jsonDecode(resp.body), []);
        }
      } catch (_) {}
    }
    // Fallback: Open-Meteo directly
    return _fetchOpenMeteo(lat, lng);
  }

  static Future<WeatherData?> _fetchOpenMeteo(double lat, double lng) async {
    try {
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,'
        'precipitation,weather_code,wind_speed_10m'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code'
        '&timezone=auto&forecast_days=7',
      );
      final weatherResp =
          await http.get(weatherUrl).timeout(const Duration(seconds: 10));
      if (weatherResp.statusCode != 200) return null;

      final alerts = <WeatherAlert>[];
      try {
        final alertResp = await http.get(
            Uri.parse('https://api.weather.gov/alerts/active?point=$lat,$lng'),
            headers: {
              'User-Agent': 'WildPath/1.0'
            }).timeout(const Duration(seconds: 6));
        if (alertResp.statusCode == 200) {
          final features =
              (jsonDecode(alertResp.body)['features'] as List?) ?? [];
          for (final f in features.take(5)) {
            final p = f['properties'] as Map<String, dynamic>;
            final sev = (p['severity'] as String? ?? '').toLowerCase();
            alerts.add(WeatherAlert(
              title: p['event'] ?? 'Weather Alert',
              description: p['description'] ?? '',
              severity: sev,
              emoji: sev == 'extreme'
                  ? '🆘'
                  : sev == 'severe'
                      ? '⛈'
                      : '⚠',
            ));
          }
        }
      } catch (_) {}

      return WeatherData.fromOpenMeteo(jsonDecode(weatherResp.body), alerts);
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../models/trip_model.dart';

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
  final String source;

  const WeatherAlert({
    required this.title,
    required this.description,
    this.severity = 'moderate',
    this.emoji = '⚠',
    this.source = 'Weather alert provider',
  });
}

// Place types that represent broad areas — no pin should be shown for these.
const _generalPlaceTypes = {
  'locality',
  'sublocality',
  'administrative_area_level_1',
  'administrative_area_level_2',
  'administrative_area_level_3',
  'administrative_area_level_4',
  'administrative_area_level_5',
  'country',
  'colloquial_area',
  'political',
  'natural_feature',
};

const _outdoorPrimaryTypes = <String>[
  'campground',
  'rv_park',
  'national_park',
  'park',
  'hiking_area',
];

const _campStayPrimaryTypes = <String>[
  'camping_cabin',
];

const _lodgePrimaryTypes = <String>[
  'lodging',
];

const _preferredOutdoorKeywords = <String>[
  'blm',
  'bureau of land management',
  'camp',
  'campground',
  'campsite',
  'rv',
  'national park',
  'state park',
  'forest',
  'wilderness',
  'recreation area',
  'dispersed',
  'trail',
  'trailhead',
  'backcountry',
  'base camp',
  'basecamp',
  'cabin',
  'lodge',
];

const _campingLodgingKeywords = <String>[
  'cabin',
  'cabins',
  'lodge',
  'lodges',
  'base camp',
  'basecamp',
  'glamp',
  'camp',
];

const _genericLodgingKeywords = <String>[
  'hotel',
  'resort',
  'spa',
  'motel',
  'inn',
  'suites',
];

const _campingSearchIntentKeywords = <String>[
  'camp',
  'campground',
  'campgrounds',
  'campsite',
  'campsites',
  'blm',
  'cabin',
  'cabins',
  'lodge',
  'lodges',
  'rv',
  'trail',
  'trails',
  'park',
  'parks',
  'dispersed',
  'basecamp',
  'base camp',
];

class LocationResult {
  final double? lat;
  final double? lng;
  final String displayName;
  final String? placeId;
  final String country;
  final String region;
  final String primaryText;
  final String secondaryText;

  /// True when the result is a specific place (campground, address, etc.)
  /// and a map pin should be shown. False for cities/regions/countries.
  final bool isSpecific;
  const LocationResult({
    this.lat,
    this.lng,
    required this.displayName,
    this.placeId,
    this.country = '',
    this.region = '',
    this.primaryText = '',
    this.secondaryText = '',
    this.isSpecific = true,
  });

  bool get hasCoordinates => lat != null && lng != null;
}

class StructuredPlaceDetails {
  final String country;
  final String region;
  final String locality;
  final String sublocality;
  final String route;
  final String streetNumber;
  final String postalCode;

  const StructuredPlaceDetails({
    this.country = '',
    this.region = '',
    this.locality = '',
    this.sublocality = '',
    this.route = '',
    this.streetNumber = '',
    this.postalCode = '',
  });

  String get bestLocalityLabel {
    for (final value in [locality, sublocality, route]) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}

class WeatherService {
  static http.Client? _activeSearchClient;
  static int _activeSearchId = 0;
  static const _defaultPlacesProxyUrl =
      'https://jade-lolly-1a2c94.netlify.app/.netlify/functions/places-proxy';
  static String? placesProxyUrlOverride;
  static String get googleGeocodingApiKey =>
      const String.fromEnvironment('MAPS_API_KEY').trim();
  static String get placesProxyUrl =>
      (placesProxyUrlOverride ??
              const String.fromEnvironment(
                'PLACES_PROXY_URL',
                defaultValue: _defaultPlacesProxyUrl,
              ))
          .trim()
          .replaceAll(RegExp(r'/+$'), '');
  static String get weatherAlertsApiKey =>
      const String.fromEnvironment('WEATHER_API_KEY').trim();
  static bool get hasGoogleGeocodingApiKey => googleGeocodingApiKey.isNotEmpty;
  static bool get hasPlacesProxy => placesProxyUrl.isNotEmpty;
  static bool get hasPlacesLookupConfigured =>
      hasPlacesProxy || hasGoogleGeocodingApiKey;
  static bool get hasWeatherAlertsApiKey => weatherAlertsApiKey.isNotEmpty;

  static Uri get _placesProxyUri => Uri.parse(placesProxyUrl);

  static Future<http.Response> _proxyRequest(
    http.Client client, {
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return client
        .post(
          _placesProxyUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'operation': operation,
            ...payload,
          }),
        )
        .timeout(const Duration(seconds: 8));
  }

  static Future<http.Response> _autocompleteRequest(
    http.Client client, {
    required String input,
    required List<String> types,
    String? sessionToken,
  }) {
    if (hasPlacesProxy) {
      return _proxyRequest(
        client,
        operation: 'autocomplete',
        payload: {
          'input': input,
          'sessionToken': sessionToken,
          'includedPrimaryTypes': types,
        },
      );
    }

    final url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
    return client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': googleGeocodingApiKey,
            'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,'
                'suggestions.placePrediction.text.text,'
                'suggestions.placePrediction.structuredFormat.mainText.text,'
                'suggestions.placePrediction.structuredFormat.secondaryText.text',
          },
          body: jsonEncode({
            'input': input,
            'sessionToken': sessionToken,
            'includeQueryPredictions': false,
            'includePureServiceAreaBusinesses': false,
            'includedPrimaryTypes': types,
          }),
        )
        .timeout(const Duration(seconds: 8));
  }

  static Future<http.Response> _searchTextRequest(
    http.Client client, {
    required String textQuery,
    required int limit,
    String? includedType,
    required bool strictTypeFiltering,
    String? sessionToken,
  }) {
    if (hasPlacesProxy) {
      return _proxyRequest(
        client,
        operation: 'searchText',
        payload: {
          'textQuery': textQuery,
          'pageSize': limit,
          'strictTypeFiltering': strictTypeFiltering,
          'sessionToken': sessionToken,
          if (includedType != null) 'includedType': includedType,
        },
      );
    }

    final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
    return client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': googleGeocodingApiKey,
            'X-Goog-FieldMask':
                'places.id,places.displayName,places.formattedAddress,places.primaryType',
            if (sessionToken != null && sessionToken.isNotEmpty)
              'X-Goog-Session-Token': sessionToken,
          },
          body: jsonEncode({
            'textQuery': textQuery,
            'pageSize': limit,
            'strictTypeFiltering': strictTypeFiltering,
            if (includedType != null) 'includedType': includedType,
            'rankPreference': 'RELEVANCE',
          }),
        )
        .timeout(const Duration(seconds: 8));
  }

  static Future<http.Response> _placeDetailsRequest(
    String placeId, {
    String? sessionToken,
  }) {
    final client = http.Client();
    if (hasPlacesProxy) {
      return _proxyRequest(
        client,
        operation: 'placeDetails',
        payload: {
          'placeId': placeId,
          'sessionToken': sessionToken,
        },
      ).whenComplete(client.close);
    }

    final url = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
    return client
        .get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': googleGeocodingApiKey,
            'X-Goog-FieldMask':
                'formattedAddress,addressComponents,location,id,types,displayName',
            if (sessionToken != null && sessionToken.isNotEmpty)
              'X-Goog-Session-Token': sessionToken,
          },
        )
        .timeout(const Duration(seconds: 8))
        .whenComplete(client.close);
  }

  static Future<http.Response> _reverseGeocodeRequest(
    double lat,
    double lng,
  ) {
    final client = http.Client();
    if (hasPlacesProxy) {
      return _proxyRequest(
        client,
        operation: 'reverseGeocode',
        payload: {
          'lat': lat,
          'lng': lng,
        },
      ).whenComplete(client.close);
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng&key=$googleGeocodingApiKey',
    );
    return client
        .get(url)
        .timeout(const Duration(seconds: 8))
        .whenComplete(client.close);
  }

  static StructuredPlaceDetails parseStructuredPlaceDetails(
    List<dynamic> rawComponents,
  ) {
    final components = rawComponents.whereType<Map<String, dynamic>>().toList();

    String componentText(
      String type, {
      bool preferShortText = false,
    }) {
      for (final component in components) {
        final types = (component['types'] as List?)?.cast<String>() ?? const [];
        if (!types.contains(type)) continue;
        final longText =
            ((component['longText'] ?? component['long_name']) as String? ?? '')
                .trim();
        final shortText =
            ((component['shortText'] ?? component['short_name']) as String? ??
                    '')
                .trim();
        if (preferShortText && shortText.isNotEmpty) return shortText;
        if (longText.isNotEmpty) return longText;
        return shortText;
      }
      return '';
    }

    return StructuredPlaceDetails(
      country: TripModel.normalizeCountryName(componentText('country')),
      region: componentText('administrative_area_level_1'),
      locality: componentText('locality').isNotEmpty
          ? componentText('locality')
          : componentText('postal_town'),
      sublocality: [
        componentText('sublocality_level_1'),
        componentText('sublocality'),
        componentText('administrative_area_level_2'),
      ].firstWhere((value) => value.isNotEmpty, orElse: () => ''),
      route: componentText('route'),
      streetNumber: componentText('street_number'),
      postalCode: componentText('postal_code', preferShortText: true),
    );
  }

  static Future<List<LocationResult>> searchLocations(String query,
      {int limit = 5, String? sessionToken, String? country}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || !hasPlacesLookupConfigured) {
      return const [];
    }
    final normalizedCountry = TripModel.normalizeCountryName(country ?? '');

    _activeSearchClient?.close();
    final client = http.Client();
    _activeSearchClient = client;
    final requestId = ++_activeSearchId;

    try {
      Future<List<LocationResult>> requestForTypes(
        String input,
        List<String> types,
      ) async {
        final resp = await _autocompleteRequest(
          client,
          input: input,
          types: types,
          sessionToken: sessionToken,
        );
        if (requestId != _activeSearchId) {
          return const [];
        }
        if (resp.statusCode != 200) {
          final errBody = resp.body;
          assert(() {
            dev.log(
                '[Places] searchLocations error ${resp.statusCode}: $errBody',
                name: 'WeatherService');
            return true;
          }());
          throw Exception('Places API ${resp.statusCode}: $errBody');
        }

        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final suggestions = (data['suggestions'] as List?) ?? const [];
        return suggestions
            .map((item) => item['placePrediction'] as Map<String, dynamic>?)
            .whereType<Map<String, dynamic>>()
            .map((prediction) {
              final structured =
                  prediction['structuredFormat'] as Map<String, dynamic>?;
              final primaryText =
                  structured?['mainText']?['text'] as String? ?? '';
              final secondaryText =
                  structured?['secondaryText']?['text'] as String? ?? '';
              final displayName = prediction['text']?['text'] as String? ??
                  [
                    if (primaryText.trim().isNotEmpty) primaryText.trim(),
                    if (secondaryText.trim().isNotEmpty) secondaryText.trim(),
                  ].join(', ');
              return LocationResult(
                placeId: prediction['placeId'] as String?,
                displayName: displayName,
                primaryText: primaryText.trim(),
                secondaryText: secondaryText.trim(),
                country: _extractCountryName(
                  secondaryText.isNotEmpty ? secondaryText : displayName,
                ),
              );
            })
            .where(
                (item) => item.displayName.isNotEmpty && item.placeId != null)
            .toList();
      }

      final outdoorResults = <LocationResult>[
        ...await requestForTypes(trimmed, _outdoorPrimaryTypes),
        if (!_containsKeyword(trimmed, const ['camp', 'rv', 'trail', 'park']))
          ...await requestForTypes('$trimmed camping', _outdoorPrimaryTypes),
        if (!_containsKeyword(trimmed, const ['blm']))
          ...await requestForTypes(
              '$trimmed blm', const ['park', 'hiking_area']),
      ];
      final campStayResults =
          await requestForTypes(trimmed, _campStayPrimaryTypes);
      final lodgeResults = !_containsKeyword(trimmed, _campingLodgingKeywords)
          ? await requestForTypes(
              '$trimmed cabin lodge basecamp',
              _lodgePrimaryTypes,
            )
          : const <LocationResult>[];
      final cityResults = await requestForTypes(trimmed, const ['(cities)']);
      if (requestId != _activeSearchId) {
        return const [];
      }

      final merged = <String, LocationResult>{};
      for (final result in [
        ...outdoorResults.where(_isOutdoorFocusedResult),
        ...campStayResults,
        ...lodgeResults.where(_isCampingLodgingResult),
        ...cityResults,
      ]) {
        final placeId = result.placeId;
        if (placeId == null || merged.containsKey(placeId)) continue;
        merged[placeId] = result;
      }

      final ranked = merged.values.toList()
        ..sort((a, b) => _locationScore(b.displayName, trimmed)
            .compareTo(_locationScore(a.displayName, trimmed)));
      if (ranked.isNotEmpty) {
        return _filterResultsByCountry(
          ranked,
          country: normalizedCountry,
          limit: limit,
          sessionToken: sessionToken,
        );
      }

      final fallbackResults = await _searchCampingDestinations(
        client,
        query: trimmed,
        limit: limit,
        requestId: requestId,
        sessionToken: sessionToken,
      );
      return _filterResultsByCountry(
        fallbackResults,
        country: normalizedCountry,
        limit: limit,
        sessionToken: sessionToken,
      );
    } catch (e) {
      assert(() {
        dev.log('[Places] searchLocations exception: $e',
            name: 'WeatherService');
        return true;
      }());
      rethrow;
    } finally {
      if (identical(_activeSearchClient, client)) {
        _activeSearchClient = null;
      }
      client.close();
    }
  }

  static bool _containsKeyword(String text, List<String> keywords) {
    final normalized = text.toLowerCase();
    return keywords.any(normalized.contains);
  }

  static bool _isOutdoorFocusedResult(LocationResult result) {
    final name = result.displayName.toLowerCase();
    return _preferredOutdoorKeywords.any(name.contains);
  }

  static bool _isCampingLodgingResult(LocationResult result) {
    final name = result.displayName.toLowerCase();
    final hasCampStayKeyword = _campingLodgingKeywords.any(name.contains);
    final looksLikeGenericHotel = _genericLodgingKeywords.any(name.contains);
    return hasCampStayKeyword && !looksLikeGenericHotel;
  }

  static int _locationScore(String name, String query) {
    final normalizedName = name.toLowerCase();
    final normalizedQuery = query.toLowerCase();

    var score = 0;
    if (normalizedName.contains(normalizedQuery)) score += 8;

    for (final keyword in _preferredOutdoorKeywords) {
      if (normalizedName.contains(keyword)) {
        score += switch (keyword) {
          'blm' || 'bureau of land management' => 10,
          'campground' || 'campsite' || 'camp' => 8,
          'national park' || 'state park' => 7,
          'rv' => 6,
          'trail' || 'trailhead' => 6,
          'cabin' || 'lodge' || 'base camp' || 'basecamp' => 5,
          _ => 4,
        };
      }
    }

    if (_genericLodgingKeywords.any(normalizedName.contains)) {
      score -= 10;
    }

    return score;
  }

  static String _extractCountryName(String text) {
    final parts = text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return TripModel.normalizeCountryName(parts.last);
  }

  static bool _matchesCountry(String candidate, String expected) {
    return TripModel.countriesMatch(candidate, expected);
  }

  static Future<List<LocationResult>> _filterResultsByCountry(
    List<LocationResult> results, {
    required String country,
    required int limit,
    String? sessionToken,
  }) async {
    if (results.isEmpty) return const [];
    if (country.isEmpty || TripModel.isGenericCountryChoice(country)) {
      return results.take(limit).toList();
    }

    final matches = <LocationResult>[];
    final pendingResolution = <LocationResult>[];

    for (final result in results.take(limit * 4)) {
      if (result.country.isEmpty) {
        pendingResolution.add(result);
        continue;
      }
      if (_matchesCountry(result.country, country)) {
        matches.add(result);
        if (matches.length >= limit) {
          return matches.take(limit).toList();
        }
      }
    }

    for (final result in pendingResolution) {
      if (matches.length >= limit) break;
      final placeId = result.placeId;
      if (placeId == null || placeId.isEmpty) continue;
      final resolved = await resolvePlace(
        placeId,
        sessionToken: sessionToken,
      );
      if (resolved == null || !_matchesCountry(resolved.country, country)) {
        continue;
      }
      matches.add(LocationResult(
        lat: result.lat ?? resolved.lat,
        lng: result.lng ?? resolved.lng,
        displayName: result.displayName,
        placeId: result.placeId,
        country: resolved.country,
        region: resolved.region,
        primaryText: result.primaryText.isNotEmpty
            ? result.primaryText
            : resolved.primaryText,
        secondaryText: result.secondaryText.isNotEmpty
            ? result.secondaryText
            : resolved.secondaryText,
        isSpecific: resolved.isSpecific,
      ));
    }

    return matches.take(limit).toList();
  }

  static Future<List<LocationResult>> _searchCampingDestinations(
    http.Client client, {
    required String query,
    required int limit,
    required int requestId,
    String? sessionToken,
  }) async {
    if (!_containsKeyword(query, _campingSearchIntentKeywords)) {
      return const [];
    }

    final typeGroups = _textSearchTypesForQuery(query);
    final queryVariants = _textSearchQueries(query);
    final merged = <String, LocationResult>{};

    Future<void> collectResults({
      required String textQuery,
      String? includedType,
      required bool strictTypeFiltering,
    }) async {
      final resp = await _searchTextRequest(
        client,
        textQuery: textQuery,
        limit: limit,
        includedType: includedType,
        strictTypeFiltering: strictTypeFiltering,
        sessionToken: sessionToken,
      );

      if (requestId != _activeSearchId) {
        return;
      }
      if (resp.statusCode != 200) {
        assert(() {
          dev.log(
            '[Places] searchText error ${resp.statusCode}: ${resp.body}',
            name: 'WeatherService',
          );
          return true;
        }());
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final places = (data['places'] as List?) ?? const [];
      for (final place in places.whereType<Map<String, dynamic>>()) {
        final placeId = place['id'] as String?;
        final name = place['displayName']?['text'] as String? ?? '';
        final address = place['formattedAddress'] as String? ?? '';
        final displayName = address.isNotEmpty ? '$name, $address' : name;
        if (placeId == null ||
            displayName.isEmpty ||
            merged.containsKey(placeId)) {
          continue;
        }
        merged[placeId] = LocationResult(
          placeId: placeId,
          displayName: displayName,
          primaryText: name.trim(),
          secondaryText: address.trim(),
          country: _extractCountryName(displayName),
        );
      }
    }

    for (final textQuery in queryVariants) {
      for (final type in typeGroups) {
        await collectResults(
          textQuery: textQuery,
          includedType: type,
          strictTypeFiltering: true,
        );
      }
    }

    if (merged.isEmpty) {
      for (final textQuery in queryVariants) {
        await collectResults(
          textQuery: textQuery,
          strictTypeFiltering: false,
        );
      }
    }

    final ranked = merged.values.toList()
      ..sort((a, b) => _locationScore(b.displayName, query)
          .compareTo(_locationScore(a.displayName, query)));
    return ranked;
  }

  static List<String> _textSearchQueries(String query) {
    final normalized = query.trim();
    final variants = <String>{
      normalized,
      normalized.replaceAll(
          RegExp(r'\bcampgrounds\b', caseSensitive: false), 'campground'),
      normalized.replaceAll(
          RegExp(r'\bcamp sites\b', caseSensitive: false), 'campsites'),
    };

    if (_containsKeyword(
        normalized, const ['campground', 'campgrounds', 'camping'])) {
      variants.add(
        normalized.replaceAll(
          RegExp(r'\bcampgrounds?\b', caseSensitive: false),
          'camping',
        ),
      );
    }

    return variants.where((item) => item.trim().isNotEmpty).toList();
  }

  static List<String> _textSearchTypesForQuery(String query) {
    final normalized = query.toLowerCase();

    if (_containsKeyword(
        normalized, const ['cabin', 'cabins', 'lodge', 'lodges'])) {
      return const ['camping_cabin', 'lodging'];
    }
    if (_containsKeyword(normalized, const ['rv'])) {
      return const ['rv_park', 'campground'];
    }
    if (_containsKeyword(normalized, const ['trail', 'trails'])) {
      return const ['hiking_area', 'park', 'national_park'];
    }
    if (_containsKeyword(normalized, const ['blm', 'dispersed'])) {
      return const ['park', 'hiking_area', 'campground'];
    }
    return const [
      'campground',
      'rv_park',
      'national_park',
      'park',
      'hiking_area',
      'camping_cabin',
    ];
  }

  static Future<LocationResult?> geocode(String query,
      {String? country}) async {
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    final results = await searchLocations(
      query,
      limit: 1,
      sessionToken: token,
      country: country,
    );
    if (results.isEmpty) return null;
    final first = results.first;
    if (first.hasCoordinates) return first;
    final placeId = first.placeId;
    if (placeId == null || placeId.isEmpty) return first;
    final resolved = await resolvePlace(placeId, sessionToken: token);
    if (resolved == null) return first;
    return LocationResult(
      lat: resolved.lat,
      lng: resolved.lng,
      displayName: first.displayName,
      placeId: first.placeId,
      country: resolved.country,
      region: resolved.region,
      primaryText: first.primaryText.isNotEmpty
          ? first.primaryText
          : resolved.primaryText,
      secondaryText: first.secondaryText.isNotEmpty
          ? first.secondaryText
          : resolved.secondaryText,
      isSpecific: resolved.isSpecific,
    );
  }

  static Future<LocationResult?> resolvePlace(
    String placeId, {
    String? sessionToken,
  }) async {
    if (!hasPlacesLookupConfigured || placeId.trim().isEmpty) {
      return null;
    }

    try {
      final resp = await _placeDetailsRequest(
        placeId,
        sessionToken: sessionToken,
      );

      if (resp.statusCode != 200) {
        assert(() {
          dev.log(
              '[Places] resolvePlace error ${resp.statusCode}: ${resp.body}',
              name: 'WeatherService');
          return true;
        }());
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>?;
      if (location == null) {
        return null;
      }
      final formattedAddress =
          (data['formattedAddress'] as String? ?? '').trim();
      final placeName = (data['displayName']?['text'] as String? ?? '').trim();
      final structured = parseStructuredPlaceDetails(
        (data['addressComponents'] as List?) ?? const [],
      );

      final types =
          (data['types'] as List?)?.cast<String>() ?? const <String>[];
      final isSpecific = !types.any((t) => _generalPlaceTypes.contains(t));
      final compositeDisplayName = [
        if (placeName.isNotEmpty) placeName,
        if (formattedAddress.isNotEmpty) formattedAddress,
      ].join(', ');
      final primaryLabel = [
        placeName,
        formattedAddress,
        structured.bestLocalityLabel,
      ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');

      return LocationResult(
        placeId: data['id'] as String?,
        displayName: compositeDisplayName.isNotEmpty
            ? compositeDisplayName
            : formattedAddress,
        lat: (location['latitude'] as num).toDouble(),
        lng: (location['longitude'] as num).toDouble(),
        country: structured.country.isNotEmpty
            ? structured.country
            : _extractCountryName(formattedAddress),
        region: structured.region,
        primaryText: primaryLabel,
        secondaryText: formattedAddress,
        isSpecific: isSpecific,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<LocationResult?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    if (!hasPlacesLookupConfigured) return null;

    try {
      final resp = await _reverseGeocodeRequest(lat, lng);
      if (resp.statusCode != 200) {
        assert(() {
          dev.log(
              '[Geocoding] reverseGeocode error ${resp.statusCode}: ${resp.body}',
              name: 'WeatherService');
          return true;
        }());
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const [];
      if (results.isEmpty) return null;

      Map<String, dynamic>? best;
      for (final entry in results.whereType<Map<String, dynamic>>()) {
        final types = (entry['types'] as List?)?.cast<String>() ?? const [];
        if (!types.contains('plus_code') && !types.contains('country')) {
          best = entry;
          break;
        }
      }
      best ??= results.first as Map<String, dynamic>;

      final geometry = best['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final structured = parseStructuredPlaceDetails(
        (best['address_components'] as List?) ?? const [],
      );
      final formattedAddress =
          (best['formatted_address'] as String? ?? '').trim();
      final primaryLabel = [
        formattedAddress,
        structured.bestLocalityLabel,
      ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');

      return LocationResult(
        placeId: best['place_id'] as String?,
        displayName: formattedAddress,
        lat: (location?['lat'] as num?)?.toDouble() ?? lat,
        lng: (location?['lng'] as num?)?.toDouble() ?? lng,
        country: structured.country.isNotEmpty
            ? structured.country
            : _extractCountryName(formattedAddress),
        region: structured.region,
        primaryText: primaryLabel,
        secondaryText: formattedAddress,
        isSpecific: true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<WeatherData?> fetchWeather(double lat, double lng) =>
      _fetchOpenMeteo(lat, lng);

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

      final alerts = await _fetchAlerts(lat, lng);

      return WeatherData.fromOpenMeteo(jsonDecode(weatherResp.body), alerts);
    } catch (_) {
      return null;
    }
  }

  static Future<List<WeatherAlert>> _fetchAlerts(double lat, double lng) async {
    if (hasWeatherAlertsApiKey) {
      final globalAlerts = await _fetchWeatherApiAlerts(lat, lng);
      if (globalAlerts.isNotEmpty) return globalAlerts;
    }
    return _fetchNwsAlerts(lat, lng);
  }

  static Future<List<WeatherAlert>> _fetchWeatherApiAlerts(
      double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.weatherapi.com/v1/forecast.json'
        '?key=$weatherAlertsApiKey&q=$lat,$lng&days=1&alerts=yes&aqi=no',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return const [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final alertsBlock = data['alerts'] as Map<String, dynamic>?;
      final alertList = (alertsBlock?['alert'] as List?) ?? const [];
      return alertList.take(5).map((item) {
        final alert = item as Map<String, dynamic>;
        final sev = (alert['severity'] as String? ?? '').toLowerCase();
        return WeatherAlert(
          title: alert['headline'] as String? ??
              alert['event'] as String? ??
              'Weather Alert',
          description:
              alert['desc'] as String? ?? alert['instruction'] as String? ?? '',
          severity: sev,
          emoji: _emojiForSeverity(sev),
          source: 'WeatherAPI alerts',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<WeatherAlert>> _fetchNwsAlerts(
      double lat, double lng) async {
    try {
      final alertResp = await http.get(
          Uri.parse('https://api.weather.gov/alerts/active?point=$lat,$lng'),
          headers: {'User-Agent': 'WildPath/1.0'}).timeout(
        const Duration(seconds: 6),
      );
      if (alertResp.statusCode != 200) return const [];

      final features =
          (jsonDecode(alertResp.body)['features'] as List?) ?? const [];
      return features.take(5).map((feature) {
        final p = (feature as Map<String, dynamic>)['properties']
            as Map<String, dynamic>;
        final sev = (p['severity'] as String? ?? '').toLowerCase();
        return WeatherAlert(
          title: p['event'] ?? 'Weather Alert',
          description: p['description'] ?? '',
          severity: sev,
          emoji: _emojiForSeverity(sev),
          source: 'National Weather Service',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static String _emojiForSeverity(String severity) {
    if (severity == 'extreme') return '🆘';
    if (severity == 'severe') return '⛈';
    return '⚠';
  }
}

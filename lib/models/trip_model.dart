import 'dart:convert';

const _tripModelNoChange = Object();

class TripModel {
  static const Map<String, String> _countryMatchAliases = {
    'England': 'United Kingdom',
    'Scotland': 'United Kingdom',
    'Wales': 'United Kingdom',
    'Northern Ireland': 'United Kingdom',
  };

  static String? normalizePlaceId(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String id;
  String name;
  String campsite;
  String country;
  String region;
  String destination;
  String? placeId;
  String startDate;
  String endDate;
  int groupSize;
  String tripType;
  String notes;
  double? lat;
  double? lng;
  bool isSpecificLocation;
  String savedAt;

  TripModel({
    required this.id,
    this.name = '',
    this.campsite = '',
    this.country = '',
    this.region = '',
    this.destination = '',
    String? placeId,
    this.startDate = '',
    this.endDate = '',
    this.groupSize = 1,
    this.tripType = 'Campsites',
    this.notes = '',
    this.lat,
    this.lng,
    this.isSpecificLocation = true,
    String? savedAt,
  })  : placeId = normalizePlaceId(placeId),
        savedAt = savedAt ?? DateTime.now().toIso8601String();

  int get nights {
    if (startDate.isEmpty || endDate.isEmpty) return 0;
    try {
      final s = DateTime.parse(startDate);
      final e = DateTime.parse(endDate);
      final d = e.difference(s).inDays;
      return d > 0 ? d : 0;
    } catch (_) {
      return 0;
    }
  }

  List<DateTime> get tripDays {
    if (startDate.isEmpty || endDate.isEmpty) return [];
    try {
      final s = DateTime.parse(startDate);
      final e = DateTime.parse(endDate);
      final days = <DateTime>[];
      for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
        days.add(d);
      }
      return days;
    } catch (_) {
      return [];
    }
  }

  String get tripTypeEmoji {
    const map = {
      'Campsites': '🏕',
      'RV or Van': '🚐',
      'Backpacking': '🎒',
      'On the Water': '🛶',
      'Cabins': '🏡',
      'Off-Grid': '🌲',
      'Group Camp': '👥',
      'Glamping': '✨',
    };
    return map[tripType] ?? '🏕';
  }

  static String normalizeCountryName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final normalized = trimmed.toLowerCase();
    if (normalized == 'us' ||
        normalized == 'u.s.' ||
        normalized == 'u.s.a.' ||
        normalized == 'usa' ||
        normalized == 'united states' ||
        normalized == 'united states of america' ||
        normalized == 'america') {
      return 'United States';
    }
    return trimmed;
  }

  static String canonicalCountryMatchName(String value) {
    final normalized = normalizeCountryName(value);
    return _countryMatchAliases[normalized] ?? normalized;
  }

  static bool countriesMatch(String candidate, String expected) {
    final normalizedExpected = canonicalCountryMatchName(expected);
    if (normalizedExpected.isEmpty ||
        isGenericCountryChoice(normalizedExpected)) {
      return true;
    }

    final normalizedCandidate = canonicalCountryMatchName(candidate);
    return normalizedCandidate.isNotEmpty &&
        normalizedCandidate == normalizedExpected;
  }

  static bool isGenericCountryChoice(String value) {
    final normalized = normalizeCountryName(value).toLowerCase();
    return normalized == 'other' || normalized == 'international';
  }

  bool get isUnitedStates => normalizeCountryName(country) == 'United States';

  bool get hasStructuredLocation {
    final normalizedCountry = normalizeCountryName(country);
    return destination.trim().isNotEmpty ||
        (!isGenericCountryChoice(normalizedCountry) &&
            region.trim().isNotEmpty);
  }

  String get locationDisplay {
    if (!hasStructuredLocation) return campsite.trim();
    final normalizedCountry = normalizeCountryName(country);
    final parts = <String>[
      if (destination.trim().isNotEmpty) destination.trim(),
      if (!isGenericCountryChoice(normalizedCountry) &&
          region.trim().isNotEmpty)
        region.trim(),
      if (normalizedCountry.isNotEmpty &&
          !isUnitedStates &&
          !isGenericCountryChoice(normalizedCountry))
        normalizedCountry,
    ];
    return parts.join(', ');
  }

  String get locationSearchQuery {
    if (!hasStructuredLocation) return campsite.trim();
    final normalizedCountry = normalizeCountryName(country);
    final builtQueryParts = <String>[
      if (destination.trim().isNotEmpty) destination.trim(),
      if (!isGenericCountryChoice(normalizedCountry) &&
          region.trim().isNotEmpty)
        region.trim(),
      if (normalizedCountry.isNotEmpty &&
          !isGenericCountryChoice(normalizedCountry))
        normalizedCountry,
    ];
    final builtQuery = builtQueryParts.join(', ');
    final storedQuery = campsite.trim();
    if (storedQuery.isEmpty) return builtQuery;
    return storedQuery.toLowerCase() == locationDisplay.toLowerCase()
        ? builtQuery
        : storedQuery;
  }

  bool get hasLocationLabel => locationDisplay.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'campsite': campsite,
        'country': normalizeCountryName(country),
        'region': region,
        'destination': destination,
        'placeId': normalizePlaceId(placeId),
        'startDate': startDate,
        'endDate': endDate,
        'groupSize': groupSize,
        'tripType': tripType,
        'notes': notes,
        'lat': lat,
        'lng': lng,
        'isSpecificLocation': isSpecificLocation,
        'savedAt': savedAt,
      };

  factory TripModel.fromJson(Map<String, dynamic> j) => TripModel(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        campsite: j['campsite'] ?? '',
        country: normalizeCountryName(j['country'] ?? ''),
        region: j['region'] ?? '',
        destination: j['destination'] ?? '',
        placeId: normalizePlaceId((j['placeId'] ?? j['place_id']) as String?),
        startDate: j['startDate'] ?? '',
        endDate: j['endDate'] ?? '',
        groupSize: j['groupSize'] ?? 1,
        tripType: j['tripType'] ?? 'Campsites',
        notes: j['notes'] ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        isSpecificLocation: j['isSpecificLocation'] as bool? ?? true,
        savedAt: j['savedAt'] ?? '',
      );

  String toJsonString() => jsonEncode(toJson());
  factory TripModel.fromJsonString(String s) =>
      TripModel.fromJson(jsonDecode(s));

  TripModel copyWith({
    String? id,
    String? name,
    String? campsite,
    String? country,
    String? region,
    String? destination,
    Object? placeId = _tripModelNoChange,
    String? startDate,
    String? endDate,
    int? groupSize,
    String? tripType,
    String? notes,
    Object? lat = _tripModelNoChange,
    Object? lng = _tripModelNoChange,
    bool? isSpecificLocation,
    String? savedAt,
  }) =>
      TripModel(
        id: id ?? this.id,
        name: name ?? this.name,
        campsite: campsite ?? this.campsite,
        country: normalizeCountryName(country ?? this.country),
        region: region ?? this.region,
        destination: destination ?? this.destination,
        placeId: identical(placeId, _tripModelNoChange)
            ? this.placeId
            : normalizePlaceId(placeId as String?),
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        groupSize: groupSize ?? this.groupSize,
        tripType: tripType ?? this.tripType,
        notes: notes ?? this.notes,
        lat: identical(lat, _tripModelNoChange) ? this.lat : lat as double?,
        lng: identical(lng, _tripModelNoChange) ? this.lng : lng as double?,
        isSpecificLocation: isSpecificLocation ?? this.isSpecificLocation,
        savedAt: savedAt ?? this.savedAt,
      );
}

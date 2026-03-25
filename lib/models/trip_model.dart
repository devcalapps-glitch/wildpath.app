import 'dart:convert';

const _tripModelNoChange = Object();

class TripModel {
  String id;
  String name;
  String campsite;
  String startDate;
  String endDate;
  int groupSize;
  String tripType;
  String permitNum;
  String permitTime;
  String notes;
  double? lat;
  double? lng;
  String savedAt;

  TripModel({
    required this.id,
    this.name = '',
    this.campsite = '',
    this.startDate = '',
    this.endDate = '',
    this.groupSize = 1,
    this.tripType = 'Campsites',
    this.permitNum = '',
    this.permitTime = '',
    this.notes = '',
    this.lat,
    this.lng,
    String? savedAt,
  }) : savedAt = savedAt ?? DateTime.now().toIso8601String();

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'campsite': campsite,
        'startDate': startDate,
        'endDate': endDate,
        'groupSize': groupSize,
        'tripType': tripType,
        'permitNum': permitNum,
        'permitTime': permitTime,
        'notes': notes,
        'lat': lat,
        'lng': lng,
        'savedAt': savedAt,
      };

  factory TripModel.fromJson(Map<String, dynamic> j) => TripModel(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        campsite: j['campsite'] ?? '',
        startDate: j['startDate'] ?? '',
        endDate: j['endDate'] ?? '',
        groupSize: j['groupSize'] ?? 1,
        tripType: j['tripType'] ?? 'Campsites',
        permitNum: j['permitNum'] ?? '',
        permitTime: j['permitTime'] ?? '',
        notes: j['notes'] ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        savedAt: j['savedAt'] ?? '',
      );

  String toJsonString() => jsonEncode(toJson());
  factory TripModel.fromJsonString(String s) =>
      TripModel.fromJson(jsonDecode(s));

  TripModel copyWith({
    String? id,
    String? name,
    String? campsite,
    String? startDate,
    String? endDate,
    int? groupSize,
    String? tripType,
    String? permitNum,
    String? permitTime,
    String? notes,
    Object? lat = _tripModelNoChange,
    Object? lng = _tripModelNoChange,
    String? savedAt,
  }) =>
      TripModel(
        id: id ?? this.id,
        name: name ?? this.name,
        campsite: campsite ?? this.campsite,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        groupSize: groupSize ?? this.groupSize,
        tripType: tripType ?? this.tripType,
        permitNum: permitNum ?? this.permitNum,
        permitTime: permitTime ?? this.permitTime,
        notes: notes ?? this.notes,
        lat: identical(lat, _tripModelNoChange) ? this.lat : lat as double?,
        lng: identical(lng, _tripModelNoChange) ? this.lng : lng as double?,
        savedAt: savedAt ?? this.savedAt,
      );
}

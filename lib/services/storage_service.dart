import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import '../models/gear_item.dart';
import '../models/meal_item.dart';
import '../models/permit_model.dart';

class StorageService {
  static const _tripKey = 'wildpath_current_trip_v2';
  static const _savedTripsKey = 'wildpath_saved_trips_v2';
  static const _gearKey = 'wildpath_gear_v2';
  static const _mealsKey = 'wildpath_meals_v2';
  static const _budgetKey = 'wildpath_budget_v2';
  static const _budgetTotalKey = 'wildpath_budget_total_v2';
  static const _emContactsKey = 'wildpath_em_contacts_v2';
  static const _gearByTripKey = 'wildpath_gear_by_trip_v1';
  static const _mealsByTripKey = 'wildpath_meals_by_trip_v1';
  static const _budgetByTripKey = 'wildpath_budget_by_trip_v1';
  static const _budgetTotalByTripKey = 'wildpath_budget_total_by_trip_v1';
  static const _emContactsByTripKey = 'wildpath_em_contacts_by_trip_v1';
  static const _permitsByTripKey = 'wildpath_permits_by_trip_v1';
  static const _onboardingKey = 'wildpath_onboarding_done';
  // Name and email use secure storage — kept as legacy keys only for migration
  static const _userNameKey = 'wildpath_user_name';
  static const _userEmailKey = 'wildpath_user_email';
  static const _userStyleKey = 'wildpath_user_style';
  static const _userStylesKey = 'wildpath_user_styles';
  static const _notifTripsKey = 'wildpath_notif_trips';
  static const _notifWeatherKey = 'wildpath_notif_weather';
  static const _notifPermissionAskedKey = 'wildpath_notif_permission_asked';

  late SharedPreferences _prefs;
  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // In-memory cache so synchronous getters work after init()
  String _userName = '';
  String _userEmail = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateUserPiiToSecureStorage();
    _userName = await _secure.read(key: _userNameKey) ?? '';
    _userEmail = await _secure.read(key: _userEmailKey) ?? '';
    await _migrateLegacyTripData();
  }

  /// One-time migration: move plaintext name/email from SharedPreferences
  /// into encrypted storage, then delete the plaintext copies.
  Future<void> _migrateUserPiiToSecureStorage() async {
    final plainName = _prefs.getString(_userNameKey);
    final plainEmail = _prefs.getString(_userEmailKey);
    if (plainName != null) {
      await _secure.write(key: _userNameKey, value: plainName);
      await _prefs.remove(_userNameKey);
    }
    if (plainEmail != null) {
      await _secure.write(key: _userEmailKey, value: plainEmail);
      await _prefs.remove(_userEmailKey);
    }
  }

  // Onboarding
  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;
  Future<void> setOnboardingDone() => _prefs.setBool(_onboardingKey, true);

  String get userName => _userName;
  String get userEmail => _userEmail;
  List<String> get userStyles {
    final styles = _prefs.getStringList(_userStylesKey);
    if (styles != null && styles.isNotEmpty) return styles;
    final legacyStyle = _prefs.getString(_userStyleKey);
    if (legacyStyle != null && legacyStyle.isNotEmpty) return [legacyStyle];
    return ['Campsites'];
  }

  String get userStyle => userStyles.first;
  bool get notifTrips => _prefs.getBool(_notifTripsKey) ?? true;
  bool get notifWeather => _prefs.getBool(_notifWeatherKey) ?? true;
  bool get notifPermissionAsked =>
      _prefs.getBool(_notifPermissionAskedKey) ?? false;

  Future<void> setUserName(String v) async {
    _userName = v;
    await _secure.write(key: _userNameKey, value: v);
  }

  Future<void> setUserEmail(String v) async {
    _userEmail = v;
    await _secure.write(key: _userEmailKey, value: v);
  }
  Future<void> setUserStyle(String v) async {
    await _prefs.setString(_userStyleKey, v);
    await _prefs.setStringList(_userStylesKey, [v]);
  }

  Future<void> setUserStyles(List<String> values) async {
    final styles = values.where((v) => v.trim().isNotEmpty).toList();
    if (styles.isEmpty) {
      await _prefs.remove(_userStylesKey);
      await _prefs.remove(_userStyleKey);
      return;
    }
    await _prefs.setStringList(_userStylesKey, styles);
    await _prefs.setString(_userStyleKey, styles.first);
  }
  Future<void> setNotifTrips(bool v) => _prefs.setBool(_notifTripsKey, v);
  Future<void> setNotifWeather(bool v) => _prefs.setBool(_notifWeatherKey, v);
  Future<void> setNotifPermissionAsked(bool v) =>
      _prefs.setBool(_notifPermissionAskedKey, v);

  // Current Trip
  TripModel? loadCurrentTrip() {
    final s = _prefs.getString(_tripKey);
    if (s == null) return null;
    try {
      return TripModel.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCurrentTrip(TripModel t) =>
      _prefs.setString(_tripKey, t.toJsonString());

  // Saved Trips
  List<TripModel> loadSavedTrips() {
    final s = _prefs.getString(_savedTripsKey);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list.map((e) => TripModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSavedTrips(List<TripModel> trips) => _prefs.setString(
      _savedTripsKey, jsonEncode(trips.map((e) => e.toJson()).toList()));

  Future<void> saveTrip(TripModel trip) {
    final trips = loadSavedTrips();
    final idx = trips.indexWhere((t) => t.id == trip.id);
    if (idx >= 0)
      trips[idx] = trip;
    else
      trips.insert(0, trip);
    return saveSavedTrips(trips);
  }

  Future<void> deleteTrip(String id) {
    final trips = loadSavedTrips()..removeWhere((t) => t.id == id);
    _deleteScopedValue(_gearByTripKey, id);
    _deleteScopedValue(_mealsByTripKey, id);
    _deleteScopedValue(_budgetByTripKey, id);
    _deleteScopedValue(_budgetTotalByTripKey, id);
    _deleteScopedValue(_emContactsByTripKey, id);
    _deleteScopedValue(_permitsByTripKey, id);
    return saveSavedTrips(trips);
  }

  // Gear
  List<GearItem> loadGear(String tripId) {
    final list = _loadScopedList(_gearByTripKey, tripId);
    if (list == null) return [];
    try {
      return list.map((e) => GearItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveGear(String tripId, List<GearItem> items) =>
      _saveScopedValue(
          _gearByTripKey, tripId, items.map((e) => e.toJson()).toList());

  // Meals
  List<MealItem> loadMeals(String tripId) {
    final list = _loadScopedList(_mealsByTripKey, tripId);
    if (list == null) return [];
    try {
      return list.map((e) => MealItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMeals(String tripId, List<MealItem> meals) =>
      _saveScopedValue(
          _mealsByTripKey, tripId, meals.map((e) => e.toJson()).toList());

  // Budget
  List<BudgetItem> loadBudget(String tripId) {
    final list = _loadScopedList(_budgetByTripKey, tripId);
    if (list == null) return [];
    try {
      return list.map((e) => BudgetItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBudget(String tripId, List<BudgetItem> items) =>
      _saveScopedValue(
          _budgetByTripKey, tripId, items.map((e) => e.toJson()).toList());

  double budgetTotal(String tripId) =>
      (_loadScopedMap(_budgetTotalByTripKey)[tripId] as num?)?.toDouble() ?? 0;
  Future<void> setBudgetTotal(String tripId, double v) =>
      _saveScopedValue(_budgetTotalByTripKey, tripId, v);

  // Emergency Contacts
  List<EmergencyContact> loadEmContacts(String tripId) {
    final list = _loadScopedList(_emContactsByTripKey, tripId);
    if (list == null) return [];
    try {
      return list.map((e) => EmergencyContact.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEmContacts(String tripId, List<EmergencyContact> contacts) =>
      _saveScopedValue(_emContactsByTripKey, tripId,
          contacts.map((e) => e.toJson()).toList());

  // Permits
  List<PermitModel> loadPermits(String tripId) {
    final list = _loadScopedList(_permitsByTripKey, tripId);
    if (list == null) return [];
    try {
      return list.map((e) => PermitModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePermits(String tripId, List<PermitModel> permits) =>
      _saveScopedValue(
          _permitsByTripKey, tripId, permits.map((e) => e.toJson()).toList());

  Future<void> _migrateLegacyTripData() async {
    final currentTrip = loadCurrentTrip();
    if (currentTrip == null) return;

    if (!_loadScopedMap(_gearByTripKey).containsKey(currentTrip.id)) {
      final s = _prefs.getString(_gearKey);
      if (s != null) {
        try {
          final list = jsonDecode(s) as List;
          await _saveScopedValue(_gearByTripKey, currentTrip.id, list);
        } catch (_) {}
      }
    }

    if (!_loadScopedMap(_mealsByTripKey).containsKey(currentTrip.id)) {
      final s = _prefs.getString(_mealsKey);
      if (s != null) {
        try {
          final list = jsonDecode(s) as List;
          await _saveScopedValue(_mealsByTripKey, currentTrip.id, list);
        } catch (_) {}
      }
    }

    if (!_loadScopedMap(_budgetByTripKey).containsKey(currentTrip.id)) {
      final s = _prefs.getString(_budgetKey);
      if (s != null) {
        try {
          final list = jsonDecode(s) as List;
          await _saveScopedValue(_budgetByTripKey, currentTrip.id, list);
        } catch (_) {}
      }
    }

    if (!_loadScopedMap(_budgetTotalByTripKey).containsKey(currentTrip.id) &&
        _prefs.containsKey(_budgetTotalKey)) {
      await _saveScopedValue(_budgetTotalByTripKey, currentTrip.id,
          _prefs.getDouble(_budgetTotalKey) ?? 0);
    }

    if (!_loadScopedMap(_emContactsByTripKey).containsKey(currentTrip.id)) {
      final s = _prefs.getString(_emContactsKey);
      if (s != null) {
        try {
          final list = jsonDecode(s) as List;
          await _saveScopedValue(_emContactsByTripKey, currentTrip.id, list);
        } catch (_) {}
      }
    }

    await _prefs.remove(_gearKey);
    await _prefs.remove(_mealsKey);
    await _prefs.remove(_budgetKey);
    await _prefs.remove(_budgetTotalKey);
    await _prefs.remove(_emContactsKey);
  }

  Map<String, dynamic> _loadScopedMap(String key) {
    final s = _prefs.getString(key);
    if (s == null) return {};
    try {
      final decoded = jsonDecode(s);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  List<dynamic>? _loadScopedList(String key, String tripId) {
    final value = _loadScopedMap(key)[tripId];
    return value is List ? value : null;
  }

  Future<void> _saveScopedValue(String key, String tripId, Object value) {
    final map = _loadScopedMap(key);
    map[tripId] = value;
    return _prefs.setString(key, jsonEncode(map));
  }

  void _deleteScopedValue(String key, String tripId) {
    final map = _loadScopedMap(key);
    if (map.remove(tripId) != null) {
      _prefs.setString(key, jsonEncode(map));
    }
  }
}

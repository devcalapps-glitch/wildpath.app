import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../models/meal_item.dart';
import '../services/storage_service.dart';
import '../services/weather_service.dart';
import '../widgets/common_widgets.dart';

class PlanScreen extends StatefulWidget {
  final StorageService storage;
  final TripModel trip;
  final ValueChanged<TripModel> onTripChanged;
  final VoidCallback? onNewTrip;
  final VoidCallback? onNextTab;
  final ValueChanged<int>? onGoToTab;
  final bool triggerSave;
  final bool triggerSummary;
  final VoidCallback? onFlagHandled;

  const PlanScreen({
    required this.storage,
    required this.trip,
    required this.onTripChanged,
    this.onNewTrip,
    this.onNextTab,
    this.onGoToTab,
    this.triggerSave = false,
    this.triggerSummary = false,
    this.onFlagHandled,
    super.key,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _campsiteCtrl;
  late TextEditingController _permitNumCtrl;
  late TextEditingController _permitTimeCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _groupSizeCtrl;
  Timer? _locationSearchDebounce;
  String? _autocompleteSessionToken;
  List<LocationResult> _locationSuggestions = const [];
  bool _isSearchingLocations = false;
  bool _locationSearchAttempted = false;
  bool _showSummary = false;

  static const _tripTypes = [
    'Campsites',
    'RV or Van',
    'Backpacking',
    'On the Water',
    'Cabins',
    'Off-Grid',
    'Group Camp',
    'Glamping',
  ];

  @override
  void initState() {
    super.initState();
    _initControllers(widget.trip);
  }

  void _initControllers(TripModel t) {
    _nameCtrl = TextEditingController(text: t.name);
    _campsiteCtrl = TextEditingController(text: t.campsite);
    _permitNumCtrl = TextEditingController(text: t.permitNum);
    _permitTimeCtrl = TextEditingController(text: t.permitTime);
    _notesCtrl = TextEditingController(text: t.notes);
    _groupSizeCtrl = TextEditingController(text: t.groupSize.toString());
  }

  @override
  void didUpdateWidget(PlanScreen old) {
    super.didUpdateWidget(old);
    if (old.trip.id != widget.trip.id) {
      _locationSearchDebounce?.cancel();
      _autocompleteSessionToken = null;
      _locationSuggestions = const [];
      _isSearchingLocations = false;
      _locationSearchAttempted = false;
      for (final c in _controllers) c.dispose();
      _initControllers(widget.trip);
    }
    // Trigger save sheet from external source (e.g. Budget page)
    if (widget.triggerSave && !old.triggerSave) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSaveTripSheet();
        widget.onFlagHandled?.call();
      });
    }
    // Trigger switch to Summary tab
    if (widget.triggerSummary && !old.triggerSummary) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showSummary = true);
        widget.onFlagHandled?.call();
      });
    }
  }

  List<TextEditingController> get _controllers => [
        _nameCtrl,
        _campsiteCtrl,
        _permitNumCtrl,
        _permitTimeCtrl,
        _notesCtrl,
        _groupSizeCtrl
      ];

  @override
  void dispose() {
    _locationSearchDebounce?.cancel();
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  void _update(TripModel t) {
    widget.onTripChanged(t);
    widget.storage.saveCurrentTrip(t);
  }

  TripModel get _trip => widget.trip;

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_trip.startDate.isNotEmpty ? DateTime.parse(_trip.startDate) : now)
        : (_trip.endDate.isNotEmpty ? DateTime.parse(_trip.endDate) : now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
                primary: WildPathColors.forest,
                onPrimary: Colors.white,
                surface: Colors.white)),
        child: child!,
      ),
    );
    if (picked == null) return;
    final s =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    _update(
        isStart ? _trip.copyWith(startDate: s) : _trip.copyWith(endDate: s));
    setState(() {});
  }

  void _saveTrip() => _showSaveTripSheet();

  void _showSaveTripSheet() {
    final nameCtrl = TextEditingController(
      text: _trip.name.isNotEmpty ? _trip.name : _trip.campsite,
    );
    final gearItems = widget.storage.loadGear(_trip.id);
    final gearTotal = gearItems.length;
    final gearPacked = gearItems.where((i) => i.checked).length;
    final allMeals = widget.storage.loadMeals(_trip.id);
    final tripDays = _trip.tripDays;
    final totalSlots = tripDays.length * MealType.values.length;
    int filledSlots = 0;
    for (final d in tripDays) {
      final k =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      for (final mt in MealType.values) {
        if (allMeals.any((m) => m.dateKey == k && m.mealType == mt))
          filledSlots++;
      }
    }
    final budgetSpent = widget.storage
        .loadBudget(_trip.id)
        .fold<double>(0, (s, i) => s + i.amount);
    final budgetLimit = widget.storage.budgetTotal(_trip.id);

    // Build still-to-do list
    // gearTotal == 0 means gear screen was never visited (nothing saved yet)
    final todos = <Map<String, dynamic>>[];
    if (gearTotal == 0 || (gearPacked == 0 && gearTotal > 0))
      todos.add(
          {'e': '🎒', 't': 'Gear not started', 'a': 'START PACKING', 'tab': 1});
    else if (gearPacked < gearTotal)
      todos.add({
        'e': '🎒',
        't': '${gearTotal - gearPacked} items to pack',
        'a': 'CONTINUE',
        'tab': 1
      });
    if (filledSlots == 0 && totalSlots > 0)
      todos.add(
          {'e': '🍳', 't': 'No meals planned', 'a': 'PLAN MEALS', 'tab': 2});
    else if (filledSlots < totalSlots && totalSlots > 0)
      todos.add({
        'e': '🍳',
        't': '${totalSlots - filledSlots} meals to plan',
        'a': 'ADD MEALS',
        'tab': 2
      });
    if (budgetSpent == 0)
      todos.add(
          {'e': '💰', 't': 'No budget tracked', 'a': 'ADD EXPENSES', 'tab': 4});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                      child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: WildPathColors.mist,
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 20),
                  // Title
                  Row(children: [
                    const Text('💾', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Text('Save to My Trips',
                        style: WildPathTypography.display(
                            fontSize: 24, color: WildPathColors.pine)),
                  ]),
                  const SizedBox(height: 4),
                  Text("Give your trip a name and review what's included",
                      style: WildPathTypography.body(
                          fontSize: 13,
                          color: WildPathColors.smoke,
                          height: 1.5)),
                  const SizedBox(height: 20),
                  // Trip name field
                  Text('TRIP NAME',
                      style: WildPathTypography.body(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: WildPathColors.smoke)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    style: WildPathTypography.body(
                        fontSize: 16, color: WildPathColors.pine),
                    decoration: InputDecoration(
                      hintText: 'e.g. Lost Coast Weekend',
                      hintStyle: WildPathTypography.body(
                          fontSize: 15, color: WildPathColors.stone),
                      filled: true,
                      fillColor: WildPathColors.cream,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Snapshot card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: WildPathColors.cream,
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _snapItem(
                                    'LOCATION',
                                    _trip.campsite.isNotEmpty
                                        ? _trip.campsite
                                        : '—')),
                            Expanded(
                                child: _snapItem(
                                    'DATES',
                                    _trip.startDate.isNotEmpty
                                        ? '${_trip.startDate} →\n${_trip.endDate}'
                                        : '—')),
                          ]),
                      const SizedBox(height: 14),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _snapItem(
                                    'GEAR',
                                    gearTotal == 0
                                        ? 'Not started'
                                        : '$gearPacked/$gearTotal packed')),
                            Expanded(
                                child: _snapItem(
                                    'MEALS',
                                    totalSlots > 0
                                        ? '$filledSlots of $totalSlots planned'
                                        : '—')),
                          ]),
                      const SizedBox(height: 14),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _snapItem('GROUP',
                                    '${_trip.groupSize} ${_trip.groupSize == 1 ? "person" : "people"}')),
                            Expanded(
                                child: _snapItem(
                                    'BUDGET',
                                    budgetLimit > 0
                                        ? '\$${budgetSpent.toStringAsFixed(0)} / \$${budgetLimit.toStringAsFixed(0)}'
                                        : budgetSpent > 0
                                            ? '\$${budgetSpent.toStringAsFixed(0)} spent'
                                            : 'Not tracked')),
                          ]),
                    ]),
                  ),
                  // Still to do
                  if (todos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      const Text('💡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('STILL TO DO',
                          style: WildPathTypography.body(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: WildPathColors.amber,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    ...todos.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Text(item['e'] as String,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(item['t'] as String,
                                    style: WildPathTypography.body(
                                        fontSize: 13,
                                        color: WildPathColors.smoke))),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                widget.onGoToTab?.call(item['tab'] as int);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: WildPathColors.forest, width: 1.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(item['a'] as String,
                                    style: WildPathTypography.body(
                                        fontSize: 10,
                                        letterSpacing: 0.8,
                                        color: WildPathColors.forest,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ]),
                        )),
                  ],
                  const SizedBox(height: 20),
                  // Save + Cancel buttons
                  Row(children: [
                    Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            final toSave = _trip.copyWith(
                              name: name.isNotEmpty ? name : _trip.name,
                              savedAt: DateTime.now().toIso8601String(),
                            );
                            if (name.isNotEmpty && name != _trip.name)
                              _update(toSave);
                            await widget.storage.saveTrip(toSave);
                            if (context.mounted) Navigator.pop(context);
                            if (mounted) {
                              setState(() => _showSummary = true);
                              showWildToast(context, 'Saved to My Trips');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('💾',
                                      style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text('SAVE TO MY TRIPS',
                                      style: WildPathTypography.body(
                                          fontSize: 12,
                                          letterSpacing: 1.1,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ]),
                          ),
                        )),
                    const SizedBox(width: 10),
                    Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            side: const BorderSide(
                                color: WildPathColors.mist, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('CANCEL',
                              style: WildPathTypography.body(
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: WildPathColors.smoke)),
                        )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _snapItem(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: WildPathTypography.body(
                  fontSize: 9.5,
                  letterSpacing: 1,
                  color: WildPathColors.smoke)),
          const SizedBox(height: 3),
          Text(value,
              style: WildPathTypography.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: WildPathColors.pine,
                  height: 1.4)),
        ],
      );

  void _newTrip() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('New Trip?',
                  style: WildPathTypography.display(fontSize: 20)),
              content: Text('Save first if you want to keep the current plan.',
                  style: WildPathTypography.body(
                      fontSize: 13, color: WildPathColors.smoke)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: WildPathTypography.body(
                            color: WildPathColors.smoke))),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      final t = TripModel(id: const Uuid().v4());
                      for (final c in _controllers) c.clear();
                      _groupSizeCtrl.text = '1';
                      setState(() => _showSummary = false);
                      _update(t);
                    },
                    child: const Text('New Trip')),
              ],
            ));
  }

  String _fmtShort(String? d) {
    if (d == null || d.isEmpty) return '—';
    try {
      final dt = DateTime.parse(d);
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${m[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return '—';
    }
  }

  String _fmtFull(String? d) {
    if (d == null || d.isEmpty) return 'Pick a date';
    try {
      final dt = DateTime.parse(d);
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  void _onLocationChanged(String value) {
    _update(_trip.copyWith(campsite: value, lat: null, lng: null));
    _queueLocationSearch(value);
  }

  void _queueLocationSearch(String query) {
    _locationSearchDebounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.length < 2 || !WeatherService.hasGoogleGeocodingApiKey) {
      if (_locationSuggestions.isNotEmpty ||
          _isSearchingLocations ||
          _locationSearchAttempted) {
        setState(() {
          _locationSuggestions = const [];
          _isSearchingLocations = false;
          _locationSearchAttempted = false;
          _autocompleteSessionToken = null;
        });
      }
      return;
    }

    _autocompleteSessionToken ??= const Uuid().v4();

    setState(() {
      _isSearchingLocations = true;
      _locationSearchAttempted = false;
    });

    _locationSearchDebounce =
        Timer(const Duration(milliseconds: 500), () async {
      final sessionToken = _autocompleteSessionToken;
      final results = await WeatherService.searchLocations(
        trimmed,
        sessionToken: sessionToken,
      );
      if (!mounted || _campsiteCtrl.text.trim() != trimmed) return;
      setState(() {
        _locationSuggestions = results;
        _isSearchingLocations = false;
        _locationSearchAttempted = true;
      });
    });
  }

  Future<void> _resolveTypedLocation() async {
    _locationSearchDebounce?.cancel();
    final query = _campsiteCtrl.text.trim();
    if (query.length < 2) {
      setState(() {
        _locationSuggestions = const [];
        _isSearchingLocations = false;
        _locationSearchAttempted = false;
        _autocompleteSessionToken = null;
      });
      return;
    }

    if (!WeatherService.hasGoogleGeocodingApiKey) {
      showWildToast(context, 'Google Places is not configured');
      return;
    }

    _autocompleteSessionToken ??= const Uuid().v4();

    setState(() {
      _isSearchingLocations = true;
      _locationSearchAttempted = false;
    });

    List<LocationResult> suggestions;
    try {
      suggestions = await WeatherService.searchLocations(
        query,
        limit: 1,
        sessionToken: _autocompleteSessionToken,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationSuggestions = const [];
        _isSearchingLocations = false;
        _locationSearchAttempted = true;
      });
      showWildToast(context, 'Location error: $e');
      return;
    }
    if (!mounted) return;

    if (suggestions.isEmpty) {
      setState(() {
        _locationSuggestions = const [];
        _isSearchingLocations = false;
        _locationSearchAttempted = true;
      });
      showWildToast(context, 'No matching location found');
      return;
    }

    await _selectLocationSuggestion(suggestions.first);
  }

  Future<void> _selectLocationSuggestion(LocationResult result) async {
    _locationSearchDebounce?.cancel();
    setState(() {
      _isSearchingLocations = true;
      _locationSearchAttempted = false;
    });

    final resolved = result.hasCoordinates
        ? result
        : await WeatherService.resolvePlace(
            result.placeId ?? '',
            sessionToken: _autocompleteSessionToken,
          );
    if (!mounted) return;

    if (resolved == null || !resolved.hasCoordinates) {
      setState(() {
        _isSearchingLocations = false;
        _locationSearchAttempted = true;
      });
      showWildToast(context, 'Could not load location details');
      return;
    }

    _autocompleteSessionToken = null;
    _campsiteCtrl
      ..text = resolved.displayName
      ..selection =
          TextSelection.collapsed(offset: resolved.displayName.length);
    FocusScope.of(context).unfocus();
    setState(() {
      _locationSuggestions = const [];
      _isSearchingLocations = false;
      _locationSearchAttempted = false;
    });
    _update(_trip.copyWith(
      campsite: resolved.displayName,
      lat: resolved.lat,
      lng: resolved.lng,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Plan / Summary toggle
      Container(
        color: WildPathColors.forest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _tabChip('PLAN', !_showSummary,
              () => setState(() => _showSummary = false)),
          const SizedBox(width: 8),
          _tabChip('SUMMARY', _showSummary,
              () => setState(() => _showSummary = true)),
          const Spacer(),
          GestureDetector(
            onTap: widget.onNewTrip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('+ NEW TRIP',
                  style: WildPathTypography.body(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: _showSummary ? _buildSummary() : _buildForm(),
        ),
      ),
    ]);
  }

  Widget _tabChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? Colors.white : Colors.white.withOpacity(0.35),
                width: 1.5),
          ),
          child: Text(label,
              style: WildPathTypography.body(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: active ? WildPathColors.forest : Colors.white,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ),
      );

  // ── PLAN FORM ────────────────────────────────────────────────────────────

  Widget _buildForm() {
    final allMeals = widget.storage.loadMeals(_trip.id);
    final tripDays = _trip.tripDays;
    int plannedMeals = 0;
    for (final d in tripDays) {
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      for (final mt in MealType.values) {
        if (allMeals.any((m) => m.dateKey == key && m.mealType == mt)) {
          plannedMeals++;
        }
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageTitle('Trip Planner',
          subtitle: 'Changes are auto-saved as a draft'),
      const SizedBox(height: 16),
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: WildPathColors.mist.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WildPathColors.mist, width: 1.2),
        ),
        child: Row(children: [
          const Text('💾', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your draft updates save automatically. Use "Save to My Trips" when you want to store this trip in My Trips.',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.forest, height: 1.45),
            ),
          ),
        ]),
      ),
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Trip Info'),
        _field('TRIP NAME', _nameCtrl, 'e.g. Lost Coast Weekend',
            onChanged: (v) => _update(_trip.copyWith(name: v))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _field('GROUP SIZE', _groupSizeCtrl, '1',
                  type: TextInputType.number,
                  onChanged: (v) => _update(_trip.copyWith(
                      groupSize: (int.tryParse(v) ?? 1).clamp(1, 500))))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('TRIP TYPE',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: WildPathColors.smoke)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                      color: WildPathColors.cream,
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                    value: _trip.tripType,
                    isExpanded: true,
                    style: WildPathTypography.body(
                        fontSize: 13, color: WildPathColors.pine),
                    items: _tripTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _update(_trip.copyWith(tripType: v));
                    },
                  )),
                ),
              ])),
        ]),
      ])),
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Location & Dates'),
        _locationField(),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _datePicker(
                  'START DATE', _trip.startDate, () => _pickDate(true))),
          const SizedBox(width: 10),
          Expanded(
              child: _datePicker(
                  'END DATE', _trip.endDate, () => _pickDate(false))),
        ]),
      ])),
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Permit & Notes'),
        Row(children: [
          Expanded(
              child: _field('PERMIT #', _permitNumCtrl, 'Optional',
                  onChanged: (v) => _update(_trip.copyWith(permitNum: v)))),
          const SizedBox(width: 10),
          Expanded(
              child: _field('ENTRY TIME', _permitTimeCtrl, 'e.g. 10:00',
                  onChanged: (v) => _update(_trip.copyWith(permitTime: v)))),
        ]),
        const SizedBox(height: 14),
        Text('NOTES',
            style: WildPathTypography.body(
                fontSize: 10, letterSpacing: 1.2, color: WildPathColors.smoke)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          style:
              WildPathTypography.body(fontSize: 14, color: WildPathColors.pine),
          decoration: InputDecoration(
            hintText: 'Trail conditions, campsite notes, reminders...',
            hintStyle: WildPathTypography.body(
                fontSize: 13, color: WildPathColors.stone),
            filled: true,
            fillColor: WildPathColors.cream,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (v) => _update(_trip.copyWith(notes: v)),
        ),
      ])),
      StatsRow([
        StatItem(value: '${_trip.nights}', label: 'Nights'),
        StatItem(value: '${_trip.groupSize}', label: 'Campers'),
        StatItem(value: '$plannedMeals', label: 'Meals Planned'),
      ]),
      Row(children: [
        Expanded(
            child: OutlineButton2('Save to My Trips', onPressed: _saveTrip)),
        const SizedBox(width: 10),
        Expanded(child: GhostButton('New Trip', onPressed: _newTrip)),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: widget.onNextTab,
          style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: Text('Next: Pack Your Gear →',
              style: WildPathTypography.body(
                  fontSize: 13,
                  letterSpacing: 1.04,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    ]);
  }

  // ── SUMMARY (matches screenshot) ─────────────────────────────────────────

  Widget _buildSummary() {
    final t = widget.trip;

    // Live gear data
    final gearItems = widget.storage.loadGear(t.id);
    final gearTotal = gearItems.length;
    final gearPacked = gearItems.where((i) => i.checked).length;
    final gearPct = gearTotal > 0 ? (gearPacked / gearTotal * 100).round() : 0;
    final gearLeft = gearTotal - gearPacked;

    // Live meal data
    final allMeals = widget.storage.loadMeals(t.id);
    final tripDays = t.tripDays;
    final totalSlots = tripDays.length * MealType.values.length;
    int filledSlots = 0;
    for (final d in tripDays) {
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      for (final mt in MealType.values) {
        if (allMeals.any((m) => m.dateKey == key && m.mealType == mt))
          filledSlots++;
      }
    }
    final mealsAllPlanned = totalSlots > 0 && filledSlots == totalSlots;

    // Live budget data
    final budgetItems = widget.storage.loadBudget(t.id);
    final budgetSpent = budgetItems.fold<double>(0, (s, i) => s + i.amount);
    final budgetLimit = widget.storage.budgetTotal(t.id);
    final budgetRemain = budgetLimit > 0 ? budgetLimit - budgetSpent : 0.0;

    // Category breakdown for budget
    final catTotals = <String, double>{};
    for (final item in budgetItems) {
      final label = item.category.label;
      catTotals[label] = (catTotals[label] ?? 0) + item.amount;
    }
    final topCat = catTotals.entries.isEmpty
        ? null
        : catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Hero card ────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [WildPathColors.forest, WildPathColors.moss],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.name.isNotEmpty ? t.name : 'Your Trip',
              style: WildPathTypography.display(
                  fontSize: 22, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            [t.tripType, if (t.campsite.isNotEmpty) t.campsite].join(' · '),
            style: WildPathTypography.body(
                fontSize: 12, color: Colors.white.withOpacity(0.75)),
          ),
          const SizedBox(height: 16),
          // 2-column grid of meta items
          Row(children: [
            Expanded(
                child: _heroItem(
                    'LOCATION', t.campsite.isNotEmpty ? t.campsite : '—')),
            Expanded(
                child: _heroItem(
                    'DATES',
                    t.startDate.isNotEmpty
                        ? '${_fmtShort(t.startDate)} –\n${_fmtShort(t.endDate)}, ${DateTime.parse(t.endDate).year}'
                        : '—')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _heroItem(
                    'DURATION',
                    t.nights > 0
                        ? '${t.nights} night${t.nights == 1 ? '' : 's'}'
                        : '—')),
            Expanded(
                child: _heroItem('GROUP',
                    '${t.groupSize} ${t.groupSize == 1 ? 'camper' : 'campers'}')),
          ]),
        ]),
      ),
      const SizedBox(height: 12),

      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [WildPathColors.forest, WildPathColors.moss],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('⛅', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Check the forecast',
                  style: WildPathTypography.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text(
                'Verify conditions 48-72 hrs before you go',
                style: WildPathTypography.body(
                    fontSize: 12, color: Colors.white.withOpacity(0.75)),
                softWrap: true,
              ),
            ]),
          ),
        ]),
      ),

      // ── Packing Readiness ────────────────────────────────────────────────
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WildProgressBar(
          progress: gearTotal > 0 ? gearPacked / gearTotal : 0,
          title: 'PACKING READINESS',
          countLabel: '$gearPacked / $gearTotal ($gearPct%)',
        ),
        if (gearLeft > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Text('⚠',
                style: TextStyle(fontSize: 14, color: WildPathColors.amber)),
            const SizedBox(width: 6),
            Text('$gearLeft item${gearLeft == 1 ? '' : 's'} still to pack',
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.amber)),
          ]),
        ] else if (gearTotal > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Text('✓',
                style: TextStyle(fontSize: 14, color: WildPathColors.moss)),
            const SizedBox(width: 6),
            Text('All packed!',
                style: WildPathTypography.body(
                    fontSize: 12,
                    color: WildPathColors.moss,
                    fontWeight: FontWeight.w700)),
          ]),
        ],
        const SizedBox(height: 12),
        _actionButton(
          gearLeft > 0 ? 'CONTINUE PACKING →' : 'VIEW GEAR LIST →',
          WildPathColors.moss,
          () => widget.onGoToTab?.call(1),
        ),
      ])),

      // ── Meal Plan ────────────────────────────────────────────────────────
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WildProgressBar(
          progress: totalSlots > 0 ? filledSlots / totalSlots : 0,
          title: 'MEAL PLAN',
          countLabel: totalSlots > 0 ? '$filledSlots / $totalSlots meals' : '—',
          barColor: WildPathColors.amber,
        ),
        const SizedBox(height: 10),
        if (mealsAllPlanned)
          Row(children: [
            const Text('✓',
                style: TextStyle(fontSize: 14, color: WildPathColors.moss)),
            const SizedBox(width: 6),
            Text('All meals planned!',
                style: WildPathTypography.body(
                    fontSize: 12,
                    color: WildPathColors.moss,
                    fontWeight: FontWeight.w700)),
          ])
        else if (totalSlots == 0)
          Text('Set trip dates to plan meals',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke))
        else
          Text(
              '${totalSlots - filledSlots} meal${(totalSlots - filledSlots) == 1 ? '' : 's'} to plan',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.amber)),
        if (!mealsAllPlanned && totalSlots > 0) ...[
          const SizedBox(height: 12),
          _actionButton('PLAN MORE MEALS →', WildPathColors.amber,
              () => widget.onGoToTab?.call(2)),
        ],
      ])),

      // ── Trip Budget ──────────────────────────────────────────────────────
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TRIP BUDGET',
            style: WildPathTypography.body(
                fontSize: 10, letterSpacing: 1.4, color: WildPathColors.amber)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final metricGap = compact ? 8.0 : 12.0;
          return Row(children: [
            Expanded(
                child: _budgetMetric(
              '\$${budgetSpent.toStringAsFixed(2)}',
              'SPENT',
              WildPathColors.forest,
              compact: compact,
            )),
            SizedBox(width: metricGap),
            Expanded(
                child: _budgetMetric(
              budgetLimit > 0 ? '\$${budgetRemain.toStringAsFixed(2)}' : '—',
              'REMAINING',
              budgetLimit > 0 && budgetRemain < 0
                  ? WildPathColors.red
                  : WildPathColors.moss,
              compact: compact,
            )),
            SizedBox(width: metricGap),
            Expanded(
                child: _budgetMetric(
              '${budgetItems.length}',
              'EXPENSES',
              WildPathColors.smoke,
              compact: compact,
            )),
          ]);
        }),
        if (topCat != null) ...[
          const SizedBox(height: 10),
          Container(height: 1, color: WildPathColors.mist),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: Text(topCat.key,
                    style: WildPathTypography.body(
                        fontSize: 12, color: WildPathColors.pine),
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            Flexible(
                child: Text(
              '\$${topCat.value.toStringAsFixed(2)}${budgetSpent > 0 ? ' · ${(topCat.value / budgetSpent * 100).round()}%' : ''}',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke),
              textAlign: TextAlign.right,
            )),
          ]),
        ],
        const SizedBox(height: 12),
        _actionButton('VIEW FULL BUDGET →', WildPathColors.stone,
            () => widget.onGoToTab?.call(4)),
      ])),

      const WildDivider(),

      // ── Emergency Info ───────────────────────────────────────────────────
      Text('Emergency Info',
          style: WildPathTypography.display(
              fontSize: 20, color: WildPathColors.red)),
      const SizedBox(height: 12),

      // 911 + USFS side by side
      Row(children: [
        Expanded(
            child: _dialCard('911', 'Emergency', WildPathColors.red,
                isLarge: true)),
        const SizedBox(width: 10),
        Expanded(
            child: _dialCard('USFS', '1-877-444-6777', WildPathColors.forest)),
      ]),
      const SizedBox(height: 10),
      // NPS full width
      _dialCard('NPS', '1-800-922-0399', WildPathColors.forest,
          fullWidth: true),
      const SizedBox(height: 12),

      // Trip info for rescuers
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TRIP INFO FOR RESCUERS',
            style: WildPathTypography.body(
                fontSize: 10, letterSpacing: 1.2, color: WildPathColors.smoke)),
        const SizedBox(height: 10),
        _rescuerRow('Trip', t.name.isNotEmpty ? t.name : '—'),
        _rescuerRow('Location', t.campsite.isNotEmpty ? t.campsite : '—'),
        if (t.startDate.isNotEmpty)
          _rescuerRow('Dates', '${t.startDate} → ${t.endDate}'),
        _rescuerRow('Group',
            '${t.groupSize} ${t.groupSize == 1 ? "person" : "people"}'),
        _rescuerRow('Type', t.tripType),
        if (t.permitNum.isNotEmpty) _rescuerRow('Permit', t.permitNum),
      ])),

      TipCard(
        emoji: 'SOS',
        content:
            'Signal for help: 3 whistle blasts, 3 fires in a triangle, or wave bright clothing. The universal distress signal is groups of 3.',
        bgColor: WildPathColors.red.withOpacity(0.06),
        borderColor: WildPathColors.red.withOpacity(0.2),
      ),
      TipCard(
        emoji: '📡',
        content:
            'No signal? Move to high ground or a clearing. Text messages often send when calls won\'t. Try 911 even with 0 bars.',
        bgColor: WildPathColors.red.withOpacity(0.06),
        borderColor: WildPathColors.red.withOpacity(0.2),
      ),

      const WildDivider(),

      // ── Essential Tips ───────────────────────────────────────────────────
      Text('Essential Tips',
          style: WildPathTypography.display(
              fontSize: 20, color: WildPathColors.forest)),
      const SizedBox(height: 12),
      const TipCard(
          emoji: '🐻',
          content:
              'Bear safety: Store food 200 ft from camp in a bear canister or hung 10 ft off the ground.'),
      const TipCard(
          emoji: '🔥',
          content:
              'Fire safety: Check local restrictions. Drown, stir, feel — make sure fire is cold.'),
      const TipCard(
          emoji: '💧',
          content:
              'Water: Always filter or treat backcountry water. Bring a filter and backup tablets.'),
      const TipCard(
          emoji: '🗺',
          content:
              'Navigation: Download offline maps before you go. Carry a physical map and compass.'),
      const TipCard(
          emoji: '🌡',
          content:
              'Layering: Nights can be 20-30 degrees cooler. Pack one extra insulation layer.'),

      const WildDivider(),

      // ── Actions ──────────────────────────────────────────────────────────
      Row(children: [
        Expanded(
            child: PrimaryButton('Save to My Trips', onPressed: _saveTrip)),
        const SizedBox(width: 10),
        Expanded(
            child: OutlineButton2('Share', onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: _buildSummaryClipboardText()),
          );
          if (context.mounted) {
            showWildToast(context, 'Summary copied!');
          }
        })),
      ]),
    ]);
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  String _buildSummaryClipboardText() {
    final t = widget.trip;
    final gearItems = widget.storage.loadGear(t.id);
    final gearPacked = gearItems.where((i) => i.checked).length;
    final gearTotal = gearItems.length;

    final allMeals = widget.storage.loadMeals(t.id);
    final tripDays = t.tripDays;
    final totalSlots = tripDays.length * MealType.values.length;
    int filledSlots = 0;
    for (final d in tripDays) {
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      for (final mt in MealType.values) {
        if (allMeals.any((m) => m.dateKey == key && m.mealType == mt)) {
          filledSlots++;
        }
      }
    }

    final budgetItems = widget.storage.loadBudget(t.id);
    final budgetSpent =
        budgetItems.fold<double>(0, (sum, item) => sum + item.amount);
    final budgetLimit = widget.storage.budgetTotal(t.id);

    final lines = <String>[
      'WildPath Trip Summary',
      if (t.name.isNotEmpty) 'Trip: ${t.name}',
      if (t.tripType.isNotEmpty) 'Type: ${t.tripType}',
      if (t.campsite.isNotEmpty) 'Location: ${t.campsite}',
      if (t.startDate.isNotEmpty) 'Dates: ${t.startDate} to ${t.endDate}',
      'Group: ${t.groupSize} ${t.groupSize == 1 ? 'person' : 'people'}',
      'Nights: ${t.nights}',
      'Gear: $gearPacked / $gearTotal packed',
      if (totalSlots > 0) 'Meals: $filledSlots / $totalSlots planned',
      if (budgetLimit > 0)
        'Budget: \$${budgetSpent.toStringAsFixed(2)} spent of \$${budgetLimit.toStringAsFixed(2)}'
      else if (budgetSpent > 0)
        'Budget: \$${budgetSpent.toStringAsFixed(2)} spent',
      if (t.permitNum.isNotEmpty) 'Permit: ${t.permitNum}',
      if (t.notes.isNotEmpty) 'Notes: ${t.notes}',
    ];

    return lines.join('\n');
  }

  Widget _heroItem(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: WildPathTypography.body(
                  fontSize: 9.5,
                  letterSpacing: 1,
                  color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 3),
          Text(value,
              style: WildPathTypography.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ],
      );

  Widget _dialCard(String label, String sub, Color color,
          {bool isLarge = false, bool fullWidth = false}) =>
      Container(
        width: fullWidth ? double.infinity : null,
        padding:
            EdgeInsets.symmetric(vertical: isLarge ? 16 : 12, horizontal: 8),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (isLarge) ...[
            const Icon(Icons.phone, color: Colors.white, size: 18),
            const SizedBox(width: 6),
          ],
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: WildPathTypography.body(
                    fontSize: isLarge ? 18 : 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                textAlign: TextAlign.center),
            Text(sub,
                style: WildPathTypography.body(
                    fontSize: 10, color: Colors.white.withOpacity(0.85)),
                textAlign: TextAlign.center),
          ]),
        ]),
      );

  Widget _rescuerRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: WildPathTypography.body(
                      fontSize: 12, color: WildPathColors.smoke))),
          Expanded(
              child: Text(value,
                  style: WildPathTypography.body(
                      fontSize: 12, color: WildPathColors.pine))),
        ]),
      );

  Widget _budgetMetric(String value, String label, Color valueColor,
          {bool compact = false}) =>
      Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: double.infinity,
            height: compact ? 34 : 38,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: WildPathTypography.display(
                      fontSize: compact ? 22 : 26, color: valueColor)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: WildPathTypography.body(
                  fontSize: 9,
                  letterSpacing: 0.9,
                  color: WildPathColors.smoke)),
        ]),
      );

  Widget _actionButton(String label, Color color, VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: WildPathTypography.body(
                  fontSize: 11,
                  letterSpacing: 0.88,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ),
      );

  Widget _field(String label, TextEditingController ctrl, String hint,
          {TextInputType type = TextInputType.text,
          ValueChanged<String>? onChanged}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: WildPathTypography.body(
                fontSize: 10, letterSpacing: 1.2, color: WildPathColors.smoke)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          onChanged: onChanged,
          style:
              WildPathTypography.body(fontSize: 14, color: WildPathColors.pine),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: WildPathTypography.body(
                fontSize: 13, color: WildPathColors.stone),
            filled: true,
            fillColor: WildPathColors.cream,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]);

  Widget _locationField() {
    final isLocationSearchConfigured = WeatherService.hasGoogleGeocodingApiKey;
    final hasVerifiedLocation = _trip.lat != null && _trip.lng != null;
    final showSuggestions =
        _isSearchingLocations || _locationSuggestions.isNotEmpty;
    final showNoResults = !_isSearchingLocations &&
        isLocationSearchConfigured &&
        _locationSearchAttempted &&
        _campsiteCtrl.text.trim().length >= 2 &&
        _locationSuggestions.isEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('LOCATION / CAMPSITE',
          style: WildPathTypography.body(
              fontSize: 10, letterSpacing: 1.2, color: WildPathColors.smoke)),
      const SizedBox(height: 6),
      TextFormField(
        controller: _campsiteCtrl,
        keyboardType: TextInputType.streetAddress,
        textInputAction: TextInputAction.search,
        onChanged: _onLocationChanged,
        onFieldSubmitted: (_) => _resolveTypedLocation(),
        style:
            WildPathTypography.body(fontSize: 14, color: WildPathColors.pine),
        decoration: InputDecoration(
          hintText: 'Search for a park, city, or campsite',
          hintStyle: WildPathTypography.body(
              fontSize: 13, color: WildPathColors.stone),
          filled: true,
          fillColor: WildPathColors.cream,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: _isSearchingLocations
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : hasVerifiedLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.verified_rounded,
                          size: 20, color: WildPathColors.forest),
                    )
                  : IconButton(
                      onPressed: _resolveTypedLocation,
                      icon: const Icon(Icons.search_rounded,
                          size: 20, color: WildPathColors.smoke),
                      tooltip: 'Search address',
                    ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        !isLocationSearchConfigured
            ? 'Google Places is not configured. Add MAPS_API_KEY in .env.'
            : hasVerifiedLocation
                ? 'Verified map coordinates saved for this trip.'
                : 'Type at least 2 characters to see matching places. Tap a result to save verified coordinates.',
        style: WildPathTypography.body(
            fontSize: 11,
            color: hasVerifiedLocation
                ? WildPathColors.moss
                : WildPathColors.smoke),
      ),
      if (hasVerifiedLocation) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: WildPathColors.mist.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: WildPathColors.mist, width: 1.1),
          ),
          child: Text(
            '${_trip.lat!.toStringAsFixed(5)}, ${_trip.lng!.toStringAsFixed(5)}',
            style: WildPathTypography.body(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WildPathColors.forest),
          ),
        ),
      ],
      if (showSuggestions) ...[
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WildPathColors.mist, width: 1.2),
          ),
          child: Column(
            children: _isSearchingLocations
                ? [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Searching locations...',
                          style: WildPathTypography.body(
                              fontSize: 12, color: WildPathColors.smoke),
                        ),
                      ]),
                    ),
                  ]
                : _locationSuggestions
                    .map((result) => InkWell(
                          onTap: () => _selectLocationSuggestion(result),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(Icons.place_outlined,
                                      size: 18, color: WildPathColors.forest),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result.displayName
                                            .split(',')
                                            .first
                                            .trim(),
                                        style: WildPathTypography.body(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: WildPathColors.pine),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        result.displayName,
                                        style: WildPathTypography.body(
                                            fontSize: 11,
                                            color: WildPathColors.smoke,
                                            height: 1.45),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tap to use this location',
                                        style: WildPathTypography.body(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: WildPathColors.moss),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
          ),
        ),
      ] else if (showNoResults) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: WildPathColors.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WildPathColors.mist, width: 1.2),
          ),
          child: Text(
            'No matching locations found yet. Try a broader search like the park or city name.',
            style: WildPathTypography.body(
                fontSize: 11, color: WildPathColors.smoke, height: 1.45),
          ),
        ),
      ],
    ]);
  }

  Widget _datePicker(String label, String current, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: WildPathColors.smoke)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: WildPathColors.cream,
                borderRadius: BorderRadius.circular(10)),
            child: Text(_fmtFull(current),
                style: WildPathTypography.body(
                    fontSize: 13,
                    color: current.isNotEmpty
                        ? WildPathColors.pine
                        : WildPathColors.stone)),
          ),
        ]),
      );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../models/meal_item.dart';
import '../services/storage_service.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';
import '../widgets/common_widgets.dart';

class PlanScreen extends StatefulWidget {
  final StorageService storage;
  final TripModel trip;
  final ValueChanged<TripModel> onTripChanged;
  final VoidCallback? onNewTrip;
  final VoidCallback? onNextTab;
  final ValueChanged<int>? onGoToTab;
  final VoidCallback? onViewSavedTrips;
  final bool triggerSave;
  final VoidCallback? onFlagHandled;
  final ValueChanged<VoidCallback>? onRegisterScrollToTop;

  const PlanScreen({
    required this.storage,
    required this.trip,
    required this.onTripChanged,
    this.onNewTrip,
    this.onNextTab,
    this.onGoToTab,
    this.onViewSavedTrips,
    this.triggerSave = false,
    this.onFlagHandled,
    this.onRegisterScrollToTop,
    super.key,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _campsiteCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _groupSizeCtrl;
  Timer? _locationSearchDebounce;
  String? _autocompleteSessionToken;
  List<LocationResult> _locationSuggestions = const [];
  bool _isSearchingLocations = false;
  bool _locationSearchAttempted = false;
  bool _isPreviouslySaved = false;
  bool _isDirty = false;
  final ScrollController _formScrollController = ScrollController();
  final GlobalKey _locationFieldKey = GlobalKey();
  final FocusNode _locationFocusNode = FocusNode();

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
    _checkIfSaved(widget.trip.id);
    widget.onRegisterScrollToTop?.call(() {
      if (_formScrollController.hasClients) {
        _formScrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _checkIfSaved(String tripId) {
    _isPreviouslySaved =
        widget.storage.loadSavedTrips().any((t) => t.id == tripId);
    _isDirty = false;
  }

  void _initControllers(TripModel t) {
    _nameCtrl = TextEditingController(text: t.name);
    _campsiteCtrl = TextEditingController(text: t.campsite);
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
      for (final c in _controllers) {
        c.dispose();
      }
      _initControllers(widget.trip);
      _checkIfSaved(widget.trip.id);
    }
    // Trigger save sheet from external source (e.g. Budget page)
    if (widget.triggerSave && !old.triggerSave) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSaveTripSheet();
        widget.onFlagHandled?.call();
      });
    }
  }

  List<TextEditingController> get _controllers =>
      [_nameCtrl, _campsiteCtrl, _notesCtrl, _groupSizeCtrl];

  @override
  void dispose() {
    _locationSearchDebounce?.cancel();
    _formScrollController.dispose();
    _locationFocusNode.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _scrollToLocationField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _locationFieldKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.0);
      }
    });
  }

  void _update(TripModel t) {
    widget.onTripChanged(t);
    widget.storage.saveCurrentTrip(t);
    if (_isPreviouslySaved && !_isDirty) setState(() => _isDirty = true);
  }

  TripModel get _trip => widget.trip;

  void _restoreLocationFocusAbility() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _locationFocusNode.canRequestFocus = true;
      });
    });
  }

  Future<void> _pickDateRange() async {
    // Block the location field from receiving focus during date picking.
    // This prevents Flutter's route-pop focus restoration from scrolling
    // the form back to the location field after the dialog closes.
    _locationFocusNode.unfocus();
    _locationFocusNode.canRequestFocus = false;
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existingStart =
        _trip.startDate.isNotEmpty ? DateTime.parse(_trip.startDate) : null;
    final existingEnd =
        _trip.endDate.isNotEmpty ? DateTime.parse(_trip.endDate) : null;
    final initialStart = existingStart != null && !existingStart.isBefore(today)
        ? existingStart
        : today;
    final initialEnd =
        existingEnd != null && !existingEnd.isBefore(initialStart)
            ? existingEnd
            : initialStart.add(const Duration(days: 1));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'SELECT TRIP DATES',
      saveText: 'Done',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
                primary: WildPathColors.forest,
                onPrimary: Colors.white,
                surface: Colors.white)),
        child: child!,
      ),
    );
    // Unfocus again after dialog closes to stop Flutter's focus-restoration
    // from scrolling the location field back into view.
    if (mounted) FocusScope.of(context).unfocus();
    if (picked == null) {
      _restoreLocationFocusAbility();
      return;
    }
    final start =
        '${picked.start.year}-${picked.start.month.toString().padLeft(2, '0')}-${picked.start.day.toString().padLeft(2, '0')}';
    final end =
        '${picked.end.year}-${picked.end.month.toString().padLeft(2, '0')}-${picked.end.day.toString().padLeft(2, '0')}';
    _update(_trip.copyWith(startDate: start, endDate: end));
    setState(() {});
    _restoreLocationFocusAbility();
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
        if (allMeals.any((m) => m.dateKey == k && m.mealType == mt)) {
          filledSlots++;
        }
      }
    }
    final budgetSpent = widget.storage
        .loadBudget(_trip.id)
        .fold<double>(0, (s, i) => s + i.amount);
    final budgetLimit = widget.storage.budgetTotal(_trip.id);
    final permitCount = widget.storage.loadPermits(_trip.id).length;

    // Build still-to-do list
    // gearTotal == 0 means gear screen was never visited (nothing saved yet)
    final todos = <Map<String, dynamic>>[];
    if (gearTotal == 0 || (gearPacked == 0 && gearTotal > 0)) {
      todos.add(
          {'e': '🎒', 't': 'Gear not started', 'a': 'START PACKING', 'tab': 1});
    } else if (gearPacked < gearTotal) {
      todos.add({
        'e': '🎒',
        't': '${gearTotal - gearPacked} items to pack',
        'a': 'CONTINUE',
        'tab': 1
      });
    }
    if (filledSlots == 0 && totalSlots > 0) {
      todos.add(
          {'e': '🍳', 't': 'No meals planned', 'a': 'PLAN MEALS', 'tab': 2});
    } else if (filledSlots < totalSlots && totalSlots > 0) {
      todos.add({
        'e': '🍳',
        't': '${totalSlots - filledSlots} meals to plan',
        'a': 'ADD MEALS',
        'tab': 2
      });
    }
    if (budgetSpent == 0) {
      todos.add(
          {'e': '💰', 't': 'No budget tracked', 'a': 'ADD EXPENSES', 'tab': 3});
    }
    if (permitCount == 0) {
      todos.add(
          {'e': '📜', 't': 'No permits added', 'a': 'ADD PERMIT', 'tab': 4});
    }

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
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: LayoutBuilder(
              builder: (context, constraints) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                                child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: WildPathColors.mist,
                                  borderRadius: BorderRadius.circular(2)),
                            )),
                            const SizedBox(height: 20),
                            Row(children: [
                              Text('💾',
                                  style:
                                      WildPathTypography.display(fontSize: 26)),
                              const SizedBox(width: 10),
                              Text('Save to My Trips',
                                  style: WildPathTypography.display(
                                      fontSize: 24,
                                      color: WildPathColors.pine)),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                                "Give your trip a name and review what's included",
                                style: WildPathTypography.body(
                                    fontSize: 13,
                                    color: WildPathColors.smoke,
                                    height: 1.5)),
                            const SizedBox(height: 20),
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
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: WildPathColors.cream,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _trip.campsite.isNotEmpty
                                        ? _trip.campsite
                                        : 'Location not set yet',
                                    style: WildPathTypography.body(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: WildPathColors.pine),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _trip.startDate.isNotEmpty
                                        ? _trip.endDate.isNotEmpty
                                            ? '${_fmtFull(_trip.startDate)} → ${_fmtFull(_trip.endDate)}'
                                            : _fmtFull(_trip.startDate)
                                        : 'Add your trip dates to complete the plan.',
                                    style: WildPathTypography.body(
                                        fontSize: 12,
                                        color: WildPathColors.smoke,
                                        height: 1.45),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _sheetPill('GROUP',
                                          '${_trip.groupSize} ${_trip.groupSize == 1 ? "person" : "people"}'),
                                      _sheetPill(
                                          'GEAR',
                                          gearTotal == 0
                                              ? 'Not started'
                                              : '$gearPacked/$gearTotal'),
                                      _sheetPill(
                                          'MEALS',
                                          totalSlots > 0
                                              ? '$filledSlots/$totalSlots'
                                              : 'Not ready'),
                                      _sheetPill(
                                          'BUDGET',
                                          budgetLimit > 0
                                              ? '\$${budgetSpent.toStringAsFixed(0)}/\$${budgetLimit.toStringAsFixed(0)}'
                                              : budgetSpent > 0
                                                  ? '\$${budgetSpent.toStringAsFixed(0)} spent'
                                                  : 'Not tracked'),
                                      _sheetPill(
                                          'PERMITS',
                                          permitCount == 0
                                              ? 'None added'
                                              : '$permitCount saved'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (todos.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text('(OPTIONAL) NEXT STEPS',
                                  style: WildPathTypography.body(
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                      color: WildPathColors.amber,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              ...todos.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: WildPathColors.mist,
                                            width: 1.2),
                                      ),
                                      child: Row(children: [
                                        Text(item['e'] as String,
                                            style: WildPathTypography.display(
                                                fontSize: 18)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Text(item['t'] as String,
                                                style: WildPathTypography.body(
                                                    fontSize: 12.5,
                                                    color: WildPathColors.pine,
                                                    fontWeight:
                                                        FontWeight.w600))),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context);
                                            widget.onGoToTab
                                                ?.call(item['tab'] as int);
                                          },
                                          child: Text(item['a'] as String,
                                              style: WildPathTypography.body(
                                                  fontSize: 10.5,
                                                  letterSpacing: 0.8,
                                                  color: WildPathColors.forest,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ]),
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(height: 1, color: WildPathColors.mist),
                    const SizedBox(height: 16),
                    _responsivePair(
                      first: PrimaryButton('💾  SAVE TO MY TRIPS',
                          fullWidth: true, onPressed: () async {
                        final rootNavigator =
                            Navigator.of(context, rootNavigator: true);
                        final onViewSavedTrips = widget.onViewSavedTrips;
                        final name = nameCtrl.text.trim();
                        final toSave = _trip.copyWith(
                          name: name.isNotEmpty ? name : _trip.name,
                          savedAt: DateTime.now().toIso8601String(),
                        );
                        if (name.isNotEmpty && name != _trip.name) {
                          _update(toSave);
                        }
                        await widget.storage.saveTrip(toSave);
                        if (widget.storage.notifTrips) {
                          await NotificationService.instance
                              .scheduleTripReminders(toSave);
                        }
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                        if (!context.mounted) return;
                        setState(() {
                          _isPreviouslySaved = true;
                          _isDirty = false;
                        });
                        showWildSuccessBanner(
                          context,
                          title: 'Trip saved',
                          primaryLabel: 'View Trips',
                          onPrimaryPressed: () {
                            rootNavigator.pop();
                            onViewSavedTrips?.call();
                          },
                          secondaryLabel: 'Close',
                        );
                      }),
                      second: OutlineButton2('Cancel',
                          fullWidth: true,
                          onPressed: () => Navigator.pop(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetPill(String label, String value) => Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: WildPathColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: WildPathColors.mist, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: WildPathTypography.body(
                    fontSize: 9,
                    letterSpacing: 0.9,
                    color: WildPathColors.smoke,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: WildPathColors.moss,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WildPathTypography.body(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: WildPathColors.pine)),
            ),
          ],
        ),
      );

  Widget _responsivePair({
    required Widget first,
    required Widget second,
    double spacing = 10,
    bool stackOnNarrow = true,
  }) =>
      LayoutBuilder(
        builder: (context, constraints) {
          if (stackOnNarrow && constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                first,
                SizedBox(height: spacing),
                second,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: first),
              SizedBox(width: spacing),
              Expanded(child: second),
            ],
          );
        },
      );

  Widget _tripSnapshot() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: WildPathColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WildPathColors.mist, width: 1.1),
        ),
        child: Row(
          children: [
            Expanded(child: _snapshotPill('${_trip.nights}', 'Nights')),
            const SizedBox(width: 10),
            Expanded(child: _snapshotPill('${_trip.groupSize}', 'Campers')),
          ],
        ),
      );

  Widget _snapshotPill(String value, String label) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WildPathColors.mist),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: WildPathTypography.body(
                    fontSize: 9.5,
                    letterSpacing: 0.9,
                    color: WildPathColors.smoke)),
            const SizedBox(height: 3),
            Text(value,
                style: WildPathTypography.body(
                    fontSize: 13,
                    color: WildPathColors.forest,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _newTripHeaderButton() => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _newTrip,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: WildPathColors.cream,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: WildPathColors.mist,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded,
                    size: 15, color: WildPathColors.forest),
                const SizedBox(width: 6),
                Text('Start New Trip',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.75,
                        color: WildPathColors.forest,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Save first if you want to keep the current plan.',
                      style: WildPathTypography.body(
                          fontSize: 13, color: WildPathColors.smoke)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: PrimaryButton('Yes', fullWidth: true,
                            onPressed: () {
                      Navigator.pop(context);
                      final t = TripModel(id: const Uuid().v4());
                      for (final c in _controllers) {
                        c.clear();
                      }
                      _groupSizeCtrl.text = '1';
                      _update(t);
                    })),
                    const SizedBox(width: 10),
                    Expanded(
                        child: GhostButton('Cancel',
                            fullWidth: true,
                            onPressed: () => Navigator.pop(context))),
                  ]),
                ],
              ),
            ));
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
      if (results.isNotEmpty) _scrollToLocationField();
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
    // Use the autocomplete suggestion text (short, e.g. "Sedona, Arizona"),
    // not the full formattedAddress from place details.
    final parts = result.displayName.split(',');
    final shortName = parts.length > 1
        ? '${parts[0].trim()}, ${parts[1].trim()}'
        : parts[0].trim();
    _campsiteCtrl
      ..text = shortName
      ..selection = TextSelection.collapsed(offset: shortName.length);
    FocusScope.of(context).unfocus();
    setState(() {
      _locationSuggestions = const [];
      _isSearchingLocations = false;
      _locationSearchAttempted = false;
    });
    _update(_trip.copyWith(
      campsite: shortName,
      lat: resolved.lat,
      lng: resolved.lng,
      isSpecificLocation: resolved.isSpecific,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _formScrollController,
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, 32 + MediaQuery.viewInsetsOf(context).bottom),
      child: _buildForm(),
    );
  }

  // ── PLAN FORM ────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final showStackedHeader = constraints.maxWidth < 390;
          const title = PageTitle(
            'Plan a Trip',
            subtitle:
                'Start with the basics. Add gear, meals, budget, and permits when you need them.',
          );

          if (showStackedHeader) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 10),
                _newTripHeaderButton(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: title),
              const SizedBox(width: 12),
              _newTripHeaderButton(),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Trip Info'),
        _field('TRIP NAME', _nameCtrl, 'e.g. Lost Coast Weekend',
            onChanged: (v) => _update(_trip.copyWith(name: v))),
        const SizedBox(height: 14),
        _responsivePair(
          first: _field('GROUP SIZE', _groupSizeCtrl, '1',
              type: TextInputType.number,
              onChanged: (v) => _update(_trip.copyWith(
                  groupSize: (int.tryParse(v) ?? 1).clamp(1, 500)))),
          second:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]),
        ),
      ])),
      WildCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Location & Dates'),
        _locationField(),
        const SizedBox(height: 14),
        _responsivePair(
          first: _datePicker('START DATE', _trip.startDate, _pickDateRange),
          second: _datePicker('END DATE', _trip.endDate, _pickDateRange),
          stackOnNarrow: false,
        ),
      ])),
      const SizedBox(height: 12),
      _tripSnapshot(),
      const SizedBox(height: 12),
      PrimaryButton(
          _isPreviouslySaved && _isDirty ? 'Update Trip' : 'Save Trip',
          fullWidth: true,
          onPressed: _saveTrip),
    ]);
  }

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

    return Column(
        key: _locationFieldKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DESTINATION',
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: WildPathColors.smoke)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _campsiteCtrl,
            focusNode: _locationFocusNode,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.search,
            onChanged: _onLocationChanged,
            onFieldSubmitted: (_) => _resolveTypedLocation(),
            style: WildPathTypography.body(
                fontSize: 14, color: WildPathColors.pine),
            decoration: InputDecoration(
              hintText:
                  'Search for a campground, cabin, RV park, park, or city',
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
                    : 'Search for a campground, cabin, RV park, park, or city.',
            style: WildPathTypography.body(
                fontSize: 11,
                color: hasVerifiedLocation
                    ? WildPathColors.moss
                    : WildPathColors.smoke),
          ),
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
                                padding:
                                    const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(Icons.place_outlined,
                                          size: 18,
                                          color: WildPathColors.forest),
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
                'No matches yet. Try a campground, cabin, RV park, park, or city.',
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

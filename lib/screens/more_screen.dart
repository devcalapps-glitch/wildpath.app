import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';
import '../services/background_service.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../models/meal_item.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';

enum MoreSection {
  menu,
  map,
  emergency,
  budget,
  passes,
  profile,
  about,
  privacy
}

class MoreScreen extends StatefulWidget {
  final StorageService storage;
  final TripModel currentTrip;
  final ValueChanged<TripModel> onLoadTrip;
  final ValueChanged<int> onSwitchTab;
  final bool openBudgetOnLoad;
  final bool isActive;

  const MoreScreen({
    required this.storage,
    required this.currentTrip,
    required this.onLoadTrip,
    required this.onSwitchTab,
    this.openBudgetOnLoad = false,
    this.isActive = false,
    super.key,
  });

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  MoreSection _section = MoreSection.menu;

  @override
  void initState() {
    super.initState();
    if (widget.openBudgetOnLoad) {
      _section = MoreSection.budget;
    }
  }

  @override
  void didUpdateWidget(MoreScreen old) {
    super.didUpdateWidget(old);
    if (old.isActive && !widget.isActive) {
      setState(() => _section = MoreSection.menu);
      return;
    }
    if (widget.openBudgetOnLoad && !old.openBudgetOnLoad) {
      setState(() => _section = MoreSection.budget);
    }
  }

  void _go(MoreSection s) => setState(() => _section = s);
  void _back() => setState(() => _section = MoreSection.menu);

  @override
  Widget build(BuildContext context) {
    switch (_section) {
      case MoreSection.map:
        return MapSection(trip: widget.currentTrip, onBack: _back);
      case MoreSection.emergency:
        return _EmergencySection(
            storage: widget.storage, trip: widget.currentTrip, onBack: _back);
      case MoreSection.budget:
        return BudgetSection(
          storage: widget.storage,
          tripId: widget.currentTrip.id,
          onBack: _back,
          onSaveTrip: () => widget.onSwitchTab(-1), // -1 = trigger save sheet
          onGoToPermits: () => _go(MoreSection.passes),
        );
      case MoreSection.passes:
        return _PassesSection(onBack: _back);
      case MoreSection.profile:
        return _ProfileSection(storage: widget.storage, onBack: _back);
      case MoreSection.about:
        return _AboutSection(
            onBack: _back, onPrivacy: () => _go(MoreSection.privacy));
      case MoreSection.privacy:
        return _PrivacyPolicySection(onBack: _back);
      default:
        return _buildMenu();
    }
  }

  Widget _buildMenu() {
    final name = widget.storage.userName;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageTitle('More',
              subtitle: name.isNotEmpty ? 'Hey, $name 👋' : 'Tools & settings'),
          const SizedBox(height: 20),
          _item('🚨', 'Emergency Info', 'Contacts, GPS & rescue tips',
              () => _go(MoreSection.emergency)),
          _item('🏞️', 'Passes & Permits', 'Photos of passes, permits & cards',
              () => _go(MoreSection.passes)),
          _item('👤', 'My Profile', 'Name, style & notifications',
              () => _go(MoreSection.profile)),
          _item('ℹ️', 'About WildPath', 'Version, credits & feedback',
              () => _go(MoreSection.about)),
        ],
      ),
    );
  }

  Widget _item(String emoji, String title, String sub, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: WildPathColors.pine.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: WildPathTypography.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: WildPathColors.pine)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: WildPathTypography.body(
                          fontSize: 11, color: WildPathColors.smoke)),
                ])),
            const Icon(Icons.chevron_right,
                color: WildPathColors.stone, size: 20),
          ]),
        ),
      );
}

// ── Shared back-header ─────────────────────────────────────────────────────
class _BackHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  const _BackHeader({required this.title, this.onBack});
  @override
  Widget build(BuildContext context) => Row(children: [
        if (onBack != null)
          IconButton(
              icon: const Icon(Icons.arrow_back, color: WildPathColors.forest),
              onPressed: onBack,
              tooltip: 'Go back',
              padding: EdgeInsets.zero),
        if (onBack != null) const SizedBox(width: 4),
        Flexible(
            child: Text(title,
                style: WildPathTypography.display(
                    fontSize: 22, color: WildPathColors.forest))),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════
// MAP
// ══════════════════════════════════════════════════════════════════════════
class MapSection extends StatefulWidget {
  final TripModel trip;
  final VoidCallback? onBack;
  const MapSection({required this.trip, this.onBack, super.key});

  @override
  State<MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<MapSection> {
  late Future<LocationResult?> _locationFuture;

  @override
  void initState() {
    super.initState();
    _locationFuture = _resolveLocation();
  }

  @override
  void didUpdateWidget(covariant MapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldQuery = _mapQuery(oldWidget.trip);
    final newQuery = _mapQuery(widget.trip);
    if (oldWidget.trip.lat != widget.trip.lat ||
        oldWidget.trip.lng != widget.trip.lng ||
        oldQuery != newQuery) {
      _locationFuture = _resolveLocation();
    }
  }

  String? _mapQuery(TripModel trip) {
    final campsite = trip.campsite.trim();
    if (campsite.isNotEmpty) return campsite;

    final name = trip.name.trim();
    if (name.isNotEmpty) return name;

    return null;
  }

  Future<LocationResult?> _resolveLocation() async {
    if (widget.trip.lat != null && widget.trip.lng != null) {
      return LocationResult(
        lat: widget.trip.lat!,
        lng: widget.trip.lng!,
        displayName: widget.trip.campsite.trim().isNotEmpty
            ? widget.trip.campsite.trim()
            : widget.trip.name.trim(),
      );
    }

    final query = _mapQuery(widget.trip);
    if (query == null) return null;
    return WeatherService.geocode(query);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LocationResult?>(
      future: _locationFuture,
      builder: (context, snapshot) {
        final hasSavedCoordinates =
            widget.trip.lat != null && widget.trip.lng != null;
        final resolvedLocation = snapshot.data;
        final hasMapLocation = resolvedLocation?.hasCoordinates ?? false;
        final mapCenter = hasMapLocation
            ? LatLng(resolvedLocation!.lat!, resolvedLocation.lng!)
            : const LatLng(39, -98);
        // Show coordinate detail only when the trip has a specific
        // address-level location rather than a general area.
        final showCoordinates =
            hasMapLocation && widget.trip.isSpecificLocation;
        // Use a wider zoom for general areas (city/region) vs specific places.
        final mapZoom = widget.trip.isSpecificLocation ? 12.5 : 9.5;
        final title = widget.trip.campsite.trim().isNotEmpty
            ? widget.trip.campsite.trim()
            : widget.trip.name.trim();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _BackHeader(title: 'Map', onBack: widget.onBack),
            Text('Campsite location & surroundings',
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.smoke)),
            const SizedBox(height: 16),
            if (title.isNotEmpty)
              WildCard(
                  child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: WildPathTypography.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: WildPathColors.pine)),
                      if (hasMapLocation && showCoordinates)
                        Text(
                            '${resolvedLocation!.lat!.toStringAsFixed(5)}, ${resolvedLocation.lng!.toStringAsFixed(5)}',
                            style: WildPathTypography.body(
                                fontSize: 11, color: WildPathColors.smoke)),
                      if (hasMapLocation && !showCoordinates)
                        Text(
                          'Showing area — choose a specific campsite in Plan for exact coordinates',
                          style: WildPathTypography.body(
                              fontSize: 11, color: WildPathColors.smoke),
                        ),
                    ])),
              ])),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: WildPathColors.mist.withValues(alpha: 0.35),
                  border: Border.all(color: WildPathColors.mist, width: 1.5),
                ),
                child: snapshot.connectionState == ConnectionState.waiting &&
                        !hasSavedCoordinates
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(height: 14),
                          Text('Loading map location...',
                              style: WildPathTypography.display(
                                  fontSize: 18, color: WildPathColors.forest)),
                        ],
                      )
                    : hasMapLocation
                        ? Stack(children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: mapCenter,
                                initialZoom: mapZoom,
                                minZoom: 3,
                                maxZoom: 18,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.wildpath.app',
                                ),
                                SimpleAttributionWidget(
                                  alignment: Alignment.bottomLeft,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.9),
                                  source: Text(
                                    'OpenStreetMap contributors',
                                    style:
                                        WildPathTypography.body(fontSize: 10),
                                  ),
                                  onTap: () async {
                                    final url = Uri.parse(
                                        'https://www.openstreetmap.org/copyright');
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ])
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🗺️', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 10),
                              Text('Interactive Map',
                                  style: WildPathTypography.display(
                                      fontSize: 18,
                                      color: WildPathColors.forest)),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  title.isEmpty
                                      ? 'Set a campsite in the Plan tab first'
                                      : 'We could not locate this trip on the map yet. Search for a campsite in Plan and tap a result to save a precise spot.',
                                  style: WildPathTypography.body(
                                      fontSize: 12,
                                      color: WildPathColors.smoke,
                                      height: 1.6),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 12),
            if (hasMapLocation)
              PrimaryButton('Open in Google Maps', fullWidth: true,
                  onPressed: () async {
                final url = Uri.parse(
                    'https://maps.google.com/?q=${resolvedLocation!.lat},${resolvedLocation.lng}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              }),
            const SizedBox(height: 16),
            const TipCard(
                emoji: '💡',
                content:
                    'Search for your campsite in the Plan tab and tap a result to save verified coordinates for the most precise map placement.'),
          ]),
        );
      });
}

// ══════════════════════════════════════════════════════════════════════════
// MY TRIPS
// ══════════════════════════════════════════════════════════════════════════
class TripsSection extends StatefulWidget {
  final StorageService storage;
  final String currentTripId;
  final ValueChanged<TripModel> onLoadTrip;
  final VoidCallback? onBack;
  final bool isActive;
  const TripsSection(
      {required this.storage,
      required this.currentTripId,
      required this.onLoadTrip,
      this.onBack,
      this.isActive = false,
      super.key});
  @override
  State<TripsSection> createState() => _TripsSectionState();
}

class _TripsSectionState extends State<TripsSection> {
  late List<TripModel> _trips;
  TripModel? _viewingTrip;

  @override
  void initState() {
    super.initState();
    _trips = widget.storage.loadSavedTrips();
  }

  @override
  void didUpdateWidget(TripsSection old) {
    super.didUpdateWidget(old);
    // Reload trips whenever the tab becomes active or the current trip changes
    if (!old.isActive && widget.isActive ||
        old.currentTripId != widget.currentTripId) {
      setState(() {
        _trips = widget.storage.loadSavedTrips();
        _viewingTrip = null;
      });
    }
  }

  String _fmt(String? s) {
    if (s == null || s.isEmpty) return '—';
    try {
      final d = DateTime.parse(s);
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
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  String _fmtShort(String? s) {
    if (s == null || s.isEmpty) return '—';
    try {
      final d = DateTime.parse(s);
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
      return '${m[d.month - 1]} ${d.day}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewingTrip != null) return _buildSummary(_viewingTrip!);
    return _buildList();
  }

  Widget _buildList() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BackHeader(title: 'My Trips', onBack: widget.onBack),
          Text('Your saved adventures',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke)),
          const SizedBox(height: 16),
          if (_trips.isEmpty)
            const EmptyState(
                emoji: '🗂️',
                message:
                    'No saved trips yet.\nGo to Plan and tap "💾 Save to My Trips" to store your first adventure.')
          else
            ..._trips.map((trip) => Semantics(
                  button: true,
                  label:
                      'Open saved trip ${trip.name.isNotEmpty ? trip.name : 'Unnamed Trip'}',
                  child: WildCard(
                    onTap: () => setState(() => _viewingTrip = trip),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip.tripTypeEmoji,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          trip.name.isNotEmpty
                                              ? trip.name
                                              : 'Unnamed Trip',
                                          style: WildPathTypography.body(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: WildPathColors.pine),
                                          overflow: TextOverflow.ellipsis)),
                                  if (trip.id == widget.currentTripId) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: WildPathColors.fern,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text('Active',
                                          style: WildPathTypography.body(
                                              fontSize: 9,
                                              color: WildPathColors.forest,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                    [
                                      if (trip.campsite.isNotEmpty)
                                        trip.campsite,
                                      trip.tripType
                                    ].join(' · '),
                                    style: WildPathTypography.body(
                                        fontSize: 11,
                                        color: WildPathColors.smoke),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('Saved ${_fmt(trip.savedAt)}',
                                    style: WildPathTypography.body(
                                        fontSize: 10,
                                        color: WildPathColors.stone)),
                              ])),
                          const SizedBox(width: 10),
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: WildPathColors.stone),
                          ),
                        ]),
                  ),
                )),
        ]),
      );

  Widget _buildSummary(TripModel t) {
    // Gear
    final gearItems = widget.storage.loadGear(t.id);
    final gearTotal = gearItems.length;
    final gearPacked = gearItems.where((i) => i.checked).length;
    final gearPct = gearTotal > 0 ? (gearPacked / gearTotal * 100).round() : 0;

    // Meals
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

    // Budget
    final budgetItems = widget.storage.loadBudget(t.id);
    final budgetSpent = budgetItems.fold<double>(0, (s, i) => s + i.amount);
    final budgetLimit = widget.storage.budgetTotal(t.id);
    final budgetRemain = budgetLimit > 0 ? budgetLimit - budgetSpent : 0.0;

    // Permits
    final permits = widget.storage.loadPermits(t.id);

    // Emergency contacts
    final contacts = widget.storage.loadEmContacts(t.id);

    // Share text builder
    String shareText() {
      final lines = [
        '🌲 WildPath Trip Summary',
        '',
        if (t.name.isNotEmpty) '📋 ${t.name}',
        if (t.campsite.isNotEmpty) '📍 ${t.campsite}',
        if (t.startDate.isNotEmpty)
          '📅 ${_fmtShort(t.startDate)} – ${_fmtShort(t.endDate)} (${t.nights} night${t.nights == 1 ? '' : 's'})',
        '👥 ${t.groupSize} ${t.groupSize == 1 ? 'person' : 'people'} · ${t.tripType}',
        '',
        '🎒 Gear: $gearPacked / $gearTotal packed',
        if (totalSlots > 0) '🍳 Meals: $filledSlots / $totalSlots planned',
        if (budgetLimit > 0)
          '💰 Budget: \$${budgetSpent.toStringAsFixed(0)} of \$${budgetLimit.toStringAsFixed(0)}'
        else if (budgetSpent > 0)
          '💰 Spent: \$${budgetSpent.toStringAsFixed(0)}',
        if (permits.isNotEmpty) ...[
          '',
          '📜 Permits:',
          ...permits.map((p) =>
              '  • ${p.permitType}${p.permitNum.isNotEmpty ? ' #${p.permitNum}' : ''}${p.entryTime.isNotEmpty ? ' at ${p.entryTime}' : ''}'),
        ],
        if (t.notes.isNotEmpty) ...[
          '',
          '📝 ${t.notes}',
        ],
      ];
      return lines.join('\n');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Back header
        GestureDetector(
          onTap: () => setState(() => _viewingTrip = null),
          child: Row(children: [
            const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: WildPathColors.forest),
            const SizedBox(width: 4),
            Text('My Trips',
                style: WildPathTypography.body(
                    fontSize: 13,
                    color: WildPathColors.forest,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 16),

        // Hero card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [WildPathColors.forest, WildPathColors.moss],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(t.tripTypeEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(t.name.isNotEmpty ? t.name : 'Unnamed Trip',
                        style: WildPathTypography.display(
                            fontSize: 18, color: Colors.white),
                        overflow: TextOverflow.ellipsis),
                    if (t.campsite.isNotEmpty)
                      Text(t.campsite,
                          style: WildPathTypography.body(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75)),
                          overflow: TextOverflow.ellipsis),
                  ])),
            ]),
            if (t.startDate.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _heroChip(
                    '${_fmtShort(t.startDate)} – ${_fmtShort(t.endDate)}'),
                _heroChip('${t.nights} night${t.nights == 1 ? '' : 's'}'),
                _heroChip(
                    '${t.groupSize} ${t.groupSize == 1 ? 'person' : 'people'}'),
                _heroChip(t.tripType),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 12),

        // Stats row
        Row(children: [
          _statCard('🎒', '$gearPacked/$gearTotal', 'packed',
              gearPct == 100 ? WildPathColors.fern : WildPathColors.pine),
          const SizedBox(width: 8),
          _statCard(
              '🍳',
              '$filledSlots/$totalSlots',
              'meals',
              filledSlots == totalSlots && totalSlots > 0
                  ? WildPathColors.fern
                  : WildPathColors.pine),
          const SizedBox(width: 8),
          _statCard(
              '💰',
              budgetLimit > 0
                  ? '\$${budgetRemain.toStringAsFixed(0)}'
                  : '\$${budgetSpent.toStringAsFixed(0)}',
              budgetLimit > 0 ? 'remaining' : 'spent',
              budgetLimit > 0 && budgetSpent > budgetLimit
                  ? WildPathColors.red
                  : WildPathColors.pine),
        ]),
        const SizedBox(height: 12),

        // Trip details
        if (t.notes.isNotEmpty) ...[
          _sectionCard(
            label: 'NOTES',
            icon: Icons.notes_rounded,
            children: [
              Text(t.notes,
                  style: WildPathTypography.body(
                      fontSize: 13, color: WildPathColors.pine, height: 1.5)),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Permits card
        _sectionCard(
          label: 'PERMITS',
          icon: Icons.article_outlined,
          children: permits.isEmpty
              ? [
                  Text('No permits saved for this trip.',
                      style: WildPathTypography.body(
                          fontSize: 12, color: WildPathColors.stone))
                ]
              : permits
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: WildPathColors.forest,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(p.permitType,
                                    style: WildPathTypography.body(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (p.permitNum.isNotEmpty)
                                        Text('#${p.permitNum}',
                                            style: WildPathTypography.body(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: WildPathColors.pine)),
                                      if (p.entryTime.isNotEmpty)
                                        Text('Entry: ${p.entryTime}',
                                            style: WildPathTypography.body(
                                                fontSize: 11,
                                                color: WildPathColors.smoke)),
                                      if (p.notes.isNotEmpty)
                                        Text(p.notes,
                                            style: WildPathTypography.body(
                                                fontSize: 11,
                                                color: WildPathColors.smoke)),
                                      if (p.documentPath != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 3),
                                          child: Row(children: [
                                            const Icon(Icons.attach_file,
                                                size: 12,
                                                color: WildPathColors.fern),
                                            const SizedBox(width: 3),
                                            Text('Document attached',
                                                style: WildPathTypography.body(
                                                    fontSize: 11,
                                                    color:
                                                        WildPathColors.fern)),
                                          ]),
                                        ),
                                    ]),
                              ),
                            ]),
                      ))
                  .toList(),
        ),
        const SizedBox(height: 10),

        // Trip info for rescuers
        _sectionCard(
          label: 'TRIP INFO FOR RESCUERS',
          icon: Icons.health_and_safety_outlined,
          iconColor: WildPathColors.red,
          children: [
            _infoRow('📍', t.campsite.isNotEmpty ? t.campsite : 'Not set'),
            if (t.startDate.isNotEmpty)
              _infoRow('📅',
                  '${_fmtShort(t.startDate)} – ${_fmtShort(t.endDate)} (${t.nights} nights)'),
            _infoRow('👥',
                '${t.groupSize} ${t.groupSize == 1 ? 'person' : 'people'} · ${t.tripType}'),
            if (t.notes.isNotEmpty) _infoRow('📝', t.notes),
          ],
        ),
        const SizedBox(height: 10),

        // Emergency contacts
        _sectionCard(
          label: 'EMERGENCY CONTACTS',
          icon: Icons.contact_phone_outlined,
          iconColor: WildPathColors.red,
          children: contacts.isEmpty
              ? [
                  Text('No emergency contacts saved.',
                      style: WildPathTypography.body(
                          fontSize: 12, color: WildPathColors.stone))
                ]
              : contacts
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(c.name,
                                    style: WildPathTypography.body(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: WildPathColors.pine)),
                                Text(c.phone,
                                    style: WildPathTypography.body(
                                        fontSize: 12,
                                        color: WildPathColors.smoke)),
                              ])),
                          GestureDetector(
                            onTap: () async {
                              final u = Uri.parse('tel:${c.phone}');
                              if (await canLaunchUrl(u)) launchUrl(u);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: WildPathColors.fern,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Row(children: [
                                const Icon(Icons.phone,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('Call',
                                    style: WildPathTypography.body(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ]),
                            ),
                          ),
                        ]),
                      ))
                  .toList(),
        ),
        const SizedBox(height: 10),

        // Safety tips
        _sectionCard(
          label: 'BASIC SAFETY TIPS',
          icon: Icons.shield_outlined,
          iconColor: WildPathColors.amber,
          children: const [
            _TipRow('🆘',
                'Emergency signal: 3 whistle blasts, 3 fires in a triangle, or wave bright clothing.'),
            _TipRow('📡',
                'No signal? Move to high ground. Text often sends when calls won\'t — try 911 even with 0 bars.'),
            _TipRow('💧',
                'Purify all water before drinking. Boil 1 min (3 min above 6,500 ft) or use a filter.'),
            _TipRow('🐻',
                'Store food in bear canisters or hang 10 ft high, 4 ft from trunk. Never leave food in tents.'),
            _TipRow('🌩️',
                'Lightning: descend from peaks immediately. Crouch low, spread out, avoid lone trees.'),
          ],
        ),
        const SizedBox(height: 24),

        // CTA buttons
        PrimaryButton('Edit Trip',
            fullWidth: true, onPressed: () => widget.onLoadTrip(t)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlineButton2('🔗  Share', onPressed: () {
              Share.share(shareText(),
                  subject: t.name.isNotEmpty ? t.name : 'WildPath Trip');
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GhostButton('Delete',
                color: WildPathColors.red,
                onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: Text('Delete Trip?',
                            style: WildPathTypography.display(fontSize: 20)),
                        content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Permanently delete "${t.name.isNotEmpty ? t.name : 'this trip'}"?',
                                  style: WildPathTypography.body(
                                      fontSize: 13,
                                      color: WildPathColors.smoke)),
                              const SizedBox(height: 20),
                              Row(children: [
                                Expanded(
                                    child: OutlineButton2('Cancel',
                                        onPressed: () =>
                                            Navigator.pop(context))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Tooltip(
                                  message: 'Permanently delete this trip',
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: WildPathColors.red,
                                      minimumSize: const Size(0, 48),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () async {
                                      final nav = Navigator.of(context);
                                      await widget.storage.deleteTrip(t.id);
                                      setState(() {
                                        _trips =
                                            widget.storage.loadSavedTrips();
                                        _viewingTrip = null;
                                      });
                                      nav.pop();
                                    },
                                    child: Text('Delete',
                                        style: WildPathTypography.body(
                                            fontSize: 11,
                                            letterSpacing: 1.1,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ),
                                )),
                              ]),
                            ]),
                        actions: const [],
                      ),
                    )),
          ),
        ]),
      ]),
    );
  }

  Widget _sectionCard({
    required String label,
    required IconData icon,
    Color? iconColor,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WildPathColors.mist)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: iconColor ?? WildPathColors.forest),
            const SizedBox(width: 5),
            Text(label,
                style: WildPathTypography.body(
                    fontSize: 9.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: iconColor ?? WildPathColors.forest)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _heroChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: WildPathTypography.body(fontSize: 11, color: Colors.white)),
      );

  Widget _statCard(
          String emoji, String value, String label, Color valueColor) =>
      Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: WildPathColors.pine.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ]),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  WildPathTypography.display(fontSize: 16, color: valueColor)),
          Text(label,
              style: WildPathTypography.body(
                  fontSize: 9, color: WildPathColors.smoke)),
        ]),
      ));

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 56,
              child: Text(label,
                  style: WildPathTypography.body(
                      fontSize: 11, color: WildPathColors.smoke))),
          Expanded(
              child: Text(value,
                  style: WildPathTypography.body(
                      fontSize: 12, color: WildPathColors.pine))),
        ]),
      );
}

class _TipRow extends StatelessWidget {
  final String emoji;
  final String tip;
  const _TipRow(this.emoji, this.tip);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 16, height: 1.3)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tip,
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.pine, height: 1.5)),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════
// EMERGENCY NUMBERS DATA

class _EmergencyNumbers {
  final String emergencyNum;
  final String emergencyLabel;
  final String s1Label;
  final String s1Sub;
  final String s1Num;
  final Color s1Color;
  final String s2Label;
  final String s2Sub;
  final String s2Num;
  final Color s2Color;
  final String countryName;
  final String warning;
  const _EmergencyNumbers({
    required this.emergencyNum,
    required this.emergencyLabel,
    required this.s1Label,
    required this.s1Sub,
    required this.s1Num,
    required this.s1Color,
    required this.s2Label,
    required this.s2Sub,
    required this.s2Num,
    required this.s2Color,
    required this.countryName,
    required this.warning,
  });
}

_EmergencyNumbers _numbersForCoords(double? lat, double? lng) {
  if (lat != null && lng != null) {
    // US Alaska
    if (lat >= 51 && lat <= 72 && lng >= -170 && lng <= -130) return _usNumbers;
    // US Hawaii
    if (lat >= 18 && lat <= 23 && lng >= -161 && lng <= -154) return _usNumbers;
    // US contiguous
    if (lat >= 24 && lat <= 50 && lng >= -125 && lng <= -66) return _usNumbers;
    // Canada
    if (lat >= 41 && lat <= 84 && lng >= -141 && lng <= -52) return _caNumbers;
    // Australia
    if (lat >= -44 && lat <= -10 && lng >= 113 && lng <= 154) return _auNumbers;
    // New Zealand
    if (lat >= -47 && lat <= -34 && lng >= 166 && lng <= 178) return _nzNumbers;
    // UK / Ireland
    if (lat >= 49 && lat <= 62 && lng >= -11 && lng <= 2) return _gbNumbers;
    // Europe (broad)
    if (lat >= 35 && lat <= 72 && lng >= -10 && lng <= 40) return _euNumbers;
  }
  return _intlNumbers;
}

const _usNumbers = _EmergencyNumbers(
  emergencyNum: '911',
  emergencyLabel: 'Emergency',
  s1Label: '🏞️ USFS',
  s1Sub: '1-877-444-6777\nRecreation.gov',
  s1Num: '18774446777',
  s1Color: WildPathColors.forest,
  s2Label: '🏔️ NPS',
  s2Sub: '1-800-922-0399\nNat\'l Park Service',
  s2Num: '18009220399',
  s2Color: WildPathColors.moss,
  countryName: 'United States',
  warning:
      '⚠️ Save your local ranger station number before heading out — 911 may not reach backcountry dispatch.',
);

const _caNumbers = _EmergencyNumbers(
  emergencyNum: '911',
  emergencyLabel: 'Emergency',
  s1Label: '🏕️ Parks Canada',
  s1Sub: '1-888-773-8888\nParks Canada',
  s1Num: '18887738888',
  s1Color: WildPathColors.forest,
  s2Label: '🚑 BC Emergency',
  s2Sub: '1-800-663-3456\nBC Ambulance',
  s2Num: '18006633456',
  s2Color: WildPathColors.moss,
  countryName: 'Canada',
  warning:
      '⚠️ Save your local park warden number before heading out — 911 may not reach backcountry dispatch.',
);

const _auNumbers = _EmergencyNumbers(
  emergencyNum: '000',
  emergencyLabel: 'Emergency',
  s1Label: '🌿 Parks Australia',
  s1Sub: '1800-060-606\nParks Australia',
  s1Num: '1800060606',
  s1Color: WildPathColors.forest,
  s2Label: '🆘 SES',
  s2Sub: '132-500\nState Emergency Svc',
  s2Num: '132500',
  s2Color: WildPathColors.moss,
  countryName: 'Australia',
  warning:
      '⚠️ Save your local park ranger number before heading out — 000 may not reach remote bush dispatch.',
);

const _nzNumbers = _EmergencyNumbers(
  emergencyNum: '111',
  emergencyLabel: 'Emergency',
  s1Label: '🌿 DOC',
  s1Sub: '0800-362-468\nDept of Conservation',
  s1Num: '0800362468',
  s1Color: WildPathColors.forest,
  s2Label: '🆘 LandSAR',
  s2Sub: '111\nSearch & Rescue',
  s2Num: '111',
  s2Color: WildPathColors.moss,
  countryName: 'New Zealand',
  warning:
      '⚠️ Save your local DOC number before heading out — 111 may not reach remote backcountry dispatch.',
);

const _gbNumbers = _EmergencyNumbers(
  emergencyNum: '999',
  emergencyLabel: 'Emergency',
  s1Label: '⛰️ Mtn Rescue',
  s1Sub: '999\nMountain Rescue',
  s1Num: '999',
  s1Color: WildPathColors.forest,
  s2Label: '🌊 Coastguard',
  s2Sub: '999\nHM Coastguard',
  s2Num: '999',
  s2Color: WildPathColors.moss,
  countryName: 'United Kingdom',
  warning:
      '⚠️ Save your local mountain rescue team number before heading out — 999 may not reach remote fell dispatch.',
);

const _euNumbers = _EmergencyNumbers(
  emergencyNum: '112',
  emergencyLabel: 'Emergency',
  s1Label: '⛰️ Alpine Rescue',
  s1Sub: '112\nAlpine Emergency',
  s1Num: '112',
  s1Color: WildPathColors.forest,
  s2Label: '🆘 Local SAR',
  s2Sub: '112\nSearch & Rescue',
  s2Num: '112',
  s2Color: WildPathColors.moss,
  countryName: 'Europe',
  warning:
      '⚠️ Save your local mountain rescue number before heading out — 112 may not reach remote backcountry dispatch.',
);

const _intlNumbers = _EmergencyNumbers(
  emergencyNum: '112',
  emergencyLabel: 'International',
  s1Label: '🆘 Local Rescue',
  s1Sub: 'Check local services\nbefore heading out',
  s1Num: '112',
  s1Color: WildPathColors.forest,
  s2Label: '🏕️ Local Park',
  s2Sub: 'Save ranger number\nbefore heading out',
  s2Num: '112',
  s2Color: WildPathColors.moss,
  countryName: '',
  warning:
      '⚠️ Save your local park and rescue numbers before heading out — 112 may not reach remote backcountry dispatch.',
);

// ══════════════════════════════════════════════════════════════════════════
// EMERGENCY
// ══════════════════════════════════════════════════════════════════════════
class _EmergencySection extends StatefulWidget {
  final StorageService storage;
  final TripModel trip;
  final VoidCallback onBack;
  const _EmergencySection(
      {required this.storage, required this.trip, required this.onBack});
  @override
  State<_EmergencySection> createState() => _EmergencySectionState();
}

class _EmergencySectionState extends State<_EmergencySection> {
  final _n1 = TextEditingController(), _p1 = TextEditingController();
  final _n2 = TextEditingController(), _p2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void didUpdateWidget(_EmergencySection old) {
    super.didUpdateWidget(old);
    if (old.trip.id != widget.trip.id) {
      _loadContacts();
    }
  }

  void _loadContacts() {
    _n1.clear();
    _p1.clear();
    _n2.clear();
    _p2.clear();
    final c = widget.storage.loadEmContacts(widget.trip.id);
    if (c.isNotEmpty) {
      _n1.text = c[0].name;
      _p1.text = c[0].phone;
    }
    if (c.length > 1) {
      _n2.text = c[1].name;
      _p2.text = c[1].phone;
    }
  }

  @override
  void dispose() {
    for (final c in [_n1, _p1, _n2, _p2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final contacts = <EmergencyContact>[];
    if (_n1.text.trim().isNotEmpty) {
      contacts.add(EmergencyContact(
          id: const Uuid().v4(),
          name: _n1.text.trim(),
          phone: _p1.text.trim()));
    }
    if (_n2.text.trim().isNotEmpty) {
      contacts.add(EmergencyContact(
          id: const Uuid().v4(),
          name: _n2.text.trim(),
          phone: _p2.text.trim()));
    }
    widget.storage.saveEmContacts(widget.trip.id, contacts);
    showWildToast(context, '✅ Contacts saved');
  }

  Future<void> _call(String n) async {
    final u = Uri.parse('tel:$n');
    if (await canLaunchUrl(u)) launchUrl(u);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final nums = _numbersForCoords(t.lat, t.lng);
    final hasLocation = t.lat != null && t.lng != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _BackHeader(title: '🚨 Emergency Info', onBack: widget.onBack),
        Text('Critical info for emergencies in the field',
            style: WildPathTypography.body(
                fontSize: 12, color: WildPathColors.smoke)),
        const SizedBox(height: 16),
        WildCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('EMERGENCY NUMBERS',
                style: WildPathTypography.body(
                    fontSize: 10,
                    letterSpacing: 0.12 * 10,
                    color: WildPathColors.red)),
            Text(
              hasLocation
                  ? '📍 ${nums.countryName}'
                  : 'Set location for local numbers',
              style: WildPathTypography.body(
                  fontSize: 10, color: WildPathColors.smoke),
            ),
          ]),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                  child: _dialBtn(
                      '📞 ${nums.emergencyNum}',
                      nums.emergencyLabel,
                      WildPathColors.red,
                      nums.emergencyNum)),
              const SizedBox(width: 8),
              Expanded(
                  child: _dialBtn(
                      nums.s1Label, nums.s1Sub, nums.s1Color, nums.s1Num)),
              const SizedBox(width: 8),
              Expanded(
                  child: _dialBtn(
                      nums.s2Label, nums.s2Sub, nums.s2Color, nums.s2Num)),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: WildPathColors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Text(nums.warning,
                style: WildPathTypography.body(
                    fontSize: 11, color: WildPathColors.amber, height: 1.5)),
          ),
        ])),
        WildCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TRIP INFO FOR RESCUERS',
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 0.12 * 10,
                  color: WildPathColors.smoke)),
          const SizedBox(height: 12),
          _rr('📍 Location', t.campsite.isNotEmpty ? t.campsite : 'Not set'),
          _rr(
              '📅 Dates',
              t.startDate.isNotEmpty
                  ? '${t.startDate} – ${t.endDate}'
                  : 'Not set'),
          _rr('👥 Group Size',
              '${t.groupSize} ${t.groupSize == 1 ? "person" : "people"}'),
          _rr('🏕️ Trip Type', t.tripType),
          if (t.notes.isNotEmpty) _rr('📝 Notes', t.notes),
        ])),
        WildCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EMERGENCY CONTACTS',
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 0.12 * 10,
                  color: WildPathColors.smoke)),
          const SizedBox(height: 14),
          Text('Contact 1',
              style: WildPathTypography.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WildPathColors.pine)),
          const SizedBox(height: 8),
          _ef(_n1, 'Name', 'e.g. Jane Smith'),
          const SizedBox(height: 8),
          _ef(_p1, 'Phone', 'e.g. 555-123-4567', type: TextInputType.phone),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: WildPathColors.mist)),
          Text('Contact 2',
              style: WildPathTypography.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: WildPathColors.pine)),
          const SizedBox(height: 8),
          _ef(_n2, 'Name', 'e.g. John Doe'),
          const SizedBox(height: 8),
          _ef(_p2, 'Phone', 'e.g. 555-987-6543', type: TextInputType.phone),
          const SizedBox(height: 16),
          PrimaryButton('💾 Save Contacts', fullWidth: true, onPressed: _save),
        ])),
        TipCard(
            emoji: '🆘',
            content:
                '3 whistle blasts, 3 fires in a triangle, or wave bright clothing. Groups of 3 = universal distress signal.',
            bgColor: WildPathColors.red.withValues(alpha: 0.06),
            borderColor: WildPathColors.red.withValues(alpha: 0.2)),
        TipCard(
            emoji: '📡',
            content:
                'No signal? Move to high ground. Text often sends when calls won\'t. Try ${nums.emergencyNum} even with 0 bars.',
            bgColor: WildPathColors.red.withValues(alpha: 0.06),
            borderColor: WildPathColors.red.withValues(alpha: 0.2)),
      ]),
    );
  }

  Widget _dialBtn(String label, String sub, Color color, String number) =>
      Semantics(
        label: 'Call $number',
        button: true,
        child: GestureDetector(
            onTap: () => _call(number),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: WildPathTypography.body(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(sub,
                      style: WildPathTypography.body(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.85)),
                      textAlign: TextAlign.center,
                      maxLines: 2),
                ],
              ),
            )),
      );

  Widget _rr(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.smoke))),
        Expanded(
            child: Text(value,
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.pine))),
      ]));

  Widget _ef(TextEditingController ctrl, String label, String hint,
          {TextInputType type = TextInputType.text}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: WildPathTypography.body(
                fontSize: 9.5,
                letterSpacing: 0.12 * 9.5,
                color: WildPathColors.smoke)),
        const SizedBox(height: 5),
        TextFormField(
            controller: ctrl,
            keyboardType: type,
            style: WildPathTypography.body(
                fontSize: 14, color: WildPathColors.pine),
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11))),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════
// BUDGET
// ══════════════════════════════════════════════════════════════════════════

/// Per-category color accent used across chips and row indicators.
const _budgetCategoryColors = {
  BudgetCategory.campsite: WildPathColors.forest,
  BudgetCategory.lodging: WildPathColors.amber,
  BudgetCategory.food: WildPathColors.amber,
  BudgetCategory.gear: WildPathColors.moss,
  BudgetCategory.fuel: WildPathColors.ember,
  BudgetCategory.permits: WildPathColors.blue,
  BudgetCategory.activities: WildPathColors.sage,
  BudgetCategory.other: WildPathColors.smoke,
};

Color _catColor(BudgetCategory c) =>
    _budgetCategoryColors[c] ?? WildPathColors.smoke;

class BudgetSection extends StatefulWidget {
  final StorageService storage;
  final String tripId;
  final VoidCallback? onBack;
  final VoidCallback? onSaveTrip;
  final VoidCallback? onGoToPermits;
  const BudgetSection(
      {required this.storage,
      required this.tripId,
      this.onBack,
      this.onSaveTrip,
      this.onGoToPermits,
      super.key});
  @override
  State<BudgetSection> createState() => _BudgetSectionState();
}

class _BudgetSectionState extends State<BudgetSection> {
  late List<BudgetItem> _items;
  late double _limit;
  final _limitCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBudgetState();
  }

  @override
  void didUpdateWidget(BudgetSection old) {
    super.didUpdateWidget(old);
    if (old.tripId != widget.tripId) {
      setState(_loadBudgetState);
    }
  }

  void _loadBudgetState() {
    _items = widget.storage.loadBudget(widget.tripId);
    _limit = widget.storage.budgetTotal(widget.tripId);
    _limitCtrl.text = _limit > 0 ? _limit.toStringAsFixed(0) : '';
  }

  @override
  void dispose() {
    for (final c in [_limitCtrl, _descCtrl, _amtCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _items.fold(0, (s, i) => s + i.amount);
  double get _remaining => _limit > 0 ? _limit - _total : 0;

  void _save() {
    widget.storage.saveBudget(widget.tripId, _items);
    widget.storage.setBudgetTotal(widget.tripId, _limit);
  }

  // ── Add-expense bottom sheet ──────────────────────────────────────────────

  void _showAddSheet() {
    _descCtrl.clear();
    _amtCtrl.clear();
    BudgetCategory sheetCat = BudgetCategory.other;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: WildPathColors.mist,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('ADD EXPENSE',
                        style: WildPathTypography.body(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: WildPathColors.smoke)),
                    const SizedBox(height: 14),
                    _sheetField(_descCtrl, 'DESCRIPTION', 'e.g. Campsite fee'),
                    const SizedBox(height: 12),
                    _sheetField(_amtCtrl, 'AMOUNT', '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        prefixText: '\$ '),
                    const SizedBox(height: 12),
                    // Category picker
                    Text('CATEGORY',
                        style: WildPathTypography.body(
                            fontSize: 9.5,
                            letterSpacing: 0.12 * 9.5,
                            color: WildPathColors.smoke)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: BudgetCategory.values.map((c) {
                        final selected = c == sheetCat;
                        final cc = _catColor(c);
                        return GestureDetector(
                          onTap: () => setSheet(() => sheetCat = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? cc.withValues(alpha: 0.12)
                                  : WildPathColors.cream,
                              border: Border.all(
                                color: selected ? cc : WildPathColors.mist,
                                width: selected ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(c.emoji,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(c.label,
                                    style: WildPathTypography.body(
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: selected
                                            ? cc
                                            : WildPathColors.pine)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      'Add Expense',
                      fullWidth: true,
                      onPressed: () {
                        final amt = double.tryParse(
                                _amtCtrl.text.replaceAll(',', '')) ??
                            0;
                        if (_descCtrl.text.trim().isEmpty || amt <= 0) {
                          return;
                        }
                        setState(() {
                          _items.add(BudgetItem(
                              id: const Uuid().v4(),
                              description: _descCtrl.text.trim(),
                              amount: amt,
                              category: sheetCat));
                          _descCtrl.clear();
                          _amtCtrl.clear();
                        });
                        _save();
                        Navigator.pop(ctx);
                        showWildToast(context, '✅ Expense added');
                      },
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Category breakdown ────────────────────────────────────────────────────

  Widget _buildCategoryBreakdown() {
    final Map<BudgetCategory, double> totals = {};
    for (final item in _items) {
      totals[item.category] = (totals[item.category] ?? 0) + item.amount;
    }
    if (totals.isEmpty) return const SizedBox.shrink();
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('BY CATEGORY',
          style: WildPathTypography.body(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: WildPathColors.smoke)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: sorted.map((e) {
          final cc = _catColor(e.key);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: cc.withValues(alpha: 0.08),
              border: Border.all(color: cc.withValues(alpha: 0.25), width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(e.key.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.key.label,
                    style: WildPathTypography.body(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: cc)),
                Text('\$${e.value.toStringAsFixed(2)}',
                    style: WildPathTypography.display(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WildPathColors.pine)),
              ]),
            ]),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
    ]);
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final overBudget = _limit > 0 && _total > _limit;
    final progress = _limit > 0 ? (_total / _limit).clamp(0.0, 1.0) : 0.0;
    final barColor = overBudget ? WildPathColors.red : WildPathColors.moss;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        _BackHeader(title: '💰 Budget', onBack: widget.onBack),
        Text('Track every dollar on the trail',
            style: WildPathTypography.body(
                fontSize: 12, color: WildPathColors.smoke)),
        const SizedBox(height: 20),

        // ── Hero summary card ────────────────────────────────────────────
        WildCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            // Top: budget total input row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: WildPathColors.forest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TRIP BUDGET',
                            style: WildPathTypography.body(
                                fontSize: 9.5,
                                letterSpacing: 1.1,
                                color: WildPathColors.mist)),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _limitCtrl,
                          keyboardType: TextInputType.number,
                          style: WildPathTypography.display(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: WildPathColors.white),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            prefixStyle: WildPathTypography.display(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: WildPathColors.fern),
                            hintText: '0',
                            hintStyle: WildPathTypography.display(
                                fontSize: 28,
                                color:
                                    WildPathColors.mist.withValues(alpha: 0.5)),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (v) {
                            _limit = double.tryParse(v) ?? 0;
                            _save();
                            setState(() {});
                          },
                        ),
                      ]),
                ),
                // Spent / Remaining column
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _heroStat('\$${_total.toStringAsFixed(2)}', 'SPENT',
                      WildPathColors.fern),
                  const SizedBox(height: 10),
                  _heroStat(
                      _limit > 0
                          ? '\$${_remaining.abs().toStringAsFixed(2)}'
                          : '—',
                      overBudget ? 'OVER' : 'LEFT',
                      overBudget ? WildPathColors.ember : WildPathColors.mist),
                ]),
              ]),
            ),

            // Bottom: progress bar
            if (_limit > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${(progress * 100).toStringAsFixed(0)}% of budget used',
                            style: WildPathTypography.body(
                                fontSize: 11, color: WildPathColors.smoke)),
                        Text(
                            '\$${_total.toStringAsFixed(0)} / \$${_limit.toStringAsFixed(0)}',
                            style: WildPathTypography.body(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: overBudget
                                    ? WildPathColors.red
                                    : WildPathColors.forest)),
                      ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: WildPathColors.mist,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                  if (overBudget) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: WildPathColors.ember),
                      const SizedBox(width: 4),
                      Text(
                          'Over budget by \$${(-_remaining).toStringAsFixed(2)}',
                          style: WildPathTypography.body(
                              fontSize: 11,
                              color: WildPathColors.ember,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Text('Set a budget above to track your spending',
                    style: WildPathTypography.body(
                        fontSize: 12, color: WildPathColors.smoke)),
              ),
          ]),
        ),

        // ── Category breakdown ───────────────────────────────────────────
        if (_items.isNotEmpty) _buildCategoryBreakdown(),

        // ── Expense list or empty state ──────────────────────────────────
        if (_items.isEmpty) ...[
          const TipCard(
            emoji: '💡',
            content:
                'No expenses yet — add your first one below and WildPath will track every dollar so you can focus on the adventure.',
            bgColor: WildPathColors.cream,
            borderColor: WildPathColors.mist,
          ),
          const SizedBox(height: 4),
        ] else ...[
          GroupHeader('Expenses (${_items.length})'),
          ..._items.map((item) => _BudgetExpenseRow(
                key: Key(item.id),
                item: item,
                onDelete: () {
                  setState(() => _items.removeWhere((i) => i.id == item.id));
                  _save();
                },
              )),
          const WildDivider(),
        ],

        // ── Add expense CTA ──────────────────────────────────────────────
        PrimaryButton('＋  Add Expense',
            fullWidth: true, onPressed: _showAddSheet),

        const SizedBox(height: 10),
        OutlineButton2('Next: Add Permit and Passes',
            fullWidth: true, onPressed: widget.onGoToPermits),
      ]),
    );
  }

  Widget _heroStat(String value, String label, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value,
              style: WildPathTypography.display(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: WildPathTypography.body(
                  fontSize: 9,
                  letterSpacing: 1.0,
                  color: WildPathColors.mist.withValues(alpha: 0.7))),
        ],
      );

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: WildPathTypography.body(
                fontSize: 9.5,
                letterSpacing: 0.12 * 9.5,
                color: WildPathColors.smoke)),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style:
              WildPathTypography.body(fontSize: 14, color: WildPathColors.pine),
          decoration: InputDecoration(
            prefixText: prefixText,
            prefixStyle: WildPathTypography.body(
                fontSize: 14, color: WildPathColors.pine),
            hintText: hint,
            hintStyle: WildPathTypography.body(
                fontSize: 13, color: WildPathColors.stone),
            filled: true,
            fillColor: WildPathColors.cream,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
      ]);
}

// ── Budget expense row ──────────────────────────────────────────────────────

class _BudgetExpenseRow extends StatelessWidget {
  final BudgetItem item;
  final VoidCallback onDelete;
  const _BudgetExpenseRow(
      {required this.item, required this.onDelete, super.key});

  @override
  Widget build(BuildContext context) {
    final cc = _catColor(item.category);
    return Dismissible(
      key: Key('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: WildPathColors.red, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.delete_outline, color: Colors.white, size: 20),
          const SizedBox(height: 2),
          Text('DELETE',
              style: WildPathTypography.body(
                  fontSize: 9,
                  letterSpacing: 1.1,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
      onDismissed: (_) => onDelete(),
      child: WildCard(
        child: Row(children: [
          // Category color indicator dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: cc, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          // Emoji
          Text(item.category.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          // Description + category label
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.description,
                  style: WildPathTypography.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WildPathColors.pine)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item.category.label,
                    style: WildPathTypography.body(
                        fontSize: 9.5, fontWeight: FontWeight.w600, color: cc)),
              ),
            ]),
          ),
          // Amount
          Text('\$${item.amount.toStringAsFixed(2)}',
              style: WildPathTypography.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WildPathColors.forest)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PASSES & PERMITS
// ══════════════════════════════════════════════════════════════════════════
class _PassesSection extends StatelessWidget {
  final VoidCallback onBack;
  const _PassesSection({required this.onBack});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BackHeader(title: '🏞️ Passes & Permits', onBack: onBack),
          Text('Photos of your park passes, permits & cards',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke)),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WildPathColors.mist, width: 1.5)),
            child: Column(children: [
              const Text('🏞️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('Coming Soon',
                  style: WildPathTypography.display(
                      fontSize: 22, color: WildPathColors.forest)),
              const SizedBox(height: 8),
              Text(
                  'Passes & Permits storage is on the way.\nStore photos of your park passes, annual permits, and reservation confirmations — all in one place.',
                  style: WildPathTypography.body(
                      fontSize: 13, color: WildPathColors.smoke, height: 1.5),
                  textAlign: TextAlign.center),
            ]),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════
// MY PROFILE
// ══════════════════════════════════════════════════════════════════════════
class _ProfileSection extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onBack;
  const _ProfileSection({required this.storage, required this.onBack});
  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  late TextEditingController _name, _email;
  late List<String> _selectedStyles;
  late bool _notifTrips, _notifWeather;

  final _styles = [
    ('Campsites', '🏕️ Campsites'),
    ('RV or Van', '🚐 RV or Van'),
    ('Backpacking', '🎒 Backpacking'),
    ('On the Water', '🛶 On the Water'),
    ('Cabins', '🏡 Cabins'),
    ('Off-Grid', '🌲 Off-Grid'),
    ('Group Camp', '👨‍👩‍👧‍👦 Group Camp'),
    ('Glamping', '✨ Glamping'),
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.storage.userName);
    _email = TextEditingController(text: widget.storage.userEmail);
    _selectedStyles = List<String>.from(widget.storage.userStyles);
    _notifTrips = widget.storage.notifTrips;
    _notifWeather = widget.storage.notifWeather;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prevTrips = widget.storage.notifTrips;
    final prevWeather = widget.storage.notifWeather;

    await widget.storage.setUserName(_name.text.trim());
    await widget.storage.setUserEmail(_email.text.trim());
    await widget.storage.setUserStyles(_selectedStyles);
    await widget.storage.setNotifTrips(_notifTrips);
    await widget.storage.setNotifWeather(_notifWeather);

    // Trip reminders toggled
    if (_notifTrips && !prevTrips) {
      await NotificationService.instance
          .rescheduleAllSavedTrips(widget.storage);
    } else if (!_notifTrips && prevTrips) {
      final trips = widget.storage.loadSavedTrips();
      await NotificationService.instance.cancelAllTripReminders(trips);
    }

    // Weather alerts toggled
    if (_notifWeather && !prevWeather) {
      await startWeatherAlertWorker();
    } else if (!_notifWeather && prevWeather) {
      await stopWeatherAlertWorker();
    }

    if (mounted) showWildToast(context, '✅ Profile saved');
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BackHeader(title: '👤 My Profile', onBack: widget.onBack),
          Text('Personalize your WildPath experience',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke)),
          const SizedBox(height: 16),
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _pf('Your Name', _name, 'e.g. Alex', TextInputType.name),
                const SizedBox(height: 12),
                _pf('Email (optional)', _email, 'e.g. alex@email.com',
                    TextInputType.emailAddress),
                const SizedBox(height: 12),
                Text('CAMP STYLES',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.12 * 10,
                        color: WildPathColors.smoke)),
                const SizedBox(height: 6),
                Text('Matches the camp types you picked during onboarding.',
                    style: WildPathTypography.body(
                        fontSize: 11, color: WildPathColors.smoke)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _styles
                      .map((style) => _styleOption(style.$1, style.$2))
                      .toList(),
                ),
              ])),
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('NOTIFICATIONS',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.12 * 10,
                        color: WildPathColors.smoke)),
                const SizedBox(height: 12),
                _notif(
                    'Trip Reminders',
                    '2 days & 1 day before your trip starts',
                    _notifTrips,
                    (v) => setState(() => _notifTrips = v)),
                const SizedBox(height: 10),
                _notif(
                    'Severe Weather Alerts',
                    'In-app banner when NWS issues alerts',
                    _notifWeather,
                    (v) => setState(() => _notifWeather = v)),
              ])),
          PrimaryButton('Save Profile', fullWidth: true, onPressed: _save),
        ]),
      );

  Widget _pf(String label, TextEditingController ctrl, String hint,
          TextInputType type) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: WildPathTypography.body(
                fontSize: 10,
                letterSpacing: 0.12 * 10,
                color: WildPathColors.smoke)),
        const SizedBox(height: 6),
        TextFormField(
            controller: ctrl,
            keyboardType: type,
            style: WildPathTypography.body(
                fontSize: 14, color: WildPathColors.pine),
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      ]);

  Widget _styleOption(String value, String label) {
    final isSelected = _selectedStyles.contains(value);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          if (_selectedStyles.length == 1) return;
          _selectedStyles.remove(value);
        } else {
          _selectedStyles.add(value);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? WildPathColors.forest : WildPathColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? WildPathColors.forest : WildPathColors.mist,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: WildPathTypography.body(
            fontSize: 12,
            color: isSelected ? Colors.white : WildPathColors.pine,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _notif(
          String title, String sub, bool value, ValueChanged<bool> onChanged) =>
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: WildPathTypography.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WildPathColors.pine)),
          Text(sub,
              style: WildPathTypography.body(
                  fontSize: 11, color: WildPathColors.smoke)),
        ])),
        Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: WildPathColors.moss),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════
// ABOUT
// ══════════════════════════════════════════════════════════════════════════
class _AboutSection extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onPrivacy;
  const _AboutSection({required this.onBack, required this.onPrivacy});

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BackHeader(title: 'About WildPath', onBack: widget.onBack),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [WildPathColors.pine, WildPathColors.forest],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Text.rich(TextSpan(
                  text: 'Wild',
                  style: WildPathTypography.display(
                      fontSize: 32, color: Colors.white),
                  children: [
                    TextSpan(
                        text: 'Path',
                        style: WildPathTypography.display(
                            fontSize: 32,
                            fontStyle: FontStyle.italic,
                            color: WildPathColors.fern))
                  ])),
              const SizedBox(height: 6),
              Text('PLAN THE WILD. CAMP WITH CONFIDENCE.',
                  style: WildPathTypography.body(
                      fontSize: 9.5,
                      letterSpacing: 0.2 * 9.5,
                      color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 12),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      _version.isNotEmpty ? 'Version $_version' : 'Version —',
                      style: WildPathTypography.body(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7)))),
            ]),
          ),
          const SizedBox(height: 16),
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('ABOUT THE APP',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.12 * 10,
                        color: WildPathColors.amber)),
                const SizedBox(height: 10),
                Text(
                    'WildPath is a full-featured camping trip planner. Plan trips, track gear, schedule meals, monitor weather, manage your budget, and store past adventures — all in one place.',
                    style: WildPathTypography.body(
                        fontSize: 13, color: WildPathColors.pine, height: 1.7)),
              ])),
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('DEVELOPER',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.12 * 10,
                        color: WildPathColors.amber)),
                const SizedBox(height: 10),
                _aRow(
                    '📧',
                    'Contact / Support',
                    'dev.cal.apps@gmail.com',
                    () =>
                        launchUrl(Uri.parse('mailto:dev.cal.apps@gmail.com'))),
                const SizedBox(height: 8),
                _aRow(
                    '💬',
                    'Send Feedback',
                    'We read every message',
                    () => launchUrl(Uri.parse(
                        'mailto:dev.cal.apps@gmail.com?subject=WildPath Feedback'))),
                const SizedBox(height: 8),
                _aRow('🔒', 'Privacy Policy', 'How we handle your data',
                    widget.onPrivacy),
              ])),
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('POWERED BY',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.12 * 10,
                        color: WildPathColors.amber)),
                const SizedBox(height: 10),
                _pRow('🗺️ OpenStreetMap + flutter_map', 'Open Source'),
                _pRow('🌤️ Open-Meteo', 'Free Weather API'),
                _pRow('⛈️ NWS / weather.gov', 'Alerts'),
                _pRow('🔍 Nominatim', 'Geocoding'),
              ])),
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'WILDPATH${_version.isNotEmpty ? ' v$_version' : ''} · BUILT WITH ❤️ FOR THE OUTDOORS',
                      style: WildPathTypography.body(
                          fontSize: 9.5,
                          color: WildPathColors.stone,
                          letterSpacing: 0.08 * 9.5)))),
        ]),
      );

  Widget _aRow(String emoji, String title, String sub, VoidCallback onTap) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: WildPathColors.cream,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: WildPathTypography.body(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: WildPathColors.pine)),
                Text(sub,
                    style: WildPathTypography.body(
                        fontSize: 11, color: WildPathColors.moss)),
              ]),
            ]),
          ));

  Widget _pRow(String name, String desc) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(name,
            style: WildPathTypography.body(
                fontSize: 12, color: WildPathColors.pine)),
        Text(desc,
            style: WildPathTypography.body(
                fontSize: 11, color: WildPathColors.smoke)),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════
// PRIVACY POLICY
// ══════════════════════════════════════════════════════════════════════════
class _PrivacyPolicySection extends StatelessWidget {
  final VoidCallback onBack;
  const _PrivacyPolicySection({required this.onBack});

  Widget _section(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: WildCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 0.12 * 10,
                  color: WildPathColors.amber)),
          const SizedBox(height: 8),
          Text(body,
              style: WildPathTypography.body(
                  fontSize: 13, color: WildPathColors.pine, height: 1.6)),
        ])),
      );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BackHeader(title: '🔒 Privacy Policy', onBack: onBack),
          Text('Last updated: March 2026',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke)),
          const SizedBox(height: 16),
          _section('Overview',
              'WildPath is designed with your privacy in mind. All data you enter — trip details, gear lists, meals, emergency contacts, and profile information — is stored locally on your device only. We do not collect, transmit, or sell your personal data.'),
          _section('Data We Collect',
              'WildPath does not collect personal data on our servers. The following information is stored only on your device:\n\n• Your name and optional email address (entered during onboarding)\n• Trip plans, dates, locations, and notes\n• Gear lists and meal schedules\n• Emergency contact names and phone numbers\n• Budget entries\n• Camping style preferences'),
          _section('Location Data',
              'WildPath may request access to your device location to help identify your current position on the map. Location data is used only within the app in real time and is never stored or transmitted to any server.'),
          _section('Third-Party Services',
              'WildPath uses the following third-party services to provide core functionality:\n\n• Google Places API — to search and resolve campsite locations. Your search queries are sent to Google\'s servers.\n• Open-Meteo — to fetch weather forecasts. Your trip coordinates are sent to Open-Meteo\'s servers.\n• NWS / weather.gov — to retrieve weather alerts for your area.\n\nThese services have their own privacy policies. We recommend reviewing them if you have concerns.'),
          _section('Data Retention',
              'All app data is stored in your device\'s local storage (SharedPreferences). Uninstalling the app will permanently delete all stored data. We have no ability to recover deleted data.'),
          _section('Children\'s Privacy',
              'WildPath is not directed at children under 13. We do not knowingly collect information from children.'),
          _section('Changes to This Policy',
              'We may update this Privacy Policy from time to time. Updates will be reflected in the app with a revised date. Continued use of the app after changes constitutes acceptance of the updated policy.'),
          _section('Contact',
              'If you have questions about this Privacy Policy, please contact us at:\n\ndev.cal.apps@gmail.com'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://jade-lolly-1a2c94.netlify.app'),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: WildPathColors.amber.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'View full policy online',
                textAlign: TextAlign.center,
                style: WildPathTypography.body(
                    fontSize: 13, color: WildPathColors.amber),
              ),
            ),
          ),
        ]),
      );
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';
import '../services/background_service.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../models/meal_item.dart';
import '../models/pass_item.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/country_autocomplete_field.dart';

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
        return _PassesSection(storage: widget.storage, onBack: _back);
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

    return KeyboardAwareScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageTitle('More',
              subtitle: name.isNotEmpty ? 'Hey, $name 👋' : 'Tools & settings'),
          const SizedBox(height: 20),
          _item('👤', 'My Profile', 'Name, style & notifications',
              () => _go(MoreSection.profile)),
          _item('🏞️', 'Passes & Permits', 'Photos of passes, permits & cards',
              () => _go(MoreSection.passes)),
          _item('🚨', 'Emergency Info', 'Contacts, GPS & rescue tips',
              () => _go(MoreSection.emergency)),
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
    final location = trip.locationSearchQuery.trim();
    if (location.isNotEmpty) return location;

    final name = trip.name.trim();
    if (name.isNotEmpty) return name;

    return null;
  }

  Future<LocationResult?> _resolveLocation() async {
    if (widget.trip.lat != null && widget.trip.lng != null) {
      return LocationResult(
        lat: widget.trip.lat!,
        lng: widget.trip.lng!,
        displayName: widget.trip.locationDisplay.trim().isNotEmpty
            ? widget.trip.locationDisplay.trim()
            : widget.trip.name.trim(),
      );
    }

    final query = _mapQuery(widget.trip);
    if (query == null) return null;
    return WeatherService.geocode(query, country: widget.trip.country);
  }

  Widget _buildEmptyMapState(String title) {
    final hasDestination = widget.trip.locationDisplay.trim().isNotEmpty;
    final headline = hasDestination ? 'Map placement needs coordinates' : 'Set a destination to unlock the map';
    final body = hasDestination
        ? 'This trip has a destination label, but no verified coordinates yet. Open Plan, choose the saved destination again, and tap a result to anchor it precisely.'
        : 'Your map will look much better once this trip has a saved destination. Choose a campsite or area in Plan and save it to populate the map, weather, and local emergency details.';

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned(
            top: -36,
            right: -30,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WildPathColors.fern.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -44,
            left: -12,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WildPathColors.moss.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: WildPathColors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: WildPathColors.mist),
                      ),
                      child: Text(
                        'MAP WAITING FOR LOCATION',
                        style: WildPathTypography.body(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: WildPathColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: WildPathColors.forest,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    WildPathColors.pine.withValues(alpha: 0.16),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.explore_off_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headline,
                                style: WildPathTypography.display(
                                  fontSize: 20,
                                  color: WildPathColors.forest,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                body,
                                style: WildPathTypography.body(
                                  fontSize: 12,
                                  color: WildPathColors.smoke,
                                  height: 1.6,
                                ),
                              ),
                              if (title.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Current trip: $title',
                                  style: WildPathTypography.body(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: WildPathColors.pine,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MapSetupStep(
                          step: '1',
                          title: 'Open Plan',
                          subtitle: 'Start from the trip planner',
                        ),
                        _MapSetupStep(
                          step: '2',
                          title: 'Choose destination',
                          subtitle: 'Search and tap a result',
                        ),
                        _MapSetupStep(
                          step: '3',
                          title: 'Save trip',
                          subtitle: 'Verified coordinates appear here',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
        final title = widget.trip.locationDisplay.trim().isNotEmpty
            ? widget.trip.locationDisplay.trim()
            : widget.trip.name.trim();
        final mapFrameHeight = hasMapLocation ? 280.0 : 360.0;

        return KeyboardAwareScrollView(
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
                height: mapFrameHeight,
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
                        : _buildEmptyMapState(title),
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
            TipCard(
                emoji: hasMapLocation ? '💡' : '🧭',
                content: hasMapLocation
                    ? 'Search for your campsite in the Plan tab and tap a result to save verified coordinates for the most precise map placement.'
                    : 'The map, weather, and local emergency numbers all become more precise once the trip has a saved destination with verified coordinates.'),
          ]),
        );
      });
}

class _MapSetupStep extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;

  const _MapSetupStep({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WildPathColors.mist),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: WildPathColors.forest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                step,
                style: WildPathTypography.body(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: WildPathTypography.body(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: WildPathColors.pine,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: WildPathTypography.body(
                fontSize: 10,
                color: WildPathColors.smoke,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
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

  Widget _buildList() => KeyboardAwareScrollView(
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
                                      if (trip.locationDisplay.isNotEmpty)
                                        trip.locationDisplay,
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

    // Quick-share text for messages
    String shareText() {
      final lines = [
        '🌲 WildPath Trip Summary',
        '',
        if (t.name.isNotEmpty) '📋 ${t.name}',
        if (t.locationDisplay.isNotEmpty) '📍 ${t.locationDisplay}',
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

    String shareEmailBody() {
      final lines = [
        'WildPath Trip Summary',
        '',
        if (t.name.isNotEmpty) 'Trip: ${t.name}',
        if (t.locationDisplay.isNotEmpty) 'Destination: ${t.locationDisplay}',
        if (t.startDate.isNotEmpty)
          'Dates: ${_fmtShort(t.startDate)} – ${_fmtShort(t.endDate)} (${t.nights} night${t.nights == 1 ? '' : 's'})',
        'Group: ${t.groupSize} ${t.groupSize == 1 ? 'person' : 'people'}',
        'Trip type: ${t.tripType}',
        '',
        'Packing',
        'Gear packed: $gearPacked / $gearTotal',
        if (totalSlots > 0) 'Meals planned: $filledSlots / $totalSlots',
        if (budgetLimit > 0)
          'Budget: \$${budgetSpent.toStringAsFixed(0)} spent of \$${budgetLimit.toStringAsFixed(0)} (\$${budgetRemain.toStringAsFixed(0)} remaining)'
        else if (budgetSpent > 0)
          'Budget spent: \$${budgetSpent.toStringAsFixed(0)}',
        'Permits saved: ${permits.length}',
        '',
        'Trip Info For Rescuers',
        'Location: ${t.locationDisplay.isNotEmpty ? t.locationDisplay : 'Not set'}',
        if (t.startDate.isNotEmpty)
          'Dates: ${_fmtShort(t.startDate)} – ${_fmtShort(t.endDate)}',
        'Group: ${t.groupSize} ${t.groupSize == 1 ? 'person' : 'people'} · ${t.tripType}',
        if (permits.isNotEmpty) ...[
          '',
          'Permits',
          ...permits.map((p) =>
              '- ${p.permitType}${p.permitNum.isNotEmpty ? ' #${p.permitNum}' : ''}${p.entryTime.isNotEmpty ? ' · ${p.entryTime}' : ''}${p.notes.isNotEmpty ? ' · ${p.notes}' : ''}'),
        ],
        if (contacts.isNotEmpty) ...[
          '',
          'Emergency Contacts',
          ...contacts.map((c) => '- ${c.name}: ${c.phone}'),
        ],
        if (t.notes.isNotEmpty) ...[
          '',
          'Notes',
          t.notes,
        ],
      ];
      return lines.join('\n');
    }

    return KeyboardAwareScrollView(
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
                    if (t.locationDisplay.isNotEmpty)
                      Text(t.locationDisplay,
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
            _infoRow('📍',
                t.locationDisplay.isNotEmpty ? t.locationDisplay : 'Not set'),
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
            child: OutlineButton2('Share via Text', onPressed: () {
              Share.share(shareText(),
                  subject: t.name.isNotEmpty ? t.name : 'WildPath Trip');
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlineButton2('Share via Email', onPressed: () async {
              final subject = t.name.isNotEmpty
                  ? 'WildPath Trip: ${t.name}'
                  : 'WildPath Trip Summary';
              final uri = Uri(
                scheme: 'mailto',
                queryParameters: {
                  'subject': subject,
                  'body': shareEmailBody(),
                },
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else if (mounted) {
                showWildToast(context, 'No email app available');
              }
            }),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
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
                                    fontSize: 13, color: WildPathColors.smoke)),
                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(
                                  child: OutlineButton2('Cancel',
                                      onPressed: () => Navigator.pop(context))),
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
                                      _trips = widget.storage.loadSavedTrips();
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
  Position? _currentPosition;
  bool _isLoadingPosition = false;

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

  String get _currentCoordinateText {
    final pos = _currentPosition;
    if (pos == null) return 'Not captured yet';
    return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
  }

  Future<void> _getCurrentCoordinates() async {
    setState(() => _isLoadingPosition = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) showWildToast(context, 'Location permission is required');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) showWildToast(context, 'Turn on device location services');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      if (!mounted) return;
      setState(() => _currentPosition = position);
      showWildToast(context, '📍 Current coordinates captured');
    } catch (e) {
      if (mounted) showWildToast(context, 'Could not get current coordinates');
    } finally {
      if (mounted) setState(() => _isLoadingPosition = false);
    }
  }

  Future<void> _copyCoordinates() async {
    final pos = _currentPosition;
    if (pos == null) {
      showWildToast(context, 'Get current coordinates first');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _currentCoordinateText));
    if (mounted) showWildToast(context, 'Coordinates copied');
  }

  Future<void> _shareCoordinates() async {
    final pos = _currentPosition;
    if (pos == null) {
      showWildToast(context, 'Get current coordinates first');
      return;
    }
    final tripName = widget.trip.name.trim().isNotEmpty
        ? widget.trip.name.trim()
        : 'My location';
    await Share.share(
      '$tripName\nCurrent coordinates: $_currentCoordinateText\nhttps://maps.google.com/?q=${pos.latitude},${pos.longitude}',
      subject: 'Current coordinates',
    );
  }

  Future<void> _openCoordinatesInMaps() async {
    final pos = _currentPosition;
    if (pos == null) {
      showWildToast(context, 'Get current coordinates first');
      return;
    }
    final url = Uri.parse(
        'https://maps.google.com/?q=${pos.latitude},${pos.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final nums = _numbersForCoords(t.lat, t.lng);
    final hasLocation = t.lat != null && t.lng != null;
    return KeyboardAwareScrollView(
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EMERGENCY NUMBERS',
                  style: WildPathTypography.body(
                      fontSize: 10,
                      letterSpacing: 0.12 * 10,
                      color: WildPathColors.red)),
              const SizedBox(height: 4),
              Text(
                hasLocation
                    ? '📍 ${nums.countryName}'
                    : 'Set location for local numbers',
                style: WildPathTypography.body(
                    fontSize: 10, color: WildPathColors.smoke),
              ),
            ],
          ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CURRENT COORDINATES',
                  style: WildPathTypography.body(
                      fontSize: 10,
                      letterSpacing: 0.12 * 10,
                      color: WildPathColors.smoke)),
              if (_isLoadingPosition)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentCoordinateText,
            style: WildPathTypography.display(
                fontSize: 22, color: WildPathColors.pine),
          ),
          const SizedBox(height: 6),
          Text(
            _currentPosition == null
                ? 'Use this when you are on trail or off-grid and need your exact location.'
                : 'Accuracy ${_currentPosition!.accuracy.toStringAsFixed(0)} m${_currentPosition!.altitude != 0 ? ' • Alt ${_currentPosition!.altitude.toStringAsFixed(0)} m' : ''}',
            style: WildPathTypography.body(
                fontSize: 11, color: WildPathColors.smoke, height: 1.5),
          ),
          const SizedBox(height: 14),
          PrimaryButton('Get My Current Coordinates',
              fullWidth: true,
              onPressed: _isLoadingPosition ? null : _getCurrentCoordinates),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlineButton2('Copy Coordinates',
                  onPressed: _copyCoordinates),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlineButton2('Share Location',
                  onPressed: _shareCoordinates),
            ),
          ]),
          const SizedBox(height: 8),
          OutlineButton2('Open in Maps',
              fullWidth: true, onPressed: _openCoordinatesInMaps),
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
          _rr('📍 Location',
              t.locationDisplay.isNotEmpty ? t.locationDisplay : 'Not set'),
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

    return KeyboardAwareScrollView(
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
class _PassesSection extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onBack;
  const _PassesSection({required this.storage, required this.onBack});

  @override
  State<_PassesSection> createState() => _PassesSectionState();
}

class _PassesSectionState extends State<_PassesSection> {
  List<PassItem> _passes = [];

  @override
  void initState() {
    super.initState();
    _passes = widget.storage.loadPasses();
  }

  Future<void> _save() => widget.storage.savePasses(_passes);

  Future<void> _delete(PassItem pass) async {
    try {
      final f = File(pass.filePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    setState(() => _passes.removeWhere((x) => x.id == pass.id));
    await _save();
  }

  Future<void> _addPass() async {
    final choice = await _showAttachSheet();
    if (choice == null || !mounted) return;

    final result = await _resolveFile(choice);
    if (result == null || !mounted) return;
    final (filePath, mimeType) = result;

    final label = await _showLabelDialog();
    if (label == null || !mounted) return;

    final destPath = await _copyToPassesDir(filePath);

    final newPass = PassItem(
      id: const Uuid().v4(),
      label: label,
      filePath: destPath,
      mimeType: mimeType,
    );
    setState(() => _passes.add(newPass));
    await _save();
  }

  Future<String> _copyToPassesDir(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final passesDir = Directory('${docsDir.path}/passes');
    passesDir.createSync(recursive: true);
    final ext = p.extension(filePath);
    final destPath = '${passesDir.path}/${const Uuid().v4()}$ext';
    File(filePath).copySync(destPath);
    return destPath;
  }

  Future<(String, String)?> _resolveFile(String choice) async {
    String? filePath;
    String? mimeType;

    if (choice == 'camera' || choice == 'gallery') {
      final source =
          choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final xfile =
          await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (xfile == null) return null;
      filePath = xfile.path;
      mimeType = xfile.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
    } else {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.single.path == null) return null;
      filePath = result.files.single.path!;
      mimeType = 'application/pdf';
    }
    return (filePath, mimeType);
  }

  Future<String?> _showAttachSheet() => showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _PassesDragHandle(),
              const SizedBox(height: 16),
              Text('Add Pass',
                  style: WildPathTypography.display(
                      fontSize: 18, color: WildPathColors.pine)),
              const SizedBox(height: 4),
              Text('Choose a photo or PDF to save',
                  style: WildPathTypography.body(
                      fontSize: 12, color: WildPathColors.smoke)),
              const SizedBox(height: 12),
              _attachOption(Icons.camera_alt_outlined, 'Take Photo', 'camera'),
              _attachOption(Icons.photo_library_outlined, 'Choose from Gallery',
                  'gallery'),
              _attachOption(
                  Icons.picture_as_pdf_outlined, 'Choose PDF File', 'pdf'),
            ]),
          ),
        ),
      );

  Widget _attachOption(IconData icon, String label, String value) => ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: WildPathColors.forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: WildPathColors.forest, size: 20),
        ),
        title: Text(label,
            style: WildPathTypography.body(
                fontSize: 14, color: WildPathColors.pine)),
        onTap: () => Navigator.pop(context, value),
      );

  Future<String?> _showLabelDialog() async {
    final ctrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PassesDragHandle(),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: WildPathColors.forest.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.badge_outlined,
                          color: WildPathColors.forest, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Name This Pass',
                        style: WildPathTypography.display(
                            fontSize: 20, color: WildPathColors.pine)),
                  ]),
                  const SizedBox(height: 20),
                  Text('LABEL',
                      style: WildPathTypography.body(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: WildPathColors.smoke)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: WildPathTypography.body(
                        fontSize: 14, color: WildPathColors.pine),
                    decoration: InputDecoration(
                      hintText: 'e.g. Annual Pass, State Park Pass',
                      hintStyle: WildPathTypography.body(
                          fontSize: 13, color: WildPathColors.stone),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    'Save Pass',
                    fullWidth: true,
                    onPressed: () {
                      final val = ctrl.text.trim();
                      Navigator.pop(ctx, val.isEmpty ? 'Untitled Pass' : val);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openImage(PassItem pass) {
    showDialog(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(_),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Hero(
                    tag: 'pass_img_${pass.id}',
                    child: InteractiveViewer(
                      child: Image.file(
                        File(pass.filePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(_),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      pass.label,
                      style: WildPathTypography.body(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPdf(PassItem pass) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PdfViewerPage(filePath: pass.filePath, title: pass.label),
      ),
    );
  }

  void _confirmDelete(PassItem pass) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _PassesDragHandle(),
            const SizedBox(height: 20),
            Text('Delete "${pass.label}"?',
                style: WildPathTypography.display(
                    fontSize: 18, color: WildPathColors.pine)),
            const SizedBox(height: 8),
            Text('This will permanently remove the pass from your wallet.',
                style: WildPathTypography.body(
                    fontSize: 13, color: WildPathColors.smoke, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlineButton2(
                  'Cancel',
                  onPressed: () => Navigator.pop(_),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WildPathColors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide.none,
                  ),
                  onPressed: () {
                    Navigator.pop(_);
                    _delete(pass);
                  },
                  child: Text('Delete',
                      style: WildPathTypography.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WildPathColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackHeader(title: 'Passes & Permits', onBack: widget.onBack),
                  const SizedBox(height: 4),
                  Text('Photos of your park passes, permits & cards',
                      style: WildPathTypography.body(
                          fontSize: 12, color: WildPathColors.smoke)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Expanded(
              child: _passes.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: _passes.length,
                      itemBuilder: (_, i) => _PassCard(
                        pass: _passes[i],
                        onTap: () {
                          final pass = _passes[i];
                          if (pass.mimeType == 'application/pdf') {
                            _openPdf(pass);
                          } else {
                            _openImage(pass);
                          }
                        },
                        onDelete: () => _confirmDelete(_passes[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPass,
        backgroundColor: WildPathColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Pass',
            style: WildPathTypography.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: WildPathColors.forest.withValues(alpha: 0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.badge_outlined,
                    color: WildPathColors.forest, size: 36),
              ),
              const SizedBox(height: 20),
              Text('No Passes Yet',
                  style: WildPathTypography.display(
                      fontSize: 20, color: WildPathColors.forest)),
              const SizedBox(height: 8),
              Text(
                  'Store photos of your park passes, annual permits, and reservation confirmations — all in one place.',
                  style: WildPathTypography.body(
                      fontSize: 13, color: WildPathColors.smoke, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              PrimaryButton('Add your first pass',
                  fullWidth: false, onPressed: _addPass),
            ],
          ),
        ),
      );
}

class _PassCard extends StatelessWidget {
  final PassItem pass;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PassCard({
    required this.pass,
    required this.onTap,
    required this.onDelete,
  });

  bool get _isPdf => pass.mimeType == 'application/pdf';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: WildPathColors.mist.withValues(alpha: 0.9), width: 1),
              boxShadow: [
                BoxShadow(
                    color: WildPathColors.pine.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _isPdf ? _pdfThumbnail() : _imageThumbnail(),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    pass.label,
                    style: WildPathTypography.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: WildPathColors.pine),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageThumbnail() => Hero(
        tag: 'pass_img_${pass.id}',
        child: Image.file(
          File(pass.filePath),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _pdfThumbnail(),
        ),
      );

  Widget _pdfThumbnail() => Container(
        color: WildPathColors.forest.withValues(alpha: 0.07),
        child: const Center(
          child: Icon(Icons.picture_as_pdf_outlined,
              color: WildPathColors.forest, size: 48),
        ),
      );
}

class _PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String title;
  const _PdfViewerPage({required this.filePath, required this.title});

  @override
  State<_PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<_PdfViewerPage> {
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: WildPathColors.forest,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: WildPathTypography.body(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: WildPathTypography.body(
                      fontSize: 13, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: PDFView(
        filePath: widget.filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onRender: (pages) => setState(() => _totalPages = pages ?? 0),
        onPageChanged: (page, _) => setState(() => _currentPage = page ?? 0),
      ),
    );
  }
}

class _PassesDragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: WildPathColors.mist,
                borderRadius: BorderRadius.circular(2))),
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
  late TextEditingController _name, _email, _countryCtrl;
  late FocusNode _countryFocusNode;
  late List<String> _selectedStyles;
  late bool _notifTrips, _notifWeather;
  String _country = '';

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
    _country = widget.storage.userCountry;
    _countryCtrl = TextEditingController(text: _country);
    _countryFocusNode = FocusNode();
    _selectedStyles = List<String>.from(widget.storage.userStyles);
    _notifTrips = widget.storage.notifTrips;
    _notifWeather = widget.storage.notifWeather;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _countryCtrl.dispose();
    _countryFocusNode.dispose();
    super.dispose();
  }

  void _onCountrySelected(String value) {
    final normalized = TripModel.normalizeCountryName(value);
    _countryCtrl.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    if (_country == normalized) return;
    setState(() => _country = normalized);
  }

  void _onCountryInputChanged(String _, String? exactMatch) {
    final normalized =
        exactMatch == null ? '' : TripModel.normalizeCountryName(exactMatch);
    if (_country == normalized) return;
    setState(() => _country = normalized);
  }

  Future<bool> _ensureNotificationPermission() async {
    if (widget.storage.notifPermissionAsked) return true;
    final granted = await NotificationService.instance.requestPermission();
    await widget.storage.setNotifPermissionAsked(true);
    if (!granted && mounted) {
      showWildToast(
        context,
        'Notifications stayed off. You can enable them later in system settings.',
      );
    }
    return granted;
  }

  Future<void> _onNotifTripsChanged(bool value) async {
    if (!value) {
      setState(() => _notifTrips = false);
      return;
    }
    final granted = await _ensureNotificationPermission();
    if (!mounted || !granted) return;
    setState(() => _notifTrips = true);
  }

  Future<void> _onNotifWeatherChanged(bool value) async {
    if (!value) {
      setState(() => _notifWeather = false);
      return;
    }
    final granted = await _ensureNotificationPermission();
    if (!mounted || !granted) return;
    setState(() => _notifWeather = true);
  }

  Future<void> _save() async {
    final prevTrips = widget.storage.notifTrips;
    final prevWeather = widget.storage.notifWeather;

    await widget.storage.setUserName(_name.text.trim());
    await widget.storage.setUserEmail(_email.text.trim());
    await widget.storage.setUserCountry(_country);
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
  Widget build(BuildContext context) => KeyboardAwareScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BackHeader(title: '👤 My Profile', onBack: widget.onBack),
          Text(
              'Keep your account details and default camping preferences in sync.',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [WildPathColors.forest, WildPathColors.moss],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile & Preferences',
                    style: WildPathTypography.display(
                        fontSize: 22, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                    'Your country and camp styles shape the defaults you see across WildPath.',
                    style: WildPathTypography.body(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.72))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _profileSectionHeader(
                  'Profile Basics',
                  'These match the personal details from onboarding.',
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack = constraints.maxWidth < 520;
                    final fields = [
                      Expanded(
                        child: _pf('Your Name', _name, 'e.g. Alex',
                            TextInputType.name),
                      ),
                      Expanded(
                        child: _pf('Email', _email, 'e.g. alex@email.com',
                            TextInputType.emailAddress),
                      ),
                    ];
                    if (stack) {
                      return Column(
                        children: [
                          _pf('Your Name', _name, 'e.g. Alex',
                              TextInputType.name),
                          const SizedBox(height: 12),
                          _pf('Email', _email, 'e.g. alex@email.com',
                              TextInputType.emailAddress),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        fields[0],
                        const SizedBox(width: 12),
                        fields[1],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _countryField(),
              ])),
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _profileSectionHeader(
                  'Camp Styles',
                  'Update the trip types you want emphasized throughout the app.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _styles
                      .map((style) => _styleOption(style.$1, style.$2))
                      .toList(),
                ),
              ])),
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _profileSectionHeader(
                  'Notifications',
                  'Choose which reminders and weather alerts stay active.',
                ),
                const SizedBox(height: 12),
                _notif(
                    'Trip Reminders',
                    '2 days & 1 day before your trip starts',
                    _notifTrips,
                    _onNotifTripsChanged),
                const SizedBox(height: 10),
                _notif(
                    'Severe Weather Alerts',
                    'In-app banner when NWS issues alerts',
                    _notifWeather,
                    _onNotifWeatherChanged),
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

  Widget _countryField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COUNTRY',
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: WildPathColors.smoke)),
          const SizedBox(height: 6),
          CountryAutocompleteField(
            controller: _countryCtrl,
            focusNode: _countryFocusNode,
            hintText: 'Type your country',
            fallbackValue: _country,
            fillColor: WildPathColors.cream,
            textColor: WildPathColors.pine,
            hintColor: WildPathColors.stone,
            iconColor: WildPathColors.smoke,
            optionsBackgroundColor: Colors.white,
            optionsTextColor: WildPathColors.pine,
            optionsBorderColor: WildPathColors.mist,
            onSelected: _onCountrySelected,
            onChanged: _onCountryInputChanged,
          ),
        ],
      );

  Widget _profileSectionHeader(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: WildPathColors.smoke)),
          const SizedBox(height: 4),
          Text(title,
              style: WildPathTypography.display(
                  fontSize: 18, color: WildPathColors.forest)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: WildPathTypography.body(
                  fontSize: 11.5, height: 1.45, color: WildPathColors.smoke)),
        ],
      );

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? WildPathColors.forest : WildPathColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? WildPathColors.forest : WildPathColors.mist,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: WildPathTypography.body(
            fontSize: 11,
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
  Widget build(BuildContext context) => KeyboardAwareScrollView(
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
              Text('Plan the wild. Camp with confidence.',
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
                    'WildPath is your trip planner for the backcountry and beyond. Plan trips, pack smarter, eat well out there, watch the weather, keep tabs on spending, and hold onto every adventure — one app for all of it.',
                    style: WildPathTypography.body(
                        fontSize: 13, color: WildPathColors.pine, height: 1.7)),
                const SizedBox(height: 12),
                Text(
                    'WildPath is a planning tool, not a substitute for your own judgment. Conditions, access rules, permits, weather, and safety needs can change quickly, so you are still responsible for verifying your trip details and preparing adequately before heading out.',
                    style: WildPathTypography.body(
                        fontSize: 12,
                        color: WildPathColors.smoke,
                        height: 1.6)),
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
                Text(
                    'Questions, feedback, or just want to say hi — reach out anytime.',
                    style: WildPathTypography.body(
                        fontSize: 12,
                        color: WildPathColors.smoke,
                        height: 1.5)),
                const SizedBox(height: 12),
                _aRow(
                    '📧',
                    'Get Support',
                    'dev.cal.apps@gmail.com',
                    () =>
                        launchUrl(Uri.parse('mailto:dev.cal.apps@gmail.com'))),
                const SizedBox(height: 8),
                _aRow(
                    '💬',
                    'Send Feedback',
                    'goes straight to the developer',
                    () => launchUrl(Uri.parse(
                        'mailto:dev.cal.apps@gmail.com?subject=WildPath Feedback'))),
                const SizedBox(height: 8),
                _aRow('🔒', 'Privacy Policy',
                    'stored on your device, not our servers', widget.onPrivacy),
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
                _pRow('🗺️ OpenStreetMap', 'Open Source'),
                _pRow('🌤️ Open-Meteo', 'weather forecasts'),
                _pRow('⛈️ NWS / weather.gov', 'severe weather alerts'),
                _pRow('🔍 Google Places', 'location search'),
                _pRow('🛡️ Netlify Functions', 'search proxy'),
              ])),
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'WildPath${_version.isNotEmpty ? ' v$_version' : ''} · made for the outdoors',
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
  Widget build(BuildContext context) => KeyboardAwareScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BackHeader(title: '🔒 Privacy Policy', onBack: onBack),
          Text('Last updated: April 2026',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke)),
          const SizedBox(height: 16),
          _section('Overview',
              'WildPath is designed to keep your planning data on your device. WildPath does not operate user accounts, cloud sync, analytics, advertising, or a cloud trip database. Some features do send limited data to third-party providers when you use them, such as destination search queries, trip coordinates for weather and alerts, and handoffs to an external maps app. If enabled in your build, destination search may be relayed through a WildPath-managed serverless proxy before reaching Google Places.'),
          _section('Planning Responsibility',
              'WildPath is a tool to help you organize a trip, not a guarantee that every trip detail is complete, current, or safe. Outdoor conditions, weather, access rules, permits, closures, and rescue availability can change quickly. You are responsible for verifying your plans, following local guidance, and preparing adequately before you go.'),
          _section('Data We Collect',
              'WildPath does not collect or store your trip data in a developer-run cloud database. Data saved on your device includes:\n\n• Your name and email address in encrypted secure storage\n• Trip plans, dates, saved destination details, coordinates, and notes in app preferences\n• Gear lists, meals, budget entries, emergency contacts, and notification preferences in app preferences\n• Pass and permit details, including attached photos or documents, in app-managed local files and references to those files'),
          _section('Location Data',
              'WildPath may request access to your device location when you choose features such as Get My Current Coordinates. Your live device coordinates are used on-device at the time you request them and are not automatically saved unless you choose a feature that stores or shares them. Saved trip coordinates remain on your device, but may be transmitted to weather or alert providers when you load conditions or enable weather alert checks.'),
          _section('Third-Party Services',
              'WildPath uses the following third-party services to provide core functionality:\n\n• WildPath search proxy (optional) — if enabled in your build, destination search requests are first relayed through a WildPath-managed Netlify function to keep the Google web-service key off the device\n• Google Places API — destination search text and place lookups are sent to Google when you search for a location, either directly from the app or through the WildPath search proxy\n• Open-Meteo — saved trip coordinates are sent to Open-Meteo when you load forecasts\n• NWS / weather.gov — saved trip coordinates are sent to weather.gov when you load alerts, and may also be checked in the background if weather alerts are enabled\n• Optional weather providers — if configured in your build, saved trip coordinates may also be sent to those services for alerts\n• Google Maps or other map apps — if you tap Open in Maps, your coordinates are handed off to that external app\n\nWildPath does not sell your data or send it to advertisers or analytics providers, but these service calls are still disclosures you should understand. Each provider has its own privacy policy.'),
          _section('Data Retention',
              'WildPath data stays on your device until you delete it, clear app storage, remove individual trips or documents, or uninstall the app. Uninstalling the app removes WildPath\'s local app data from your device, and we cannot recover it. If the optional search proxy is enabled, it forwards search requests but is not intended to store trip records. Requests already sent to third-party providers are governed by those providers\' own retention and privacy practices.'),
          _section('Children\'s Privacy',
              'WildPath is not directed at children under 13. We do not knowingly collect information from children.'),
          _section('Changes to This Policy',
              'We may update this Privacy Policy from time to time. Updates will be reflected in the app with a revised date. Continued use of the app after changes constitutes acceptance of the updated policy.'),
          _section('Contact',
              'If you have questions about this Privacy Policy, please contact us at:\n\ndev.cal.apps@gmail.com'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://wildpath-app.netlify.app'),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: WildPathColors.amber.withValues(alpha: 0.4)),
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

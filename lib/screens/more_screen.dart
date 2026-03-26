import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../models/meal_item.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';

enum MoreSection { menu, map, trips, emergency, budget, passes, profile, about, privacy }

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
        return _MapSection(trip: widget.currentTrip, onBack: _back);
      case MoreSection.trips:
        return _TripsSection(
          storage: widget.storage,
          currentTripId: widget.currentTrip.id,
          onLoadTrip: (t) {
            widget.onLoadTrip(t);
            _back();
          },
          onBack: _back,
        );
      case MoreSection.emergency:
        return _EmergencySection(
            storage: widget.storage, trip: widget.currentTrip, onBack: _back);
      case MoreSection.budget:
        return _BudgetSection(
          storage: widget.storage,
          tripId: widget.currentTrip.id,
          onBack: _back,
          onSaveTrip: () => widget.onSwitchTab(-1), // -1 = trigger save sheet
          onViewSummary: () => widget.onSwitchTab(-2), // -2 = go to summary
        );
      case MoreSection.passes:
        return _PassesSection(onBack: _back);
      case MoreSection.profile:
        return _ProfileSection(storage: widget.storage, onBack: _back);
      case MoreSection.about:
        return _AboutSection(onBack: _back, onPrivacy: () => _go(MoreSection.privacy));
      case MoreSection.privacy:
        return _PrivacyPolicySection(onBack: _back);
      default:
        return _buildMenu();
    }
  }

  Widget _buildMenu() {
    final name = widget.storage.userName;
    final trips = widget.storage.loadSavedTrips();
    final spent = widget.storage
        .loadBudget(widget.currentTrip.id)
        .fold<double>(0, (s, i) => s + i.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageTitle('More',
              subtitle: name.isNotEmpty ? 'Hey, $name 👋' : 'Tools & settings'),
          const SizedBox(height: 20),
          _item('🗺️', 'Map', 'Campsite location & surroundings',
              () => _go(MoreSection.map)),
          _item(
              '🗂️',
              'My Trips',
              '${trips.length} saved trip${trips.length == 1 ? '' : 's'}',
              () => _go(MoreSection.trips)),
          _item('🚨', 'Emergency Info', 'Contacts, GPS & rescue tips',
              () => _go(MoreSection.emergency)),
          _item('💰', 'Budget', '\$${spent.toStringAsFixed(0)} spent so far',
              () => _go(MoreSection.budget)),
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
                  color: WildPathColors.pine.withOpacity(0.06),
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
  final VoidCallback onBack;
  const _BackHeader({required this.title, required this.onBack});
  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(
            icon: const Icon(Icons.arrow_back, color: WildPathColors.forest),
            onPressed: onBack,
            padding: EdgeInsets.zero),
        const SizedBox(width: 4),
        Flexible(
            child: Text(title,
                style: WildPathTypography.display(
                    fontSize: 22, color: WildPathColors.forest))),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════
// MAP
// ══════════════════════════════════════════════════════════════════════════
class _MapSection extends StatefulWidget {
  final TripModel trip;
  final VoidCallback onBack;
  const _MapSection({required this.trip, required this.onBack});

  @override
  State<_MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<_MapSection> {
  late Future<LocationResult?> _locationFuture;

  @override
  void initState() {
    super.initState();
    _locationFuture = _resolveLocation();
  }

  @override
  void didUpdateWidget(covariant _MapSection oldWidget) {
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
                const Text('📍', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: WildPathTypography.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: WildPathColors.pine)),
                      if (hasMapLocation)
                        Text(
                            '${resolvedLocation!.lat!.toStringAsFixed(5)}, ${resolvedLocation.lng!.toStringAsFixed(5)}',
                            style: WildPathTypography.body(
                                fontSize: 11, color: WildPathColors.smoke)),
                      if (hasMapLocation && !hasSavedCoordinates)
                        Text(
                          'Using searched location',
                          style: WildPathTypography.body(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: WildPathColors.moss),
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
                                initialZoom: 12.5,
                                minZoom: 3,
                                maxZoom: 18,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.wildpath.app',
                                ),
                                MarkerLayer(markers: [
                                  Marker(
                                    point: mapCenter,
                                    width: 64,
                                    height: 64,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: WildPathColors.forest,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x22000000),
                                                blurRadius: 10,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'Camp',
                                            style: WildPathTypography.body(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Icon(
                                          Icons.location_on,
                                          size: 28,
                                          color: WildPathColors.ember,
                                        ),
                                      ],
                                    ),
                                  ),
                                ]),
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
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  hasSavedCoordinates
                                      ? 'Pinned campsite'
                                      : 'Searched map',
                                  style: WildPathTypography.body(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: WildPathColors.forest,
                                  ),
                                ),
                              ),
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
                                      : 'We could not locate this trip on the map yet. Add a campsite pin in Plan for a precise spot.',
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
              PrimaryButton('📍 Open in Google Maps', fullWidth: true,
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
                    'Use the 📍 pin button in the Plan tab to save your campsite coordinates for the most precise map placement.'),
          ]),
        );
      });
}

// ══════════════════════════════════════════════════════════════════════════
// MY TRIPS
// ══════════════════════════════════════════════════════════════════════════
class _TripsSection extends StatefulWidget {
  final StorageService storage;
  final String currentTripId;
  final ValueChanged<TripModel> onLoadTrip;
  final VoidCallback onBack;
  const _TripsSection(
      {required this.storage,
      required this.currentTripId,
      required this.onLoadTrip,
      required this.onBack});
  @override
  State<_TripsSection> createState() => _TripsSectionState();
}

class _TripsSectionState extends State<_TripsSection> {
  late List<TripModel> _trips;
  @override
  void initState() {
    super.initState();
    _trips = widget.storage.loadSavedTrips();
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

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
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
            ..._trips.map((trip) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: WildPathColors.pine.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip.tripTypeEmoji,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      trip.name.isNotEmpty
                                          ? trip.name
                                          : 'Unnamed Trip',
                                      style: WildPathTypography.body(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: WildPathColors.pine),
                                      overflow: TextOverflow.ellipsis),
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
                                  Text('Saved ${_fmt(trip.savedAt)}',
                                      style: WildPathTypography.body(
                                          fontSize: 10,
                                          color: WildPathColors.stone)),
                                ])),
                            if (trip.id == widget.currentTripId)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: WildPathColors.fern,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text('Active',
                                    style: WildPathTypography.body(
                                        fontSize: 9,
                                        color: WildPathColors.forest,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ]),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(color: WildPathColors.mist))),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Row(children: [
                        Expanded(
                            child: OutlineButton2('Load Trip',
                                onPressed: () => widget.onLoadTrip(trip))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: GhostButton('Delete',
                                color: WildPathColors.red,
                                onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        title: Text('Delete Trip?',
                                            style: WildPathTypography.display(
                                                fontSize: 20)),
                                        content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  'Permanently delete "${trip.name.isNotEmpty ? trip.name : 'this trip'}"?',
                                                  style: WildPathTypography.body(
                                                      fontSize: 13,
                                                      color:
                                                          WildPathColors.smoke)),
                                              const SizedBox(height: 20),
                                              Row(children: [
                                                Expanded(
                                                    child: OutlineButton2(
                                                        'Cancel',
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context))),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                    child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        WildPathColors.red,
                                                    minimumSize:
                                                        const Size(0, 48),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                  ),
                                                  onPressed: () async {
                                                    await widget.storage
                                                        .deleteTrip(trip.id);
                                                    setState(() => _trips =
                                                        widget.storage
                                                            .loadSavedTrips());
                                                    if (context.mounted)
                                                      Navigator.pop(context);
                                                  },
                                                  child: Text('Delete',
                                                      style: WildPathTypography
                                                          .body(
                                                              fontSize: 11,
                                                              letterSpacing:
                                                                  1.1,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: Colors
                                                                  .white)),
                                                )),
                                              ]),
                                            ]),
                                        actions: const [],
                                      ),
                                    ))),
                      ]),
                    ),
                  ]),
                )),
        ]),
      );
}

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
    for (final c in [_n1, _p1, _n2, _p2]) c.dispose();
    super.dispose();
  }

  void _save() {
    final contacts = <EmergencyContact>[];
    if (_n1.text.trim().isNotEmpty)
      contacts.add(EmergencyContact(
          id: const Uuid().v4(),
          name: _n1.text.trim(),
          phone: _p1.text.trim()));
    if (_n2.text.trim().isNotEmpty)
      contacts.add(EmergencyContact(
          id: const Uuid().v4(),
          name: _n2.text.trim(),
          phone: _p2.text.trim()));
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
          Text('EMERGENCY NUMBERS',
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 0.12 * 10,
                  color: WildPathColors.red)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child:
                    _dialBtn('📞 911', 'Emergency', WildPathColors.red, '911')),
            const SizedBox(width: 8),
            Expanded(
                child: _dialBtn('🏞️ USFS', '1-877-444-6777\nRecreation.gov',
                    WildPathColors.forest, '18774446777')),
            const SizedBox(width: 8),
            Expanded(
                child: _dialBtn(
                    '🏔️ NPS',
                    '1-800-922-0399\nNat\'l Park Service',
                    WildPathColors.moss,
                    '18009220399')),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: WildPathColors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Text(
                '⚠️ Save your local ranger station number before heading out — 911 may not reach backcountry dispatch.',
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
          if (t.permitNum.isNotEmpty) _rr('📜 Permit #', t.permitNum),
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
            bgColor: WildPathColors.red.withOpacity(0.06),
            borderColor: WildPathColors.red.withOpacity(0.2)),
        TipCard(
            emoji: '📡',
            content:
                'No signal? Move to high ground. Text often sends when calls won\'t. Try 911 even with 0 bars.',
            bgColor: WildPathColors.red.withOpacity(0.06),
            borderColor: WildPathColors.red.withOpacity(0.2)),
      ]),
    );
  }

  Widget _dialBtn(String label, String sub, Color color, String number) =>
      GestureDetector(
          onTap: () => _call(number),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: WildPathTypography.body(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    textAlign: TextAlign.center),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(sub,
                    style: WildPathTypography.body(
                        fontSize: 9, color: Colors.white.withOpacity(0.85)),
                    textAlign: TextAlign.center),
              ),
            ]),
          ));

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
class _BudgetSection extends StatefulWidget {
  final StorageService storage;
  final String tripId;
  final VoidCallback onBack;
  final VoidCallback? onSaveTrip;
  final VoidCallback? onViewSummary;
  const _BudgetSection(
      {required this.storage,
      required this.tripId,
      required this.onBack,
      this.onSaveTrip,
      this.onViewSummary});
  @override
  State<_BudgetSection> createState() => _BudgetSectionState();
}

class _BudgetSectionState extends State<_BudgetSection> {
  late List<BudgetItem> _items;
  late double _limit;
  final _limitCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  BudgetCategory _cat = BudgetCategory.other;

  @override
  void initState() {
    super.initState();
    _loadBudgetState();
  }

  @override
  void didUpdateWidget(_BudgetSection old) {
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
    for (final c in [_limitCtrl, _descCtrl, _amtCtrl]) c.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0, (s, i) => s + i.amount);
  double get _remaining => _limit > 0 ? _limit - _total : 0;

  void _save() {
    widget.storage.saveBudget(widget.tripId, _items);
    widget.storage.setBudgetTotal(widget.tripId, _limit);
  }

  void _add() {
    final amt = double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;
    if (_descCtrl.text.trim().isEmpty || amt <= 0) return;
    setState(() {
      _items.add(BudgetItem(
          id: const Uuid().v4(),
          description: _descCtrl.text.trim(),
          amount: amt,
          category: _cat));
      _descCtrl.clear();
      _amtCtrl.clear();
    });
    _save();
    showWildToast(context, '✅ Expense added');
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _BackHeader(title: '💰 Budget', onBack: widget.onBack),
          Text('Track your trip costs',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke)),
          const SizedBox(height: 16),

          // Summary
          WildCard(
              padding: EdgeInsets.zero,
              child: Row(children: [
                Expanded(
                    child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                      border: Border(
                          right: BorderSide(color: WildPathColors.mist))),
                  child: Column(children: [
                    Text('\$${_total.toStringAsFixed(2)}',
                        style: WildPathTypography.display(
                            fontSize: 28, color: WildPathColors.forest)),
                    Text('TOTAL SPENT',
                        style: WildPathTypography.body(
                            fontSize: 9,
                            letterSpacing: 0.1 * 9,
                            color: WildPathColors.smoke)),
                  ]),
                )),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Text(
                              _limit > 0
                                  ? '\$${_remaining.toStringAsFixed(2)}'
                                  : '—',
                              style: WildPathTypography.display(
                                  fontSize: 28,
                                  color: _limit > 0 && _remaining < 0
                                      ? WildPathColors.red
                                      : WildPathColors.moss)),
                          Text('REMAINING',
                              style: WildPathTypography.body(
                                  fontSize: 9,
                                  letterSpacing: 0.1 * 9,
                                  color: WildPathColors.smoke)),
                        ]))),
              ])),

          // Limit input
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('TOTAL BUDGET',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.12 * 10,
                        color: WildPathColors.smoke)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _limitCtrl,
                  keyboardType: TextInputType.number,
                  style: WildPathTypography.body(
                      fontSize: 14, color: WildPathColors.pine),
                  decoration: InputDecoration(
                      prefixText: '\$ ',
                      hintText: 'e.g. 500',
                      hintStyle: WildPathTypography.body(
                          fontSize: 13, color: WildPathColors.stone),
                      filled: true,
                      fillColor: WildPathColors.cream,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12)),
                  onChanged: (v) {
                    _limit = double.tryParse(v) ?? 0;
                    _save();
                    setState(() {});
                  },
                ),
              ])),

          if (_limit > 0) ...[
            WildProgressBar(
                progress: (_total / _limit).clamp(0, 1),
                title: 'Budget Used',
                countLabel:
                    '\$${_total.toStringAsFixed(0)} / \$${_limit.toStringAsFixed(0)}',
                barColor:
                    _total > _limit ? WildPathColors.red : WildPathColors.moss),
            const SizedBox(height: 16),
          ],

          // Expenses
          if (_items.isNotEmpty) ...[
            Text('Expenses',
                style: WildPathTypography.display(
                    fontSize: 18, color: WildPathColors.forest)),
            const SizedBox(height: 10),
            ..._items.map((item) => Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                          color: WildPathColors.red,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('DELETE',
                          style: WildPathTypography.body(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600))),
                  onDismissed: (_) {
                    setState(() => _items.removeWhere((i) => i.id == item.id));
                    _save();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 13),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: WildPathColors.pine.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1))
                        ]),
                    child: Row(children: [
                      Text(item.category.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.description,
                                style: WildPathTypography.body(
                                    fontSize: 13,
                                    color: WildPathColors.pine,
                                    fontWeight: FontWeight.w600)),
                            Text(item.category.label,
                                style: WildPathTypography.body(
                                    fontSize: 10, color: WildPathColors.smoke)),
                          ])),
                      Text('\$${item.amount.toStringAsFixed(2)}',
                          style: WildPathTypography.display(
                              fontSize: 16,
                              color: WildPathColors.forest,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                )),
            const WildDivider(),
          ],

          // Add expense form
          WildCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('ADD EXPENSE',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.1 * 10,
                        color: WildPathColors.smoke)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child:
                          _ef(_descCtrl, 'Description', 'e.g. Campsite fee')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _ef(_amtCtrl, 'Amount (\$)', '0.00',
                          type: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                      color: WildPathColors.cream,
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BudgetCategory>(
                      value: _cat,
                      isExpanded: true,
                      style: WildPathTypography.body(
                          fontSize: 13, color: WildPathColors.pine),
                      items: BudgetCategory.values
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text('${c.emoji} ${c.label}')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _cat = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _add,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: WildPathColors.amber,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text('+ Add Expense',
                          style: WildPathTypography.body(
                              fontSize: 11,
                              letterSpacing: 0.1 * 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    )),
              ])),

          // Action buttons
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: ElevatedButton(
              onPressed: widget.onSaveTrip,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(0, 48),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Text('💾', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text('Save to My Trips',
                      style: WildPathTypography.body(
                          fontSize: 11,
                          letterSpacing: 0.72,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton(
              onPressed: widget.onViewSummary,
              style: OutlinedButton.styleFrom(
                side:
                    const BorderSide(color: WildPathColors.forest, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(0, 48),
              ),
              child: Text('View Summary',
                  style: WildPathTypography.body(
                      fontSize: 11,
                      letterSpacing: 0.88,
                      color: WildPathColors.forest,
                      fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      );

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
                fontSize: 13, color: WildPathColors.pine),
            decoration: InputDecoration(
                hintText: hint,
                hintStyle: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.stone),
                filled: true,
                fillColor: WildPathColors.cream,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11))),
      ]);
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
                      fontSize: 13,
                      color: WildPathColors.smoke,
                      height: 1.5),
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
  late String _style;
  late bool _notifTrips, _notifWeather;

  final _styles = [
    ('', 'No preference'),
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
    _style = widget.storage.userStyle;
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
    await widget.storage.setUserName(_name.text.trim());
    await widget.storage.setUserEmail(_email.text.trim());
    await widget.storage.setUserStyle(_style);
    await widget.storage.setNotifTrips(_notifTrips);
    await widget.storage.setNotifWeather(_notifWeather);
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
                Text('PREFERRED CAMP STYLE',
                    style: WildPathTypography.body(
                        fontSize: 10,
                        letterSpacing: 0.12 * 10,
                        color: WildPathColors.smoke)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                      color: WildPathColors.cream,
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _style,
                      isExpanded: true,
                      style: WildPathTypography.body(
                          fontSize: 13, color: WildPathColors.pine),
                      items: _styles
                          .map((s) =>
                              DropdownMenuItem(value: s.$1, child: Text(s.$2)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _style = v);
                      },
                    ),
                  ),
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
            activeColor: WildPathColors.moss),
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
                      color: Colors.white.withOpacity(0.5))),
              const SizedBox(height: 12),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      _version.isNotEmpty ? 'Version $_version' : 'Version —',
                      style: WildPathTypography.body(
                          fontSize: 11, color: Colors.white.withOpacity(0.7)))),
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
                _aRow('📧', 'Contact / Support', 'dev.cal.apps@gmail.com',
                    () => launchUrl(Uri.parse('mailto:dev.cal.apps@gmail.com'))),
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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
        ]),
      );
}

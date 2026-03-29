import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../services/weather_service.dart';
import '../widgets/common_widgets.dart';

enum _ConditionsSection { forecast, alerts, briefing }

class ConditionsScreen extends StatefulWidget {
  final TripModel trip;
  const ConditionsScreen({required this.trip, super.key});
  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  WeatherData? _weather;
  List<RangerCard> _briefingCards = const [];
  bool _loading = false;
  String? _error;
  String _locationLabel = '';
  _ConditionsSection _section = _ConditionsSection.forecast;
  int _loadRequestId = 0;

  String get _alertSourceLabel {
    final sources = _weather?.alerts
            .map((alert) => alert.source.trim())
            .where((source) => source.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    if (sources.isEmpty) {
      return WeatherService.hasWeatherAlertsApiKey
          ? 'Alert data checks location-based providers for the selected area.'
          : 'Alert data is currently sourced from api.weather.gov (National Weather Service). Add WEATHER_API_KEY in .env for broader international alert coverage.';
    }
    return 'Alert data provided by ${sources.join(', ')}.';
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentTrip();
  }

  @override
  void didUpdateWidget(ConditionsScreen old) {
    super.didUpdateWidget(old);
    final tripChanged = old.trip.campsite != widget.trip.campsite ||
        old.trip.lat != widget.trip.lat ||
        old.trip.lng != widget.trip.lng;
    if (tripChanged) {
      _loadCurrentTrip();
    }
  }

  bool get _hasTripCoordinates =>
      widget.trip.lat != null && widget.trip.lng != null;

  bool get _hasTripLocation =>
      widget.trip.campsite.trim().isNotEmpty || _hasTripCoordinates;

  void _clearLocationState() {
    _loadRequestId++;
    if (!mounted) return;
    setState(() {
      _weather = null;
      _briefingCards = const [];
      _error = null;
      _loading = false;
      _locationLabel = '';
    });
  }

  Future<void> _loadCurrentTrip() async {
    final location = widget.trip.campsite.trim();
    if (!_hasTripLocation || location.isEmpty) {
      _clearLocationState();
      return;
    }
    await _load(location);
  }

  Future<void> _load(String location) async {
    if (location.trim().isEmpty) return;
    final requestId = ++_loadRequestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      LocationResult? loc;
      if (_hasTripCoordinates && location == widget.trip.campsite) {
        loc = LocationResult(
            lat: widget.trip.lat!,
            lng: widget.trip.lng!,
            displayName: location);
      } else {
        loc = await WeatherService.geocode(location);
      }
      if (!mounted || requestId != _loadRequestId) return;
      if (loc == null) {
        setState(() {
          _error =
              'Could not find "$location". Try adding a state, e.g. "Lake Mary, AZ".';
          _weather = null;
          _briefingCards = const [];
          _locationLabel = '';
          _loading = false;
        });
        return;
      }
      if (!loc.hasCoordinates) {
        setState(() {
          _error = 'Location found, but coordinates were unavailable.';
          _weather = null;
          _briefingCards = const [];
          _locationLabel = '';
          _loading = false;
        });
        return;
      }
      final resolvedLoc = loc;
      final weather =
          await WeatherService.fetchWeather(resolvedLoc.lat!, resolvedLoc.lng!);
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _weather = weather;
          _locationLabel =
              resolvedLoc.displayName.split(',').take(2).join(',').trim();
          _briefingCards = weather == null
              ? const []
              : RangerInsightGenerator.generate(
                  weather: weather,
                  shelter: widget.trip.tripType.toShelterType(),
                  locationName: _locationLabel.isNotEmpty
                      ? _locationLabel
                      : widget.trip.campsite,
                );
          _loading = false;
          if (weather == null) {
            _error = 'Weather data unavailable. Check your connection.';
          }
        });
      }
    } catch (e) {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _error = 'Error: $e';
          _weather = null;
          _briefingCards = const [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PageTitle('Conditions', subtitle: 'Forecast  Alerts  Briefing'),
          const SizedBox(height: 16),

          // Location bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WildPathColors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: WildPathColors.pine.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Text('📍',
                  semanticsLabel: '',
                  style: WildPathTypography.display(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        widget.trip.campsite.isNotEmpty
                            ? widget.trip.campsite
                            : 'No location set',
                        style: WildPathTypography.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: WildPathColors.pine),
                        overflow: TextOverflow.ellipsis),
                    Text('Set destination in the Plan tab',
                        style: WildPathTypography.body(
                            fontSize: 11, color: WildPathColors.smoke)),
                  ])),
              AbsorbPointer(
                absorbing: !_hasTripLocation || _loading,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hasTripLocation ? 1 : 0.45,
                  child: GestureDetector(
                    onTap: () => _loadCurrentTrip(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: WildPathColors.forest,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(_loading ? '...' : 'Refresh',
                          style: WildPathTypography.body(
                              fontSize: 11, color: WildPathColors.white)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _sectionChip('FORECAST', _ConditionsSection.forecast),
            const SizedBox(width: 8),
            _sectionChip('ALERTS', _ConditionsSection.alerts),
            const SizedBox(width: 8),
            _sectionChip('BRIEFING', _ConditionsSection.briefing),
          ]),
          const SizedBox(height: 16),

          if (_loading)
            const WildSpinner(label: 'Fetching conditions...')
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WildPathColors.red.withValues(alpha: 0.08),
                border: Border.all(
                    color: WildPathColors.red.withValues(alpha: 0.25),
                    width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Text('⚠',
                    semanticsLabel: 'Warning',
                    style: WildPathTypography.display(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(_error!,
                        style: WildPathTypography.body(
                            fontSize: 13, color: WildPathColors.pine))),
              ]),
            )
          else if (_weather == null)
            EmptyState(
              emoji: '🌤',
              message: widget.trip.campsite.isEmpty
                  ? 'Add a campsite location in the Plan tab to see weather and alerts.'
                  : 'Tap Refresh to load conditions for ${widget.trip.campsite}.',
            )
          else
            _buildWeather(_weather!),
        ]),
      );

  Widget _buildWeather(WeatherData w) {
    final minF = w.forecast.isNotEmpty ? w.forecast.first.minTempF : w.tempF;
    final tempDiff = (w.tempF - minF).abs().round();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_section == _ConditionsSection.forecast) ...[
        Container(
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
              Text(w.icon,
                  semanticsLabel: '',
                  style: WildPathTypography.display(fontSize: 48)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${w.tempF.round()}F',
                    style: WildPathTypography.display(
                        fontSize: 36, color: Colors.white)),
                Text(w.condition,
                    style: WildPathTypography.body(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85))),
              ]),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _wStat('Wind', '${w.windMph.round()} mph'),
              _wStat('Humidity', '${w.humidity}%'),
              _wStat('Feels Like', '${w.feelsLikeF.round()}F'),
            ]),
            if (_locationLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_locationLabel,
                  style: WildPathTypography.body(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.5))),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        if (w.alerts.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WildPathColors.amber.withValues(alpha: 0.08),
              border: Border.all(
                  color: WildPathColors.amber.withValues(alpha: 0.28),
                  width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Text('⚠️',
                  semanticsLabel: 'Warning',
                  style: WildPathTypography.display(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${w.alerts.length} active weather ${w.alerts.length == 1 ? "alert" : "alerts"} for this area. Open Alerts for details.',
                  style: WildPathTypography.body(
                      fontSize: 12, color: WildPathColors.pine, height: 1.45),
                ),
              ),
            ]),
          ),
        if (w.forecast.isNotEmpty) ...[
          Text('7-Day Forecast',
              style: WildPathTypography.display(
                  fontSize: 18, color: WildPathColors.forest)),
          const SizedBox(height: 10),
          ...w.forecast.map((day) => _ForecastRow(day: day)),
          const SizedBox(height: 16),
        ],
        Text('Conditions Tips',
            style: WildPathTypography.display(
                fontSize: 18, color: WildPathColors.forest)),
        const SizedBox(height: 10),
        TipCard(
            emoji: '🌡',
            content:
                'Nighttime temps can be ~${tempDiff}F lower than daytime. Pack your warmest sleep layer.'),
        if (w.windMph > 15)
          const TipCard(
              emoji: '💨',
              content:
                  'Strong winds expected. Stake your tent from all corners and use extra guylines.'),
        if (w.forecast.any((d) => d.precipMm > 5))
          const TipCard(
              emoji: '🌧',
              content:
                  'Rain in the forecast. Pack a tarp over your tent and waterproof your gear bags.'),
        const TipCard(
            emoji: '⛅',
            content:
                'Check conditions again 24-48 hrs before departure for the most accurate forecast.'),
      ] else if (_section == _ConditionsSection.alerts) ...[
        Text('Local Alerts',
            style: WildPathTypography.display(
                fontSize: 18, color: WildPathColors.forest)),
        const SizedBox(height: 10),
        if (w.alerts.isEmpty)
          EmptyState(
            emoji: '✅',
            message:
                'No active weather alerts were returned for ${_locationLabel.isNotEmpty ? _locationLabel : widget.trip.campsite}.',
          )
        else ...[
          ...w.alerts.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _alertColor(a.severity).withValues(alpha: 0.08),
                  border: Border.all(
                      color: _alertColor(a.severity).withValues(alpha: 0.3),
                      width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.emoji,
                          semanticsLabel: '',
                          style: WildPathTypography.display(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(a.title,
                                style: WildPathTypography.body(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: WildPathColors.pine)),
                            if (a.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                a.description,
                                style: WildPathTypography.body(
                                    fontSize: 12,
                                    color: WildPathColors.smoke,
                                    height: 1.5),
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ])),
                    ]),
              )),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              _alertSourceLabel,
              style: WildPathTypography.body(
                fontSize: 11,
                color: WildPathColors.smoke,
              ),
            ),
          ),
        ],
      ] else ...[
        Text('Trip Briefing',
            style: WildPathTypography.display(
                fontSize: 18, color: WildPathColors.forest)),
        const SizedBox(height: 10),
        ..._briefingCards.map((item) => _RangerCard(card: item)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WildPathColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WildPathColors.mist, width: 1.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About this briefing',
                  style: WildPathTypography.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WildPathColors.pine)),
              const SizedBox(height: 6),
              Text(
                'This view combines forecast data, official severe weather alerts, and trip context to generate a quick trip briefing. Check local operators and park notices for same-day closures or restrictions.',
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.smoke, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _sectionChip(String label, _ConditionsSection section) {
    final active = _section == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _section = section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active ? WildPathColors.forest : WildPathColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? WildPathColors.forest : WildPathColors.mist,
                width: 1.4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: WildPathTypography.body(
              fontSize: 10,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: active ? WildPathColors.white : WildPathColors.forest,
            ),
          ),
        ),
      ),
    );
  }

  // Replaced by RangerInsightGenerator below.

  Widget _wStat(String label, String value) => Expanded(
          child: Column(children: [
        Text(value,
            style: WildPathTypography.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: WildPathColors.white)),
        Text(label,
            style: WildPathTypography.body(
                fontSize: 10,
                color: WildPathColors.white.withValues(alpha: 0.65))),
      ]));

  Color _alertColor(String sev) {
    if (sev == 'extreme') return WildPathColors.red;
    if (sev == 'severe') return WildPathColors.ember;
    return WildPathColors.amber;
  }
}

// ── Ranger card renderer ──────────────────────────────────────────────────────

class _RangerCard extends StatelessWidget {
  final RangerCard card;
  const _RangerCard({required this.card});

  Color get _toneColor => switch (card.tone) {
        RangerTone.severe => WildPathColors.red,
        RangerTone.warning => WildPathColors.amber,
        RangerTone.caution => WildPathColors.ember,
        RangerTone.info => WildPathColors.forest,
      };

  @override
  Widget build(BuildContext context) {
    final color = _toneColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WildPathColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(card.emoji,
              semanticsLabel: '',
              style: WildPathTypography.display(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(card.title,
                  style: WildPathTypography.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: WildPathColors.pine)),
              const SizedBox(height: 4),
              Text(card.body,
                  style: WildPathTypography.body(
                      fontSize: 12, color: WildPathColors.smoke, height: 1.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(card.sourceLabel,
              style: WildPathTypography.body(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final ForecastDay day;
  const _ForecastRow({required this.day});

  String _fmt(String d) {
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
      const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${wd[dt.weekday - 1]} ${m[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: WildPathColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: WildPathColors.pine.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Row(children: [
          Text(day.emoji,
              semanticsLabel: '',
              style: WildPathTypography.display(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_fmt(day.date),
                    style: WildPathTypography.body(
                        fontSize: 12,
                        color: WildPathColors.pine,
                        fontWeight: FontWeight.w600)),
                Text(day.condition,
                    style: WildPathTypography.body(
                        fontSize: 11, color: WildPathColors.smoke)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${day.maxTempF.round()}F',
                style: WildPathTypography.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WildPathColors.pine)),
            Text('${day.minTempF.round()}F',
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.stone)),
          ]),
          if (day.precipMm > 0) ...[
            const SizedBox(width: 10),
            Column(children: [
              Text('🌧',
                  semanticsLabel: 'Rain',
                  style: WildPathTypography.body(fontSize: 13)),
              Text('${day.precipMm.round()}mm',
                  style: WildPathTypography.body(
                      fontSize: 10, color: WildPathColors.blue)),
            ]),
          ],
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SHELTER TYPE
// ══════════════════════════════════════════════════════════════════════════════

enum ShelterType { tent, rv, backpacking, cabin, glamping, other }

extension ShelterTypeX on String {
  ShelterType toShelterType() => switch (toLowerCase()) {
        'rv or van' => ShelterType.rv,
        'backpacking' => ShelterType.backpacking,
        'cabins' => ShelterType.cabin,
        'glamping' => ShelterType.glamping,
        _ => ShelterType.tent,
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// RANGER CARD MODEL
// ══════════════════════════════════════════════════════════════════════════════

enum RangerTone { severe, warning, caution, info }

class RangerCard {
  final String emoji;
  final String title;
  final String body;
  final String sourceLabel;
  final RangerTone tone;

  const RangerCard({
    required this.emoji,
    required this.title,
    required this.body,
    required this.sourceLabel,
    required this.tone,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// RANGER INSIGHT GENERATOR
// ══════════════════════════════════════════════════════════════════════════════

class RangerInsightGenerator {
  static const double _windAlertMph = 15;
  static const double _coldNightF = 36;
  static const double _hotDayF = 88;
  static const double _rainDayMm = 5;
  static const int _maxCards = 4;

  static List<RangerCard> generate({
    required WeatherData weather,
    required ShelterType shelter,
    required String locationName,
  }) {
    final cards = <RangerCard>[];

    final coldNight = weather.forecast.isNotEmpty
        ? weather.forecast
            .map((d) => d.minTempF)
            .reduce((a, b) => a < b ? a : b)
        : weather.tempF;
    final hotDay = weather.forecast.isNotEmpty
        ? weather.forecast
            .map((d) => d.maxTempF)
            .reduce((a, b) => a > b ? a : b)
        : weather.tempF;
    final wetDays =
        weather.forecast.where((d) => d.precipMm >= _rainDayMm).length;

    // 1. NWS alerts — always first
    if (weather.alerts.isNotEmpty) {
      cards.add(_alertTip(locationName, weather.alerts.first).resolve(shelter));
    }

    // 2. Rain
    if (wetDays > 0) cards.add(_rainTip(wetDays).resolve(shelter));

    // 3. Wind
    if (weather.windMph >= _windAlertMph) {
      cards.add(_windTip(weather.windMph).resolve(shelter));
    }

    // 4. Cold overnight
    if (coldNight <= _coldNightF) {
      cards.add(_coldTip(coldNight).resolve(shelter));
    }

    // 5. Heat
    if (hotDay >= _hotDayF) {
      cards.add(_heatTip(hotDay).resolve(shelter));
    }

    // 6. Shelter baseline tip
    cards.add(_shelterBaselineTip().resolve(shelter));

    // 7. Universal fallback
    cards.add(const RangerCard(
      emoji: '📣',
      title: 'Check the campground kiosk on arrival',
      body: 'Same-day fire restrictions, water outages, and wildlife notices '
          'change faster than any forecast. The bulletin board near the '
          'entrance is always your most current source.',
      sourceLabel: 'WildPath trip briefing',
      tone: RangerTone.info,
    ));

    return cards.take(_maxCards).toList();
  }

  // ── Tip factories ────────────────────────────────────────────────────────

  static _TipVariants _alertTip(String location, WeatherAlert alert) =>
      _TipVariants(
        emoji: alert.emoji,
        tone: alert.severity == 'extreme'
            ? RangerTone.severe
            : RangerTone.warning,
        sourceLabel: 'National Weather Service',
        variants: {
          ShelterType.tent: (
            title: 'Active alert near $location — reassess your site',
            body: 'Official alerts are in effect. Tent campers should identify '
                'a hard-sided shelter option and a bail-out route before '
                'the weather window closes.',
          ),
          ShelterType.rv: (
            title: 'Active alert near $location — secure the rig',
            body: 'Lower awnings, disconnect add-ons, and confirm slide '
                'clearance before conditions deteriorate. Know the nearest '
                'covered structure in case you need to evacuate.',
          ),
          ShelterType.backpacking: (
            title: 'Active alert near $location — reconsider your route',
            body: 'Backcountry travelers face the highest exposure during '
                'weather events. Identify your nearest low-elevation exit '
                'and update your emergency contact before heading out.',
          ),
          ShelterType.other: (
            title: 'Active alert near $location',
            body: 'Official weather alerts are in effect. Review the Alerts '
                'tab and check NWS for full details before departure.',
          ),
        },
      );

  static _TipVariants _rainTip(int wetDays) => _TipVariants(
        emoji: '🌧',
        tone: RangerTone.caution,
        sourceLabel: 'Open-Meteo 7-day forecast',
        variants: {
          ShelterType.tent: (
            title: 'Wet ground ahead — site selection matters',
            body: '$wetDays ${wetDays == 1 ? "day shows" : "days show"} '
                'measurable rain. Scout slightly elevated ground away from '
                'drainages. Lay a footprint under your tent and dig a small '
                'moat around the perimeter if the site stays damp overnight.',
          ),
          ShelterType.rv: (
            title: 'Rain in the forecast — prep your hookups',
            body: '$wetDays rainy ${wetDays == 1 ? "day" : "days"} ahead. '
                'Park on firm or gravel ground — soft soil and leveling '
                'blocks are a bad combination after heavy rain. Seal slide '
                'seams and check roof vents.',
          ),
          ShelterType.backpacking: (
            title: 'Wet trail conditions expected',
            body: '$wetDays ${wetDays == 1 ? "day shows" : "days show"} '
                'significant rain. Stream crossings rise quickly — check '
                'gauges the morning you ford. Pack rain covers on all dry '
                'bags, not just the pack lid.',
          ),
          ShelterType.other: (
            title: 'Wet conditions forecast this week',
            body: '$wetDays ${wetDays == 1 ? "day shows" : "days show"} '
                'measurable rain. Expect softer ground, slower fire-starting, '
                'and a higher need for waterproof storage.',
          ),
        },
      );

  static _TipVariants _windTip(double windMph) => _TipVariants(
        emoji: '💨',
        tone: RangerTone.caution,
        sourceLabel: 'Open-Meteo current conditions',
        variants: {
          ShelterType.tent: (
            title: 'Wind at ${windMph.round()} mph — stake and guy out fully',
            body: 'At this speed a tent without all stakes and guylines set '
                'will move. Use every anchor point, orient the lowest-profile '
                'end into the wind, and avoid exposed ridgelines.',
          ),
          ShelterType.rv: (
            title: 'Wind at ${windMph.round()} mph — retract awnings',
            body: 'Awnings are the first casualty in unexpected gusts. '
                'Retract fully before sleeping or leaving the site. '
                'Park with your side door facing downwind so it opens '
                'into the calm side.',
          ),
          ShelterType.backpacking: (
            title: 'Gusty ridgeline conditions — pick sheltered camps',
            body: 'Wind at ${windMph.round()} mph at camp can mean '
                'significantly more on exposed terrain. Camp in tree line '
                'or behind a natural windbreak. Secure everything that '
                'could roll or blow.',
          ),
          ShelterType.other: (
            title: 'Elevated winds — ${windMph.round()} mph at your location',
            body: 'Secure loose gear, choose a sheltered pitch, and avoid '
                'exposed ridgelines. Gusts can exceed the reported average, '
                'especially in open terrain.',
          ),
        },
      );

  static _TipVariants _coldTip(double coldNightF) => _TipVariants(
        emoji: '🧤',
        tone: RangerTone.caution,
        sourceLabel: 'Open-Meteo 7-day forecast',
        variants: {
          ShelterType.tent: (
            title:
                'Overnight low ~${coldNightF.round()}°F — layer your sleep system',
            body: 'Add a sleeping bag liner for 10–15°F of extra warmth. '
                'Put tomorrow\'s clothes in the foot of your bag so '
                'they\'re warm in the morning. Keep water bottles '
                'horizontal in your bag to stay liquid overnight.',
          ),
          ShelterType.rv: (
            title: 'Near-freezing nights — protect your water lines',
            body: 'Below ${coldNightF.round()}°F exposed fresh-water lines '
                'and grey tanks can freeze. Disconnect the city hose at '
                'night and use your onboard tank, or wrap exposed lines '
                'with heat tape.',
          ),
          ShelterType.backpacking: (
            title: 'Sub-freezing exposure overnight',
            body: 'At ${coldNightF.round()}°F moisture management is as '
                'important as insulation. Vent your shelter to reduce '
                'condensation. Check your water filter — many membrane '
                'filters crack if frozen while wet.',
          ),
          ShelterType.other: (
            title: 'Cold overnight — temperatures near ${coldNightF.round()}°F',
            body: 'Protect water, batteries, and temperature-sensitive gear. '
                'Layer up before you get into your sleeping bag, not '
                'after you\'re already cold.',
          ),
        },
      );

  static _TipVariants _heatTip(double hotDayF) => _TipVariants(
        emoji: '☀️',
        tone: RangerTone.warning,
        sourceLabel: 'Open-Meteo 7-day forecast',
        variants: {
          ShelterType.tent: (
            title: 'High near ${hotDayF.round()}°F — manage your shelter heat',
            body: 'A closed tent in direct sun can reach 130°F in 20 minutes. '
                'Open all vents, use a reflective tarp as a shade fly, and '
                'shift setup and hiking to before 10 am and after 4 pm.',
          ),
          ShelterType.rv: (
            title: 'High near ${hotDayF.round()}°F — manage your power draw',
            body: 'Use reflective window coverings during peak hours '
                '(11 am–3 pm). Park so the longest side of the rig faces '
                'north. If interior temps hit 90°F, that\'s a health risk, '
                'not just a comfort issue.',
          ),
          ShelterType.backpacking: (
            title: 'Heat advisory — ${hotDayF.round()}°F highs in your area',
            body: 'Start hiking by 6 am and be in shade by noon. Verify '
                'springs on recent trip reports — water sources shrink in '
                'heat. Electrolyte loss is significant above 90°F; '
                'plain water is not enough for full-day exposure.',
          ),
          ShelterType.other: (
            title: 'Hot daytime window — highs near ${hotDayF.round()}°F',
            body: 'Shift activity to early morning and evening. Carry more '
                'water than you think you need and find shade-heavy '
                'campsites where possible.',
          ),
        },
      );

  static _TipVariants _shelterBaselineTip() => const _TipVariants(
        emoji: '🏕',
        tone: RangerTone.info,
        sourceLabel: 'WildPath trip briefing',
        variants: {
          ShelterType.tent: (
            title: 'Pre-camp tent check',
            body: 'Pitch your tent at home the night before departure. '
                'Check poles, seams, zippers, and the rainfly fit. '
                'A 10-minute check at home prevents a soggy night '
                'that a backcountry repair kit can\'t fix.',
          ),
          ShelterType.rv: (
            title: 'Departure day RV walkthrough',
            body: 'Before rolling out: retract steps and awnings, confirm '
                'all slides are in, disconnect shore power and water, '
                'walk the exterior for anything hanging loose, and verify '
                'your brake controller reads correctly.',
          ),
          ShelterType.backpacking: (
            title: 'Backcountry conditions check',
            body: 'Before departure, verify trailhead access, stream '
                'crossings, and backcountry notices from the managing '
                'land agency. Local closures change faster than forecasts.',
          ),
          ShelterType.cabin: (
            title: 'Cabin arrival check',
            body: 'Confirm check-in time and access code before you leave. '
                'Locate the fuse box, water shutoff, and fire extinguisher '
                'on arrival. Report any pre-existing damage before you unpack.',
          ),
          ShelterType.glamping: (
            title: 'Glamping site prep',
            body: 'Confirm whether linens, cookware, and fire materials '
                'are provided. Arrive with a headlamp regardless — glamping '
                'sites often have less lighting than you expect.',
          ),
          ShelterType.other: (
            title: 'Trip day checklist',
            body: 'Run a final gear check before you leave home. Missing '
                'stakes, dead headlamp batteries, a forgotten can opener — '
                'all solved with a 5-minute walkthrough.',
          ),
        },
      );
}

// ── Internal tip variant helper ───────────────────────────────────────────────

class _TipVariants {
  final String emoji;
  final RangerTone tone;
  final String sourceLabel;
  final Map<ShelterType, ({String title, String body})> variants;

  const _TipVariants({
    required this.emoji,
    required this.tone,
    required this.sourceLabel,
    required this.variants,
  });

  RangerCard resolve(ShelterType shelter) {
    final v = variants[shelter] ?? variants[ShelterType.other]!;
    return RangerCard(
      emoji: emoji,
      title: v.title,
      body: v.body,
      sourceLabel: sourceLabel,
      tone: tone,
    );
  }
}

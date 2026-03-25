import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../services/weather_service.dart';
import '../widgets/common_widgets.dart';

enum _ConditionsSection { forecast, alerts, news }

class ConditionsScreen extends StatefulWidget {
  final TripModel trip;
  const ConditionsScreen({required this.trip, super.key});
  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  WeatherData? _weather;
  bool _loading = false;
  String? _error;
  String _locationLabel = '';
  _ConditionsSection _section = _ConditionsSection.forecast;

  @override
  void initState() {
    super.initState();
    if (widget.trip.campsite.isNotEmpty) _load(widget.trip.campsite);
  }

  @override
  void didUpdateWidget(ConditionsScreen old) {
    super.didUpdateWidget(old);
    if (old.trip.campsite != widget.trip.campsite &&
        widget.trip.campsite.isNotEmpty) {
      _load(widget.trip.campsite);
    }
  }

  Future<void> _load(String location) async {
    if (location.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      LocationResult? loc;
      if (widget.trip.lat != null && location == widget.trip.campsite) {
        loc = LocationResult(
            lat: widget.trip.lat!,
            lng: widget.trip.lng!,
            displayName: location);
      } else {
        loc = await WeatherService.geocode(location);
      }
      if (loc == null) {
        setState(() {
          _error =
              'Could not find "$location". Try adding a state, e.g. "Lake Mary, AZ".';
          _loading = false;
        });
        return;
      }
      if (!loc.hasCoordinates) {
        setState(() {
          _error = 'Location found, but coordinates were unavailable.';
          _loading = false;
        });
        return;
      }
      final weather = await WeatherService.fetchWeather(loc.lat!, loc.lng!);
      if (mounted)
        setState(() {
          _weather = weather;
          _locationLabel = loc!.displayName.split(',').take(2).join(',').trim();
          _loading = false;
          if (weather == null)
            _error = 'Weather data unavailable. Check your connection.';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Error: $e';
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PageTitle('Conditions',
              subtitle: 'Weather  Alerts  Air Quality'),
          const SizedBox(height: 16),

          // Location bar
          Container(
            padding: const EdgeInsets.all(14),
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
              const Text('📍', style: TextStyle(fontSize: 22)),
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
                    Text('Set location in the Plan tab',
                        style: WildPathTypography.body(
                            fontSize: 11, color: WildPathColors.smoke)),
                  ])),
              GestureDetector(
                onTap: () => _load(widget.trip.campsite),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: WildPathColors.forest,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_loading ? '...' : 'Refresh',
                      style: WildPathTypography.body(
                          fontSize: 11, color: Colors.white)),
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
            _sectionChip('CAMPGROUND NEWS', _ConditionsSection.news),
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
                const Text('⚠', style: TextStyle(fontSize: 20)),
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
    final newsItems = _buildCampgroundNews(w);

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
              Text(w.icon, style: const TextStyle(fontSize: 48)),
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
              const Text('⚠️', style: TextStyle(fontSize: 20)),
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
                'No active severe weather alerts were returned for ${_locationLabel.isNotEmpty ? _locationLabel : widget.trip.campsite}.',
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
                      Text(a.emoji, style: const TextStyle(fontSize: 20)),
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
                                a.description.length > 240
                                    ? '${a.description.substring(0, 240)}...'
                                    : a.description,
                                style: WildPathTypography.body(
                                    fontSize: 12,
                                    color: WildPathColors.smoke,
                                    height: 1.5),
                              ),
                            ],
                          ])),
                    ]),
              )),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'Alert data provided by api.weather.gov (National Weather Service).',
              style: WildPathTypography.body(
                fontSize: 11,
                color: WildPathColors.smoke,
              ),
            ),
          ),
        ],
      ] else ...[
        Text('Campground News',
            style: WildPathTypography.display(
                fontSize: 18, color: WildPathColors.forest)),
        const SizedBox(height: 10),
        ...newsItems.map((item) => _CampgroundNewsCard(item: item)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WildPathColors.mist, width: 1.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About this feed',
                  style: WildPathTypography.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WildPathColors.pine)),
              const SizedBox(height: 6),
              Text(
                'This first pass combines current forecast data, official severe weather alerts, and trip context to generate a campground briefing. Direct operator bulletins and park-specific closures can be added next.',
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
            color: active ? WildPathColors.forest : Colors.white,
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
              color: active ? Colors.white : WildPathColors.forest,
            ),
          ),
        ),
      ),
    );
  }

  List<_CampgroundNewsItem> _buildCampgroundNews(WeatherData w) {
    final location =
        _locationLabel.isNotEmpty ? _locationLabel : widget.trip.campsite;
    final items = <_CampgroundNewsItem>[];
    final coldNight = w.forecast.isNotEmpty
        ? w.forecast.map((d) => d.minTempF).reduce((a, b) => a < b ? a : b)
        : w.tempF;
    final wetDays = w.forecast.where((d) => d.precipMm >= 5).length;
    final hotDay = w.forecast.isNotEmpty
        ? w.forecast.map((d) => d.maxTempF).reduce((a, b) => a > b ? a : b)
        : w.tempF;

    if (w.alerts.isNotEmpty) {
      items.add(_CampgroundNewsItem(
        emoji: '⚠️',
        title: 'Active area alerts for $location',
        body:
            'Official weather alerts are active near your trip area. Review the Alerts section before departure and again the morning you leave.',
        source: 'National Weather Service alert feed',
        tone: WildPathColors.amber,
      ));
    }

    if (wetDays > 0) {
      items.add(_CampgroundNewsItem(
        emoji: '🌧',
        title: 'Wet setup conditions possible',
        body:
            '$wetDays ${wetDays == 1 ? "day shows" : "days show"} measurable rain in the forecast. Expect softer ground, slower fire-starting, and a greater need for waterproof storage.',
        source: 'Open-Meteo forecast',
        tone: WildPathColors.blue,
      ));
    }

    if (w.windMph >= 15) {
      items.add(_CampgroundNewsItem(
        emoji: '💨',
        title: 'Wind-sensitive campsite setup',
        body:
            'Current winds are around ${w.windMph.round()} mph. Choose a more sheltered pitch, secure loose gear, and avoid exposed ridgelines if you are tent camping.',
        source: 'Open-Meteo current conditions',
        tone: WildPathColors.ember,
      ));
    }

    if (coldNight <= 36) {
      items.add(_CampgroundNewsItem(
        emoji: '🧤',
        title: 'Cold overnight temperatures',
        body:
            'Forecast overnight lows dip to about ${coldNight.round()}F. Plan for cold sleeping conditions and protect water, batteries, and any sensitive gear overnight.',
        source: 'Open-Meteo forecast',
        tone: WildPathColors.forest,
      ));
    }

    if (hotDay >= 88) {
      items.add(_CampgroundNewsItem(
        emoji: '☀️',
        title: 'Hot daytime exposure window',
        body:
            'Highs may reach about ${hotDay.round()}F. Shift setup and hiking to earlier hours, carry more water, and look for shade-heavy campsites if available.',
        source: 'Open-Meteo forecast',
        tone: WildPathColors.amber,
      ));
    }

    if (widget.trip.tripType == 'Backpacking') {
      items.add(const _CampgroundNewsItem(
        emoji: '🥾',
        title: 'Backcountry conditions check recommended',
        body:
            'Before departure, verify trailhead access, stream crossings, and backcountry notices from the managing land agency. Local closures can change faster than forecasts.',
        source: 'WildPath trip briefing',
        tone: WildPathColors.moss,
      ));
    } else if (widget.trip.tripType == 'RV or Van') {
      items.add(const _CampgroundNewsItem(
        emoji: '🚐',
        title: 'Vehicle access and parking check',
        body:
            'For RV and van trips, confirm roadway access, overnight parking rules, and any campground generator or quiet-hour restrictions before arrival.',
        source: 'WildPath trip briefing',
        tone: WildPathColors.moss,
      ));
    }

    items.add(const _CampgroundNewsItem(
      emoji: '📣',
      title: 'Campground bulletin board check',
      body:
          'On arrival, check the campground kiosk or ranger station for same-day fire restrictions, water outages, wildlife notices, and quiet-hour changes.',
      source: 'WildPath trip briefing',
      tone: WildPathColors.forest,
    ));

    return items.take(4).toList();
  }

  Widget _wStat(String label, String value) => Expanded(
          child: Column(children: [
        Text(value,
            style: WildPathTypography.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        Text(label,
            style: WildPathTypography.body(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.65))),
      ]));

  Color _alertColor(String sev) {
    if (sev == 'extreme') return WildPathColors.red;
    if (sev == 'severe') return WildPathColors.ember;
    return WildPathColors.amber;
  }
}

class _CampgroundNewsItem {
  final String emoji;
  final String title;
  final String body;
  final String source;
  final Color tone;

  const _CampgroundNewsItem({
    required this.emoji,
    required this.title,
    required this.body,
    required this.source,
    required this.tone,
  });
}

class _CampgroundNewsCard extends StatelessWidget {
  final _CampgroundNewsItem item;
  const _CampgroundNewsCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: item.tone.withValues(alpha: 0.28), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: item.tone.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: WildPathTypography.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: WildPathColors.pine)),
                  const SizedBox(height: 4),
                  Text(item.body,
                      style: WildPathTypography.body(
                          fontSize: 12,
                          color: WildPathColors.smoke,
                          height: 1.5)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: item.tone.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.source,
              style: WildPathTypography.body(
                  fontSize: 10, fontWeight: FontWeight.w700, color: item.tone),
            ),
          ),
        ]),
      );
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: WildPathColors.pine.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Row(children: [
          Text(day.emoji, style: const TextStyle(fontSize: 20)),
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
              const Text('🌧', style: TextStyle(fontSize: 13)),
              Text('${day.precipMm.round()}mm',
                  style: WildPathTypography.body(
                      fontSize: 10, color: WildPathColors.blue)),
            ]),
          ],
        ]),
      );
}

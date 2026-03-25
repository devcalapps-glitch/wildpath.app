import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'theme/app_theme.dart';
import 'models/trip_model.dart';
import 'services/storage_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/gear_screen.dart';
import 'screens/meals_screen.dart';
import 'screens/conditions_screen.dart';
import 'screens/more_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final storage = StorageService();
  await storage.init();
  runApp(WildPathApp(storage: storage));
}

class WildPathApp extends StatelessWidget {
  final StorageService storage;
  const WildPathApp({required this.storage, super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WildPath',
        theme: WildPathTheme.theme,
        debugShowCheckedModeBanner: false,
        home: AppShell(storage: storage),
      );
}

class AppShell extends StatefulWidget {
  final StorageService storage;
  const AppShell({required this.storage, super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _loading = true;
  bool _showOnboarding = false;
  int _tab = 0;
  bool _openBudget = false;
  bool _triggerSave = false;
  bool _goToSummary = false;
  late TripModel _trip;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    final saved = widget.storage.loadCurrentTrip();
    setState(() {
      _showOnboarding = !widget.storage.onboardingDone;
      _trip = saved ?? TripModel(id: const Uuid().v4());
      _loading = false;
    });
  }

  void _setTrip(TripModel t) => setState(() => _trip = t);
  void _setTab(int i) {
    if (i == -1) {
      // Save Trip
      setState(() {
        _tab = 0;
        _triggerSave = true;
      });
    } else if (i == -2) {
      // View Summary
      setState(() {
        _tab = 0;
        _goToSummary = true;
      });
    } else {
      setState(() {
        _tab = i;
        if (i != 4) _openBudget = false;
      });
    }
  }

  void _goToBudget() => setState(() {
        _tab = 4;
        _openBudget = true;
      });

  static const _navItems = [
    _NavItem('🏕', 'Trip'),
    _NavItem('🎒', 'Gear'),
    _NavItem('🍳', 'Meals'),
    _NavItem('⛅', 'Weather'),
    _NavItem('☰', 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: WildPathColors.forest,
        body: Center(
            child: CircularProgressIndicator(color: WildPathColors.fern)),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        storage: widget.storage,
        onComplete: () => setState(() {
          _showOnboarding = false;
          _trip = _trip.copyWith(tripType: widget.storage.userStyle);
        }),
      );
    }

    return Scaffold(
      body: Column(children: [
        _TopBar(
          trip: _trip,
          userName: widget.storage.userName,
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              PlanScreen(
                storage: widget.storage,
                trip: _trip,
                onTripChanged: (t) {
                  _setTrip(t);
                },
                onNewTrip: () {
                  final t = TripModel(id: const Uuid().v4());
                  setState(() {
                    _trip = t;
                    _tab = 0;
                  });
                  widget.storage.saveCurrentTrip(t);
                },
                onNextTab: () => _setTab(1),
                onGoToTab: (i) => i == 4 ? _goToBudget() : _setTab(i),
                triggerSave: _triggerSave,
                triggerSummary: _goToSummary,
                onFlagHandled: () => setState(() {
                  _triggerSave = false;
                  _goToSummary = false;
                }),
              ),
              GearScreen(
                storage: widget.storage,
                trip: _trip,
                onNextTab: () => _setTab(2),
              ),
              MealsScreen(
                storage: widget.storage,
                trip: _trip,
                onNextTab: _goToBudget,
              ),
              ConditionsScreen(trip: _trip),
              MoreScreen(
                storage: widget.storage,
                currentTrip: _trip,
                isActive: _tab == 4,
                onLoadTrip: (t) {
                  setState(() {
                    _trip = t;
                    _tab = 0;
                  });
                  widget.storage.saveCurrentTrip(t);
                },
                onSwitchTab: _setTab,
                openBudgetOnLoad: _openBudget,
              ),
            ],
          ),
        ),
        _BottomNav(currentTab: _tab, onTab: _setTab, items: _navItems),
      ]),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TripModel trip;
  final String userName;
  const _TopBar({required this.trip, required this.userName});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _fmtRange(String start, String end) {
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
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      return '${m[s.month - 1]} ${s.day} - ${m[e.month - 1]} ${e.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTrip = trip.name.isNotEmpty || trip.campsite.isNotEmpty;
    final hasDates = trip.startDate.isNotEmpty;
    final greeting =
        userName.isNotEmpty ? '${_greeting()}, $userName' : _greeting();

    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
        colors: [WildPathColors.forest, WildPathColors.moss],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      )),
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 10, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text.rich(TextSpan(
          text: 'Wild',
          style: WildPathTypography.display(
              fontSize: 22, color: Colors.white, letterSpacing: -0.44),
          children: [
            TextSpan(
                text: 'Path',
                style: WildPathTypography.display(
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                    color: WildPathColors.fern,
                    letterSpacing: -0.44))
          ],
        )),
        const Spacer(),
        Flexible(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              greeting,
              style: WildPathTypography.body(
                  fontSize: 10, color: Colors.white.withOpacity(0.7)),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
            if (hasTrip)
              Text(
                trip.name.isNotEmpty ? trip.name : trip.campsite,
                style: WildPathTypography.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            if (hasDates)
              Text(_fmtRange(trip.startDate, trip.endDate),
                  style: WildPathTypography.body(
                      fontSize: 10, color: Colors.white.withOpacity(0.65)),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right),
          ],
        )),
      ]),
    );
  }
}

// ── Bottom Nav ─────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentTab;
  final ValueChanged<int> onTab;
  final List<_NavItem> items;
  const _BottomNav(
      {required this.currentTab, required this.onTab, required this.items});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: WildPathColors.mist)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(
          children: items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final active = i == currentTab;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTab(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(item.emoji,
                        style: const TextStyle(fontSize: 22, height: 1)),
                    const SizedBox(height: 3),
                    Text(item.label,
                        style: WildPathTypography.body(
                            fontSize: 9.5,
                            letterSpacing: 0.76,
                            color: active
                                ? WildPathColors.forest
                                : WildPathColors.stone,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400)),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: active ? 24 : 0,
                      decoration: BoxDecoration(
                        color: WildPathColors.forest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

class _NavItem {
  final String emoji;
  final String label;
  const _NavItem(this.emoji, this.label);
}

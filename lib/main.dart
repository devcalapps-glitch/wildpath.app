import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import 'theme/app_theme.dart';
import 'models/trip_model.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/gear_screen.dart';
import 'screens/meals_screen.dart';
import 'screens/conditions_screen.dart';
import 'screens/more_screen.dart'
    show MoreScreen, MapSection, BudgetSection, TripsSection;
import 'screens/permits_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final storage = StorageService();
  await storage.init();

  // Initialize notification plugin and timezone data
  await NotificationService.instance.init();

  // Initialize WorkManager with the background entry point
  await Workmanager().initialize(callbackDispatcher);

  // Start weather alert worker if enabled
  if (storage.notifPermissionAsked && storage.notifWeather) {
    await startWeatherAlertWorker();
  }

  // Reschedule trip reminders that survived app kills / reboots
  if (storage.notifPermissionAsked && storage.notifTrips) {
    try {
      await NotificationService.instance.rescheduleAllSavedTrips(storage);
    } catch (_) {
      // Silently ignore — scheduling may fail if no trips are saved yet
    }
  }

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
  bool _showSplash = true;
  bool _showOnboarding = false;
  // Bottom nav: 0=Plan, 1=Weather, 2=Map, 3=More
  int _tab = 0;
  // Plan hub sub-tabs: 0=Trip, 1=Gear, 2=Meals, 3=Budget
  int _planTab = 0;
  bool _triggerSave = false;
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
      _trip = saved ??
          TripModel(
            id: const Uuid().v4(),
          );
      _loading = false;
    });
  }

  void _setTrip(TripModel t) => setState(() => _trip = t);

  void _setTab(int i) {
    if (i == -1) {
      // Trigger save sheet
      setState(() {
        _tab = 0;
        _planTab = 0;
        _triggerSave = true;
      });
    } else if (i == -2) {
      // View Summary → navigate to More tab
      setState(() => _tab = 4);
    } else if (i == 0 && _tab == 0) {
      // Tapping Plan while already on Plan → reset to Trip sub-tab, scroll to top
      setState(() => _planTab = 0);
      _planScrollToTop?.call();
    } else {
      setState(() => _tab = i);
    }
  }

  VoidCallback? _planScrollToTop;

  static const _navItems = [
    _NavItem(Icons.terrain_rounded, 'Plan'),
    _NavItem(Icons.wb_cloudy_outlined, 'Weather'),
    _NavItem(Icons.map_outlined, 'Map'),
    _NavItem(Icons.backpack_outlined, 'My Trips'),
    _NavItem(Icons.grid_view_rounded, 'More'),
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

    if (_showSplash) {
      return SplashScreen(
        isFirstLaunch: _showOnboarding,
        userName: widget.storage.userName,
        onDone: () => setState(() => _showSplash = false),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        storage: widget.storage,
        onComplete: () => setState(() {
          _showOnboarding = false;
          _trip = _trip.copyWith(
            tripType: widget.storage.userStyle,
          );
        }),
      );
    }

    return Scaffold(
      body: Column(children: [
        _TopBar(trip: _trip, userName: widget.storage.userName),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _PlanHub(
                planTab: _planTab,
                onPlanTabChanged: (i) => setState(() => _planTab = i),
                storage: widget.storage,
                trip: _trip,
                onTripChanged: _setTrip,
                onNewTrip: () {
                  final t = TripModel(id: const Uuid().v4());
                  setState(() {
                    _trip = t;
                    _tab = 0;
                    _planTab = 0;
                  });
                  widget.storage.saveCurrentTrip(t);
                },
                triggerSave: _triggerSave,
                onSwitchTab: _setTab,
                onFlagHandled: () => setState(() {
                  _triggerSave = false;
                }),
                onRegisterScrollToTop: (fn) => _planScrollToTop = fn,
              ),
              ConditionsScreen(trip: _trip),
              MapSection(trip: _trip),
              TripsSection(
                storage: widget.storage,
                currentTripId: _trip.id,
                isActive: _tab == 3,
                onLoadTrip: (t) {
                  setState(() {
                    _trip = t;
                    _tab = 0;
                    _planTab = 0;
                  });
                  widget.storage.saveCurrentTrip(t);
                },
              ),
              MoreScreen(
                storage: widget.storage,
                currentTrip: _trip,
                isActive: _tab == 4,
                onLoadTrip: (t) {
                  setState(() {
                    _trip = t;
                    _tab = 0;
                    _planTab = 0;
                  });
                  widget.storage.saveCurrentTrip(t);
                },
                onSwitchTab: _setTab,
              ),
            ],
          ),
        ),
        _BottomNav(currentTab: _tab, onTab: _setTab, items: _navItems),
      ]),
    );
  }
}

// ── Plan Hub ────────────────────────────────────────────────────────────────
class _PlanHub extends StatelessWidget {
  final int planTab;
  final ValueChanged<int> onPlanTabChanged;
  final StorageService storage;
  final TripModel trip;
  final ValueChanged<TripModel> onTripChanged;
  final VoidCallback onNewTrip;
  final bool triggerSave;
  final VoidCallback? onFlagHandled;
  final ValueChanged<int> onSwitchTab;
  final ValueChanged<VoidCallback>? onRegisterScrollToTop;

  const _PlanHub({
    required this.planTab,
    required this.onPlanTabChanged,
    required this.storage,
    required this.trip,
    required this.onTripChanged,
    required this.onNewTrip,
    required this.triggerSave,
    required this.onSwitchTab,
    this.onFlagHandled,
    this.onRegisterScrollToTop,
  });

  static const _subTitles = [
    '',
    '🎒  Gear & Packing',
    '🍳  Meal Planning',
    '💰  Budget',
    '📜  Permits'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (planTab != 0)
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: WildPathColors.mist)),
          ),
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: WildPathColors.forest),
              onPressed: () => onPlanTabChanged(0),
            ),
            Text(
              _subTitles[planTab],
              style: WildPathTypography.body(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: WildPathColors.pine),
            ),
          ]),
        ),
      Expanded(
        child: IndexedStack(
          index: planTab,
          children: [
            PlanScreen(
              storage: storage,
              trip: trip,
              onTripChanged: onTripChanged,
              onNewTrip: onNewTrip,
              onGoToTab: (i) {
                if (i >= 1 && i <= 4) onPlanTabChanged(i);
              },
              onViewSavedTrips: () => onSwitchTab(3),
              triggerSave: triggerSave,
              onFlagHandled: onFlagHandled,
              onRegisterScrollToTop: onRegisterScrollToTop,
            ),
            GearScreen(
                storage: storage,
                trip: trip,
                onNextTab: () => onPlanTabChanged(2)),
            MealsScreen(
                storage: storage,
                trip: trip,
                onNextTab: () => onPlanTabChanged(3)),
            BudgetSection(
              storage: storage,
              tripId: trip.id,
              onSaveTrip: () => onSwitchTab(-1),
              onGoToPermits: () => onPlanTabChanged(4),
            ),
            PermitsScreen(
              storage: storage,
              trip: trip,
              onSaveTrip: () => onSwitchTab(-1),
            ),
          ],
        ),
      ),
    ]);
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
    final hasTrip = trip.name.isNotEmpty || trip.locationDisplay.isNotEmpty;
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
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
            if (hasTrip)
              Text(
                trip.name.isNotEmpty ? trip.name : trip.locationDisplay,
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
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.65)),
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
        decoration: const BoxDecoration(
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
                    Icon(item.icon,
                        size: 24,
                        color: active
                            ? WildPathColors.forest
                            : WildPathColors.stone),
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
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

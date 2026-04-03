import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/country_autocomplete_field.dart';

class OnboardingScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onComplete;
  const OnboardingScreen(
      {required this.storage, required this.onComplete, super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _scrollCtrl = ScrollController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _countryFocusNode = FocusNode();
  final _nameFieldKey = GlobalKey();
  final _emailFieldKey = GlobalKey();
  final _countryFieldKey = GlobalKey();
  String _country = '';
  final List<String> _styles = [];
  bool _notifTrips = false;
  bool _notifWeather = false;

  bool get _canContinueFromCurrentStep {
    if (_step == 0) {
      return _nameCtrl.text.trim().isNotEmpty &&
          _emailCtrl.text.trim().isNotEmpty &&
          _country.trim().isNotEmpty;
    }
    return true;
  }

  static const _tripTypes = [
    ('🏕', 'Campsites'),
    ('🚐', 'RV or Van'),
    ('🎒', 'Backpacking'),
    ('🛶', 'On the Water'),
    ('🏡', 'Cabins'),
    ('🌲', 'Off-Grid'),
    ('👥', 'Group Camp'),
    ('✨', 'Glamping'),
  ];

  @override
  void initState() {
    super.initState();
    _notifTrips = widget.storage.notifTrips;
    _notifWeather = widget.storage.notifWeather;
    _nameFocusNode
        .addListener(() => _handleFieldFocus(_nameFieldKey, _nameFocusNode));
    _emailFocusNode
        .addListener(() => _handleFieldFocus(_emailFieldKey, _emailFocusNode));
    _countryFocusNode.addListener(
        () => _handleFieldFocus(_countryFieldKey, _countryFocusNode));
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _countryCtrl.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _countryFocusNode.dispose();
    super.dispose();
  }

  void _handleFieldFocus(GlobalKey key, FocusNode node) {
    if (!node.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.18,
      );
    });
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

  Future<void> _finish() async {
    await widget.storage.setUserName(_nameCtrl.text.trim());
    await widget.storage.setUserEmail(_emailCtrl.text.trim());
    await widget.storage
        .setUserCountry(TripModel.normalizeCountryName(_country));
    if (_styles.isNotEmpty) await widget.storage.setUserStyles(_styles);
    await widget.storage.setNotifTrips(_notifTrips);
    await widget.storage.setNotifWeather(_notifWeather);
    if (_notifTrips) {
      await NotificationService.instance
          .rescheduleAllSavedTrips(widget.storage);
    }
    if (_notifWeather) {
      await startWeatherAlertWorker();
    }
    await widget.storage.setOnboardingDone();
    widget.onComplete();
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

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: WildPathColors.forest,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
              colors: [WildPathColors.forest, WildPathColors.moss],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )),
            child: SafeArea(
              bottom: MediaQuery.viewInsetsOf(context).bottom == 0,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  controller: _scrollCtrl,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    28,
                    24,
                    28 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(children: [
                      // Logo
                      Text.rich(
                          TextSpan(
                            text: 'Wild',
                            style: WildPathTypography.display(
                                fontSize: 48,
                                color: Colors.white,
                                letterSpacing: -0.96),
                            children: [
                              TextSpan(
                                  text: 'Path',
                                  style: WildPathTypography.display(
                                      fontSize: 48,
                                      fontStyle: FontStyle.italic,
                                      color: WildPathColors.fern,
                                      letterSpacing: -0.96))
                            ],
                          ),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text('PLAN THE WILD. CAMP WITH CONFIDENCE.',
                          style: WildPathTypography.body(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Colors.white.withValues(alpha: 0.5)),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 28),

                      // Dots
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                              3,
                              (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: i == _step ? 24 : 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    decoration: BoxDecoration(
                                      color: i == _step
                                          ? Colors.white
                                          : Colors.white
                                              .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ))),
                      const SizedBox(height: 28),

                      // Card
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.all(24),
                        child: _buildStep(),
                      ),
                      const SizedBox(height: 24),

                      // CTA buttons
                      if (_step == 0)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: Tooltip(
                            message: _step == 2
                                ? 'Finish onboarding and start planning'
                                : 'Continue to the next onboarding step',
                            child: ElevatedButton(
                              onPressed: !_canContinueFromCurrentStep
                                  ? null
                                  : (_step == 2
                                      ? _finish
                                      : () => setState(() => _step++)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: WildPathColors.forest,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                textStyle: WildPathTypography.body(
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700),
                              ),
                              child:
                                  Text(_step == 2 ? "LET'S GO!" : 'CONTINUE →'),
                            ),
                          ),
                        )
                      else
                        Row(children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: GhostButton('← Back',
                                  color: WildPathColors.white,
                                  onPressed: () => setState(() => _step--)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: Tooltip(
                                message: _step == 2
                                    ? 'Finish onboarding and start planning'
                                    : 'Continue to the next onboarding step',
                                child: ElevatedButton(
                                  onPressed: !_canContinueFromCurrentStep
                                      ? null
                                      : (_step == 2
                                          ? _finish
                                          : () => setState(() => _step++)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: WildPathColors.forest,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    textStyle: WildPathTypography.body(
                                        fontSize: 12,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  child: Text(
                                      _step == 2 ? "LET'S GO!" : 'CONTINUE →'),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _step0();
      case 1:
        return _step1();
      default:
        return _step2();
    }
  }

  Widget _step0() => Column(children: [
        Text('👋',
            semanticsLabel: '',
            style: WildPathTypography.display(fontSize: 40)),
        const SizedBox(height: 12),
        Text('Welcome to WildPath',
            style:
                WildPathTypography.display(fontSize: 24, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
            'Your personal camping trip planner.\nLet\'s set things up for you.',
            style: WildPathTypography.body(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.6),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _obLabel('YOUR FIRST NAME'),
        const SizedBox(height: 6),
        _obField(_nameCtrl, 'e.g. Alex', TextInputType.name,
            key: _nameFieldKey,
            focusNode: _nameFocusNode,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        _obLabel('EMAIL'),
        const SizedBox(height: 6),
        _obField(_emailCtrl, 'e.g. alex@email.com', TextInputType.emailAddress,
            key: _emailFieldKey,
            focusNode: _emailFocusNode,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        _obLabel('COUNTRY'),
        const SizedBox(height: 6),
        _countryField(key: _countryFieldKey),
        const SizedBox(height: 10),
        Text('Name, email, and country are required to continue.',
            style: WildPathTypography.body(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
      ]);

  Widget _step1() => Column(children: [
        Text('⛺',
            semanticsLabel: '',
            style: WildPathTypography.display(fontSize: 40)),
        const SizedBox(height: 12),
        Text('How do you camp?',
            style:
                WildPathTypography.display(fontSize: 22, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Pick all the styles that fit',
            style: WildPathTypography.body(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: _tripTypes.map((t) {
            final sel = _styles.contains(t.$2);
            return GestureDetector(
              onTap: () => setState(() {
                if (sel) {
                  _styles.remove(t.$2);
                } else {
                  _styles.add(t.$2);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                      color: sel
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.15),
                      width: sel ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${t.$1} ${t.$2}',
                    style: WildPathTypography.body(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400),
                    textAlign: TextAlign.center),
              ),
            );
          }).toList(),
        ),
      ]);

  Widget _step2() {
    final name = _nameCtrl.text.trim();
    return Column(children: [
      Text('🌲',
          semanticsLabel: '', style: WildPathTypography.display(fontSize: 48)),
      const SizedBox(height: 12),
      Text(name.isNotEmpty ? "You're all set, $name!" : "You're all set!",
          style: WildPathTypography.display(fontSize: 22, color: Colors.white),
          textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text('WildPath is ready to help you plan your next adventure.',
          style: WildPathTypography.body(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.6),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Container(
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NOTIFICATIONS',
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 12),
          _notifRow('Trip Reminders', '2 days & 1 day before your trip',
              _notifTrips, _onNotifTripsChanged),
          const SizedBox(height: 12),
          _notifRow(
              'Severe Weather Alerts',
              'Get notified of dangerous conditions',
              _notifWeather,
              _onNotifWeatherChanged),
        ]),
      ),
    ]);
  }

  Widget _obLabel(String text) => Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: WildPathTypography.body(
              fontSize: 10,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.5))));

  Widget _obField(
    TextEditingController ctrl,
    String hint,
    TextInputType type, {
    Key? key,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) =>
      Container(
        key: key,
        child: TextField(
          controller: ctrl,
          focusNode: focusNode,
          keyboardType: type,
          onChanged: onChanged,
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 240),
          style: WildPathTypography.body(fontSize: 16, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: WildPathTypography.body(
                fontSize: 16, color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.15),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );

  Widget _countryField({Key? key}) => Container(
        key: key,
        child: CountryAutocompleteField(
          controller: _countryCtrl,
          focusNode: _countryFocusNode,
          hintText: 'Type your country',
          fallbackValue: _country,
          fillColor: Colors.white.withValues(alpha: 0.15),
          textColor: Colors.white,
          hintColor: Colors.white.withValues(alpha: 0.45),
          iconColor: Colors.white.withValues(alpha: 0.75),
          optionsBackgroundColor: WildPathColors.forest,
          optionsTextColor: Colors.white,
          optionsBorderColor: Colors.white.withValues(alpha: 0.12),
          optionsViewOpenDirection: OptionsViewOpenDirection.up,
          optionsMaxHeight: 220,
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 240),
          onSelected: _onCountrySelected,
          onChanged: _onCountryInputChanged,
        ),
      );

  Widget _notifRow(
          String title, String sub, bool value, ValueChanged<bool> onChanged) =>
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: WildPathTypography.body(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
          Text(sub,
              style: WildPathTypography.body(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.55))),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.resolveWith((states) {
            return const Color(0xFFF5F0E2);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFD3E49A);
            }
            return const Color(0xFFE9E1CF).withValues(alpha: 0.45);
          }),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            return Colors.transparent;
          }),
        ),
      ]);
}

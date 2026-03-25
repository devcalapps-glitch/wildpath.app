import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

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
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _style = '';
  bool _notifTrips = true;
  bool _notifWeather = true;

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
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.storage.setUserName(_nameCtrl.text.trim());
    await widget.storage.setUserEmail(_emailCtrl.text.trim());
    if (_style.isNotEmpty) await widget.storage.setUserStyle(_style);
    await widget.storage.setNotifTrips(_notifTrips);
    await widget.storage.setNotifWeather(_notifWeather);
    await widget.storage.setOnboardingDone();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            colors: [WildPathColors.forest, WildPathColors.moss],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                        color: Colors.white.withOpacity(0.5)),
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
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i == _step
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ))),
                const SizedBox(height: 28),

                // Card
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.all(24),
                  child: _buildStep(),
                ),
                const SizedBox(height: 24),

                // CTA button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _step == 2 ? _finish : () => setState(() => _step++),
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
                    child: Text(_step == 2 ? "LET'S GO!" : 'CONTINUE →'),
                  ),
                ),
                if (_step > 0) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: Text('← Back',
                        style: WildPathTypography.body(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6))),
                  ),
                ],
              ]),
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
        const Text('👋', style: TextStyle(fontSize: 40)),
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
                color: Colors.white.withOpacity(0.65),
                height: 1.6),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        _obLabel('YOUR FIRST NAME'),
        const SizedBox(height: 6),
        _obField(_nameCtrl, 'e.g. Alex', TextInputType.name),
        const SizedBox(height: 14),
        _obLabel('EMAIL (OPTIONAL)'),
        const SizedBox(height: 6),
        _obField(_emailCtrl, 'e.g. alex@email.com', TextInputType.emailAddress),
      ]);

  Widget _step1() => Column(children: [
        const Text('⛺', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text('How do you camp?',
            style:
                WildPathTypography.display(fontSize: 22, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Pick your most common style',
            style: WildPathTypography.body(
                fontSize: 13, color: Colors.white.withOpacity(0.6)),
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
            final sel = _style == t.$2;
            return GestureDetector(
              onTap: () => setState(() => _style = t.$2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withOpacity(0.25)
                      : Colors.white.withOpacity(0.1),
                  border: Border.all(
                      color:
                          sel ? Colors.white : Colors.white.withOpacity(0.15),
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
      const Text('🌲', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text(name.isNotEmpty ? "You're all set, $name!" : "You're all set!",
          style: WildPathTypography.display(fontSize: 22, color: Colors.white),
          textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text('WildPath is ready to help you plan your next adventure.',
          style: WildPathTypography.body(
              fontSize: 13, color: Colors.white.withOpacity(0.65), height: 1.6),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Container(
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NOTIFICATIONS',
              style: WildPathTypography.body(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 12),
          _notifRow('Trip Reminders', '2 days & 1 day before your trip',
              _notifTrips, (v) => setState(() => _notifTrips = v)),
          const SizedBox(height: 12),
          _notifRow(
              'Severe Weather Alerts',
              'Get notified of dangerous conditions',
              _notifWeather,
              (v) => setState(() => _notifWeather = v)),
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
              color: Colors.white.withOpacity(0.5))));

  Widget _obField(
          TextEditingController ctrl, String hint, TextInputType type) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: WildPathTypography.body(fontSize: 16, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: WildPathTypography.body(
              fontSize: 16, color: Colors.white.withOpacity(0.4)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  fontSize: 11, color: Colors.white.withOpacity(0.55))),
        ])),
        Switch(
            value: value,
            onChanged: onChanged,
            activeColor: WildPathColors.fern),
      ]);
}

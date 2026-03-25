import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../models/meal_item.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';

class MealsScreen extends StatefulWidget {
  final StorageService storage;
  final TripModel trip;
  final VoidCallback? onNextTab;

  const MealsScreen(
      {required this.storage, required this.trip, this.onNextTab, super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  List<MealItem> _meals = [];

  @override
  void initState() {
    super.initState();
    _meals = widget.storage.loadMeals(widget.trip.id);
  }

  @override
  void didUpdateWidget(MealsScreen old) {
    super.didUpdateWidget(old);
    if (old.trip.id != widget.trip.id) {
      setState(() => _meals = widget.storage.loadMeals(widget.trip.id));
    }
  }

  void _save() => widget.storage.saveMeals(widget.trip.id, _meals);

  void _openSheet(String dateKey, MealType mealType, [MealItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

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
          child: SingleChildScrollView(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    Row(children: [
                      _badge(mealType),
                      const SizedBox(width: 10),
                      Text(
                          existing == null
                              ? 'Add ${mealType.label}'
                              : 'Edit ${mealType.label}',
                          style: WildPathTypography.display(fontSize: 20)),
                    ]),
                    const SizedBox(height: 16),
                    _sheetField(nameCtrl, 'Meal name (e.g. Pasta primavera)'),
                    const SizedBox(height: 10),
                    _sheetField(
                        noteCtrl, 'Notes (e.g. cook time, ingredients)'),
                    const SizedBox(height: 20),
                    Row(children: [
                      if (existing != null) ...[
                        Expanded(
                            child: GhostButton('Delete', onPressed: () {
                          setState(() =>
                              _meals.removeWhere((m) => m.id == existing.id));
                          _save();
                          Navigator.pop(context);
                        })),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                          child: PrimaryButton(
                        existing == null ? 'Add Meal' : 'Save Changes',
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setState(() {
                            if (existing != null) {
                              final idx =
                                  _meals.indexWhere((m) => m.id == existing.id);
                              if (idx >= 0) {
                                _meals[idx] = MealItem(
                                  id: existing.id,
                                  dateKey: dateKey,
                                  mealType: mealType,
                                  name: nameCtrl.text.trim(),
                                  note: noteCtrl.text.trim(),
                                );
                              }
                            } else {
                              _meals.add(MealItem(
                                id: const Uuid().v4(),
                                dateKey: dateKey,
                                mealType: mealType,
                                name: nameCtrl.text.trim(),
                                note: noteCtrl.text.trim(),
                              ));
                            }
                          });
                          _save();
                          Navigator.pop(context);
                        },
                      )),
                    ]),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dayLabel(DateTime d, int i) {
    const months = [
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
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return 'Day ${i + 1} | ${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  int get _filled {
    int n = 0;
    for (final d in widget.trip.tripDays) {
      final k = _key(d);
      for (final mt in MealType.values) {
        if (_meals.any((m) => m.dateKey == k && m.mealType == mt)) n++;
      }
    }
    return n;
  }

  int get _total => widget.trip.tripDays.length * MealType.values.length;

  @override
  Widget build(BuildContext context) {
    final days = widget.trip.tripDays;

    // Build each day's widget in a plain list — no nested spreads inside if/else
    final List<Widget> children = [
      const PageTitle('Meal Planner',
          subtitle: 'Plan every meal for every day'),
      const SizedBox(height: 16),
    ];

    if (days.isEmpty) {
      children.add(Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WildPathColors.amber.withOpacity(0.08),
          border: Border.all(
              color: WildPathColors.amber.withOpacity(0.25), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Text('📅', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
            'Set your trip dates in the Plan tab to generate a day-by-day meal schedule.',
            style: WildPathTypography.body(
                fontSize: 13, color: WildPathColors.forest, height: 1.6),
          )),
        ]),
      ));
    } else {
      children.add(WildProgressBar(
        progress: _total == 0 ? 0 : _filled / _total,
        title: 'Meal Plan',
        countLabel: '$_filled / $_total meals',
        barColor: WildPathColors.amber,
      ));
      children.add(const SizedBox(height: 20));

      for (int i = 0; i < days.length; i++) {
        final day = days[i];
        final k = _key(day);
        final parts = _dayLabel(day, i).split('|');

        children.add(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(parts[0].trim(),
                  style: WildPathTypography.display(
                      fontSize: 18,
                      color: WildPathColors.forest,
                      fontWeight: FontWeight.w700)),
              Text(parts.last.trim(),
                  style: WildPathTypography.body(
                      fontSize: 10,
                      color: WildPathColors.stone,
                      letterSpacing: 0.6)),
            ]),
            const SizedBox(height: 10),
            ...MealType.values.map((mt) {
              final existing = _meals
                  .where((m) => m.dateKey == k && m.mealType == mt)
                  .firstOrNull;
              return _MealSlot(
                  mealType: mt,
                  meal: existing,
                  onTap: () => _openSheet(k, mt, existing));
            }),
            const SizedBox(height: 12),
          ],
        ));
      }
    }

    // Guided flow buttons — always at the bottom
    children.add(const SizedBox(height: 8));
    children.add(SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: widget.onNextTab,
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text('Next: Track Your Budget →',
            style: WildPathTypography.body(
                fontSize: 13,
                letterSpacing: 1.04,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
    ));
    children.add(const SizedBox(height: 8));
    children.add(GhostButton('Skip for now',
        fullWidth: true, onPressed: widget.onNextTab));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint) => TextFormField(
        controller: ctrl,
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
      );

  Widget _badge(MealType mt) {
    const colors = {
      MealType.breakfast: WildPathColors.amber,
      MealType.lunch: WildPathColors.sage,
      MealType.dinner: WildPathColors.forest,
      MealType.snack: WildPathColors.smoke,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: colors[mt], borderRadius: BorderRadius.circular(20)),
      child: Text(mt.label,
          style: WildPathTypography.body(
              fontSize: 10, color: Colors.white, letterSpacing: 1)),
    );
  }
}

class _MealSlot extends StatelessWidget {
  final MealType mealType;
  final MealItem? meal;
  final VoidCallback onTap;
  const _MealSlot({required this.mealType, this.meal, required this.onTap});

  static const _colors = {
    MealType.breakfast: WildPathColors.amber,
    MealType.lunch: WildPathColors.sage,
    MealType.dinner: WildPathColors.forest,
    MealType.snack: WildPathColors.smoke,
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: WildPathColors.pine.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _colors[mealType],
                  borderRadius: BorderRadius.circular(20)),
              child: Text(mealType.label,
                  style: WildPathTypography.body(
                      fontSize: 10, color: Colors.white, letterSpacing: 1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: meal == null
                  ? Text('Tap to plan ${mealType.label.toLowerCase()}...',
                      style: WildPathTypography.body(
                          fontSize: 13,
                          color: WildPathColors.stone,
                          fontStyle: FontStyle.italic))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(meal!.name,
                              style: WildPathTypography.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: WildPathColors.pine)),
                          if (meal!.note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(meal!.note,
                                style: WildPathTypography.body(
                                    fontSize: 12, color: WildPathColors.smoke),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ]),
            ),
            Icon(meal == null ? Icons.add_circle_outline : Icons.edit_outlined,
                color:
                    meal == null ? WildPathColors.stone : WildPathColors.moss,
                size: 18),
          ]),
        ),
      );
}

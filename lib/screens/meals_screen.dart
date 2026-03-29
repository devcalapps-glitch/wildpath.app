import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/trip_model.dart';
import '../models/meal_item.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';

// ─── Meal-type design tokens ─────────────────────────────────────────────────

const _mealColors = {
  MealType.breakfast: WildPathColors.amber,
  MealType.lunch: WildPathColors.sage,
  MealType.dinner: WildPathColors.forest,
  MealType.snack: WildPathColors.smoke,
};

const _mealIcons = {
  MealType.breakfast: Icons.wb_sunny_outlined,
  MealType.lunch: Icons.light_mode_outlined,
  MealType.dinner: Icons.nights_stay_outlined,
  MealType.snack: Icons.local_cafe_outlined,
};

const _mealEmptyHints = {
  MealType.breakfast: 'What\'s fueling the morning?',
  MealType.lunch: 'Something quick on the trail?',
  MealType.dinner: 'Tonight\'s campfire feast?',
  MealType.snack: 'Trail mix? Energy bars?',
};

// ─── Screen ───────────────────────────────────────────────────────────────────

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

  // ─── Bottom-sheet ────────────────────────────────────────────────────────

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
                  const SizedBox(height: 20),

                  // Sheet header with pill + title
                  Row(children: [
                    _MealTypePill(mealType, compact: false),
                    const SizedBox(width: 12),
                    Text(
                      existing == null
                          ? 'Add ${mealType.label}'
                          : 'Edit ${mealType.label}',
                      style: WildPathTypography.display(
                          fontSize: 20, color: WildPathColors.pine),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  _sheetField(nameCtrl, 'Meal name (e.g. Pasta primavera)',
                      icon: Icons.restaurant_outlined),
                  const SizedBox(height: 10),
                  _sheetField(noteCtrl, 'Notes (e.g. cook time, ingredients)',
                      icon: Icons.notes_outlined),
                  const SizedBox(height: 24),

                  // Action row
                  Row(children: [
                    if (existing != null) ...[
                      Expanded(
                        child: GhostButton(
                          'Delete',
                          color: WildPathColors.red,
                          onPressed: () {
                            setState(() =>
                                _meals.removeWhere((m) => m.id == existing.id));
                            _save();
                            Navigator.pop(context);
                          },
                        ),
                      ),
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
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _shortDate(DateTime d) {
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
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
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

  List<_MealPlanDay> get _planDays => widget.trip.tripDays.map((day) {
        final key = _key(day);
        final slots = <MealType, MealItem?>{
          for (final mealType in MealType.values)
            mealType: _meals
                .where(
                    (meal) => meal.dateKey == key && meal.mealType == mealType)
                .firstOrNull,
        };
        return _MealPlanDay(
          date: day,
          dateKey: key,
          slots: slots,
        );
      }).toList();

  int get _missing => (_total - _filled).clamp(0, _total);

  ({String dateKey, MealType mealType, MealItem? existing})?
      get _nextMealTarget {
    for (final day in _planDays) {
      for (final mealType in MealType.values) {
        final meal = day.slots[mealType];
        if (meal == null) {
          return (dateKey: day.dateKey, mealType: mealType, existing: null);
        }
      }
    }
    final firstDay = _planDays.firstOrNull;
    if (firstDay == null) return null;
    final firstMealType = MealType.values.first;
    return (
      dateKey: firstDay.dateKey,
      mealType: firstMealType,
      existing: firstDay.slots[firstMealType],
    );
  }

  void _openNextMeal() {
    final target = _nextMealTarget;
    if (target == null) return;
    _openSheet(target.dateKey, target.mealType, target.existing);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final planDays = _planDays;

    final List<Widget> children = [
      const PageTitle('Meals',
          subtitle: 'Track what you will eat each day without over-planning.'),
      const SizedBox(height: 20),
    ];

    // ── Empty-trip state ──────────────────────────────────────────────────
    if (planDays.isEmpty) {
      children.add(
        TipCard(
          emoji: '📅',
          content:
              'Set your trip dates in the Plan tab to generate a day-by-day meal schedule.',
          bgColor: WildPathColors.amber.withValues(alpha: 0.07),
          borderColor: WildPathColors.amber.withValues(alpha: 0.22),
        ),
      );
    } else {
      children.add(_MealsHeroCard(
        plannedCount: _filled,
        totalCount: _total,
        dayCount: planDays.length,
        missingCount: _missing,
        progress: _total == 0 ? 0 : _filled / _total,
        onAddMeal: _openNextMeal,
        addMealLabel: _filled < _total ? '＋  Add Next Meal' : 'Review Meals',
      ));
      children.add(const SizedBox(height: 4));

      for (int i = 0; i < planDays.length; i++) {
        final day = planDays[i];
        children.add(_DayCard(
          dayNumber: i + 1,
          shortDate: _shortDate(day.date),
          filledCount: day.filledCount,
          totalSlots: MealType.values.length,
          slots: day.slots,
          onMealTap: (mealType, existing) =>
              _openSheet(day.dateKey, mealType, existing),
        ));
      }
    }

    // ── CTA ───────────────────────────────────────────────────────────────
    children.add(const SizedBox(height: 8));
    children.add(OutlineButton2('Next: Track Your Budget →',
        fullWidth: true, onPressed: widget.onNextTab));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // ─── Sheet field ─────────────────────────────────────────────────────────

  Widget _sheetField(
    TextEditingController ctrl,
    String hint, {
    IconData? icon,
  }) =>
      TextFormField(
        controller: ctrl,
        style:
            WildPathTypography.body(fontSize: 14, color: WildPathColors.pine),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: WildPathTypography.body(
              fontSize: 13, color: WildPathColors.stone),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: WildPathColors.smoke)
              : null,
          filled: true,
          fillColor: WildPathColors.cream,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: WildPathColors.moss, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}

// ─── Day card ─────────────────────────────────────────────────────────────────

class _MealPlanDay {
  final DateTime date;
  final String dateKey;
  final Map<MealType, MealItem?> slots;

  const _MealPlanDay({
    required this.date,
    required this.dateKey,
    required this.slots,
  });

  int get filledCount => slots.values.whereType<MealItem>().length;
}

class _MealsHeroCard extends StatelessWidget {
  final int plannedCount;
  final int totalCount;
  final int dayCount;
  final int missingCount;
  final double progress;
  final String addMealLabel;
  final VoidCallback onAddMeal;

  const _MealsHeroCard({
    required this.plannedCount,
    required this.totalCount,
    required this.dayCount,
    required this.missingCount,
    required this.progress,
    required this.addMealLabel,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) => WildCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: WildPathColors.forest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackStats = constraints.maxWidth < 380;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MEALS PLANNED',
                                    style: WildPathTypography.body(
                                        fontSize: 9.5,
                                        letterSpacing: 1.1,
                                        color: WildPathColors.mist)),
                                const SizedBox(height: 4),
                                Text('$plannedCount / $totalCount',
                                    style: WildPathTypography.display(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: WildPathColors.white)),
                                const SizedBox(height: 6),
                                Text(
                                    missingCount == 0
                                        ? 'All meal slots are mapped out.'
                                        : '$missingCount meal ${missingCount == 1 ? "slot is" : "slots are"} still open.',
                                    style: WildPathTypography.body(
                                        fontSize: 12,
                                        color: WildPathColors.mist,
                                        height: 1.45)),
                              ],
                            ),
                          ),
                          if (!stackStats) ...[
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _heroStat(
                                    '$dayCount', 'DAYS', WildPathColors.fern),
                                const SizedBox(height: 10),
                                _heroStat('$missingCount', 'OPEN',
                                    WildPathColors.mist),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (stackStats) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _heroStat(
                                  '$dayCount', 'DAYS', WildPathColors.fern,
                                  alignEnd: false),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _heroStat('$missingCount', 'OPEN',
                                  WildPathColors.mist,
                                  alignEnd: false),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${(progress.clamp(0, 1) * 100).toStringAsFixed(0)}% planned',
                            style: WildPathTypography.body(
                                fontSize: 11, color: WildPathColors.smoke)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('$plannedCount of $totalCount filled',
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WildPathTypography.body(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: WildPathColors.forest)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: WildPathColors.mist,
                      valueColor:
                          const AlwaysStoppedAnimation(WildPathColors.amber),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(addMealLabel,
                      fullWidth: true, onPressed: onAddMeal),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _heroStat(String value, String label, Color color,
          {bool alignEnd = true}) =>
      Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
}

class _DayCard extends StatelessWidget {
  final int dayNumber;
  final String shortDate;
  final int filledCount;
  final int totalSlots;
  final Map<MealType, MealItem?> slots;
  final void Function(MealType mealType, MealItem? existing) onMealTap;

  const _DayCard({
    required this.dayNumber,
    required this.shortDate,
    required this.filledCount,
    required this.totalSlots,
    required this.slots,
    required this.onMealTap,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = filledCount == totalSlots;
    return WildCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackHeader = constraints.maxWidth < 380;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color:
                              allDone ? WildPathColors.moss : WildPathColors.forest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNumber',
                            style: WildPathTypography.display(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: WildPathColors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Day $dayNumber',
                                style: WildPathTypography.display(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: WildPathColors.forest)),
                            Text(shortDate,
                                style: WildPathTypography.body(
                                    fontSize: 11, color: WildPathColors.smoke)),
                          ],
                        ),
                      ),
                      if (!stackHeader) ...[
                        const SizedBox(width: 12),
                        _statusPill(allDone),
                      ],
                    ],
                  ),
                  if (stackHeader) ...[
                    const SizedBox(height: 10),
                    _statusPill(allDone),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MealSlot(
                  mealType: MealType.breakfast,
                  meal: slots[MealType.breakfast],
                  onTap: () =>
                      onMealTap(MealType.breakfast, slots[MealType.breakfast]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MealSlot(
                  mealType: MealType.lunch,
                  meal: slots[MealType.lunch],
                  onTap: () => onMealTap(MealType.lunch, slots[MealType.lunch]),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _MealSlot(
                  mealType: MealType.dinner,
                  meal: slots[MealType.dinner],
                  onTap: () =>
                      onMealTap(MealType.dinner, slots[MealType.dinner]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MealSlot(
                  mealType: MealType.snack,
                  meal: slots[MealType.snack],
                  onTap: () => onMealTap(MealType.snack, slots[MealType.snack]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool allDone) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: allDone
              ? WildPathColors.moss.withValues(alpha: 0.14)
              : WildPathColors.cream,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          allDone ? 'All planned' : '$filledCount / $totalSlots filled',
          style: WildPathTypography.body(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: allDone ? WildPathColors.moss : WildPathColors.forest,
          ),
        ),
      );
}

// ─── Meal slot ────────────────────────────────────────────────────────────────

class _MealSlot extends StatelessWidget {
  final MealType mealType;
  final MealItem? meal;
  final VoidCallback onTap;

  const _MealSlot({required this.mealType, this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accentColor = _mealColors[mealType]!;
    final icon = _mealIcons[mealType]!;
    final isEmpty = meal == null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isEmpty
              ? WildPathColors.cream.withValues(alpha: 0.6)
              : accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEmpty
                ? WildPathColors.mist
                : accentColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isEmpty
                        ? WildPathColors.stone.withValues(alpha: 0.12)
                        : accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isEmpty ? WildPathColors.stone : accentColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _MealTypePill(mealType, compact: true)),
              ],
            ),
            const SizedBox(height: 10),
            if (isEmpty) ...[
              Text(
                'Add ${mealType.label.toLowerCase()}',
                style: WildPathTypography.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WildPathColors.pine),
              ),
              const SizedBox(height: 4),
              Text(
                _mealEmptyHints[mealType]!,
                style: WildPathTypography.body(
                    fontSize: 11.5, color: WildPathColors.stone, height: 1.35),
              ),
            ] else ...[
              Text(
                meal!.name,
                style: WildPathTypography.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WildPathColors.pine),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (meal!.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meal!.note,
                  style: WildPathTypography.body(
                      fontSize: 11.5,
                      color: WildPathColors.smoke,
                      height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Meal type pill ───────────────────────────────────────────────────────────

class _MealTypePill extends StatelessWidget {
  final MealType mealType;
  final bool compact;
  const _MealTypePill(this.mealType, {required this.compact});

  @override
  Widget build(BuildContext context) {
    final color = _mealColors[mealType]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            mealType.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: WildPathTypography.body(
              fontSize: compact ? 8.5 : 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: compact ? 0.6 : 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

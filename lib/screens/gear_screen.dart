import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/gear_item.dart';
import '../models/trip_model.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';

// Single Uuid instance — avoids re-instantiation on every call
const _uuid = Uuid();

class GearScreen extends StatefulWidget {
  final StorageService storage;
  final TripModel trip;
  final VoidCallback? onNextTab;

  const GearScreen(
      {required this.storage, required this.trip, this.onNextTab, super.key});

  @override
  State<GearScreen> createState() => _GearScreenState();
}

class _GearScreenState extends State<GearScreen> {
  List<GearItem> _items = [];

  // Cached derived state — updated only inside setState via _updateDerived()
  Map<String, List<GearItem>> _grouped = {};
  Map<String, bool> _expandedGroups = {};
  int _checkedCount = 0;
  double _progress = 0;

  // Debounce timer for storage writes
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    final saved = widget.storage.loadGear(widget.trip.id);
    _items = saved.isEmpty ? _defaults(widget.trip.tripType) : saved;
    _updateDerived();
  }

  @override
  void didUpdateWidget(GearScreen old) {
    super.didUpdateWidget(old);
    if (old.trip.id != widget.trip.id) {
      // Trip switched — reload gear AND check for a new tripType simultaneously
      final saved = widget.storage.loadGear(widget.trip.id);
      setState(() {
        _items = saved.isEmpty ? _defaults(widget.trip.tripType) : saved;
        _updateDerived();
      });
      return;
    }
    if (old.trip.tripType != widget.trip.tripType) {
      // Trip type changed in-place — replace defaults, keep custom items
      final custom = _items.where((i) => i.isCustom).toList();
      setState(() {
        _items = [..._defaults(widget.trip.tripType), ...custom];
        _updateDerived();
      });
      _save();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Flush any pending debounced save before disposing
    widget.storage.saveGear(widget.trip.id, _items);
    super.dispose();
  }

  /// Rebuilds all cached derived fields. Must be called inside setState.
  void _updateDerived() {
    final raw = <String, List<GearItem>>{};
    for (final item in _items) {
      raw.putIfAbsent(item.category, () => []).add(item);
    }
    // Deterministic order: known GearLists categories first, then custom ones alphabetically
    final knownOrder = GearLists.byTripType(widget.trip.tripType).keys.toList();
    final sorted = <String, List<GearItem>>{};
    for (final key in knownOrder) {
      if (raw.containsKey(key)) sorted[key] = raw[key]!;
    }
    for (final key in raw.keys) {
      if (!sorted.containsKey(key)) sorted[key] = raw[key]!;
    }
    _grouped = sorted;
    _expandedGroups = {
      for (final key in sorted.keys) key: _expandedGroups[key] ?? false,
    };
    _checkedCount = _items.where((i) => i.checked).length;
    _progress = _items.isEmpty ? 0 : _checkedCount / _items.length;
  }

  List<GearItem> _defaults(String type) {
    final result = <GearItem>[];
    GearLists.byTripType(type).forEach((cat, items) {
      for (final item in items) {
        result.add(GearItem(
          id: _uuid.v4(),
          label: item['label']!,
          qty: item['qty'] ?? '',
          category: cat,
          isCustom: false,
        ));
      }
    });
    return result;
  }

  /// Debounced save — coalesces rapid sequential writes into one.
  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) widget.storage.saveGear(widget.trip.id, _items);
    });
  }

  void _toggle(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    setState(() {
      _items[idx] = _items[idx].copyWith(checked: !_items[idx].checked);
      _updateDerived();
    });
    _save();
  }

  void _toggleGroup(String category) {
    setState(() {
      _expandedGroups[category] = !(_expandedGroups[category] ?? true);
    });
  }

  void _setAllGroups(bool expanded) {
    setState(() {
      _expandedGroups = {
        for (final key in _grouped.keys) key: expanded,
      };
    });
  }

  /// Removes item immediately with a 3-second undo snackbar.
  void _deleteWithUndo(GearItem item) {
    setState(() {
      _items.removeWhere((i) => i.id == item.id);
      _updateDerived();
    });
    _save();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${item.label} removed',
          style: WildPathTypography.body(fontSize: 13, color: Colors.white)),
      backgroundColor: WildPathColors.pine,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Undo',
        textColor: WildPathColors.fern,
        onPressed: () {
          if (!mounted) return;
          setState(() {
            _items.add(item);
            _updateDerived();
          });
          _save();
        },
      ),
    ));
  }

  /// Opens the add-item sheet. Controllers are disposed in a finally block
  /// so they are cleaned up regardless of how the sheet is dismissed.
  Future<void> _showAddItem() async {
    final labelCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    try {
      final result = await showModalBottomSheet<GearItem>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AddItemSheet(
          categories: _grouped.isNotEmpty
              ? _grouped.keys.toList()
              : GearLists.byTripType(widget.trip.tripType).keys.toList(),
          labelCtrl: labelCtrl,
          qtyCtrl: qtyCtrl,
        ),
      );
      if (!mounted || result == null) return;
      setState(() {
        _items.add(result);
        _updateDerived();
      });
      _save();
    } finally {
      labelCtrl.dispose();
      qtyCtrl.dispose();
    }
  }

  int get _remainingCount =>
      (_items.length - _checkedCount).clamp(0, _items.length);

  int get _completedGroupCount => _grouped.values
      .where((items) => items.isNotEmpty && items.every((item) => item.checked))
      .length;

  bool get _allGroupsExpanded =>
      _grouped.isNotEmpty &&
      _grouped.keys.every((key) => _expandedGroups[key] ?? false);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle('Gear & Packing',
              subtitle:
                  'Track what is packed without turning the page into a wall of checklist rows.'),
          const SizedBox(height: 8),
          Text('Tap an item to check it off. Swipe left to delete.',
              style: WildPathTypography.body(
                  fontSize: 12, color: WildPathColors.smoke)),
          const SizedBox(height: 16),
          _GearHeroCard(
            checkedCount: _checkedCount,
            totalCount: _items.length,
            remainingCount: _remainingCount,
            categoryCount: _grouped.length,
            completedGroupCount: _completedGroupCount,
            progress: _progress,
            tripTypeLabel:
                '${widget.trip.tripTypeEmoji} ${widget.trip.tripType}',
            onAddItem: _showAddItem,
            onUncheckAll: _checkedCount == 0
                ? null
                : () {
                    setState(() {
                      for (int i = 0; i < _items.length; i++) {
                        _items[i] = _items[i].copyWith(checked: false);
                      }
                      _updateDerived();
                    });
                    _save();
                  },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Packing Sections',
                    style: WildPathTypography.display(
                        fontSize: 18, color: WildPathColors.forest)),
              ),
              GestureDetector(
                onTap: _grouped.isEmpty
                    ? null
                    : () => _setAllGroups(!_allGroupsExpanded),
                child: Text(
                  _allGroupsExpanded ? 'Collapse all' : 'Expand all',
                  style: WildPathTypography.body(
                      fontSize: 11,
                      letterSpacing: 0.7,
                      color: WildPathColors.forest,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._grouped.entries.map((entry) {
            final items = entry.value;
            final checkedCount = items.where((item) => item.checked).length;
            final isExpanded = _expandedGroups[entry.key] ?? false;
            return _GearGroupCard(
              label: entry.key,
              itemCount: items.length,
              checkedCount: checkedCount,
              isExpanded: isExpanded,
              onTap: () => _toggleGroup(entry.key),
              child: Column(
                children: items
                    .map((item) => _GearTile(
                          item: item,
                          onToggle: () => _toggle(item.id),
                          onDelete: () => _deleteWithUndo(item),
                        ))
                    .toList(),
              ),
            );
          }),
          const SizedBox(height: 8),
          PrimaryButton('Next: Plan Your Meals →',
              fullWidth: true, onPressed: widget.onNextTab),
        ],
      ),
    );
  }
}

class _GearHeroCard extends StatelessWidget {
  final int checkedCount;
  final int totalCount;
  final int remainingCount;
  final int categoryCount;
  final int completedGroupCount;
  final double progress;
  final String tripTypeLabel;
  final VoidCallback onAddItem;
  final VoidCallback? onUncheckAll;

  const _GearHeroCard({
    required this.checkedCount,
    required this.totalCount,
    required this.remainingCount,
    required this.categoryCount,
    required this.completedGroupCount,
    required this.progress,
    required this.tripTypeLabel,
    required this.onAddItem,
    required this.onUncheckAll,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: WildPathColors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tripTypeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WildPathTypography.body(
                              fontSize: 10.5,
                              color: WildPathColors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PACKED',
                                    style: WildPathTypography.body(
                                        fontSize: 9.5,
                                        letterSpacing: 1.1,
                                        color: WildPathColors.mist)),
                                const SizedBox(height: 4),
                                Text('$checkedCount / $totalCount',
                                    style: WildPathTypography.display(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: WildPathColors.white)),
                                const SizedBox(height: 6),
                                Text(
                                    remainingCount == 0
                                        ? 'Everything on this list is packed.'
                                        : '$remainingCount item ${remainingCount == 1 ? "is" : "items are"} still open.',
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
                                _heroStat('$categoryCount', 'GROUPS',
                                    WildPathColors.fern),
                                const SizedBox(height: 10),
                                _heroStat('$completedGroupCount', 'DONE',
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
                              child: _heroStat('$categoryCount', 'GROUPS',
                                  WildPathColors.fern,
                                  alignEnd: false),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _heroStat('$completedGroupCount', 'DONE',
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
                            '${(progress.clamp(0, 1) * 100).toStringAsFixed(0)}% packed',
                            style: WildPathTypography.body(
                                fontSize: 11, color: WildPathColors.smoke)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('$checkedCount of $totalCount checked',
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
                          const AlwaysStoppedAnimation(WildPathColors.moss),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton('＋  Add Item',
                            fullWidth: true, onPressed: onAddItem),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlineButton2('Uncheck All',
                            fullWidth: true, onPressed: onUncheckAll),
                      ),
                    ],
                  ),
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

class _GearGroupCard extends StatelessWidget {
  final String label;
  final int itemCount;
  final int checkedCount;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget child;

  const _GearGroupCard({
    required this.label,
    required this.itemCount,
    required this.checkedCount,
    required this.isExpanded,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = itemCount > 0 && checkedCount == itemCount;
    return WildCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: WildPathTypography.body(
                                  fontSize: 13,
                                  color: WildPathColors.forest,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('$checkedCount of $itemCount packed',
                              style: WildPathTypography.body(
                                  fontSize: 11, color: WildPathColors.smoke)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: allDone
                            ? WildPathColors.moss.withValues(alpha: 0.14)
                            : WildPathColors.cream,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        allDone ? 'Done' : '${itemCount - checkedCount} left',
                        style: WildPathTypography.body(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: allDone
                                ? WildPathColors.moss
                                : WildPathColors.forest),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.expand_more,
                          size: 20, color: WildPathColors.smoke),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOut,
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

// ── Add Item Sheet ───────────────────────────────────────────────────────────
class _AddItemSheet extends StatefulWidget {
  final List<String> categories;
  final TextEditingController labelCtrl;
  final TextEditingController qtyCtrl;

  const _AddItemSheet({
    required this.categories,
    required this.labelCtrl,
    required this.qtyCtrl,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  late String _cat;

  @override
  void initState() {
    super.initState();
    _cat = widget.categories.first;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  Text('Add Custom Item',
                      style: WildPathTypography.display(fontSize: 20)),
                  const SizedBox(height: 16),
                  _sheetField(widget.labelCtrl, 'Item name (e.g. Fishing rod)'),
                  const SizedBox(height: 10),
                  _sheetField(widget.qtyCtrl, 'Quantity (optional)'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                        color: WildPathColors.cream,
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _cat,
                        isExpanded: true,
                        style: WildPathTypography.body(
                            fontSize: 13, color: WildPathColors.pine),
                        items: widget.categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _cat = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton('Add Item', fullWidth: true, onPressed: () {
                    if (widget.labelCtrl.text.trim().isEmpty) return;
                    Navigator.pop(
                        context,
                        GearItem(
                          id: _uuid.v4(),
                          label: widget.labelCtrl.text.trim(),
                          qty: widget.qtyCtrl.text.trim(),
                          category: _cat,
                          isCustom: true,
                        ));
                  }),
                ]),
          ),
        ),
      ),
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
}

// ── Gear Tile ────────────────────────────────────────────────────────────────
class _GearTile extends StatelessWidget {
  final GearItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _GearTile(
      {required this.item, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) => Dismissible(
        key: Key(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: WildPathColors.red,
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text('DELETE',
                style: WildPathTypography.body(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        onDismissed: (_) => onDelete(),
        child: GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: AnimatedOpacity(
            opacity: item.checked ? 0.42 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: item.checked
                    ? WildPathColors.cream.withValues(alpha: 0.8)
                    : WildPathColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: item.checked
                        ? WildPathColors.mist
                        : WildPathColors.mist.withValues(alpha: 0.9)),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.checked
                        ? WildPathColors.moss
                        : WildPathColors.cream,
                    border: Border.all(
                        color: item.checked
                            ? WildPathColors.moss
                            : WildPathColors.mist,
                        width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: item.checked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: WildPathTypography.body(
                            fontSize: 14,
                            color: item.checked
                                ? WildPathColors.smoke
                                : WildPathColors.pine,
                            decoration: item.checked
                                ? TextDecoration.lineThrough
                                : null))),
                if (item.qty.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(item.qty,
                      style: WildPathTypography.body(
                          fontSize: 10, color: WildPathColors.stone)),
                ],
              ]),
            ),
          ),
        ),
      );
}

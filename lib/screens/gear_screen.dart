import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/gear_item.dart';
import '../models/trip_model.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';

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
  String _lastType = '';

  @override
  void initState() {
    super.initState();
    final saved = widget.storage.loadGear(widget.trip.id);
    _items = saved.isEmpty ? _defaults(widget.trip.tripType) : saved;
    _lastType = widget.trip.tripType;
  }

  @override
  void didUpdateWidget(GearScreen old) {
    super.didUpdateWidget(old);
    if (old.trip.id != widget.trip.id) {
      final saved = widget.storage.loadGear(widget.trip.id);
      setState(() {
        _items = saved.isEmpty ? _defaults(widget.trip.tripType) : saved;
        _lastType = widget.trip.tripType;
      });
      return;
    }
    if (old.trip.tripType != widget.trip.tripType &&
        _lastType != widget.trip.tripType) {
      final custom = _items.where((i) => i.isCustom).toList();
      setState(() {
        _items = [..._defaults(widget.trip.tripType), ...custom];
        _lastType = widget.trip.tripType;
      });
      _save();
    }
  }

  List<GearItem> _defaults(String type) {
    final uuid = const Uuid();
    final result = <GearItem>[];
    GearLists.byTripType(type).forEach((cat, items) {
      for (final item in items) {
        result.add(GearItem(
          id: uuid.v4(),
          label: item['label']!,
          qty: item['qty'] ?? '',
          category: cat,
          isCustom: false,
        ));
      }
    });
    return result;
  }

  void _save() => widget.storage.saveGear(widget.trip.id, _items);

  void _toggle(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    setState(() =>
        _items[idx] = _items[idx].copyWith(checked: !_items[idx].checked));
    _save();
  }

  void _delete(String id) {
    setState(() => _items.removeWhere((i) => i.id == id));
    _save();
  }

  void _showAddItem() {
    final labelCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final cats = _items.map((i) => i.category).toSet().toList();
    if (cats.isEmpty)
      cats.addAll(GearLists.byTripType(widget.trip.tripType).keys);
    String cat = cats.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
          builder: (ctx, setS) => AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(ctx).bottom),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20))),
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
                                        borderRadius:
                                            BorderRadius.circular(2)))),
                            const SizedBox(height: 20),
                            Text('Add Custom Item',
                                style:
                                    WildPathTypography.display(fontSize: 20)),
                            const SizedBox(height: 16),
                            _sheetField(
                                labelCtrl, 'Item name (e.g. Fishing rod)'),
                            const SizedBox(height: 10),
                            _sheetField(qtyCtrl, 'Quantity (optional)'),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                  color: WildPathColors.cream,
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: cat,
                                  isExpanded: true,
                                  style: WildPathTypography.body(
                                      fontSize: 13, color: WildPathColors.pine),
                                  items: cats
                                      .map((c) => DropdownMenuItem(
                                          value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setS(() => cat = v);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            PrimaryButton('Add Item', fullWidth: true,
                                onPressed: () {
                              if (labelCtrl.text.trim().isEmpty) return;
                              setState(() => _items.add(GearItem(
                                    id: const Uuid().v4(),
                                    label: labelCtrl.text.trim(),
                                    qty: qtyCtrl.text.trim(),
                                    category: cat,
                                    isCustom: true,
                                  )));
                              _save();
                              Navigator.pop(ctx);
                            }),
                          ]),
                    ),
                  ),
                ),
              )),
    );
  }

  void _reset() => showDialog(
      context: context,
      builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Reset Gear List?',
                style: WildPathTypography.display(fontSize: 20)),
            content: Text(
                'Restores the default list for ${widget.trip.tripType}. Custom items will be removed.',
                style: WildPathTypography.body(
                    fontSize: 13, color: WildPathColors.smoke)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: WildPathTypography.body(
                          color: WildPathColors.smoke))),
              ElevatedButton(
                  onPressed: () {
                    setState(() => _items = _defaults(widget.trip.tripType));
                    _save();
                    Navigator.pop(context);
                  },
                  child: const Text('Reset')),
            ],
          ));

  int get _checked => _items.where((i) => i.checked).length;
  double get _progress => _items.isEmpty ? 0 : _checked / _items.length;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<GearItem>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Column(children: [
      // Type badge bar
      Container(
        color: WildPathColors.forest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text('${widget.trip.tripTypeEmoji} ${widget.trip.tripType}',
                style:
                    WildPathTypography.body(fontSize: 11, color: Colors.white)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                for (int i = 0; i < _items.length; i++)
                  _items[i] = _items[i].copyWith(checked: false);
              });
              _save();
            },
            style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.7)),
            child: Text('Uncheck All',
                style: WildPathTypography.body(fontSize: 11)),
          ),
        ]),
      ),

      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const PageTitle('Gear & Packing'),
              TextButton(
                onPressed: _showAddItem,
                style: TextButton.styleFrom(
                    foregroundColor: WildPathColors.forest),
                child: Text('+ Add',
                    style: WildPathTypography.body(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
            Text('Tap to check off   Swipe left to delete',
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.smoke)),
            const SizedBox(height: 16),

            WildProgressBar(
              progress: _progress,
              title: 'Packing Progress',
              countLabel: '$_checked / ${_items.length}',
            ),
            const SizedBox(height: 20),

            ...grouped.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GroupHeader(entry.key),
                    ...entry.value.map((item) => _GearTile(
                          item: item,
                          onToggle: () => _toggle(item.id),
                          onDelete: () => _delete(item.id),
                        )),
                  ],
                )),

            const SizedBox(height: 8),
            GhostButton('Reset to Defaults',
                fullWidth: true, onPressed: _reset),
            const SizedBox(height: 12),

            // Guided flow button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: widget.onNextTab,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Next: Plan Your Meals →',
                    style: WildPathTypography.body(
                        fontSize: 13,
                        letterSpacing: 1.04,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    ]);
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
          child: Text('DELETE',
              style: WildPathTypography.body(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
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
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: WildPathColors.pine.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ],
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

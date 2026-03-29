import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../models/permit_model.dart';
import '../models/trip_model.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';

// ── Status helpers ────────────────────────────────────────────────────────────

enum _PermitStatus { active, pending, expired }

_PermitStatus _statusFor(PermitModel permit) {
  // Heuristic: if no permit number set → pending; otherwise active.
  // Expired would be detected if the model gains an expiry date field.
  if (permit.permitNum.isEmpty && permit.entryTime.isEmpty) {
    return _PermitStatus.pending;
  }
  return _PermitStatus.active;
}

Color _statusColor(_PermitStatus s) => switch (s) {
      _PermitStatus.active => WildPathColors.fern,
      _PermitStatus.pending => WildPathColors.amber,
      _PermitStatus.expired => WildPathColors.red,
    };

Color _statusBgColor(_PermitStatus s) => switch (s) {
      _PermitStatus.active =>
        WildPathColors.fern.withValues(alpha: 0.15),
      _PermitStatus.pending =>
        WildPathColors.amber.withValues(alpha: 0.12),
      _PermitStatus.expired =>
        WildPathColors.red.withValues(alpha: 0.12),
    };

String _statusLabel(_PermitStatus s) => switch (s) {
      _PermitStatus.active => 'Active',
      _PermitStatus.pending => 'Pending',
      _PermitStatus.expired => 'Expired',
    };

// ── Icon map per permit type ──────────────────────────────────────────────────

IconData _typeIcon(String type) => switch (type) {
      'Overnight' => Icons.bedtime_outlined,
      'Day Use' => Icons.wb_sunny_outlined,
      'Fire Permit' => Icons.local_fire_department_outlined,
      'Parking' => Icons.local_parking_outlined,
      _ => Icons.badge_outlined,
    };

// ─────────────────────────────────────────────────────────────────────────────

class PermitsScreen extends StatefulWidget {
  final StorageService storage;
  final TripModel trip;
  final VoidCallback? onSaveTrip;

  const PermitsScreen(
      {required this.storage, required this.trip, this.onSaveTrip, super.key});

  @override
  State<PermitsScreen> createState() => _PermitsScreenState();
}

class _PermitsScreenState extends State<PermitsScreen> {
  List<PermitModel> _permits = [];

  @override
  void initState() {
    super.initState();
    _permits = widget.storage.loadPermits(widget.trip.id);
  }

  @override
  void didUpdateWidget(PermitsScreen old) {
    super.didUpdateWidget(old);
    if (old.trip.id != widget.trip.id) {
      setState(() => _permits = widget.storage.loadPermits(widget.trip.id));
    }
  }

  void _save() => widget.storage.savePermits(widget.trip.id, _permits);

  void _delete(String id) {
    final permit = _permits.firstWhere((p) => p.id == id);
    if (permit.documentPath != null) {
      try {
        File(permit.documentPath!).deleteSync();
      } catch (_) {}
    }
    setState(() => _permits.removeWhere((p) => p.id == id));
    _save();
  }

  void _removeAttachment(String id) {
    final idx = _permits.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final permit = _permits[idx];
    if (permit.documentPath != null) {
      try {
        File(permit.documentPath!).deleteSync();
      } catch (_) {}
    }
    setState(() => _permits[idx] =
        permit.copyWith(documentPath: null, documentMimeType: null));
    _save();
  }

  Future<void> _uploadAndCreate() async {
    final choice = await _showAttachSheet('Upload Permit',
        'Choose the permit document to attach');
    if (choice == null || !mounted) return;

    final result = await _resolveFile(choice);
    if (result == null || !mounted) return;
    final (filePath, mimeType) = result;

    final destPath = await _copyToPermitsDir(filePath);

    final newPermit = PermitModel(
      id: const Uuid().v4(),
      documentPath: destPath,
      documentMimeType: mimeType,
    );
    setState(() => _permits.add(newPermit));
    _save();

    if (!mounted) return;
    _showAddOrEdit(existing: newPermit);
  }

  Future<void> _pickDocument(String permitId) async {
    final choice =
        await _showAttachSheet('Attach Document', null);
    if (choice == null || !mounted) return;

    final result = await _resolveFile(choice);
    if (result == null || !mounted) return;
    final (filePath, mimeType) = result;

    final destPath = await _copyToPermitsDir(filePath);

    final idx = _permits.indexWhere((pm) => pm.id == permitId);
    if (idx < 0 || !mounted) return;
    if (_permits[idx].documentPath != null) {
      try {
        File(_permits[idx].documentPath!).deleteSync();
      } catch (_) {}
    }
    setState(() => _permits[idx] = _permits[idx]
        .copyWith(documentPath: destPath, documentMimeType: mimeType));
    _save();
  }

  Future<String> _copyToPermitsDir(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final permitsDir =
        Directory('${docsDir.path}/permits/${widget.trip.id}');
    permitsDir.createSync(recursive: true);
    final ext = p.extension(filePath);
    final destPath = '${permitsDir.path}/${const Uuid().v4()}$ext';
    File(filePath).copySync(destPath);
    return destPath;
  }

  Future<(String, String)?> _resolveFile(String choice) async {
    String? filePath;
    String? mimeType;

    if (choice == 'camera' || choice == 'gallery') {
      final source =
          choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final xfile =
          await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (xfile == null) return null;
      filePath = xfile.path;
      mimeType = xfile.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
    } else {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.single.path == null) return null;
      filePath = result.files.single.path!;
      mimeType = 'application/pdf';
    }
    return (filePath, mimeType);
  }

  Future<String?> _showAttachSheet(String title, String? subtitle) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DragHandle(),
              const SizedBox(height: 16),
              Text(title,
                  style: WildPathTypography.display(fontSize: 18,
                      color: WildPathColors.pine)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    style: WildPathTypography.body(
                        fontSize: 12, color: WildPathColors.smoke)),
              ],
              const SizedBox(height: 12),
              _attachOption(Icons.camera_alt_outlined, 'Take Photo', 'camera'),
              _attachOption(
                  Icons.photo_library_outlined, 'Choose from Gallery', 'gallery'),
              _attachOption(
                  Icons.picture_as_pdf_outlined, 'Choose PDF File', 'pdf'),
            ]),
          ),
        ),
      );

  Widget _attachOption(IconData icon, String label, String value) => ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: WildPathColors.forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: WildPathColors.forest, size: 20),
        ),
        title: Text(label,
            style: WildPathTypography.body(
                fontSize: 14, color: WildPathColors.pine)),
        onTap: () => Navigator.pop(context, value),
      );

  void _showAddOrEdit({PermitModel? existing}) {
    final isEdit = existing != null;
    final permitNumCtrl =
        TextEditingController(text: existing?.permitNum ?? '');
    final entryTimeCtrl =
        TextEditingController(text: existing?.entryTime ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String selectedType = existing?.permitType ?? 'Overnight';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DragHandle(),
                      const SizedBox(height: 20),
                      Row(children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: WildPathColors.forest
                                  .withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(_typeIcon(selectedType),
                              color: WildPathColors.forest, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(isEdit ? 'Edit Permit' : 'Add Permit',
                            style: WildPathTypography.display(
                                fontSize: 20, color: WildPathColors.pine)),
                      ]),
                      const SizedBox(height: 20),

                      // Permit type chips
                      Text('PERMIT TYPE',
                          style: WildPathTypography.body(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: WildPathColors.smoke)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PermitModel.permitTypes.map((type) {
                          final active = type == selectedType;
                          return GestureDetector(
                            onTap: () => setS(() => selectedType = type),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: active
                                    ? WildPathColors.forest
                                    : WildPathColors.cream,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: active
                                      ? WildPathColors.forest
                                      : WildPathColors.mist,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_typeIcon(type),
                                      size: 13,
                                      color: active
                                          ? Colors.white
                                          : WildPathColors.smoke),
                                  const SizedBox(width: 5),
                                  Text(type,
                                      style: WildPathTypography.body(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: active
                                              ? Colors.white
                                              : WildPathColors.smoke)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      _sheetField(permitNumCtrl, 'PERMIT #',
                          'e.g. USFS-2024-001',
                          icon: Icons.tag_outlined),
                      const SizedBox(height: 10),
                      _sheetField(entryTimeCtrl, 'ENTRY TIME',
                          'e.g. 10:00 AM',
                          icon: Icons.schedule_outlined),
                      const SizedBox(height: 10),
                      _sheetField(notesCtrl, 'NOTES',
                          'Parking lot, trailhead details...',
                          maxLines: 3,
                          icon: Icons.notes_outlined),
                      const SizedBox(height: 24),

                      Row(children: [
                        if (isEdit) ...[
                          Expanded(
                            child: GhostButton('Delete',
                                color: WildPathColors.red,
                                onPressed: () {
                                  _delete(existing.id);
                                  Navigator.pop(ctx);
                                }),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: PrimaryButton(
                              isEdit ? 'Save Changes' : 'Add Permit',
                              onPressed: () {
                            final permit = PermitModel(
                              id: existing?.id ?? const Uuid().v4(),
                              permitNum: permitNumCtrl.text.trim(),
                              entryTime: entryTimeCtrl.text.trim(),
                              permitType: selectedType,
                              notes: notesCtrl.text.trim(),
                              documentPath: existing?.documentPath,
                              documentMimeType: existing?.documentMimeType,
                            );
                            setState(() {
                              if (isEdit) {
                                final idx = _permits
                                    .indexWhere((p) => p.id == permit.id);
                                if (idx >= 0) _permits[idx] = permit;
                              } else {
                                _permits.add(permit);
                              }
                            });
                            _save();
                            Navigator.pop(ctx);
                          }),
                        ),
                      ]),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    IconData? icon,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: WildPathTypography.body(
                fontSize: 10,
                letterSpacing: 1.2,
                color: WildPathColors.smoke)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: WildPathTypography.body(
              fontSize: 14, color: WildPathColors.pine),
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
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]);

  void _viewDocument(PermitModel permit) {
    if (permit.documentPath == null) return;
    if (permit.documentMimeType?.startsWith('image/') == true) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  _ImageViewerScreen(filePath: permit.documentPath!)));
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  _PdfViewerScreen(filePath: permit.documentPath!)));
    }
  }

  // ── Summary card ─────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final total = _permits.length;
    final activeCount = _permits
        .where((p) => _statusFor(p) == _PermitStatus.active)
        .length;
    final attachmentCount =
        _permits.where((p) => p.documentPath != null).length;
    final pendingCount = (total - activeCount).clamp(0, total);
    final progress = total == 0 ? 0.0 : activeCount / total;

    return WildCard(
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
                              Text('PERMITS SAVED',
                                  style: WildPathTypography.body(
                                      fontSize: 9.5,
                                      letterSpacing: 1.1,
                                      color: WildPathColors.mist)),
                              const SizedBox(height: 4),
                              Text('$total',
                                  style: WildPathTypography.display(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: WildPathColors.white)),
                              const SizedBox(height: 6),
                              Text(
                                  total == 0
                                      ? 'Add permit details or attach documents before you leave.'
                                      : pendingCount == 0
                                          ? 'All saved permits look ready for this trip.'
                                          : '$pendingCount permit ${pendingCount == 1 ? "still needs" : "still need"} details or review.',
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
                              _heroStat('$activeCount', 'READY',
                                  WildPathColors.fern),
                              const SizedBox(height: 10),
                              _heroStat(
                                  '$attachmentCount', 'DOCS', WildPathColors.mist),
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
                                '$activeCount', 'READY', WildPathColors.fern,
                                alignEnd: false),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _heroStat(
                                '$attachmentCount', 'DOCS', WildPathColors.mist,
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
                          total == 0
                              ? 'No permits added yet'
                              : '${(progress.clamp(0, 1) * 100).toStringAsFixed(0)}% ready',
                          style: WildPathTypography.body(
                              fontSize: 11, color: WildPathColors.smoke)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          total == 0
                              ? 'Add your first permit'
                              : '$activeCount of $total ready',
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
                        const AlwaysStoppedAnimation(WildPathColors.blue),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlineButton2('Add Manually',
                          fullWidth: true, onPressed: () => _showAddOrEdit()),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton('Upload Doc',
                          fullWidth: true, onPressed: _uploadAndCreate),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: _permits.isEmpty
            ? SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PageTitle('Permits',
                          subtitle: 'Store permit numbers and documents'),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),
                      const SizedBox(height: 12),
                      const TipCard(
                        emoji: '💡',
                        content:
                            'Tip: Upload a photo or PDF of each permit so you always have it handy on the trail.',
                      ),
                    ]),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  const PageTitle('Permits',
                      subtitle: 'Store permit numbers and documents'),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  const SizedBox(height: 4),
                  ..._permits.map((permit) => _PermitCard(
                        permit: permit,
                        onEdit: () => _showAddOrEdit(existing: permit),
                        onDelete: () => _delete(permit.id),
                        onAttach: () => _pickDocument(permit.id),
                        onRemoveAttachment: () =>
                            _removeAttachment(permit.id),
                        onViewDocument: () => _viewDocument(permit),
                      )),
                ],
              ),
      ),

      // ── Bottom action bar ──────────────────────────────────────────────
      Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
            color: Colors.white,
            border:
                Border(top: BorderSide(color: WildPathColors.mist))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton('Save Trip',
              fullWidth: true, onPressed: widget.onSaveTrip),
        ]),
      ),
    ]);
  }

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

// ── Drag handle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: WildPathColors.mist,
                borderRadius: BorderRadius.circular(2))),
      );
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: WildPathTypography.body(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      );
}

// ── Permit Card ───────────────────────────────────────────────────────────────

class _PermitCard extends StatelessWidget {
  final PermitModel permit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAttach;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onViewDocument;

  const _PermitCard({
    required this.permit,
    required this.onEdit,
    required this.onDelete,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onViewDocument,
  });

  @override
  Widget build(BuildContext context) {
    final hasDoc = permit.documentPath != null;
    final isImage = permit.documentMimeType?.startsWith('image/') == true;
    final status = _statusFor(permit);
    final statusColor = _statusColor(status);
    final statusBg = _statusBgColor(status);

    return WildCard(
      onTap: onEdit,
      padding: EdgeInsets.zero,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
              decoration: BoxDecoration(
                color: WildPathColors.forest.withValues(alpha: 0.04),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                // Type icon badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: WildPathColors.forest.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(_typeIcon(permit.permitType),
                      color: WildPathColors.forest, size: 20),
                ),
                const SizedBox(width: 10),

                // Type label + status chip
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(permit.permitType,
                        style: WildPathTypography.display(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: WildPathColors.pine)),
                    const SizedBox(height: 3),
                    Row(children: [
                      _StatusChip(
                        label: _statusLabel(status),
                        color: statusColor,
                        bg: statusBg,
                        icon: status == _PermitStatus.active
                            ? Icons.check_circle_outline_rounded
                            : status == _PermitStatus.expired
                                ? Icons.cancel_outlined
                                : Icons.hourglass_top_rounded,
                      ),
                      if (hasDoc) ...[
                        const SizedBox(width: 6),
                        _StatusChip(
                          label: isImage ? 'Photo' : 'PDF',
                          color: WildPathColors.blue,
                          bg:
                              WildPathColors.blue.withValues(alpha: 0.10),
                          icon: isImage
                              ? Icons.image_outlined
                              : Icons.picture_as_pdf_outlined,
                        ),
                      ],
                    ]),
                  ]),
                ),

                // Action buttons
                Tooltip(
                  message: 'Edit permit',
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: WildPathColors.smoke),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 44, minHeight: 44),
                  ),
                ),
                Tooltip(
                  message: 'Delete permit',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: WildPathColors.red),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 44, minHeight: 44),
                  ),
                ),
              ]),
            ),

            // ── Permit details ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (permit.permitNum.isNotEmpty)
                  _DetailRow(
                      icon: Icons.tag_outlined,
                      label: 'Permit #',
                      value: permit.permitNum),
                if (permit.entryTime.isNotEmpty) ...[
                  if (permit.permitNum.isNotEmpty)
                    const SizedBox(height: 6),
                  _DetailRow(
                      icon: Icons.schedule_outlined,
                      label: 'Entry',
                      value: permit.entryTime),
                ],
                if (permit.notes.isNotEmpty) ...[
                  if (permit.permitNum.isNotEmpty ||
                      permit.entryTime.isNotEmpty)
                    const SizedBox(height: 6),
                  _DetailRow(
                      icon: Icons.notes_outlined,
                      label: 'Notes',
                      value: permit.notes),
                ],
                if (permit.permitNum.isEmpty &&
                    permit.entryTime.isEmpty &&
                    permit.notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Tap to fill in permit details',
                      style: WildPathTypography.body(
                          fontSize: 12,
                          color: WildPathColors.stone,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ]),
            ),

            // ── Document attachment row ───────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: hasDoc
                    ? WildPathColors.blue.withValues(alpha: 0.05)
                    : WildPathColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasDoc
                      ? WildPathColors.blue.withValues(alpha: 0.18)
                      : WildPathColors.mist,
                  width: 1.5,
                ),
              ),
              child: hasDoc
                  ? Row(children: [
                      // Thumbnail / PDF icon
                      GestureDetector(
                        onTap: onViewDocument,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isImage
                              ? Image.file(
                                  File(permit.documentPath!),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _PdfIconBox(),
                                )
                              : _PdfIconBox(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Text(
                                isImage
                                    ? 'Photo attached'
                                    : p.basename(permit.documentPath!),
                                style: WildPathTypography.body(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: WildPathColors.pine),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('Tap to view',
                                style: WildPathTypography.body(
                                    fontSize: 11,
                                    color: WildPathColors.smoke)),
                          ])),
                      // Replace attachment
                      Tooltip(
                        message: 'Replace attachment',
                        child: IconButton(
                          icon: const Icon(Icons.swap_horiz_rounded,
                              size: 18, color: WildPathColors.smoke),
                          onPressed: onAttach,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 44, minHeight: 44),
                        ),
                      ),
                      // Remove attachment
                      Tooltip(
                        message: 'Remove attachment',
                        child: IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: WildPathColors.red),
                          onPressed: onRemoveAttachment,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 44, minHeight: 44),
                        ),
                      ),
                    ])
                  : GestureDetector(
                      onTap: onAttach,
                      behavior: HitTestBehavior.opaque,
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: WildPathColors.forest
                                  .withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.attach_file_rounded,
                              size: 18, color: WildPathColors.forest),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Text('Attach permit document',
                                style: WildPathTypography.body(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: WildPathColors.forest)),
                            Text('Photo or PDF',
                                style: WildPathTypography.body(
                                    fontSize: 11,
                                    color: WildPathColors.smoke)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: WildPathColors.stone),
                      ]),
                    ),
            ),
          ]),
    );
  }
}

// ── PDF icon box ──────────────────────────────────────────────────────────────

class _PdfIconBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: WildPathColors.cream,
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.picture_as_pdf_rounded,
            color: WildPathColors.ember, size: 28),
      );
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: WildPathColors.smoke),
          const SizedBox(width: 6),
          SizedBox(
              width: 58,
              child: Text(label,
                  style: WildPathTypography.body(
                      fontSize: 11, color: WildPathColors.smoke))),
          Expanded(
              child: Text(value,
                  style: WildPathTypography.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: WildPathColors.pine))),
        ],
      );
}

// ── Image Viewer ──────────────────────────────────────────────────────────────

class _ImageViewerScreen extends StatelessWidget {
  final String filePath;
  const _ImageViewerScreen({required this.filePath});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text('Photo',
              style: WildPathTypography.body(
                  fontSize: 13, color: Colors.white)),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(
              File(filePath),
              errorBuilder: (_, __, ___) => Center(
                  child: Text('Could not load image',
                      style: WildPathTypography.body(
                          fontSize: 13, color: Colors.white))),
            ),
          ),
        ),
      );
}

// ── PDF Viewer ────────────────────────────────────────────────────────────────

class _PdfViewerScreen extends StatefulWidget {
  final String filePath;
  const _PdfViewerScreen({required this.filePath});

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  int _pages = 0;
  int _current = 1;
  bool _ready = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
              _ready && _pages > 0
                  ? 'Page $_current of $_pages'
                  : 'Permit',
              style: WildPathTypography.body(
                  fontSize: 13, color: Colors.white)),
          backgroundColor: WildPathColors.forest,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: PDFView(
          filePath: widget.filePath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          onRender: (pages) => setState(() {
            _pages = pages ?? 0;
            _ready = true;
          }),
          onPageChanged: (page, _) =>
              setState(() => _current = (page ?? 0) + 1),
          onError: (e) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e'))),
        ),
      );
}

const _noChange = Object();

class PermitModel {
  final String id;
  final String permitNum;
  final String entryTime;
  final String permitType;
  final String notes;
  final String? documentPath;
  final String? documentMimeType;

  static const permitTypes = ['Overnight', 'Day Use', 'Fire Permit', 'Parking'];

  const PermitModel({
    required this.id,
    this.permitNum = '',
    this.entryTime = '',
    this.permitType = 'Overnight',
    this.notes = '',
    this.documentPath,
    this.documentMimeType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'permitNum': permitNum,
        'entryTime': entryTime,
        'permitType': permitType,
        'notes': notes,
        'documentPath': documentPath,
        'documentMimeType': documentMimeType,
      };

  factory PermitModel.fromJson(Map<String, dynamic> j) => PermitModel(
        id: j['id'] ?? '',
        permitNum: j['permitNum'] ?? '',
        entryTime: j['entryTime'] ?? '',
        permitType: j['permitType'] ?? 'Overnight',
        notes: j['notes'] ?? '',
        documentPath: j['documentPath'] as String?,
        documentMimeType: j['documentMimeType'] as String?,
      );

  PermitModel copyWith({
    String? id,
    String? permitNum,
    String? entryTime,
    String? permitType,
    String? notes,
    Object? documentPath = _noChange,
    Object? documentMimeType = _noChange,
  }) =>
      PermitModel(
        id: id ?? this.id,
        permitNum: permitNum ?? this.permitNum,
        entryTime: entryTime ?? this.entryTime,
        permitType: permitType ?? this.permitType,
        notes: notes ?? this.notes,
        documentPath: identical(documentPath, _noChange)
            ? this.documentPath
            : documentPath as String?,
        documentMimeType: identical(documentMimeType, _noChange)
            ? this.documentMimeType
            : documentMimeType as String?,
      );
}

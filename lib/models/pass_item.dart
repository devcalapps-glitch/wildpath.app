class PassSideAttachment {
  final String filePath;
  final String mimeType;

  const PassSideAttachment({
    required this.filePath,
    required this.mimeType,
  });

  factory PassSideAttachment.fromJson(Map<String, dynamic> j) =>
      PassSideAttachment(
        filePath: j['filePath'] as String,
        mimeType: j['mimeType'] as String,
      );

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'mimeType': mimeType,
      };
}

class PassItem {
  final String id;
  final String label;
  final PassSideAttachment front;
  final PassSideAttachment? back;

  const PassItem({
    required this.id,
    required this.label,
    required this.front,
    this.back,
  });

  factory PassItem.fromJson(Map<String, dynamic> j) {
    final frontJson = j['front'];
    final backJson = j['back'];

    return PassItem(
      id: j['id'] as String,
      label: j['label'] as String,
      front: frontJson is Map<String, dynamic>
          ? PassSideAttachment.fromJson(frontJson)
          : PassSideAttachment(
              filePath: j['filePath'] as String,
              mimeType: j['mimeType'] as String,
            ),
      back: backJson is Map<String, dynamic>
          ? PassSideAttachment.fromJson(backJson)
          : null,
    );
  }

  String get filePath => front.filePath;
  String get mimeType => front.mimeType;
  bool get hasBack => back != null;
  int get sideCount => hasBack ? 2 : 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'front': front.toJson(),
        'back': back?.toJson(),
      };
}

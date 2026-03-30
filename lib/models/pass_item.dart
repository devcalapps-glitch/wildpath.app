class PassItem {
  final String id;
  final String label;
  final String filePath;
  final String mimeType;

  const PassItem({
    required this.id,
    required this.label,
    required this.filePath,
    required this.mimeType,
  });

  factory PassItem.fromJson(Map<String, dynamic> j) => PassItem(
        id: j['id'] as String,
        label: j['label'] as String,
        filePath: j['filePath'] as String,
        mimeType: j['mimeType'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'filePath': filePath,
        'mimeType': mimeType,
      };
}

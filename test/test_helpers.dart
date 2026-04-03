import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void setUpFlutterSecureStorageMock() {
  final storage = <String, String>{};

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    final arguments = Map<String, dynamic>.from(
      (call.arguments as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final key = arguments['key'] as String?;

    switch (call.method) {
      case 'read':
        return key == null ? null : storage[key];
      case 'write':
        if (key != null) {
          storage[key] = (arguments['value'] as String?) ?? '';
        }
        return null;
      case 'delete':
        if (key != null) storage.remove(key);
        return null;
      case 'deleteAll':
        storage.clear();
        return null;
      case 'containsKey':
        return key != null && storage.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(storage);
      default:
        return null;
    }
  });
}

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'offline_storage_browser.dart'
    if (dart.library.io) 'offline_storage_native.dart'
    as platform;

abstract interface class OfflineStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String data);
}

OfflineStorage deviceStorage(String project, String userId) =>
    platform.createOfflineStorage(
      sha256.convert(utf8.encode('$project/$userId')).toString(),
    );

class MemoryOfflineStorage implements OfflineStorage {
  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String data) async {
    _data[key] = data;
  }
}

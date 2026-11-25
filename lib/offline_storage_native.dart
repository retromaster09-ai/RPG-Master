import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'offline_storage.dart';

OfflineStorage createOfflineStorage(String scope) => _FileStorage(scope);

class _FileStorage implements OfflineStorage {
  _FileStorage(this.scope);

  final String scope;
  late final Future<Directory> _directory = _openDirectory();
  final _writes = <String, Future<void>>{};

  Future<Directory> _openDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/rpg-offline/$scope').create(recursive: true);
  }

  Future<File> _file(String key) async {
    final name = sha256.convert(utf8.encode(key));
    return File('${(await _directory).path}/$name.json');
  }

  @override
  Future<String?> read(String key) async {
    await _writes[key];
    final file = await _file(key);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String key, String data) {
    final operation = (_writes[key] ?? Future<void>.value()).then((_) async {
      final file = await _file(key);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(data, flush: true);
      await temporary.rename(file.path);
    });
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes[key] = tail;
    return operation.whenComplete(() {
      if (identical(_writes[key], tail)) _writes.remove(key);
    });
  }
}

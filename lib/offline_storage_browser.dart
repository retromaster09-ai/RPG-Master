import 'package:shared_preferences/shared_preferences.dart';

import 'offline_storage.dart';

OfflineStorage createOfflineStorage(String scope) => _BrowserStorage(scope);

class _BrowserStorage implements OfflineStorage {
  _BrowserStorage(this.scope);

  final String scope;
  final _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) =>
      _preferences.getString('rpg-offline:$scope:$key');

  @override
  Future<void> write(String key, String data) =>
      _preferences.setString('rpg-offline:$scope:$key', data);
}

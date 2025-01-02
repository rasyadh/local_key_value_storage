// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'local_key_value_storage_platform_interface.dart';

/// Wraps NSUserDefaults (on iOS) and SharedPreferences (on Android), providing
/// a persistent store for simple data.
///
/// Data is persisted to disk asynchronously.
class LocalKeyValueStorage {
  LocalKeyValueStorage._(this._storageName, this._preferenceCache);

  static final Map<String?, Completer<LocalKeyValueStorage>?> _completers = {};

  static LocalKeyValueStorageStorePlatform get _store =>
      LocalKeyValueStorageStorePlatform.instance;

  /// Loads and parses the [LocalKeyValueStorage] for this app from disk.
  ///
  /// Because this is reading from disk, it shouldn't be awaited in
  /// performance-sensitive blocks.
  static Future<LocalKeyValueStorage> getInstance({String? storageName}) async {
    final cachedCompleter = _completers[storageName];
    if (cachedCompleter == null) {
      final Completer<LocalKeyValueStorage> newCompleter =
          Completer<LocalKeyValueStorage>();
      try {
        final Map<String, Object> preferencesMap =
            await _getLocalKeyValueStorageMap(storageName);
        newCompleter
            .complete(LocalKeyValueStorage._(storageName, preferencesMap));
      } on Exception catch (e) {
        // If there's an error, explicitly return the future with an error.
        // then set the completer to null so we can retry.
        newCompleter.completeError(e);
        final Future<LocalKeyValueStorage> localKeyValueStorageFuture =
            newCompleter.future;
        return localKeyValueStorageFuture;
      }
      _completers[storageName] = newCompleter;
      return newCompleter.future;
    } else {
      return cachedCompleter.future;
    }
  }

  final String? _storageName;

  /// The cache that holds all preferences.
  ///
  /// It is instantiated to the current state of the SharedPreferences or
  /// NSUserDefaults object and then kept in sync via setter methods in this
  /// class.
  ///
  /// It is NOT guaranteed that this cache and the device prefs will remain
  /// in sync since the setter method might fail for any reason.
  final Map<String, Object> _preferenceCache;

  /// Returns all keys in the persistent storage.
  Set<String> getKeys() => Set<String>.from(_preferenceCache.keys);

  /// Reads a value of any type from persistent storage.
  Object? get(String key) => _preferenceCache[key];

  /// Reads a value from persistent storage, throwing an exception if it's not a
  /// bool.
  bool? getBool(String key) => _preferenceCache[key] as bool?;

  /// Reads a value from persistent storage, throwing an exception if it's not
  /// an int.
  int? getInt(String key) => _preferenceCache[key] as int?;

  /// Reads a value from persistent storage, throwing an exception if it's not a
  /// double.
  double? getDouble(String key) => _preferenceCache[key] as double?;

  /// Reads a value from persistent storage, throwing an exception if it's not a
  /// String.
  String? getString(String key) => _preferenceCache[key] as String?;

  /// Returns true if persistent storage the contains the given [key].
  bool containsKey(String key) => _preferenceCache.containsKey(key);

  /// Reads a set of string values from persistent storage, throwing an
  /// exception if it's not a string set.
  List<String>? getStringList(String key) {
    List<dynamic>? list = _preferenceCache[key] as List<dynamic>?;
    if (list != null && list is! List<String>) {
      list = list.cast<String>().toList();
      _preferenceCache[key] = list;
    }
    // Make a copy of the list so that later mutations won't propagate
    return list?.toList() as List<String>?;
  }

  /// Saves a boolean [value] to persistent storage in the background.
  Future<bool> setBool(String key, bool value) => _setValue('Bool', key, value);

  /// Saves an integer [value] to persistent storage in the background.
  Future<bool> setInt(String key, int value) => _setValue('Int', key, value);

  /// Saves a double [value] to persistent storage in the background.
  ///
  /// Android doesn't support storing doubles, so it will be stored as a float.
  Future<bool> setDouble(String key, double value) =>
      _setValue('Double', key, value);

  /// Saves a string [value] to persistent storage in the background.
  ///
  /// Note: Due to limitations in Android's SharedPreferences,
  /// values cannot start with any one of the following:
  ///
  /// - 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu'
  /// - 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBCaWdJbnRlZ2Vy'
  /// - 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu'
  Future<bool> setString(String key, String value) =>
      _setValue('String', key, value);

  /// Saves a list of strings [value] to persistent storage in the background.
  Future<bool> setStringList(String key, List<String> value) =>
      _setValue('StringList', key, value);

  /// Removes an entry from persistent storage.
  Future<bool> remove(String key) {
    _preferenceCache.remove(key);
    return _store.remove(key, _storageName);
  }

  Future<bool> _setValue(String valueType, String key, Object value) {
    ArgumentError.checkNotNull(value, 'value');
    if (value is List<String>) {
      // Make a copy of the list so that later mutations won't propagate
      _preferenceCache[key] = value.toList();
    } else {
      _preferenceCache[key] = value;
    }
    return _store.setValue(valueType, key, value, _storageName);
  }

  /// Always returns true.
  /// On iOS, synchronize is marked deprecated. On Android, we commit every set.
  @Deprecated('This method is now a no-op, and should no longer be called.')
  Future<bool> commit() async => true;

  /// Completes with true once the user preferences for the app has been cleared.
  Future<bool> clear() {
    _preferenceCache.clear();
    return _store.clear(_storageName);
  }

  /// Fetches the latest values from the host platform.
  ///
  /// Use this method to observe modifications that were made in native code
  /// (without using the plugin) while the app is running.
  Future<void> reload() async {
    final Map<String, Object> preferences =
        await _getLocalKeyValueStorageMap(_storageName);
    _preferenceCache.clear();
    _preferenceCache.addAll(preferences);
  }

  static Future<Map<String, Object>> _getLocalKeyValueStorageMap(
      String? storageName) async {
    final Map<String, Object> fromSystem = await _store.getAll(storageName);
    // Strip the flutter. prefix from the returned preferences.
    final Map<String, Object> preferencesMap = <String, Object>{};
    for (final String key in fromSystem.keys) {
      preferencesMap[key] = fromSystem[key]!;
    }
    return preferencesMap;
  }

  /// Initializes the local key value storage with mock values for testing.
  ///
  /// If the singleton instance has been initialized already, it is nullified.
  @visibleForTesting
  static void setMockInitialValues(
      Map<String, Object> values, String? storageName) {
    final Map<String, Object> newValues =
        values.map<String, Object>((String key, Object value) {
      return MapEntry<String, Object>(key, value);
    });
    LocalKeyValueStorageStorePlatform.instance =
        InMemoryLocalKeyValueStorageStore.withData(newValues);
    _completers.remove(storageName);
  }
}

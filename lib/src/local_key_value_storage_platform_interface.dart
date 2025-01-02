// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_local_key_value_storage.dart';

/// The interface that implementations of local_key_value_storage must implement.
///
/// Platform implementations should extend this class rather than implement it as `local_key_value_storage`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [LocalKeyValueStorageStorePlatform] methods.
abstract class LocalKeyValueStorageStorePlatform extends PlatformInterface {
  /// Constructs a LocalKeyValueStorageStorePlatform.
  LocalKeyValueStorageStorePlatform() : super(token: _token);

  static final Object _token = Object();

  /// The default instance of [LocalKeyValueStorageStorePlatform] to use.
  ///
  /// Defaults to [MethodChannelLocalKeyValueStorageStore].
  static LocalKeyValueStorageStorePlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [LocalKeyValueStorageStorePlatform] when they register themselves.
  static set instance(LocalKeyValueStorageStorePlatform instance) {
    if (!instance.isMock) {
      PlatformInterface.verify(instance, _token);
    }
    _instance = instance;
  }

  static LocalKeyValueStorageStorePlatform _instance =
      MethodChannelLocalKeyValueStorageStore();

  /// Only mock implementations should set this to true.
  ///
  /// Mockito mocks are implementing this class with `implements` which is forbidden for anything
  /// other than mocks (see class docs). This property provides a backdoor for mockito mocks to
  /// skip the verification that the class isn't implemented with `implements`.
  @visibleForTesting
  @Deprecated('Use MockPlatformInterfaceMixin instead')
  bool get isMock => false;

  /// Removes the value associated with the [key].
  Future<bool> remove(String key, String? storageName);

  /// Stores the [value] associated with the [key].
  ///
  /// The [valueType] must match the type of [value] as follows:
  ///
  /// * Value type "Bool" must be passed if the value is of type `bool`.
  /// * Value type "Double" must be passed if the value is of type `double`.
  /// * Value type "Int" must be passed if the value is of type `int`.
  /// * Value type "String" must be passed if the value is of type `String`.
  /// * Value type "StringList" must be passed if the value is of type `List<String>`.
  Future<bool> setValue(
      String valueType, String key, Object value, String? storageName);

  /// Removes all keys and values in the store.
  Future<bool> clear(String? storageName);

  /// Returns all key/value pairs persisted in this store.
  Future<Map<String, Object>> getAll(String? storageName);
}

/// Stores data in memory.
///
/// Data does not persist across application restarts. This is useful in unit-tests.
class InMemoryLocalKeyValueStorageStore
    extends LocalKeyValueStorageStorePlatform {
  /// Instantiates an empty in-memory preferences store.
  InMemoryLocalKeyValueStorageStore.empty()
      : _data = <String?, Map<String, Object>>{};

  /// Instantiates an in-memory preferences store containing a copy of [data].
  InMemoryLocalKeyValueStorageStore.withData(Map<String, Object> data)
      : _data = Map<String?, Map<String, Object>>.from(data);

  final Map<String?, Map<String, Object>> _data;

  @override
  Future<bool> clear(String? storageName) async {
    _data.remove(storageName);
    return true;
  }

  @override
  Future<Map<String, Object>> getAll(String? storageName) async {
    final data = _data[storageName];
    if (data == null) {
      return <String, Object>{};
    } else {
      return Map<String, Object>.from(data);
    }
  }

  @override
  Future<bool> remove(String key, String? storageName) async {
    _data[storageName]?.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(
      String valueType, String key, Object value, String? storageName) async {
    final data = _data[storageName];
    if (data == null) {
      _data[key] = <String, Object>{key: value};
    } else {
      data[key] = value;
      _data[key] = data;
    }
    return true;
  }
}

// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:local_key_value_storage/src/local_key_value_storage_platform_interface.dart';

const MethodChannel _kChannel =
    MethodChannel('rasyadh/local_key_value_storage');

/// Wraps NSUserDefaults (on iOS) and SharedPreferences (on Android), providing
/// a persistent store for simple data.
///
/// Data is persisted to disk asynchronously.
class MethodChannelLocalKeyValueStorageStore
    extends LocalKeyValueStorageStorePlatform {
  @override
  Future<bool> remove(String key, String? storageName) async {
    return (await _kChannel.invokeMethod<bool>(
      'remove',
      <String, dynamic>{
        'key': key,
        if (storageName != null) 'storageName': storageName,
      },
    ))!;
  }

  @override
  Future<bool> setValue(
      String valueType, String key, Object value, String? storageName) async {
    return (await _kChannel.invokeMethod<bool>(
      'set$valueType',
      <String, dynamic>{
        'key': key,
        'value': value,
        if (storageName != null) 'storageName': storageName,
      },
    ))!;
  }

  @override
  Future<bool> clear(String? storageName) async {
    return (await _kChannel.invokeMethod<bool>(
      'clear',
      <String, dynamic>{
        if (storageName != null) 'storageName': storageName,
      },
    ))!;
  }

  @override
  Future<Map<String, Object>> getAll(String? storageName) async {
    final Map<String, Object>? preferences =
        await _kChannel.invokeMapMethod<String, Object>(
      'getAll',
      <String, dynamic>{
        if (storageName != null) 'storageName': storageName,
      },
    );

    if (preferences == null) {
      return <String, Object>{};
    }
    return preferences;
  }
}

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models.dart';

class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage storage;
  SecureSessionStore(this.storage);
  @override
  Future<Map<String, dynamic>?> read() async {
    final value = await storage.read(key: 'session');
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> session) =>
      storage.write(key: 'session', value: jsonEncode(session));
  @override
  Future<void> clear() => storage.delete(key: 'session');
}

class HiveFeedCache implements FeedCache {
  final Box<String> box;
  HiveFeedCache(this.box);
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final value = box.get(key);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) =>
      box.put(key, jsonEncode(value));
  @override
  Future<void> clear() => box.clear();
}

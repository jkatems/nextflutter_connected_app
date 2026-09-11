/// Live end-to-end check. Creates and deletes its own temporary Firebase user.
/// Run with: dart run scripts/firebase_smoke.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:carnet/core/api_client.dart';
import 'package:carnet/core/firebase_config.dart';
import 'package:carnet/data/firebase_auth_repository.dart';
import 'package:carnet/data/repositories.dart';
import 'package:carnet/domain/models.dart';

class Session implements SessionStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> next) async {
    value = next;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class Cache implements FeedCache {
  final data = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => data[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    data[key] = value;
  }

  @override
  Future<void> clear() async => data.clear();
}

void verify(bool condition, String label) {
  if (!condition) throw StateError(label);
  stdout.writeln('PASS $label');
}

Future<void> main() async {
  final identity = createDio(FirebaseConfig.authUrl);
  final tokens = createDio(FirebaseConfig.refreshUrl);
  final dio = createDio(FirebaseConfig.dataUrl);
  final session = Session();
  final cache = Cache();
  final auth = FirebaseAuthRepository(identity, tokens, session, cache);
  final email =
      'carnet-check-${DateTime.now().microsecondsSinceEpoch}@example.com';
  final password = 'Carnet-${DateTime.now().microsecondsSinceEpoch}-X!';
  Map<String, dynamic>? created;
  try {
    created = await auth.authenticate(
      email: email,
      password: password,
      name: 'Vérification Carnet',
    );
    verify(created['user']['id'] != null, 'Firebase signup');
    await auth.logout();
    await auth.authenticate(email: email, password: password);
    verify(
      session.value!['user']['id'] == created['user']['id'],
      'Firebase login',
    );
    dio.interceptors.add(
      AuthInterceptor(dio, tokens, session, refreshSession: auth.refresh),
    );
    final repo = RestContentRepository(
      dio,
      cache,
      '${created['user']['id']}',
      firestore: true,
    );
    for (final category in ['articles', 'products', 'tasks']) {
      final feed = await repo.fetch(category);
      verify(feed.items.length == 4 && !feed.cached, 'Firestore $category');
    }
    final renewed = await auth.refresh(session.value!);
    await session.write(renewed);
    verify(
      (await repo.fetch('articles')).items.isNotEmpty,
      'Firebase refresh token',
    );
    final unsigned = createDio(FirebaseConfig.dataUrl);
    final denied = await unsigned.get<dynamic>(
      '/articles',
      options: Options(validateStatus: (_) => true),
    );
    verify(
      denied.statusCode == 403 || denied.statusCode == 401,
      'Unauthenticated read denied',
    );
    final write = await dio.patch<dynamic>(
      '/smoke-denied',
      data: {'fields': {}},
      options: Options(validateStatus: (_) => true),
    );
    verify(write.statusCode == 403, 'Client write denied');
    // Use a closed loopback port to exercise a real Dio network failure.
    final offlineDio = createDio('http://127.0.0.1:1');
    final offline = RestContentRepository(
      offlineDio,
      cache,
      '${created['user']['id']}',
      firestore: true,
    );
    verify(
      (await offline.fetch('articles')).cached,
      'Offline repository fallback',
    );
    stdout.writeln('Live Firebase checks passed.');
  } finally {
    if (created != null) {
      final current = session.value ?? created;
      await identity.post<dynamic>(
        '/accounts:delete',
        queryParameters: {'key': FirebaseConfig.apiKey},
        data: {'idToken': current['accessToken']},
      );
      await auth.logout();
      stdout.writeln('Temporary Firebase user deleted.');
    }
    dio.close();
    identity.close();
    tokens.close();
  }
}

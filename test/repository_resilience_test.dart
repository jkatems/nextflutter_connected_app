import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carnet/core/api_client.dart';
import 'package:carnet/data/repositories.dart';
import 'package:carnet/domain/models.dart';
import 'support/doubles.dart';

class BrokenCache extends MemoryCache {
  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      throw StateError('disk');
  @override
  Future<void> write(String key, Map<String, dynamic> value) async =>
      throw StateError('disk');
}

class BrokenSession extends MemorySession {
  @override
  Future<void> write(Map<String, dynamic> session) async =>
      throw StateError('keychain');
  @override
  Future<void> clear() async => throw StateError('keychain');
}

Matcher failure(FailureKind kind) =>
    throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', kind));

void main() {
  late Dio dio;
  late Dio refresh;
  late MemoryCache cache;
  late MemorySession store;
  late RestContentRepository repository;

  setUp(() {
    dio = createDio('http://test');
    refresh = createDio('http://test');
    cache = MemoryCache();
    store = MemorySession()..value = session;
    repository = RestContentRepository(dio, cache, '7');
    cache.values['7/articles'] = {
      'items': [item],
      'savedAt': DateTime(2026).toIso8601String(),
    };
  });
  tearDown(() {
    dio.close(force: true);
    refresh.close(force: true);
  });

  test('403 never falls back to cache', () async {
    dio.httpClientAdapter = Adapter((_) async => response({}, 403));
    await expectLater(
      repository.fetch('articles'),
      failure(FailureKind.forbidden),
    );
  });

  test(
    'malformed successful response never falls back or overwrites cache',
    () async {
      dio.httpClientAdapter = Adapter(
        (_) async => response({'items': 'invalid'}),
      );
      await expectLater(
        repository.fetch('articles'),
        failure(FailureKind.invalidData),
      );
      expect(cache.values['7/articles']!['items'], [item]);
    },
  );

  test(
    'corrupt cached timestamp becomes an actionable storage failure',
    () async {
      cache.values['7/articles']!['savedAt'] = 'not-a-date';
      dio.httpClientAdapter = Adapter((_) async => response({}, 503));
      await expectLater(
        repository.fetch('articles'),
        failure(FailureKind.storage),
      );
    },
  );

  test('cache read exception does not escape the domain boundary', () async {
    dio.httpClientAdapter = Adapter((_) async => response({}, 503));
    final broken = RestContentRepository(dio, BrokenCache(), '7');
    await expectLater(broken.fetch('articles'), failure(FailureKind.storage));
  });

  test('cache write failure has a distinct storage error', () async {
    dio.httpClientAdapter = Adapter(
      (_) async => response({
        'items': [item],
      }),
    );
    final broken = RestContentRepository(dio, BrokenCache(), '7');
    await expectLater(broken.fetch('articles'), failure(FailureKind.storage));
  });

  test('invalid login session is never persisted', () async {
    dio.httpClientAdapter = Adapter(
      (_) async => response({'accessToken': 'incomplete'}),
    );
    final auth = AuthRepository(dio, dio, store, cache);
    await expectLater(
      auth.authenticate(email: 'a@b.cd', password: 'password'),
      failure(FailureKind.invalidData),
    );
    expect(store.value, session);
  });

  test('credential write failure is translated into a storage error', () async {
    dio.httpClientAdapter = Adapter((_) async => response(session));
    final auth = AuthRepository(dio, dio, BrokenSession(), cache);
    await expectLater(
      auth.authenticate(email: 'a@b.cd', password: 'password'),
      failure(FailureKind.storage),
    );
  });

  test(
    'logout attempts cache cleanup even when credential cleanup fails',
    () async {
      dio.httpClientAdapter = Adapter((_) async => response({}));
      final auth = AuthRepository(dio, dio, BrokenSession(), cache);
      await expectLater(auth.logout(), failure(FailureKind.storage));
      expect(cache.values, isEmpty);
    },
  );

  test('corrupt stored session is rejected on restore', () async {
    store.value = {'user': {}};
    await expectLater(
      AuthRepository(dio, dio, store, cache).restore(),
      failure(FailureKind.storage),
    );
  });

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.connectionError,
  ]) {
    test('refresh $type preserves session and permits offline cache', () async {
      dio.interceptors.add(AuthInterceptor(dio, refresh, store));
      dio.httpClientAdapter = Adapter((_) async => response({}, 401));
      refresh.httpClientAdapter = Adapter(
        (o) async => throw DioException(requestOptions: o, type: type),
      );
      expect((await repository.fetch('articles')).cached, true);
      expect(store.value, session);
    });
  }

  test('401 after successful refresh is not retried indefinitely', () async {
    var count = 0;
    dio.interceptors.add(AuthInterceptor(dio, refresh, store));
    dio.httpClientAdapter = Adapter((_) async => response({}, 401));
    refresh.httpClientAdapter = Adapter((_) async {
      count++;
      return response({
        ...session,
        'accessToken': 'new',
        'refreshToken': 'rotated',
      });
    });
    await expectLater(
      repository.fetch('articles'),
      failure(FailureKind.unauthorized),
    );
    expect(count, 1);
  });

  test('late refresh cannot restore a locally removed session', () async {
    final started = Completer<void>();
    final result = Completer<ResponseBody>();
    dio.interceptors.add(AuthInterceptor(dio, refresh, store));
    dio.httpClientAdapter = Adapter((_) async => response({}, 401));
    refresh.httpClientAdapter = Adapter((_) {
      started.complete();
      return result.future;
    });
    final pending = expectLater(
      repository.fetch('articles'),
      failure(FailureKind.unauthorized),
    );
    await started.future;
    await store.clear();
    result.complete(response({...session, 'accessToken': 'new'}));
    await pending;
    expect(store.value, isNull);
  });

  test('refresh cannot switch the current account', () async {
    dio.interceptors.add(AuthInterceptor(dio, refresh, store));
    dio.httpClientAdapter = Adapter((_) async => response({}, 401));
    refresh.httpClientAdapter = Adapter(
      (_) async => response({
        ...session,
        'user': {'id': 8, 'name': 'Bob'},
      }),
    );
    await expectLater(
      repository.fetch('articles'),
      failure(FailureKind.unauthorized),
    );
    expect(store.value, session);
  });

  test('malformed refresh never replaces valid credentials', () async {
    dio.interceptors.add(AuthInterceptor(dio, refresh, store));
    dio.httpClientAdapter = Adapter((_) async => response({}, 401));
    refresh.httpClientAdapter = Adapter(
      (_) async => response({'accessToken': 'new'}),
    );
    await expectLater(
      repository.fetch('articles'),
      failure(FailureKind.unauthorized),
    );
    expect(store.value, session);
  });
}

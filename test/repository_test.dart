import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carnet/core/api_client.dart';
import 'package:carnet/data/repositories.dart';
import 'package:carnet/domain/models.dart';

class MemoryCache implements FeedCache {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = value;
  }

  @override
  Future<void> clear() async => values.clear();
}

class MemorySession implements SessionStore {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
final item = {
  'id': 1,
  'title': 'Article',
  'body': 'Contenu réel',
  'label': 'TEST',
};
final session = {
  'accessToken': 'old',
  'refreshToken': 'refresh',
  'user': {'id': 7, 'name': 'Alice'},
};
void main() {
  late Dio dio;
  late MemoryCache cache;
  late RestContentRepository repo;
  setUp(() {
    dio = createDio('http://test');
    cache = MemoryCache();
    repo = RestContentRepository(dio, cache, '7');
  });
  test('repository returns REST data and persists its timestamp', () async {
    dio.httpClientAdapter = Adapter(
      (_) async => response({
        'items': [item],
      }),
    );
    final feed = await repo.fetch('articles');
    expect(feed.items.single.title, 'Article');
    expect(feed.cached, false);
    expect(
      cache.values['7/articles']!['savedAt'],
      feed.savedAt.toIso8601String(),
    );
  });
  test('repository reads previous cache when connection fails', () async {
    dio.httpClientAdapter = Adapter(
      (_) async => response({
        'items': [item],
      }),
    );
    await repo.fetch('articles');
    dio.httpClientAdapter = Adapter(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    final feed = await repo.fetch('articles');
    expect(feed.cached, true);
    expect(feed.items.single.id, 1);
  });
  test('repository reports offline without cached data', () async {
    dio.httpClientAdapter = Adapter(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionTimeout,
      ),
    );
    await expectLater(repo.fetch('tasks'), throwsA(isA<AppFailure>()));
  });
  test('repository never masks 401 with cached data', () async {
    cache.values['7/articles'] = {
      'items': [item],
      'savedAt': DateTime.now().toIso8601String(),
    };
    dio.httpClientAdapter = Adapter((_) async => response({}, 401));
    await expectLater(
      repo.fetch('articles'),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('Session expirée'),
        ),
      ),
    );
  });
  test('repository isolates cache between accounts', () async {
    cache.values['8/articles'] = {
      'items': [item],
      'savedAt': DateTime.now().toIso8601String(),
    };
    dio.httpClientAdapter = Adapter(
      (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(repo.fetch('articles'), throwsA(isA<AppFailure>()));
  });
  test('repository uses cache on server 503', () async {
    cache.values['7/products'] = {
      'items': [item],
      'savedAt': DateTime.now().toIso8601String(),
    };
    dio.httpClientAdapter = Adapter((_) async => response({}, 503));
    expect((await repo.fetch('products')).cached, true);
  });
  test('auth repository registers and persists session', () async {
    final store = MemorySession();
    dio.httpClientAdapter = Adapter((o) async {
      expect(o.path, '/auth/register');
      expect(o.data['name'], 'Alice');
      return response(session, 201);
    });
    await AuthRepository(dio, dio, store, cache).authenticate(
      email: 'alice@test.dev',
      password: 'password1',
      name: 'Alice',
    );
    expect(store.value!['accessToken'], 'old');
  });
  test(
    'auth repository clears credentials and cache on offline logout',
    () async {
      final store = MemorySession()..value = session;
      cache.values['7/articles'] = {};
      dio.httpClientAdapter = Adapter(
        (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(await AuthRepository(dio, dio, store, cache).logout(), false);
      expect(store.value, isNull);
      expect(cache.values, isEmpty);
    },
  );
  test(
    'interceptor injects JWT and refreshes concurrent 401 only once',
    () async {
      final store = MemorySession()..value = session;
      final refresh = createDio('http://test');
      var count = 0;
      refresh.httpClientAdapter = Adapter((o) async {
        count++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return response({
          ...session,
          'accessToken': 'new',
          'refreshToken': 'rotated',
        });
      });
      dio.interceptors.add(AuthInterceptor(dio, refresh, store));
      dio.httpClientAdapter = Adapter(
        (o) async => o.headers['Authorization'] == 'Bearer new'
            ? response({
                'items': [item],
              })
            : response({}, 401),
      );
      final results = await Future.wait([
        repo.fetch('articles'),
        repo.fetch('products'),
        repo.fetch('tasks'),
      ]);
      expect(results.length, 3);
      expect(count, 1);
      expect(store.value!['refreshToken'], 'rotated');
    },
  );
  test('interceptor does not loop on rejected refresh token', () async {
    final store = MemorySession()..value = session;
    final refresh = createDio('http://test');
    var count = 0;
    refresh.httpClientAdapter = Adapter((_) async {
      count++;
      return response({}, 401);
    });
    dio.interceptors.add(AuthInterceptor(dio, refresh, store));
    dio.httpClientAdapter = Adapter((_) async => response({}, 401));
    await expectLater(repo.fetch('articles'), throwsA(isA<AppFailure>()));
    expect(count, 1);
  });
}

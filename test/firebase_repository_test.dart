import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carnet/core/api_client.dart';
import 'package:carnet/core/firebase_config.dart';
import 'package:carnet/data/firebase_auth_repository.dart';
import 'package:carnet/data/repositories.dart';
import 'package:carnet/domain/models.dart';
import 'repository_test.dart'
    show Adapter, MemoryCache, MemorySession, response;

final firebaseResponse = {
  'idToken': 'firebase-jwt',
  'refreshToken': 'firebase-refresh',
  'localId': 'uid-123',
  'email': 'alice@example.com',
  'displayName': 'Alice',
};
final firestoreDocument = {
  'fields': {
    'items': {
      'arrayValue': {
        'values': [
          {
            'mapValue': {
              'fields': {
                'id': {'integerValue': '1'},
                'title': {'stringValue': 'Firestore réel'},
                'body': {'stringValue': 'Contenu distant'},
                'label': {'stringValue': 'FIREBASE'},
              },
            },
          },
        ],
      },
    },
  },
};
void main() {
  late Dio identity, tokens, data;
  late MemorySession sessions;
  late MemoryCache cache;
  late FirebaseAuthRepository auth;
  setUp(() {
    identity = createDio(FirebaseConfig.authUrl);
    tokens = createDio(FirebaseConfig.refreshUrl);
    data = createDio(FirebaseConfig.dataUrl);
    sessions = MemorySession();
    cache = MemoryCache();
    auth = FirebaseAuthRepository(identity, tokens, sessions, cache);
  });
  test(
    'Firebase registration sends name and persists real Firebase session',
    () async {
      identity.httpClientAdapter = Adapter((o) async {
        expect(o.path, '/accounts:signUp');
        expect(o.data['displayName'], 'Alice');
        expect(o.queryParameters['key'], FirebaseConfig.apiKey);
        return response(firebaseResponse);
      });
      final result = await auth.authenticate(
        email: 'alice@example.com',
        password: 'password123',
        name: 'Alice',
      );
      expect(result['projectId'], 'rentit-30415');
      expect(sessions.value!['user']['id'], 'uid-123');
    },
  );
  test(
    'Firebase login uses signInWithPassword and restores without network',
    () async {
      identity.httpClientAdapter = Adapter((o) async {
        expect(o.path, '/accounts:signInWithPassword');
        return response(firebaseResponse);
      });
      await auth.authenticate(
        email: 'alice@example.com',
        password: 'password123',
      );
      identity.httpClientAdapter = Adapter(
        (o) async => throw DioException(requestOptions: o),
      );
      expect((await auth.restore())!['user']['name'], 'Alice');
    },
  );
  test('Firebase rejects old Python sessions and clears their cache', () async {
    sessions.value = {'accessToken': 'legacy'};
    cache.values['old/articles'] = {};
    expect(await auth.restore(), isNull);
    expect(cache.values, isEmpty);
  });
  test('Firebase authentication translates invalid credentials', () async {
    identity.httpClientAdapter = Adapter(
      (o) async => response({
        'error': {'message': 'INVALID_LOGIN_CREDENTIALS'},
      }, 400),
    );
    await expectLater(
      auth.authenticate(email: 'alice@example.com', password: 'wrongpass'),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('incorrect'),
        ),
      ),
    );
    expect(sessions.value, isNull);
  });
  test(
    'Firebase sign-out clears credentials and cache without network',
    () async {
      sessions.value = {'projectId': 'rentit-30415'};
      cache.values['uid-123/articles'] = {};
      expect(await auth.logout(), true);
      expect(sessions.value, isNull);
      expect(cache.values, isEmpty);
    },
  );
  test(
    'Firestore repository decodes typed REST fields and caches them',
    () async {
      data.httpClientAdapter = Adapter((o) async {
        expect(o.uri.toString(), '${FirebaseConfig.dataUrl}/articles');
        return response(firestoreDocument);
      });
      final repo = RestContentRepository(
        data,
        cache,
        'uid-123',
        firestore: true,
      );
      final feed = await repo.fetch('articles');
      expect(feed.items.single.title, 'Firestore réel');
      expect(cache.values['uid-123/articles']!['items'], isNotEmpty);
    },
  );
  test(
    'Firestore repository loads cache when offline after initial REST load',
    () async {
      data.httpClientAdapter = Adapter(
        (o) async => response(firestoreDocument),
      );
      final repo = RestContentRepository(
        data,
        cache,
        'uid-123',
        firestore: true,
      );
      await repo.fetch('tasks');
      data.httpClientAdapter = Adapter(
        (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      expect((await repo.fetch('tasks')).cached, true);
    },
  );
  test(
    'Firebase refresh is form-encoded, persists new tokens and retries Firestore',
    () async {
      sessions.value = {
        'projectId': 'rentit-30415',
        'accessToken': 'old',
        'refreshToken': 'old-refresh',
        'user': {'id': 'uid-123'},
      };
      var refreshes = 0;
      tokens.httpClientAdapter = Adapter((o) async {
        refreshes++;
        expect(o.path, '/token');
        expect(o.contentType, Headers.formUrlEncodedContentType);
        expect(o.data['grant_type'], 'refresh_token');
        expect(o.data['refresh_token'], 'old-refresh');
        return response({'id_token': 'fresh', 'refresh_token': 'renewed'});
      });
      data.interceptors.add(
        AuthInterceptor(data, tokens, sessions, refreshSession: auth.refresh),
      );
      data.httpClientAdapter = Adapter(
        (o) async => o.headers['Authorization'] == 'Bearer fresh'
            ? response(firestoreDocument)
            : response({}, 401),
      );
      final repo = RestContentRepository(
        data,
        cache,
        'uid-123',
        firestore: true,
      );
      expect((await repo.fetch('products')).items.length, 1);
      expect(refreshes, 1);
      expect(sessions.value!['refreshToken'], 'renewed');
    },
  );
}

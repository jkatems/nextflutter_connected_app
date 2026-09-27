import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../domain/models.dart';

class RestContentRepository implements ContentRepository {
  final Dio dio;
  final FeedCache cache;
  final String userId;
  RestContentRepository(this.dio, this.cache, this.userId);
  @override
  Future<Feed> fetch(String category) async {
    final key = '$userId/$category';
    Object? payload;
    try {
      final response = await dio.get<dynamic>('/$category');
      payload = response.data;
    } on DioException catch (e) {
      if (isUnavailable(e)) {
        final saved = await _readCache(key);
        if (saved != null) return saved;
      }
      throw networkFailure(e);
    }
    final items = _decodeItems(payload);
    final now = DateTime.now();
    try {
      await cache.write(key, {
        'items': items.map((e) => e.toJson()).toList(),
        'savedAt': now.toIso8601String(),
      });
    } catch (_) {
      throw const AppFailure(
        'Impossible de sauvegarder les données sur cet appareil.',
        kind: FailureKind.storage,
      );
    }
    return Feed(items, false, now);
  }

  List<Entry> _decodeItems(Object? payload) {
    try {
      final data = payload as Map;
      return (data['items'] as List)
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      throw const AppFailure(
        'Les données reçues du serveur sont invalides.',
        kind: FailureKind.invalidData,
      );
    }
  }

  Future<Feed?> _readCache(String key) async {
    try {
      final saved = await cache.read(key);
      if (saved == null) return null;
      return Feed(
        _decodeItems(saved),
        true,
        DateTime.parse(saved['savedAt'] as String),
      );
    } catch (_) {
      throw const AppFailure(
        'Le cache local est illisible. Reconnectez-vous au réseau puis actualisez.',
        kind: FailureKind.storage,
      );
    }
  }
}

class AuthRepository implements AuthenticationRepository {
  final Dio publicDio, authenticatedDio;
  final SessionStore sessions;
  final FeedCache cache;
  AuthRepository(
    this.publicDio,
    this.authenticatedDio,
    this.sessions,
    this.cache,
  );
  @override
  Future<Map<String, dynamic>?> restore() async {
    try {
      final value = await sessions.read();
      return value == null ? null : parseSession(value);
    } catch (_) {
      throw const AppFailure(
        'Impossible de restaurer la session locale.',
        kind: FailureKind.storage,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await publicDio.post<dynamic>(
        name == null ? '/auth/login' : '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          if (name != null) 'name': name.trim(),
        },
      );
      final session = parseSession(response.data);
      try {
        await sessions.write(session);
      } catch (_) {
        throw const AppFailure(
          'Impossible d’enregistrer la session sur cet appareil.',
          kind: FailureKind.storage,
        );
      }
      return session;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 401 &&
          data is Map &&
          data['message'] is String) {
        throw AppFailure(data['message'] as String);
      }
      throw networkFailure(e);
    }
  }

  /// Returns false if server revocation could not be confirmed. Local logout
  /// always attempts both cleanups and reports any local storage failure.
  @override
  Future<bool> logout() async {
    var revoked = false;
    try {
      await authenticatedDio.post<dynamic>('/auth/logout');
      revoked = true;
    } on DioException {
      /* Local logout is available offline. */
    } finally {
      try {
        try {
          await sessions.clear();
        } finally {
          // Attempt both cleanups, even if secure storage fails.
          await cache.clear();
        }
      } catch (_) {
        throw const AppFailure(
          'Le nettoyage local a échoué. Réessayez la déconnexion.',
          kind: FailureKind.storage,
        );
      }
    }
    return revoked;
  }
}

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
    try {
      final response = await dio.get<Map<String, dynamic>>('/$category');
      final items = (response.data!['items'] as List)
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final now = DateTime.now();
      await cache.write(key, {
        'items': items.map((e) => e.toJson()).toList(),
        'savedAt': now.toIso8601String(),
      });
      return Feed(items, false, now);
    } on DioException catch (e) {
      if (isUnavailable(e)) {
        final saved = await cache.read(key);
        if (saved != null) {
          return Feed(
            (saved['items'] as List)
                .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
            true,
            DateTime.parse(saved['savedAt'] as String),
          );
        }
      }
      throw networkFailure(e);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Impossible de lire ou sauvegarder les données locales.',
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
  Future<Map<String, dynamic>?> restore() => sessions.read();
  @override
  Future<Map<String, dynamic>> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await publicDio.post<Map<String, dynamic>>(
        name == null ? '/auth/login' : '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          if (name != null) 'name': name.trim(),
        },
      );
      await sessions.write(response.data!);
      return response.data!;
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
  /// always removes credentials and account-specific cached data.
  @override
  Future<bool> logout() async {
    var revoked = false;
    try {
      await authenticatedDio.post<dynamic>('/auth/logout');
      revoked = true;
    } on DioException {
      /* Local logout is available offline. */
    } finally {
      await sessions.clear();
      await cache.clear();
    }
    return revoked;
  }
}

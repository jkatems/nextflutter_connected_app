import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/firebase_config.dart';
import '../domain/models.dart';

/// Firebase Authentication through its official HTTPS REST API.
class FirebaseAuthRepository implements AuthenticationRepository {
  final Dio identity, tokenClient;
  final SessionStore sessions;
  final FeedCache cache;
  FirebaseAuthRepository(
    this.identity,
    this.tokenClient,
    this.sessions,
    this.cache,
  );

  @override
  Future<Map<String, dynamic>?> restore() async {
    final session = await sessions.read();
    // Do not reuse JWTs from the previous local Python server.
    if (session != null && session['projectId'] != FirebaseConfig.projectId) {
      await sessions.clear();
      await cache.clear();
      return null;
    }
    return session;
  }

  @override
  Future<Map<String, dynamic>> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final result = await identity.post<Map<String, dynamic>>(
        name == null ? '/accounts:signInWithPassword' : '/accounts:signUp',
        queryParameters: {'key': FirebaseConfig.apiKey},
        data: {
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true,
          if (name != null) 'displayName': name.trim(),
        },
      );
      final data = result.data!;
      final session = <String, dynamic>{
        'projectId': FirebaseConfig.projectId,
        'accessToken': data['idToken'],
        'refreshToken': data['refreshToken'],
        'user': {
          'id': data['localId'],
          'email': data['email'] ?? email.trim(),
          'name':
              name?.trim() ??
              ((data['displayName'] as String?)?.isNotEmpty == true
                  ? data['displayName']
                  : email.trim().split('@').first),
        },
      };
      await sessions.write(session);
      return session;
    } on DioException catch (e) {
      throw firebaseFailure(e);
    }
  }

  /// Called by AuthInterceptor, which coalesces simultaneous refresh requests.
  Future<Map<String, dynamic>> refresh(Map<String, dynamic> old) async {
    final response = await tokenClient.post<Map<String, dynamic>>(
      '/token',
      queryParameters: {'key': FirebaseConfig.apiKey},
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'grant_type': 'refresh_token',
        'refresh_token': old['refreshToken'],
      },
    );
    return {
      ...old,
      'accessToken': response.data!['id_token'],
      'refreshToken': response.data!['refresh_token'],
    };
  }

  @override
  Future<bool> logout() async {
    // Firebase client sign-out is local; it does not revoke other devices.
    await sessions.clear();
    await cache.clear();
    return true;
  }
}

AppFailure firebaseFailure(DioException e) {
  if (isUnavailable(e)) return networkFailure(e);
  final data = e.response?.data;
  final code = data is Map && data['error'] is Map
      ? '${data['error']['message']}'.split(' : ').first
      : '';
  return AppFailure(switch (code) {
    'EMAIL_EXISTS' => 'Cet email possède déjà un compte. Connectez-vous.',
    'INVALID_LOGIN_CREDENTIALS' ||
    'INVALID_PASSWORD' ||
    'EMAIL_NOT_FOUND' => 'Email ou mot de passe incorrect.',
    'USER_DISABLED' => 'Ce compte a été désactivé.',
    'INVALID_EMAIL' => 'Saisissez une adresse email valide.',
    'WEAK_PASSWORD' => 'Choisissez un mot de passe plus robuste.',
    'TOO_MANY_ATTEMPTS_TRY_LATER' =>
      'Trop de tentatives. Réessayez dans quelques minutes.',
    'OPERATION_NOT_ALLOWED' || 'CONFIGURATION_NOT_FOUND' =>
      'La connexion Firebase n’est pas encore activée. Contactez l’administrateur.',
    _ => 'La connexion à Firebase a échoué. Veuillez réessayer.',
  });
}

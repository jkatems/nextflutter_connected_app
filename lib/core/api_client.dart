import 'package:dio/dio.dart';
import '../domain/models.dart';

bool isUnavailable(DioException e) =>
    [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.connectionError,
    ].contains(e.type) ||
    (e.response?.statusCode ?? 0) >= 500;

AppFailure networkFailure(DioException e) {
  if (e.response?.statusCode == 401) {
    return const AppFailure(
      'Session expirée. Déconnectez-vous puis reconnectez-vous.',
    );
  }
  if (isUnavailable(e)) {
    return const AppFailure(
      'Connexion impossible. Vérifiez votre réseau ou réessayez plus tard.',
    );
  }
  final data = e.response?.data;
  return AppFailure(
    data is Map && data['message'] is String
        ? data['message'] as String
        : 'La requête a échoué. Veuillez réessayer.',
  );
}

Dio createDio(String baseUrl) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    sendTimeout: const Duration(seconds: 8),
  ),
);

class AuthInterceptor extends Interceptor {
  final Dio dio, refreshDio;
  final SessionStore sessions;
  Future<Map<String, dynamic>>? _refreshing;
  AuthInterceptor(this.dio, this.refreshDio, this.sessions);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final session = await sessions.read();
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session['accessToken']}';
      }
      handler.next(options);
    } catch (e) {
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }

  Future<Map<String, dynamic>> _refresh() async {
    final old = await sessions.read();
    if (old == null) throw const AppFailure('Session absente.');
    final response = await refreshDio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': old['refreshToken']},
    );
    final current = await sessions.read();
    if (current == null || current['refreshToken'] != old['refreshToken']) {
      throw const AppFailure('Session modifiée.');
    }
    final next = response.data!;
    await sessions.write(next);
    return next;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['retried'] == true) {
      handler.next(err);
      return;
    }
    try {
      final current = await sessions.read();
      if (current == null) {
        handler.next(err);
        return;
      }
      final sent = err.requestOptions.headers['Authorization'];
      if (sent == 'Bearer ${current['accessToken']}') {
        final pending = _refreshing ??= _refresh();
        try {
          await pending;
        } finally {
          if (identical(_refreshing, pending)) _refreshing = null;
        }
      }
      final options = err.requestOptions;
      options.extra['retried'] = true;
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      // An unavailable refresh endpoint must still allow the cache fallback.
      handler.next(isUnavailable(e) ? e : err);
    } catch (_) {
      handler.next(err);
    }
  }
}

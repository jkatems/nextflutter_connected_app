import 'package:flutter/foundation.dart';
import '../domain/models.dart';

/// Presentation state depends only on domain contracts, never on Dio or Hive.
class AuthController extends ChangeNotifier {
  final AuthenticationRepository _repository;
  Map<String, dynamic>? _session;
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  AuthController(this._repository, {Map<String, dynamic>? initialSession})
    : _session = initialSession;

  Map<String, dynamic>? get session => _session;
  bool get busy => _busy;
  String? get error => _error;

  void clearError() {
    _error = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    if (_busy || _disposed) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final next = await _repository.authenticate(
        email: email,
        password: password,
        name: name,
      );
      if (!_disposed) _session = next;
    } catch (e) {
      if (!_disposed) {
        _error = e is AppFailure
            ? e.message
            : 'Impossible d’enregistrer la session. Réessayez.';
      }
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> logout() async {
    if (_busy || _disposed) {
      throw const AppFailure('Une opération est déjà en cours.');
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final revoked = await _repository.logout();
      if (!_disposed) _session = null;
      return revoked;
    } catch (e) {
      final failure = e is AppFailure
          ? e
          : const AppFailure('La déconnexion a échoué. Réessayez.');
      if (!_disposed) _error = failure.message;
      throw failure;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class FeedController extends ChangeNotifier {
  final ContentRepository _repository;
  final String category;
  Feed? _feed;
  String? _error;
  bool _loading = false;
  bool _disposed = false;
  Future<void>? _pending;

  FeedController(this._repository, this.category);

  Feed? get feed => _feed;
  String? get error => _error;
  bool get loading => _loading;

  /// Multiple gestures share one request. A disposed screen ignores its result.
  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final next = await _repository.fetch(category);
      if (!_disposed) _feed = next;
    } catch (e) {
      if (!_disposed) {
        _feed = null;
        _error = e is AppFailure
            ? e.message
            : 'Une erreur est survenue. Réessayez.';
      }
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

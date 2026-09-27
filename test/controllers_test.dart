import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:carnet/domain/models.dart';
import 'package:carnet/presentation/controllers.dart';

class PendingContent implements ContentRepository {
  int calls = 0;
  Completer<Feed> result = Completer<Feed>();
  @override
  Future<Feed> fetch(String category) {
    calls++;
    return result.future;
  }
}

class PendingAuth implements AuthenticationRepository {
  int calls = 0;
  Completer<Map<String, dynamic>> result = Completer();
  bool revoked = false;
  bool failLogout = false;
  @override
  Future<Map<String, dynamic>?> restore() async => null;
  @override
  Future<Map<String, dynamic>> authenticate({
    required String email,
    required String password,
    String? name,
  }) {
    calls++;
    return result.future;
  }

  @override
  Future<bool> logout() async {
    if (failLogout) throw const AppFailure('Nettoyage impossible');
    return revoked;
  }
}

void main() {
  final feed = Feed([], true, DateTime(2026));
  final session = <String, dynamic>{
    'user': {'id': 7, 'name': 'Alice'},
  };

  test(
    'feed deduplicates concurrent refresh and exposes loading state',
    () async {
      final repository = PendingContent();
      final controller = FeedController(repository, 'articles');
      addTearDown(controller.dispose);
      final first = controller.refresh();
      final second = controller.refresh();
      expect(controller.loading, true);
      expect(repository.calls, 1);
      repository.result.complete(feed);
      await Future.wait([first, second]);
      expect(controller.loading, false);
      expect(controller.feed, feed);
      expect(controller.error, isNull);
    },
  );

  test('feed reports failure and recovers on retry', () async {
    final repository = PendingContent();
    final controller = FeedController(repository, 'articles');
    addTearDown(controller.dispose);
    final failed = controller.refresh();
    repository.result.completeError(const AppFailure('Réseau indisponible'));
    await failed;
    expect(controller.error, 'Réseau indisponible');
    expect(controller.loading, false);
    repository.result = Completer<Feed>();
    final retry = controller.refresh();
    repository.result.complete(feed);
    await retry;
    expect(controller.error, isNull);
    expect(controller.feed, feed);
  });

  test('feed ignores response after disposal', () async {
    final repository = PendingContent();
    final controller = FeedController(repository, 'articles');
    final pending = controller.refresh();
    controller.dispose();
    repository.result.complete(feed);
    await pending;
    expect(controller.feed, isNull);
    await controller.refresh();
    expect(repository.calls, 1);
  });

  test('auth prevents duplicate submission and logs out offline', () async {
    final repository = PendingAuth();
    final controller = AuthController(repository);
    addTearDown(controller.dispose);
    final pending = controller.authenticate(
      email: 'a@b.cd',
      password: 'password',
    );
    await controller.authenticate(email: 'a@b.cd', password: 'password');
    expect(repository.calls, 1);
    expect(controller.busy, true);
    repository.result.complete(session);
    await pending;
    expect(controller.session, session);
    expect(controller.busy, false);
    expect(await controller.logout(), false);
    expect(controller.session, isNull);
  });

  test('auth exposes failure and accepts a subsequent login', () async {
    final repository = PendingAuth();
    final controller = AuthController(repository);
    addTearDown(controller.dispose);
    final pending = controller.authenticate(
      email: 'a@b.cd',
      password: 'password',
    );
    repository.result.completeError(
      const AppFailure('Identifiants incorrects'),
    );
    await pending;
    expect(controller.error, 'Identifiants incorrects');
    expect(controller.session, isNull);
    controller.clearError();
    expect(controller.error, isNull);
    repository.result = Completer();
    final retry = controller.authenticate(
      email: 'a@b.cd',
      password: 'password',
    );
    repository.result.complete(session);
    await retry;
    expect(controller.session, session);
  });

  test('auth preserves session when local logout cleanup fails', () async {
    final repository = PendingAuth()..failLogout = true;
    final controller = AuthController(repository, initialSession: session);
    addTearDown(controller.dispose);
    await expectLater(controller.logout(), throwsA(isA<AppFailure>()));
    expect(controller.session, session);
    expect(controller.busy, false);
    expect(controller.error, 'Nettoyage impossible');
  });

  test('auth ignores a login response after disposal', () async {
    final repository = PendingAuth();
    final controller = AuthController(repository);
    final pending = controller.authenticate(
      email: 'a@b.cd',
      password: 'password',
    );
    controller.dispose();
    repository.result.complete(session);
    await pending;
    expect(controller.session, isNull);
  });
}

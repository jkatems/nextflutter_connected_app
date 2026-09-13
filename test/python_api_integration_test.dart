import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:carnet/core/api_client.dart';
import 'package:carnet/data/repositories.dart';
import 'package:carnet/data/storage.dart';

void main() {
  test(
    'real Dio + Python API + SQLite + Hive survive refresh and network loss',
    () async {
      final directory = await Directory.systemTemp.createTemp('carnet-e2e-');
      final random = Random.secure();
      final secret = List.generate(
        48,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final process = await Process.start(
        'python3',
        ['-u', 'backend/server.py'],
        environment: {
          'JWT_SECRET': secret,
          'DATABASE_PATH': '${directory.path}/api.sqlite3',
          'HOST': '127.0.0.1',
          'PORT': '0',
        },
      );
      final errors = StringBuffer();
      final errorSubscription = process.stderr
          .transform(utf8.decoder)
          .listen(errors.write);
      try {
        final line = await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 20));
        final port = int.parse(line.split(' ').last);
        final baseUrl = 'http://127.0.0.1:$port';
        Hive.init(directory.path);
        var box = await Hive.openBox<String>('feeds');
        final cache = HiveFeedCache(box);
        // Platform secure storage is exercised with its official test backend;
        // HTTP, Python, SQLite and Hive in this test are real.
        FlutterSecureStorage.setMockInitialValues({});
        final sessions = SecureSessionStore(const FlutterSecureStorage());
        final public = createDio(baseUrl), dio = createDio(baseUrl);
        dio.interceptors.add(AuthInterceptor(dio, public, sessions));
        final auth = AuthRepository(public, dio, sessions, cache);
        final registered = await auth.authenticate(
          email: 'e2e@example.com',
          password: 'Test-password-123',
          name: 'Alice',
        );
        expect(await auth.logout(), true);
        await auth.authenticate(
          email: 'e2e@example.com',
          password: 'Test-password-123',
        );
        final current = (await sessions.read())!;
        // A rejected access token forces a real server refresh using the valid
        // refresh token; no sleeps or mock network responses are involved.
        await sessions.write({...current, 'accessToken': 'expired-test-token'});
        final repository = RestContentRepository(
          dio,
          cache,
          '${registered['user']['id']}',
        );
        final feeds = await Future.wait(
          ['articles', 'products', 'tasks'].map(repository.fetch),
        );
        expect(feeds.every((f) => f.items.length == 4 && !f.cached), true);
        expect(
          (await sessions.read())!['accessToken'],
          isNot('expired-test-token'),
        );
        process.kill();
        await process.exitCode;
        await box.close();
        box = await Hive.openBox<String>('feeds');
        final reopened = HiveFeedCache(box);
        final offline = RestContentRepository(
          dio,
          reopened,
          '${registered['user']['id']}',
        );
        final cached = await offline.fetch('articles');
        expect(cached.cached, true);
        expect(cached.items.first.title, feeds.first.items.first.title);
        expect(
          await AuthRepository(public, dio, sessions, reopened).logout(),
          false,
        );
        expect(await sessions.read(), isNull);
        expect(box.isEmpty, true);
        dio.close();
        public.close();
      } catch (error) {
        fail('$error\nPython stderr: $errors');
      } finally {
        process.kill();
        await process.exitCode;
        await errorSubscription.cancel();
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

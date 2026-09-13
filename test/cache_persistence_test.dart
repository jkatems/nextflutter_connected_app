import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:carnet/core/api_client.dart';
import 'package:carnet/data/repositories.dart';
import 'package:carnet/data/storage.dart';
import 'package:carnet/domain/models.dart';
import 'repository_test.dart' show Adapter, MemorySession, response, item;

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('carnet-hive-test-');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'real Hive survives box closure and a fresh offline repository',
    () async {
      var box = await Hive.openBox<String>('feeds');
      final online = createDio('http://test');
      online.httpClientAdapter = Adapter(
        (_) async => response({
          'items': [item],
        }),
      );
      final saved = await RestContentRepository(
        online,
        HiveFeedCache(box),
        '7',
      ).fetch('articles');
      await box.close();
      box = await Hive.openBox<String>('feeds');
      final offline = createDio('http://test');
      offline.httpClientAdapter = Adapter(
        (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      final cached = await RestContentRepository(
        offline,
        HiveFeedCache(box),
        '7',
      ).fetch('articles');
      expect(cached.cached, true);
      expect(cached.savedAt, saved.savedAt);
      expect(cached.items.single.toJson(), item);
      await expectLater(
        RestContentRepository(
          offline,
          HiveFeedCache(box),
          '8',
        ).fetch('articles'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'logout erases real Hive data even after reopen and with no network',
    () async {
      var box = await Hive.openBox<String>('feeds');
      final cache = HiveFeedCache(box);
      await cache.write('7/articles', {
        'items': [item],
      });
      final sessions = MemorySession()..value = {'accessToken': 'saved'};
      final offline = createDio('http://test');
      offline.httpClientAdapter = Adapter(
        (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(
        await AuthRepository(offline, offline, sessions, cache).logout(),
        false,
      );
      expect(sessions.value, isNull);
      await box.close();
      box = await Hive.openBox<String>('feeds');
      expect(box.isEmpty, true);
    },
  );
}

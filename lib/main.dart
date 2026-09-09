import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/api_client.dart';
import 'data/repositories.dart';
import 'data/storage.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    final cache = HiveFeedCache(await Hive.openBox<String>('feeds'));
    final sessions = SecureSessionStore(const FlutterSecureStorage());
    final baseUrl = const String.fromEnvironment('API_BASE_URL').isNotEmpty
        ? const String.fromEnvironment('API_BASE_URL')
        : Platform.isAndroid
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
    final public = createDio(baseUrl);
    final dio = createDio(baseUrl);
    dio.interceptors.add(AuthInterceptor(dio, public, sessions));
    final auth = AuthRepository(public, dio, sessions, cache);
    final session = await auth.restore();
    runApp(
      CarnetApp(
        auth: auth,
        repositoryFor: (id) => RestContentRepository(dio, cache, id),
        initialSession: session,
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Le stockage local est indisponible. Fermez puis relancez l’application.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

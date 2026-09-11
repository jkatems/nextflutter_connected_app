import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/api_client.dart';
import 'core/firebase_config.dart';
import 'data/firebase_auth_repository.dart';
import 'data/repositories.dart';
import 'data/storage.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    final cache = HiveFeedCache(await Hive.openBox<String>('feeds'));
    final sessions = SecureSessionStore(const FlutterSecureStorage());
    final identity = createDio(FirebaseConfig.authUrl);
    final tokens = createDio(FirebaseConfig.refreshUrl);
    final dio = createDio(FirebaseConfig.dataUrl);
    final auth = FirebaseAuthRepository(identity, tokens, sessions, cache);
    dio.interceptors.add(
      AuthInterceptor(dio, tokens, sessions, refreshSession: auth.refresh),
    );
    final session = await auth.restore();
    runApp(
      CarnetApp(
        auth: auth,
        repositoryFor: (id) =>
            RestContentRepository(dio, cache, id, firestore: true),
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
                'Impossible d’initialiser l’application. Vérifiez le stockage disponible puis relancez-la.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carnet/presentation/controllers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carnet/domain/models.dart';
import 'package:carnet/presentation/app.dart';

class FakeAuth implements AuthenticationRepository {
  int attempts = 0;
  bool reject = false;
  String? registeredName;
  @override
  Future<Map<String, dynamic>?> restore() async => null;
  @override
  Future<Map<String, dynamic>> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    attempts++;
    registeredName = name;
    if (reject) throw const AppFailure('Email ou mot de passe incorrect.');
    return {
      'user': {'id': 7, 'name': name ?? 'Alice'},
    };
  }

  @override
  Future<bool> logout() async => true;
}

class RecoveringRepository implements ContentRepository {
  bool failing = true;
  @override
  Future<Feed> fetch(String category) async {
    if (failing) {
      throw const AppFailure('Connexion impossible. Vérifiez votre réseau.');
    }
    return Feed(
      [
        const Entry(
          id: 1,
          title: 'Données retrouvées',
          body: 'Contenu',
          label: 'API',
        ),
      ],
      false,
      DateTime.now(),
    );
  }
}

void main() {
  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'alice@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'password123',
    );
  }

  testWidgets('invalid form does not call authentication repository', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => AuthController(auth),
          child: const AuthScreen(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(auth.attempts, 0);
    expect(find.text('Saisissez un email valide.'), findsOneWidget);
    expect(find.text('Entre 8 et 128 caractères.'), findsOneWidget);
  });
  testWidgets('login displays repository error and succeeds after retry', (
    tester,
  ) async {
    final auth = FakeAuth()..reject = true;
    final controller = AuthController(auth);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: controller,
          child: const AuthScreen(),
        ),
      ),
    );
    await fill(tester);
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
    expect(controller.session, isNull);
    auth.reject = false;
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(controller.session!['user']['id'], 7);
    expect(auth.attempts, 2);
  });
  testWidgets('registration sends name and opens authenticated navigation', (
    tester,
  ) async {
    final auth = FakeAuth();
    final repo = RecoveringRepository()..failing = false;
    await tester.pumpWidget(CarnetApp(auth: auth, repositoryFor: (_) => repo));
    await tester.ensureVisible(find.text('Nouveau ici ? Créer un compte'));
    await tester.tap(find.text('Nouveau ici ? Créer un compte'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Alice');
    await fill(tester);
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();
    expect(auth.registeredName, 'Alice');
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.byTooltip('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Se connecter'), findsOneWidget);
  });
  testWidgets('network error retry replaces error with API data', (
    tester,
  ) async {
    final repo = RecoveringRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedScreen(
            category: 'articles',
            title: 'Explorer',
            subtitle: 'Test',
            icon: Icons.book,
            repository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Connexion impossible'), findsOneWidget);
    repo.failing = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Données retrouvées'), findsOneWidget);
    expect(find.textContaining('Connexion impossible'), findsNothing);
  });
}

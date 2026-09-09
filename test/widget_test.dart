import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carnet/domain/models.dart';
import 'package:carnet/presentation/app.dart';

class DemoRepository implements ContentRepository {
  @override
  Future<Feed> fetch(String category) async => Feed(
    [
      Entry(
        id: 1,
        title: 'Titre $category',
        body: 'Texte complet',
        label: 'DÉMO',
      ),
    ],
    true,
    DateTime(2026, 9, 8),
  );
}

void main() {
  testWidgets('three API screens, offline status and detail navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          name: 'Alice',
          repository: DemoRepository(),
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Titre articles'), findsOneWidget);
    expect(
      find.textContaining('Hors ligne / serveur indisponible'),
      findsOneWidget,
    );
    await tester.tap(find.text('Catalogue'));
    await tester.pumpAndSettle();
    expect(find.text('Titre products'), findsOneWidget);
    await tester.tap(find.text('Tâches'));
    await tester.pumpAndSettle();
    expect(find.text('Titre tasks'), findsOneWidget);
    await tester.tap(find.text('Titre tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Votre carnet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

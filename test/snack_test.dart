// Le bouton « Annuler » est placé dans le contenu, pas dans `action:` — une
// SnackBar qui porte un SnackBarAction ne se referme jamais seule dans cette
// version de Flutter (voir util/snack.dart). Ces tests vérifient que ce
// déplacement ne se voit pas : même hauteur, même couleur qu'avant.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncwatch_mobile/theme.dart';
import 'package:syncwatch_mobile/util/snack.dart';

Future<double> hauteurApres(
    WidgetTester tester, void Function(ScaffoldMessengerState) montrer) async {
  await tester.pumpWidget(MaterialApp(
    theme: themeSyncWatch(),
    home: Scaffold(
      body: Builder(
        builder: (c) => ElevatedButton(
          onPressed: () => montrer(ScaffoldMessenger.of(c)),
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return tester.getSize(find.byType(SnackBar)).height;
}

void main() {
  const texte = 'Game of Thrones S01E01 marqué vu ✓';

  testWidgets('la barre ne grandit pas à cause du bouton', (tester) async {
    final nue = await hauteurApres(tester,
        (m) => m.showSnackBar(const SnackBar(content: Text(texte))));
    final avecBouton = await hauteurApres(
        tester,
        (m) => afficherAnnulable(m,
            texte: texte, libelleAction: 'Annuler', surAction: () {}));

    expect(avecBouton, lessThanOrEqualTo(nue + 1),
        reason: 'un TextButton ordinaire imposerait ses 36 px de hauteur');
  });

  testWidgets('le bouton reprend la couleur d\'un SnackBarAction',
      (tester) async {
    await hauteurApres(
        tester,
        (m) => afficherAnnulable(m,
            texte: texte, libelleAction: 'Annuler', surAction: () {}));

    final contexte = tester.element(find.text('Annuler'));
    final theme = Theme.of(contexte);
    final attendue = theme.snackBarTheme.actionTextColor ??
        theme.colorScheme.inversePrimary;
    final bouton = tester.widget<TextButton>(
        find.ancestor(of: find.text('Annuler'), matching: find.byType(TextButton)));

    expect(bouton.style?.foregroundColor?.resolve({}), attendue);
  });

  testWidgets('la barre se referme seule, et le bouton agit', (tester) async {
    var annule = false;
    await hauteurApres(
        tester,
        (m) => afficherAnnulable(m,
            texte: texte,
            libelleAction: 'Annuler',
            surAction: () => annule = true));

    await tester.tap(find.text('Annuler'));
    expect(annule, isTrue);
    await tester.pumpAndSettle(); // animation de sortie
    expect(find.byType(SnackBar), findsNothing);
  });
}

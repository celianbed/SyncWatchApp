// Rotation et plein écran du feed d'extraits.
//
// L'iPhone autorise le paysage dans l'Info.plist, mais aucun écran n'est
// dessiné pour : bandeaux de 230 px, cadre de téléphone de l'onboarding,
// grilles d'affiches. L'app est donc verrouillée en portrait, et seul le feed
// le déverrouille — le temps de passer une bande-annonce en grand.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Retient les orientations demandées à iOS.
  final demandes = <List<String>>[];

  setUp(() {
    demandes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (appel) async {
      if (appel.method == 'SystemChrome.setPreferredOrientations') {
        demandes.add(List<String>.from(appel.arguments as List));
      }
      return null;
    });
  });

  test('le portrait seul est demandé au démarrage', () async {
    // reproduit ce que fait main() avant runApp
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp]);

    expect(demandes.single, ['DeviceOrientation.portraitUp']);
  });

  test('le feed déverrouille les deux paysages, et rien de plus', () async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    expect(demandes.single, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    // portraitDown reste exclu : on ne veut pas de l'app à l'envers
    expect(demandes.single, isNot(contains('DeviceOrientation.portraitDown')));
  });
}

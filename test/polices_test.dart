// google_fonts ne trouve une police embarquée que si le fichier s'appelle
// exactement « Famille-Variante.ttf » et que son dossier est déclaré en assets.
// Le jour où l'un des deux lâche, l'app repasse en police système sans rien dire :
// ce test est là pour que ça se voie ici, et pas chez le premier utilisateur.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les variantes réellement demandées par le thème (cf. lib/theme.dart) :
/// Sora en 600 et 700, Inter en 400 et 600. google_fonts nomme 600 « SemiBold »,
/// 700 « Bold » et 400 « Regular ».
const _attendues = [
  'Sora-SemiBold.ttf',
  'Sora-Bold.ttf',
  'Inter-Regular.ttf',
  'Inter-SemiBold.ttf',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('les polices du thème sont embarquées sous le nom attendu', () async {
    final manifeste = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifeste.listAssets();
    for (final police in _attendues) {
      expect(assets, contains('assets/google_fonts/$police'),
          reason: '$police manque : google_fonts retomberait sur la police '
              'système, ou irait la télécharger si le réseau était autorisé.');
    }
  });

  test('la licence OFL accompagne les polices', () async {
    final manifeste = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(manifeste.listAssets(), contains('assets/google_fonts/OFL.txt'));

    final licence = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    // l'OFL impose que la licence soit distribuée avec les fichiers de police
    expect(licence, contains('SIL OPEN FONT LICENSE'));
    expect(licence, contains('Sora'));
    expect(licence, contains('Inter'));
  });
}

// google_fonts ne trouve une police embarquée que si le fichier s'appelle
// exactement « Famille-Variante.ttf » et que son dossier est déclaré en assets.
// Le jour où l'un des deux lâche, l'app repasse en police système sans rien dire :
// ce test est là pour que ça se voie ici, et pas chez le premier utilisateur.
import 'dart:io';

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

  test('aucune variante demandée par le code n\'est absente des assets', () async {
    // Le test précédent part des assets ; celui-ci part du code, et c'est le
    // seul des deux qui attrape une graisse réclamée hors liste. Cas vécu :
    // GoogleFonts.inter(w700) alors que seul Inter-SemiBold est embarqué —
    // exception au rendu du tout premier écran, invisible en analyse statique.
    const variantes = {
      100: 'Thin', 200: 'ExtraLight', 300: 'Light', 400: 'Regular',
      500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold',
      900: 'Black',
    };
    final assets =
        (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
    final appel = RegExp(r'GoogleFonts\.([a-z]\w*)\(');
    final graisse = RegExp(r'FontWeight\.w(\d00)');
    final manquantes = <String>{};

    for (final fichier in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final code = fichier.readAsStringSync();
      for (final m in appel.allMatches(code)) {
        if (m.group(1) == 'config') continue; // GoogleFonts.config n'est pas une police
        final famille = m.group(1)!;
        // corps de l'appel : on suit les parenthèses jusqu'à la fermante
        var profondeur = 0, i = m.end - 1;
        for (; i < code.length; i++) {
          if (code[i] == '(') profondeur++;
          if (code[i] == ')' && --profondeur == 0) break;
        }
        final corps = code.substring(m.end, i);
        final poids = int.parse(graisse.firstMatch(corps)?.group(1) ?? '400');
        final nom = '${famille[0].toUpperCase()}${famille.substring(1)}'
            '-${variantes[poids]}.ttf';
        if (!assets.contains('assets/google_fonts/$nom')) {
          manquantes.add('$nom (${fichier.path})');
        }
      }
    }

    expect(manquantes, isEmpty,
        reason: 'ces variantes sont demandées par le code mais absentes des '
            'assets : avec allowRuntimeFetching à false, google_fonts lève '
            'une exception au rendu.');
  });
}

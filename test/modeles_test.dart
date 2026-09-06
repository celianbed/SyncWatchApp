// Tests unitaires — helpers de format et calcul de progression.
import 'package:flutter_test/flutter_test.dart';
import 'package:syncwatch_mobile/modeles/modeles.dart';
import 'package:syncwatch_mobile/util/format.dart';

/// Saison de `nbEpisodes`, dont les `vus` premiers sont marqués vus.
SaisonAvecEpisodes saison(int num, int nbEpisodes, {int vus = 0}) =>
    SaisonAvecEpisodes.depuisJson({
      'id_saison': num,
      'num_saison': num,
      'titre': null,
      'episodes': [
        for (var i = 1; i <= nbEpisodes; i++)
          {
            'id_episode': num * 100 + i,
            'num_episode': i,
            'titre': null,
            'duree': 45,
            'date_diffusion': null,
            'vu': i <= vus,
          }
      ],
    });

ProchainEpisode prochain(int numSaison, int numEpisode) =>
    ProchainEpisode.depuisJson({
      'id_episode': 1,
      'num_saison': numSaison,
      'num_episode': numEpisode,
      'titre': null,
      'duree': null,
      'date_diffusion': null,
      'vignette': null,
      'deja_diffuse': true,
    });

void main() {
  group('formatDuree', () {
    test('moins d’une heure', () => expect(formatDuree(45), '45 min'));
    test('heures rondes', () => expect(formatDuree(120), '2 h'));
    test('heures et minutes', () => expect(formatDuree(92), '1 h 32'));
  });

  group('progressionSerie', () {
    test('exclut les saisons spéciales du total', () {
      final p = progressionSerie(
          [saison(0, 3, vus: 3), saison(1, 10), saison(2, 8)]);
      expect(p.total, 18);
      expect(p.vus, 0, reason: 'les épisodes spéciaux ne comptent pas');
    });

    test('compte les épisodes réellement vus', () {
      final p = progressionSerie(
          [saison(0, 3), saison(1, 10, vus: 10), saison(2, 8, vus: 2)]);
      expect(p.vus, 12);
    });

    test('tout vu', () {
      final p = progressionSerie([saison(1, 10, vus: 10), saison(2, 8, vus: 8)]);
      expect(p.vus, 18);
      expect(p.total, 18);
    });

    test('un trou au milieu ne se déduit plus des épisodes suivants', () {
      // c'est le cas que l'ancienne déduction ratait : dé-marquer S1E5 alors
      // que S1E6..E10 restent vus donnait « 4 vus », pas 9.
      final saisons = [saison(1, 10, vus: 10)];
      saisons.first.episodes[4].vu = false;
      expect(progressionSerie(saisons).vus, 9);
    });
  });

  test('code épisode formaté S..E..', () {
    expect(prochain(3, 5).code, 'S03E05');
  });
}

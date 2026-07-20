// Tests unitaires — helpers de format et calcul de progression.
import 'package:flutter_test/flutter_test.dart';
import 'package:syncwatch_mobile/modeles/modeles.dart';
import 'package:syncwatch_mobile/util/format.dart';

SaisonAvecEpisodes saison(int num, int nbEpisodes) =>
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
    final saisons = [saison(0, 3), saison(1, 10), saison(2, 8)];

    test('exclut les saisons spéciales du total', () {
      final p = progressionSerie(saisons, prochain(1, 1));
      expect(p.total, 18);
      expect(p.vus, 0);
    });

    test('compte les épisodes avant le prochain', () {
      final p = progressionSerie(saisons, prochain(2, 3));
      expect(p.vus, 12); // saison 1 complète + 2 épisodes de la saison 2
    });

    test('prochain null = tout vu', () {
      final p = progressionSerie(saisons, null);
      expect(p.vus, 18);
    });
  });

  test('code épisode formaté S..E..', () {
    expect(prochain(3, 5).code, 'S03E05');
  });
}

// Les horodatages arrivaient sans décalage : Dart lisait « 19:07 » comme de
// l'heure locale alors que c'était de l'UTC, et tout s'affichait deux heures
// en retard. L'API marque désormais son fuseau ; les modèles ramènent à
// l'heure de l'appareil dès l'analyse, une fois pour toutes.
import 'package:flutter_test/flutter_test.dart';
import 'package:syncwatch_mobile/modeles/modeles.dart';

NotificationPublique _notif(String dateEnvoi) =>
    NotificationPublique.depuisJson({
      'id_notification': 1,
      'type': 'abonnement',
      'contenu': 'Kenan a commencé à te suivre',
      'date_envoi': dateEnvoi,
      'lue': false,
      'id_serie': null,
      'id_film': null,
      'id_acteur': 2,
      'reference_tmdb': null,
      'cible': null,
    });

void main() {
  test('un horodatage UTC désigne le bon instant', () {
    final notif = _notif('2026-09-06T19:07:12+00:00');

    // assertion indépendante du fuseau de la machine qui exécute le test
    expect(notif.dateEnvoi.toUtc(), DateTime.utc(2026, 9, 6, 19, 7, 12));
    expect(notif.dateEnvoi.isUtc, isFalse,
        reason: 'l\'écran doit afficher l\'heure de l\'appareil');
  });

  test('le suffixe Z est accepté au même titre', () {
    expect(_notif('2026-09-06T19:07:12Z').dateEnvoi.toUtc(),
        DateTime.utc(2026, 9, 6, 19, 7, 12));
  });

  test('un horodatage sans fuseau ne fait pas planter', () {
    // les builds en circulation peuvent croiser une API pas encore déployée
    expect(() => _notif('2026-09-06T19:07:12.283238'), returnsNormally);
  });

  test('deux instants identiques écrits différemment se rejoignent', () {
    final avecZ = _notif('2026-09-06T19:07:12Z').dateEnvoi;
    final avecDecalage = _notif('2026-09-06T21:07:12+02:00').dateEnvoi;

    expect(avecZ.isAtSameMomentAs(avecDecalage), isTrue);
  });
}

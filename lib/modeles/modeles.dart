// Modèles miroirs des schémas Pydantic de l'API SyncWatch.

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);

class Utilisateur {
  final int id;
  final String adresseMail;
  final String pseudo;
  final String? avatar;
  final DateTime dateInscription;

  Utilisateur.depuisJson(Map<String, dynamic> json)
      : id = json['id_utilisateur'] as int,
        adresseMail = json['adresse_mail'] as String,
        pseudo = json['pseudo'] as String,
        avatar = json['avatar'] as String?,
        dateInscription = DateTime.parse(json['date_inscription'] as String);
}

class Genre {
  final String libelle;
  Genre.depuisJson(Map<String, dynamic> json)
      : libelle = json['libelle'] as String;
}

class SerieResume {
  final int idSerie;
  final int referenceTmdb;
  final String titre;
  final String? affiche;

  SerieResume.depuisJson(Map<String, dynamic> json)
      : idSerie = json['id_serie'] as int,
        referenceTmdb = json['reference_tmdb'] as int,
        titre = json['titre'] as String,
        affiche = json['affiche'] as String?;
}

class ProchainEpisode {
  final int idEpisode;
  final int numSaison;
  final int numEpisode;
  final String? titre;
  final int? duree;
  final DateTime? dateDiffusion;
  final String? vignette;
  final bool dejaDiffuse;

  ProchainEpisode.depuisJson(Map<String, dynamic> json)
      : idEpisode = json['id_episode'] as int,
        numSaison = json['num_saison'] as int,
        numEpisode = json['num_episode'] as int,
        titre = json['titre'] as String?,
        duree = json['duree'] as int?,
        dateDiffusion = _date(json['date_diffusion']),
        vignette = json['vignette'] as String?,
        dejaDiffuse = json['deja_diffuse'] as bool;

  /// « S03E05 »
  String get code =>
      'S${numSaison.toString().padLeft(2, '0')}E${numEpisode.toString().padLeft(2, '0')}';
}

class AccueilEntree {
  final SerieResume serie;
  final ProchainEpisode episode;

  AccueilEntree.depuisJson(Map<String, dynamic> json)
      : serie = SerieResume.depuisJson(json['serie'] as Map<String, dynamic>),
        episode =
            ProchainEpisode.depuisJson(json['episode'] as Map<String, dynamic>);
}

class CalendrierEntree {
  final SerieResume serie;
  final ProchainEpisode episode;

  CalendrierEntree.depuisJson(Map<String, dynamic> json)
      : serie = SerieResume.depuisJson(json['serie'] as Map<String, dynamic>),
        episode =
            ProchainEpisode.depuisJson(json['episode'] as Map<String, dynamic>);
}

class ResultatRecherche {
  final int referenceTmdb;
  final String type; // "serie" | "film"
  final String titre;
  final String? affiche;
  final String? imageDeFond;
  final DateTime? dateSortie;
  final double? noteMoyenne;

  ResultatRecherche.depuisJson(Map<String, dynamic> json)
      : referenceTmdb = json['reference_tmdb'] as int,
        type = json['type'] as String,
        titre = json['titre'] as String,
        affiche = json['affiche'] as String?,
        imageDeFond = json['image_de_fond'] as String?,
        dateSortie = _date(json['date_sortie']),
        noteMoyenne = (json['note_moyenne'] as num?)?.toDouble();
}

class Plateforme {
  final String nom;
  final String? logo;

  Plateforme.depuisJson(Map<String, dynamic> json)
      : nom = json['nom'] as String,
        logo = json['logo'] as String?;
}

class PlateformesVisionnage {
  final String? lien; // page TMDB « où regarder » (attribution JustWatch)
  final List<Plateforme> abonnement;
  final List<Plateforme> gratuit;
  final List<Plateforme> location;
  final List<Plateforme> achat;

  PlateformesVisionnage.depuisJson(Map<String, dynamic> json)
      : lien = json['lien'] as String?,
        abonnement = _plateformes(json['abonnement']),
        gratuit = _plateformes(json['gratuit']),
        location = _plateformes(json['location']),
        achat = _plateformes(json['achat']);

  static List<Plateforme> _plateformes(dynamic liste) => [
        for (final p in liste as List)
          Plateforme.depuisJson(p as Map<String, dynamic>)
      ];

  bool get vide =>
      abonnement.isEmpty && gratuit.isEmpty && location.isEmpty && achat.isEmpty;
}

/// Un avis de l'utilisateur courant (extrait de GET /avis/moi).
class MonAvis {
  final int idAvis;
  final int? note;
  final String? commentaire;
  final int? idSerie;
  final int? idFilm;
  final int? idEpisode;

  MonAvis.depuisJson(Map<String, dynamic> json)
      : idAvis = json['id_avis'] as int,
        note = json['note'] as int?,
        commentaire = json['commentaire'] as String?,
        idSerie = json['id_serie'] as int?,
        idFilm = json['id_film'] as int?,
        idEpisode = json['id_episode'] as int?;
}

class SeriePublique {
  final int idSerie;
  final int referenceTmdb;
  final String titre;
  final String? synopsis;
  final String? affiche;
  final String? imageDeFond;
  final String? statutDiffusion;
  final DateTime? datePremiereDiffusion;
  final double? noteMoyenneTmdb;
  final List<Genre> genres;

  SeriePublique.depuisJson(Map<String, dynamic> json)
      : idSerie = json['id_serie'] as int,
        referenceTmdb = json['reference_tmdb'] as int,
        titre = json['titre'] as String,
        synopsis = json['synopsis'] as String?,
        affiche = json['affiche'] as String?,
        imageDeFond = json['image_de_fond'] as String?,
        statutDiffusion = json['statut_diffusion'] as String?,
        datePremiereDiffusion = _date(json['date_premiere_diffusion']),
        noteMoyenneTmdb = (json['note_moyenne_tmdb'] as num?)?.toDouble(),
        genres = [
          for (final g in json['genres'] as List)
            Genre.depuisJson(g as Map<String, dynamic>)
        ];
}

class EpisodeDansSaison {
  final int idEpisode;
  final int numEpisode;
  final String? titre;
  final int? duree;
  final DateTime? dateDiffusion;

  EpisodeDansSaison.depuisJson(Map<String, dynamic> json)
      : idEpisode = json['id_episode'] as int,
        numEpisode = json['num_episode'] as int,
        titre = json['titre'] as String?,
        duree = json['duree'] as int?,
        dateDiffusion = _date(json['date_diffusion']);
}

class SaisonAvecEpisodes {
  final int idSaison;
  final int numSaison;
  final String? titre;
  final List<EpisodeDansSaison> episodes;

  SaisonAvecEpisodes.depuisJson(Map<String, dynamic> json)
      : idSaison = json['id_saison'] as int,
        numSaison = json['num_saison'] as int,
        titre = json['titre'] as String?,
        episodes = [
          for (final e in json['episodes'] as List)
            EpisodeDansSaison.depuisJson(e as Map<String, dynamic>)
        ];
}

class FilmPublic {
  final int idFilm;
  final int referenceTmdb;
  final String titre;
  final String? synopsis;
  final String? affiche;
  final int? duree;
  final DateTime? dateSortie;
  final double? noteMoyenneTmdb;
  final List<Genre> genres;

  FilmPublic.depuisJson(Map<String, dynamic> json)
      : idFilm = json['id_film'] as int,
        referenceTmdb = json['reference_tmdb'] as int,
        titre = json['titre'] as String,
        synopsis = json['synopsis'] as String?,
        affiche = json['affiche'] as String?,
        duree = json['duree'] as int?,
        dateSortie = _date(json['date_sortie']),
        noteMoyenneTmdb = (json['note_moyenne_tmdb'] as num?)?.toDouble(),
        genres = [
          for (final g in json['genres'] as List)
            Genre.depuisJson(g as Map<String, dynamic>)
        ];
}

class SuiviPublic {
  final String statutSuivi; // a_voir | en_cours | terminee | abandonnee | en_pause
  final bool favori;

  SuiviPublic.depuisJson(Map<String, dynamic> json)
      : statutSuivi = json['statut_suivi'] as String,
        favori = json['favori'] as bool;
}

const libellesStatutSuivi = {
  'a_voir': 'À voir',
  'en_cours': 'En cours',
  'terminee': 'Terminée',
  'abandonnee': 'Abandonnée',
  'en_pause': 'En pause',
};

class StatsGlobales {
  final int episodesVus;
  final int filmsVus;
  final int seriesSuivies;
  final int seriesTerminees;
  final int minutesTotales;

  StatsGlobales.depuisJson(Map<String, dynamic> json)
      : episodesVus = json['episodes_vus'] as int,
        filmsVus = json['films_vus'] as int,
        seriesSuivies = json['series_suivies'] as int,
        seriesTerminees = json['series_terminees'] as int,
        minutesTotales = json['minutes_totales'] as int;
}

class PeriodeStats {
  final DateTime periode;
  final int episodesVus;
  final int minutes;

  PeriodeStats.depuisJson(Map<String, dynamic> json)
      : periode = DateTime.parse(json['periode'] as String),
        episodesVus = json['episodes_vus'] as int,
        minutes = json['minutes'] as int;
}

class NotificationPublique {
  final int idNotification;
  final String type;
  final String contenu;
  final DateTime dateEnvoi;
  bool lue;
  final int? idSerie;
  final int? idFilm;

  NotificationPublique.depuisJson(Map<String, dynamic> json)
      : idNotification = json['id_notification'] as int,
        type = json['type'] as String,
        contenu = json['contenu'] as String,
        dateEnvoi = DateTime.parse(json['date_envoi'] as String),
        lue = json['lue'] as bool,
        idSerie = json['id_serie'] as int?,
        idFilm = json['id_film'] as int?;
}

/// Progression estimée d'une série : l'API expose le prochain épisode non vu,
/// on considère vus tous les épisodes qui le précèdent (visionnage linéaire).
/// `prochain` à null = série entièrement vue. Saisons spéciales (0) exclues.
({int vus, int total}) progressionSerie(
    List<SaisonAvecEpisodes> saisons, ProchainEpisode? prochain) {
  var vus = 0, total = 0;
  for (final saison in saisons.where((s) => s.numSaison > 0)) {
    for (final episode in saison.episodes) {
      total++;
      if (prochain == null ||
          saison.numSaison < prochain.numSaison ||
          (saison.numSaison == prochain.numSaison &&
              episode.numEpisode < prochain.numEpisode)) {
        vus++;
      }
    }
  }
  return (vus: vus, total: total);
}

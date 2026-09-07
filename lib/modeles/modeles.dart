// Modèles miroirs des schémas Pydantic de l'API SyncWatch.

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);

/// Horodatage venu de l'API, ramené à l'heure de l'appareil.
///
/// L'API sérialise en UTC avec son décalage (`...+00:00`) : sans `toLocal()`,
/// Dart afficherait l'heure UTC telle quelle, soit deux heures de retard en
/// France l'été. La conversion est faite ici, une fois, plutôt que sur chaque
/// écran — où l'oubli passait inaperçu.
DateTime _dateHeure(dynamic v) => DateTime.parse(v as String).toLocal();

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
        dateInscription = _dateHeure(json['date_inscription']);
}

/// Ligne d'utilisateur (recherche, abonnés, abonnements). `estAbonne` est mutable
/// pour les mises à jour optimistes du bouton Suivre.
class ResumeUtilisateur {
  final int idUtilisateur;
  final String pseudo;
  final String? avatar;
  final int nbSeries;
  final int nbFilms;
  bool estAbonne; // je le suis
  final bool meSuit; // il me suit

  ResumeUtilisateur.depuisJson(Map<String, dynamic> json)
      : idUtilisateur = json['id_utilisateur'] as int,
        pseudo = json['pseudo'] as String,
        avatar = json['avatar'] as String?,
        nbSeries = json['nb_series'] as int,
        nbFilms = json['nb_films'] as int,
        estAbonne = json['est_abonne'] as bool,
        meSuit = json['me_suit'] as bool;

  bool get estAmi => estAbonne && meSuit; // suivi mutuel
}

/// Profil public détaillé d'un utilisateur. `estAbonne`/`nbAbonnes` mutables (optimiste).
class ProfilPublic {
  final int idUtilisateur;
  final String pseudo;
  final String? avatar;
  final DateTime dateInscription;
  int nbAbonnes;
  final int nbAbonnements;
  final int nbSeries;
  bool estAbonne;
  final bool meSuit;

  ProfilPublic.depuisJson(Map<String, dynamic> json)
      : idUtilisateur = json['id_utilisateur'] as int,
        pseudo = json['pseudo'] as String,
        avatar = json['avatar'] as String?,
        dateInscription = _dateHeure(json['date_inscription']),
        nbAbonnes = json['nb_abonnes'] as int,
        nbAbonnements = json['nb_abonnements'] as int,
        nbSeries = json['nb_series'] as int,
        estAbonne = json['est_abonne'] as bool,
        meSuit = json['me_suit'] as bool;

  bool get estAmi => estAbonne && meSuit;
}

/// Où en est une personne suivie sur une série commune.
class ProgressionAmi {
  final int idUtilisateur;
  final String pseudo;
  final String? avatar;
  final int episodesVus;
  final int totalEpisodes;
  final String? prochainCode; // null = série terminée

  ProgressionAmi.depuisJson(Map<String, dynamic> json)
      : idUtilisateur = json['id_utilisateur'] as int,
        pseudo = json['pseudo'] as String,
        avatar = json['avatar'] as String?,
        episodesVus = json['episodes_vus'] as int,
        totalEpisodes = json['total_episodes'] as int,
        prochainCode = json['prochain_code'] as String?;

  double get fraction => totalEpisodes == 0 ? 0 : episodesVus / totalEpisodes;
  String get position =>
      prochainCode == null ? 'A terminé la série' : 'En est à $prochainCode';
}

/// Compatibilité de goûts avec un autre utilisateur.
class Compatibilite {
  final int pourcentage;
  final int titresCommuns;
  final String base; // "notes" | "titres" | "aucune"

  Compatibilite.depuisJson(Map<String, dynamic> json)
      : pourcentage = json['pourcentage'] as int,
        titresCommuns = json['titres_communs'] as int,
        base = json['base'] as String;

  bool get pertinent => base != 'aucune';

  String get detail {
    final t = '$titresCommuns titre${titresCommuns > 1 ? 's' : ''} en commun';
    return base == 'notes' ? 'vos notes concordent · $t' : t;
  }
}

/// Un avis affiché sur un profil public : titre de la cible + note (sans commentaire).
class AvisProfil {
  final int idAvis;
  final String titre;
  final String type; // "serie" | "film" | "episode"
  final int? referenceTmdb;
  final int? note;

  AvisProfil.depuisJson(Map<String, dynamic> json)
      : idAvis = json['id_avis'] as int,
        titre = json['titre'] as String,
        type = json['type'] as String,
        referenceTmdb = json['reference_tmdb'] as int?,
        note = json['note'] as int?;
}

/// Un évènement du fil d'activité (une action d'une personne suivie).
class EvenementActivite {
  final String type; // "avis" | "film_vu" | "serie_suivie"
  final DateTime date;
  final int idActeur;
  final String pseudo;
  final String? avatar;
  final String titre;
  final String typeCible; // "serie" | "film"
  final int? referenceTmdb;
  final int? note;

  EvenementActivite.depuisJson(Map<String, dynamic> json)
      : type = json['type'] as String,
        date = _dateHeure(json['date']),
        idActeur = (json['acteur'] as Map)['id_utilisateur'] as int,
        pseudo = (json['acteur'] as Map)['pseudo'] as String,
        avatar = (json['acteur'] as Map)['avatar'] as String?,
        titre = json['titre'] as String,
        typeCible = json['type_cible'] as String,
        referenceTmdb = json['reference_tmdb'] as int?,
        note = json['note'] as int?;

  /// Verbe de l'action pour la phrase « pseudo [action] titre ».
  String get action => switch (type) {
        'avis' => note != null ? 'a noté' : 'a donné son avis sur',
        'film_vu' => 'a vu',
        'serie_suivie' => 'suit maintenant',
        _ => '',
      };
}

/// Un avis d'une personne suivie, affiché sur la fiche d'un titre.
class AvisAmi {
  final int idAvis;
  final int idAuteur;
  final String pseudo;
  final String? avatar;
  final int? note;
  final String? commentaire;

  /// L'API a retiré le commentaire : cette personne est plus avancée que vous
  /// dans la série. La note, elle, ne divulgue rien et reste affichée.
  final bool masque;

  AvisAmi.depuisJson(Map<String, dynamic> json)
      : idAvis = json['id_avis'] as int,
        idAuteur = (json['utilisateur'] as Map)['id_utilisateur'] as int,
        pseudo = (json['utilisateur'] as Map)['pseudo'] as String,
        avatar = (json['utilisateur'] as Map)['avatar'] as String?,
        note = json['note'] as int?,
        commentaire = json['commentaire'] as String?,
        masque = json['masque'] as bool? ?? false;
}

/// Une tête d'affiche, telle que l'API la renvoie pour la personne connectée.
class MembreCasting {
  final int idActeur;
  final String nom;
  final String? photo;
  final String? personnage;

  /// Nombre d'AUTRES titres de mon historique où cette personne joue.
  final int dejaVuDans;

  MembreCasting.depuisJson(Map<String, dynamic> json)
      : idActeur = json['id_acteur'] as int,
        nom = json['nom'] as String,
        photo = json['photo'] as String?,
        personnage = json['personnage'] as String?,
        dejaVuDans = json['deja_vu_dans'] as int? ?? 0;
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

  /// Construit l'entrée depuis les saisons déjà en cache, pour avancer d'un
  /// épisode sans redemander au serveur. La vignette manque — `saisons` ne la
  /// porte pas — et la carte retombe alors sur l'affiche de la série.
  ProchainEpisode.local(EpisodeDansSaison episode, int saison)
      : idEpisode = episode.idEpisode,
        numSaison = saison,
        numEpisode = episode.numEpisode,
        titre = episode.titre,
        duree = episode.duree,
        dateDiffusion = episode.dateDiffusion,
        vignette = null,
        dejaDiffuse = episode.diffuse;

  /// « S03E05 »
  String get code =>
      'S${numSaison.toString().padLeft(2, '0')}E${numEpisode.toString().padLeft(2, '0')}';
}

/// Premier épisode diffusé et non vu, saisons spéciales exclues — la même
/// règle que l'API applique pour l'accueil, appliquée ici sur le cache local.
ProchainEpisode? prochainNonVu(List<SaisonAvecEpisodes> saisons) {
  for (final saison in saisons.where((s) => s.numSaison > 0)) {
    for (final episode in saison.episodes) {
      if (!episode.vu && episode.diffuse) {
        return ProchainEpisode.local(episode, saison.numSaison);
      }
    }
  }
  return null; // tout le diffusé est vu : la série sort de l'accueil
}

class AccueilEntree {
  final SerieResume serie;
  final ProchainEpisode episode;

  const AccueilEntree({required this.serie, required this.episode});

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

/// Une entrée du feed « Extraits » : un titre en tendance + sa bande-annonce.
class ExtraitFeed {
  final int referenceTmdb;
  final String type; // "serie" | "film"
  final String titre;
  final String? affiche;
  final String? imageDeFond;
  final String? apercu;
  final int? annee;
  final double? noteMoyenne;
  final String cleYoutube;

  ExtraitFeed.depuisJson(Map<String, dynamic> json)
      : referenceTmdb = json['reference_tmdb'] as int,
        type = json['type'] as String,
        titre = json['titre'] as String,
        affiche = json['affiche'] as String?,
        imageDeFond = json['image_de_fond'] as String?,
        apercu = json['apercu'] as String?,
        annee = json['annee'] as int?,
        noteMoyenne = (json['note_moyenne'] as num?)?.toDouble(),
        cleYoutube = json['cle_youtube'] as String;

  bool get estSerie => type == 'serie';
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

  /// Vu par moi. Mutable : les bascules de la fiche l'écrivent avant la
  /// réponse du serveur, et la remettent en place si l'appel échoue.
  bool vu;

  EpisodeDansSaison.depuisJson(Map<String, dynamic> json)
      : idEpisode = json['id_episode'] as int,
        numEpisode = json['num_episode'] as int,
        titre = json['titre'] as String?,
        duree = json['duree'] as int?,
        dateDiffusion = _date(json['date_diffusion']),
        vu = json['vu'] as bool? ?? false;

  /// Un épisode non encore diffusé ne se marque pas vu.
  bool get diffuse =>
      dateDiffusion != null && !dateDiffusion!.isAfter(DateTime.now());
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
  final int seriesTerminees;
  final int minutesTotales;

  StatsGlobales.depuisJson(Map<String, dynamic> json)
      : episodesVus = json['episodes_vus'] as int,
        filmsVus = json['films_vus'] as int,
        seriesTerminees = json['series_terminees'] as int,
        minutesTotales = json['minutes_totales'] as int;
}

class PeriodeStats {
  final DateTime periode;
  final int episodesVus;
  final int filmsVus;
  final int minutes; // épisodes + films confondus

  PeriodeStats.depuisJson(Map<String, dynamic> json)
      : periode = DateTime.parse(json['periode'] as String),
        episodesVus = json['episodes_vus'] as int,
        filmsVus = json['films_vus'] as int,
        minutes = json['minutes'] as int;

  /// Total de visionnages de la semaine (un épisode et un film comptent chacun 1).
  int get visionnages => episodesVus + filmsVus;
}

class NotificationPublique {
  final int idNotification;
  final String type;
  final String contenu;
  final DateTime dateEnvoi;
  bool lue;
  final int? idSerie;
  final int? idFilm;
  final int? idActeur; // notif sociale : profil à ouvrir au tap
  // cible de navigation (fiche à ouvrir au tap), résolue par l'API
  final int? referenceTmdb;
  final String? cible; // "serie" | "film"

  NotificationPublique.depuisJson(Map<String, dynamic> json)
      : idNotification = json['id_notification'] as int,
        type = json['type'] as String,
        contenu = json['contenu'] as String,
        dateEnvoi = _dateHeure(json['date_envoi']),
        lue = json['lue'] as bool,
        idSerie = json['id_serie'] as int?,
        idFilm = json['id_film'] as int?,
        idActeur = json['id_acteur'] as int?,
        referenceTmdb = json['reference_tmdb'] as int?,
        cible = json['cible'] as String?;
}

/// Progression d'une série, comptée sur l'état réel de chaque épisode.
/// Saisons spéciales (0) exclues. Auparavant elle était déduite du « prochain
/// épisode non vu » — tout ce qui le précédait était compté vu ; dé-marquer un
/// épisode au milieu rendait ce raccourci faux.
({int vus, int total}) progressionSerie(List<SaisonAvecEpisodes> saisons) {
  var vus = 0, total = 0;
  for (final saison in saisons.where((s) => s.numSaison > 0)) {
    for (final episode in saison.episodes) {
      total++;
      if (episode.vu) vus++;
    }
  }
  return (vus: vus, total: total);
}

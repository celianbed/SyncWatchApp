// Onboarding — carrousel de présentation affiché au premier lancement,
// avant la connexion. Le drapeau « vu » est conservé par la Session.
//
// Chaque diapo montre une maquette de l'écran concerné plutôt qu'une icône.
// Ces maquettes sont redessinées ici avec les jetons de la charte plutôt que
// d'être des captures embarquées : rien à charger (une affiche TMDB dépendrait
// du réseau, et un cadre vide ferait une piètre première impression), rien à
// régénérer à chaque retouche d'interface, et aucun poids ajouté à l'app.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../api/session.dart';
import '../theme.dart';
import '../widgets/halo.dart';

class _Diapo {
  final String titre;
  final String texte;

  /// Teinte dominante : les halos du fond et la pastille active s'y accordent.
  final Color couleur;
  final Widget maquette;

  const _Diapo({
    required this.titre,
    required this.texte,
    required this.couleur,
    required this.maquette,
  });
}

const _diapos = [
  _Diapo(
    titre: 'Tes séries et tes films,\nau même endroit.',
    texte:
        'Cherche un titre, suis-le, et retrouve tout ton suivi sur un seul écran.',
    couleur: CouleursSW.accent,
    maquette: _MaquetteBibliotheque(),
  ),
  _Diapo(
    titre: 'Reprends exactement\noù tu t’étais arrêté.',
    texte:
        'Marque tes épisodes vus : SyncWatch te propose le prochain à regarder chaque soir.',
    couleur: CouleursSW.succes,
    maquette: _MaquetteReprise(),
  ),
  _Diapo(
    titre: 'Ne rate plus\naucune sortie.',
    texte:
        'Nouvel épisode, nouvelle saison ou film attendu : tu es prévenu dès la diffusion.',
    couleur: CouleursSW.accentSecondaire,
    maquette: _MaquetteNotification(),
  ),
];

class EcranOnboarding extends StatefulWidget {
  const EcranOnboarding({super.key});

  @override
  State<EcranOnboarding> createState() => _EcranOnboardingState();
}

class _EcranOnboardingState extends State<EcranOnboarding> {
  final _pages = PageController();
  int _index = 0;

  bool get _derniere => _index == _diapos.length - 1;

  /// Position continue du carrousel (1.4 = entre la 2e et la 3e diapo). C'est
  /// elle qui pilote la parallaxe et la teinte, plutôt que l'index entier :
  /// sinon tout sauterait d'un coup en fin de glissement.
  double get _position =>
      _pages.hasClients ? (_pages.page ?? _index.toDouble()) : _index.toDouble();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _terminer() => context.read<Session>().terminerOnboarding();

  void _suivant() {
    if (_derniere) {
      _terminer();
    } else {
      _pages.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    }
  }

  /// Teinte interpolée entre la diapo courante et la suivante.
  Color _teinte() {
    final p = _position.clamp(0.0, (_diapos.length - 1).toDouble());
    final bas = p.floor(), haut = p.ceil();
    return Color.lerp(_diapos[bas].couleur, _diapos[haut].couleur, p - bas)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // rebâtit à chaque pixel de glissement : la parallaxe et les halos suivent
      body: AnimatedBuilder(
        animation: _pages,
        builder: (context, _) {
          final teinte = _teinte();
          return Stack(
            children: [
              Halo(couleur: teinte, alignement: const Alignment(-1.2, -0.9)),
              const Halo(
                  couleur: CouleursSW.accentSecondaire,
                  alignement: Alignment(1.3, 1.0)),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4),
                        child: TextButton(
                          onPressed: _terminer,
                          child: const Text('Passer',
                              style:
                                  TextStyle(color: CouleursSW.texteSecondaire)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: _diapos.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => _PageDiapo(
                          diapo: _diapos[i],
                          // <0 : la diapo est déjà passée ; >0 : elle arrive
                          ecart: i - _position,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _diapos.length; i++)
                          _Point(actif: i == _index, couleur: teinte),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: ElevatedButton(
                        onPressed: _suivant,
                        child: Text(_derniere ? 'C’est parti !' : 'Suivant'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Une diapo. [ecart] vaut 0 quand elle est centrée, ±1 à une page de distance.
/// Maquette et texte s'en servent pour se décaler à des vitesses différentes —
/// c'est ce décalage qui donne la profondeur — et s'effacer sur les bords.
class _PageDiapo extends StatelessWidget {
  final _Diapo diapo;
  final double ecart;

  const _PageDiapo({required this.diapo, required this.ecart});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final distance = ecart.abs().clamp(0.0, 1.0);
    final opacite = 1 - distance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              // la maquette traîne derrière le glissement et s'éloigne un peu
              child: Transform.translate(
                offset: Offset(ecart * -70, 0),
                child: Transform.scale(
                  scale: 1 - distance * .08,
                  child: Opacity(
                    opacity: opacite,
                    child: _CadreTelephone(
                        teinte: diapo.couleur, child: diapo.maquette),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // le texte suit plus vite que la maquette, et monte en se révélant
          Transform.translate(
            offset: Offset(ecart * 30, distance * 18),
            child: Opacity(
              opacity: opacite,
              child: Column(
                children: [
                  Text(diapo.titre,
                      textAlign: TextAlign.center,
                      style: typo.headlineMedium?.copyWith(height: 1.25)),
                  const SizedBox(height: 12),
                  Text(diapo.texte,
                      textAlign: TextAlign.center,
                      style: typo.bodySmall?.copyWith(height: 1.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Cadre de téléphone légèrement incliné, dans lequel vit chaque maquette.
class _CadreTelephone extends StatelessWidget {
  final Color teinte;
  final Widget child;

  const _CadreTelephone({required this.teinte, required this.child});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -.045, // ~2,6° : assez pour donner du relief, pas pour déranger
      child: Container(
        width: 228,
        height: 296,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: CouleursSW.fond,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: CouleursSW.surface, width: 2),
          boxShadow: [
            BoxShadow(
              color: teinte.withValues(alpha: .22),
              blurRadius: 40,
              spreadRadius: -6,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Container(
            color: CouleursSW.fond,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Maquettes. Aucune donnée réelle, aucune image distante : des formes qui
// reprennent les couleurs, rayons et polices de la charte.
// ---------------------------------------------------------------------------

/// Grille d'affiches — la bibliothèque.
class _MaquetteBibliotheque extends StatelessWidget {
  const _MaquetteBibliotheque();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BarreRecherche(),
        const SizedBox(height: 12),
        const _Etiquette('MES SÉRIES'),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            childAspectRatio: 2 / 3,
            padding: EdgeInsets.zero,
            children: const [
              _Affiche(CouleursSW.accent),
              _Affiche(CouleursSW.accentSecondaire),
              _Affiche(CouleursSW.succes),
              _Affiche(CouleursSW.accentSecondaire),
              _Affiche(CouleursSW.accent),
              _Affiche(CouleursSW.danger),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cartes « à regarder ce soir » avec progression — la reprise.
class _MaquetteReprise extends StatelessWidget {
  const _MaquetteReprise();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Etiquette('À REGARDER CE SOIR'),
        const SizedBox(height: 10),
        const _CarteReprise(
            teinte: CouleursSW.accent, largeurTitre: 74, progression: .62),
        const SizedBox(height: 8),
        const _CarteReprise(
            teinte: CouleursSW.accentSecondaire,
            largeurTitre: 56,
            progression: .3),
        const SizedBox(height: 8),
        const _CarteReprise(
            teinte: CouleursSW.danger, largeurTitre: 64, progression: .85),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.check_circle, size: 15, color: CouleursSW.succes),
            const SizedBox(width: 6),
            Text('Épisode marqué vu',
                style: GoogleFonts.inter(
                    fontSize: 9, color: CouleursSW.texteSecondaire)),
          ],
        ),
      ],
    );
  }
}

/// Bannière de notification posée sur une fiche — les sorties.
class _MaquetteNotification extends StatelessWidget {
  const _MaquetteNotification();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 44),
            Container(
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CouleursSW.accent.withValues(alpha: .55),
                    CouleursSW.accentSecondaire.withValues(alpha: .3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _Barre(largeur: 96, hauteur: 9),
            const SizedBox(height: 7),
            const _Barre(largeur: 130, hauteur: 6, attenuee: true),
            const SizedBox(height: 5),
            const _Barre(largeur: 110, hauteur: 6, attenuee: true),
            const Spacer(),
            const _Etiquette('SAISON 3 · ÉPISODE 1'),
          ],
        ),
        // la bannière système, posée par-dessus
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: CouleursSW.surface,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .45),
                  blurRadius: 14,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: CouleursSW.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 13, color: Colors.white),
              ),
              const SizedBox(width: 7),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SyncWatch',
                      // w600 : seul Inter-SemiBold est embarqué, pas Bold.
                      // À 8 px la différence ne se voit pas, et embarquer une
                      // troisième variante pour ça alourdirait l'app.
                      style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: CouleursSW.texte)),
                  const SizedBox(height: 3),
                  const _Barre(largeur: 104, hauteur: 5, attenuee: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- petites pièces communes aux maquettes ---------------------------------

class _BarreRecherche extends StatelessWidget {
  const _BarreRecherche();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: CouleursSW.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, size: 12, color: CouleursSW.texteSecondaire),
          SizedBox(width: 6),
          _Barre(largeur: 70, hauteur: 5, attenuee: true),
        ],
      ),
    );
  }
}

class _Affiche extends StatelessWidget {
  final Color teinte;
  const _Affiche(this.teinte);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            teinte.withValues(alpha: .65),
            teinte.withValues(alpha: .22),
          ],
        ),
      ),
    );
  }
}

class _CarteReprise extends StatelessWidget {
  final Color teinte;
  final double largeurTitre;
  final double progression;

  const _CarteReprise({
    required this.teinte,
    required this.largeurTitre,
    required this.progression,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: CouleursSW.surface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: [
                teinte.withValues(alpha: .7),
                teinte.withValues(alpha: .28),
              ]),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Barre(largeur: largeurTitre, hauteur: 6),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progression,
                    minHeight: 3,
                    backgroundColor: CouleursSW.fond,
                    color: CouleursSW.succes,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.check_circle_outline,
              size: 15, color: CouleursSW.texteSecondaire),
        ],
      ),
    );
  }
}

/// Trait qui tient lieu de texte dans les maquettes.
class _Barre extends StatelessWidget {
  final double largeur;
  final double hauteur;
  final bool attenuee;

  const _Barre(
      {required this.largeur, required this.hauteur, this.attenuee = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        color: (attenuee ? CouleursSW.texteSecondaire : CouleursSW.texte)
            .withValues(alpha: attenuee ? .3 : .55),
        borderRadius: BorderRadius.circular(hauteur / 2),
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  final String texte;
  const _Etiquette(this.texte);

  @override
  Widget build(BuildContext context) {
    return Text(texte,
        style: GoogleFonts.inter(
            fontSize: 7.5,
            fontWeight: FontWeight.w600, // Inter-Bold n'est pas embarqué
            letterSpacing: .9,
            color: CouleursSW.texteSecondaire));
  }
}

class _Point extends StatelessWidget {
  final bool actif;
  final Color couleur;
  const _Point({required this.actif, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: actif ? 22 : 7,
      height: 7,
      decoration: BoxDecoration(
        color:
            actif ? couleur : CouleursSW.texteSecondaire.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

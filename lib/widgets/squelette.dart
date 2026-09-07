// Squelettes de chargement — l'ossature du contenu à venir, à la place d'un
// disque qui tourne au milieu du vide.
//
// Deux raisons de préférer ça. D'abord la perception : une page qui prend déjà
// sa forme paraît plus rapide qu'un spinner, à durée identique. Ensuite la
// stabilité : le contenu s'installe là où le squelette l'annonçait, sans le
// sursaut de mise en page qui suit un spinner centré.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../theme.dart';

/// Bloc gris qui respire doucement. Brique de base de tous les squelettes.
class Squelette extends StatefulWidget {
  final double? largeur;
  final double hauteur;
  final double rayon;

  const Squelette({
    super.key,
    this.largeur,
    required this.hauteur,
    this.rayon = 8,
  });

  /// Trait de texte : la largeur suggère la longueur de la ligne à venir.
  const Squelette.ligne({super.key, required this.largeur, this.hauteur = 12})
      : rayon = 6;

  @override
  State<Squelette> createState() => _SqueletteState();
}

class _SqueletteState extends State<Squelette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulsation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respecter « Réduire les animations » : une pulsation permanente est
    // pénible, voire nauséeuse, pour qui a activé ce réglage système.
    final anime = !MediaQuery.disableAnimationsOf(context);
    final forme = BoxDecoration(
      color: CouleursSW.surface,
      borderRadius: BorderRadius.circular(widget.rayon),
    );

    if (!anime) {
      return Container(
          width: widget.largeur, height: widget.hauteur, decoration: forme);
    }
    return FadeTransition(
      opacity: Tween<double>(begin: .45, end: .9).animate(
          CurvedAnimation(parent: _pulsation, curve: Curves.easeInOut)),
      child: Container(
          width: widget.largeur, height: widget.hauteur, decoration: forme),
    );
  }
}

/// Rangée d'affiches — carrousels « Tendances », « Reprendre », « À voir »…
class SqueletteCarrousel extends StatelessWidget {
  final double hauteur;
  final int nombre;

  const SqueletteCarrousel({super.key, this.hauteur = 150, this.nombre = 4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: nombre,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Squelette(
            largeur: hauteur * 2 / 3, hauteur: hauteur, rayon: 12),
      ),
    );
  }
}

/// Cartes empilées — accueil, notifications, listes de personnes.
class SqueletteListe extends StatelessWidget {
  final int nombre;
  final double hauteur;
  final EdgeInsets marge;

  const SqueletteListe({
    super.key,
    this.nombre = 5,
    this.hauteur = 76,
    this.marge = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: marge.add(const EdgeInsets.symmetric(vertical: 16)),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: nombre,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Squelette(hauteur: hauteur, rayon: 16),
    );
  }
}

/// Fiche série ou film : bandeau, titre, boutons, puis blocs de contenu.
/// Reprend la géométrie réelle de la page pour que rien ne bouge à l'arrivée.
class SqueletteFiche extends StatelessWidget {
  const SqueletteFiche({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Squelette(hauteur: 230, rayon: 0),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Squelette.ligne(largeur: 220, hauteur: 24),
              const SizedBox(height: 12),
              Row(children: const [
                Squelette(largeur: 70, hauteur: 22, rayon: 8),
                SizedBox(width: 8),
                Squelette(largeur: 90, hauteur: 22, rayon: 8),
              ]),
              const SizedBox(height: 16),
              const Squelette.ligne(largeur: 150),
              const SizedBox(height: 20),
              Row(children: const [
                Expanded(child: Squelette(hauteur: 66, rayon: 16)),
                SizedBox(width: 12),
                Expanded(child: Squelette(hauteur: 66, rayon: 16)),
              ]),
              const SizedBox(height: 12),
              const Squelette(hauteur: 48, rayon: 14),
              const SizedBox(height: 20),
              const Squelette(hauteur: 62, rayon: 16),
              const SizedBox(height: 12),
              const Squelette(hauteur: 62, rayon: 16),
              const SizedBox(height: 24),
              const Squelette.ligne(largeur: double.infinity),
              const SizedBox(height: 8),
              const Squelette.ligne(largeur: double.infinity),
              const SizedBox(height: 8),
              const Squelette.ligne(largeur: 180),
            ],
          ),
        ),
      ],
    );
  }
}

/// Le mot d'explication quand le serveur sort de veille, posé au-dessus d'un
/// squelette : le réveil peut durer près d'une minute, et une ossature muette
/// pendant tout ce temps se lit comme une application figée.
class AvecMentionReveil extends StatelessWidget {
  final Widget child;
  const AvecMentionReveil({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: ValueListenableBuilder<bool>(
            valueListenable: api.reveil,
            builder: (context, reveil, _) => reveil
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: CouleursSW.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Réveil du serveur…',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// Onboarding — carrousel de présentation affiché au premier lancement,
// avant la connexion. Le drapeau « vu » est conservé par la Session.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/session.dart';
import '../theme.dart';
import '../widgets/halo.dart';

class _Diapo {
  final IconData icone;
  final String titre;
  final String texte;
  const _Diapo({required this.icone, required this.titre, required this.texte});
}

const _diapos = [
  _Diapo(
    icone: Icons.subscriptions_outlined,
    titre: 'Tes séries et tes films,\nau même endroit.',
    texte:
        'Cherche un titre, suis-le, et retrouve tout ton suivi sur un seul écran.',
  ),
  _Diapo(
    icone: Icons.playlist_add_check_rounded,
    titre: 'Reprends exactement\noù tu t’étais arrêté.',
    texte:
        'Marque tes épisodes vus : SyncWatch te propose le prochain à regarder chaque soir.',
  ),
  _Diapo(
    icone: Icons.notifications_active_outlined,
    titre: 'Ne rate plus\naucune sortie.',
    texte:
        'Nouvel épisode, nouvelle saison ou film attendu : tu es prévenu dès la diffusion.',
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
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Halo(
              couleur: CouleursSW.accent, alignement: Alignment(-1.2, -0.9)),
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
                    itemBuilder: (_, i) => _PageDiapo(diapo: _diapos[i]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _diapos.length; i++) _Point(actif: i == _index),
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
      ),
    );
  }
}

class _PageDiapo extends StatelessWidget {
  final _Diapo diapo;
  const _PageDiapo({required this.diapo});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CouleursSW.accent.withValues(alpha: .25),
                  CouleursSW.accentSecondaire.withValues(alpha: .15),
                ],
              ),
              border: Border.all(
                  color: CouleursSW.accent.withValues(alpha: .35)),
            ),
            child: Icon(diapo.icone, size: 56, color: CouleursSW.accent),
          ),
          const SizedBox(height: 40),
          Text(diapo.titre,
              style: typo.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(diapo.texte, style: typo.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final bool actif;
  const _Point({required this.actif});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: actif ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: actif ? CouleursSW.accent : CouleursSW.surface,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

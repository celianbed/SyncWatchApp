// Coquille de navigation : Accueil · Extraits · Recherche · Calendrier · Stats · Profil.
// 6 onglets → on n'affiche que le label sélectionné (sinon les labels de longueurs
// différentes rendent la barre visuellement mal répartie sur écran étroit).
import 'package:flutter/material.dart';

import 'ecran_accueil.dart';
import 'ecran_calendrier.dart';
import 'ecran_decouverte.dart';
import 'ecran_profil.dart';
import 'ecran_recherche.dart';
import 'ecran_stats.dart';

class Coquille extends StatefulWidget {
  const Coquille({super.key});

  @override
  State<Coquille> createState() => _CoquilleState();
}

class _CoquilleState extends State<Coquille> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const EcranAccueil(),
          EcranDecouverte(actif: _index == 1),
          const EcranRecherche(),
          const EcranCalendrier(),
          const EcranStats(),
          EcranProfil(onOuvrirRecherche: () => setState(() => _index = 2)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              selectedIcon: Icon(Icons.play_circle),
              label: 'Extraits'),
          NavigationDestination(
              icon: Icon(Icons.search), label: 'Recherche'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendrier'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Stats'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }
}

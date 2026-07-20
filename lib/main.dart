// SyncWatch — application mobile iOS (Flutter).
// Point d'entrée : restaure la session puis affiche connexion ou l'app.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/session.dart';
import 'ecrans/coquille.dart';
import 'ecrans/ecran_connexion.dart';
import 'ecrans/ecran_onboarding.dart';
import 'theme.dart';

void main() {
  runApp(const AppSyncWatch());
}

class AppSyncWatch extends StatelessWidget {
  const AppSyncWatch({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Session()..restaurer(),
      child: MaterialApp(
        title: 'SyncWatch',
        debugShowCheckedModeBanner: false,
        theme: themeSyncWatch(),
        home: Consumer<Session>(
          builder: (_, session, _) {
            if (!session.pret) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (session.connecte) return const Coquille();
            // premier lancement : présentation de l'app avant la connexion
            return session.onboardingVu
                ? const EcranConnexion()
                : const EcranOnboarding();
          },
        ),
      ),
    );
  }
}

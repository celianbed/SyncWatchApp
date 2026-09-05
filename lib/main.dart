// SyncWatch — application mobile iOS (Flutter).
// Point d'entrée : restaure la session puis affiche connexion ou l'app.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'api/session.dart';
import 'ecrans/coquille.dart';
import 'ecrans/ecran_connexion.dart';
import 'ecrans/ecran_onboarding.dart';
import 'services/push.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Les polices sont embarquées dans assets/google_fonts/ : on interdit le
  // téléchargement à l'exécution, pour que la typographie soit juste dès le
  // premier lancement et sans réseau. Une variante non embarquée retombe alors
  // sur la police système, en le signalant dans la console.
  GoogleFonts.config.allowRuntimeFetching = false;

  // L'OFL exige que la licence accompagne les polices distribuées.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['google_fonts'], await rootBundle.loadString('assets/google_fonts/OFL.txt'));
  });

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
        navigatorKey: navigatorKey, // ouverture d'une fiche depuis une notif push
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

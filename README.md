# SyncWatch App

Application mobile (Flutter, iOS) du projet SyncWatch : suivi de séries et
de films, marquage des épisodes vus, prochain épisode à regarder, avis,
statistiques et notifications de diffusion.

Consomme l'API du dépôt séparé `SyncWatchAPI`.

## Stack

Flutter (iOS) · Provider · flutter_secure_storage (JWT dans le trousseau) ·
charte graphique et maquettes Figma (dark, Sora/Inter).

## Lancer en local

```bash
flutter run                      # API en prod (https://syncwatch-b3tv.onrender.com)
flutter run --dart-define=SYNCWATCH_API=http://127.0.0.1:8000   # API locale
```

L'app vise le simulateur iOS ; l'URL de l'API se change au lancement via
`--dart-define=SYNCWATCH_API=…`.

## Configuration iOS

Trois choses ne vivent pas dans le code et doivent être en place avant de
compiler pour un vrai appareil :

- **Notifications** — la capability *Push Notifications* passe par
  `ios/Runner/Runner.entitlements` (`aps-environment`). Xcode bascule seul sur
  `production` à l'archivage. Il faut en plus une clé APNs (.p8) déposée dans la
  console Firebase, sans quoi FCM ne peut rien remettre à APNs.
- **Sign in with Apple** — capability déclarée dans le même fichier
  d'entitlements, et à activer sur l'App ID dans le portail Apple Developer.
- **Google Sign-In** — dépend de deux clés d'`Info.plist` dérivées de
  `GoogleService-Info.plist`. Après tout changement de projet Firebase :

  ```bash
  ./ios/scripts/configurer_google_signin.sh
  ```

- **Polices** — Sora et Inter sont embarquées dans `assets/google_fonts/` et le
  téléchargement à l'exécution est coupé (`allowRuntimeFetching = false`), pour
  que la typographie soit juste dès le premier lancement et hors ligne. Ajouter
  une graisse au thème suppose d'ajouter le `.ttf` correspondant, nommé
  `Famille-Variante.ttf` — `test/polices_test.dart` le vérifie.

Le simulateur ne délivre pas de jeton APNs : les push se testent sur un appareil
réel (l'app le détecte et n'enregistre alors aucun appareil).

## Tests

```bash
flutter test
```

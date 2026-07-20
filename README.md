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

## Tests

```bash
flutter test
```

// Affiche l'état d'un Future de façon uniforme : spinner pendant le chargement,
// message clair + bouton « Réessayer » en cas d'erreur, sinon le contenu.
// Évite de recopier FutureBuilder + gestion loading/erreur dans chaque écran.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../theme.dart';

class ChargeurAsync<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T donnees) enfant;

  /// Optionnel : affiche un bouton « Réessayer » qui déclenche ce rappel.
  final VoidCallback? surReessayer;

  const ChargeurAsync({
    super.key,
    required this.future,
    required this.enfant,
    this.surReessayer,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Attente();
        }
        if (snap.hasError) {
          return _Erreur(
            message: snap.error is ExceptionApi
                ? (snap.error as ExceptionApi).message
                : 'Une erreur est survenue.',
            surReessayer: surReessayer,
          );
        }
        return enfant(snap.data as T);
      },
    );
  }
}

/// Spinner, qui s'accompagne d'un mot d'explication quand le serveur sort de
/// veille : le réveil peut durer près d'une minute, et un spinner muet pendant
/// tout ce temps se lit comme une application cassée.
class _Attente extends StatelessWidget {
  const _Attente();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<bool>(
        valueListenable: api.reveil,
        builder: (context, reveil, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (reveil) ...[
              const SizedBox(height: 16),
              Text('Réveil du serveur…',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}


class _Erreur extends StatelessWidget {
  final String message;
  final VoidCallback? surReessayer;
  const _Erreur({required this.message, this.surReessayer});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 44, color: CouleursSW.texteSecondaire),
            const SizedBox(height: 12),
            Text(message, style: typo.bodyMedium, textAlign: TextAlign.center),
            if (surReessayer != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: surReessayer,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

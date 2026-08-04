// Notifications — liste, pastille non-lu, « Tout marquer lu ».
// Wireframe W5 · Notifications.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import '../util/format.dart';
import 'ecran_fiche_film.dart';
import 'ecran_fiche_serie.dart';
import 'ecran_profil_public.dart';

class EcranNotifications extends StatefulWidget {
  const EcranNotifications({super.key});

  @override
  State<EcranNotifications> createState() => _EcranNotificationsState();
}

class _EcranNotificationsState extends State<EcranNotifications> {
  List<NotificationPublique>? _notifications;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final donnees = await api.get('/notifications') as List;
      if (!mounted) return;
      setState(() => _notifications = [
            for (final n in donnees)
              NotificationPublique.depuisJson(n as Map<String, dynamic>)
          ]);
    } catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    }
  }

  Future<void> _marquerLue(NotificationPublique notification) async {
    if (notification.lue) return;
    setState(() => notification.lue = true); // optimiste
    try {
      await api.patch('/notifications/${notification.idNotification}/lue');
    } on ExceptionApi {
      if (mounted) setState(() => notification.lue = false);
    }
  }

  /// Tap : marque lu et ouvre la fiche liée (série/film), sinon le profil de
  /// l'acteur pour une notif sociale (abonnement).
  void _ouvrir(NotificationPublique notification) {
    _marquerLue(notification); // en arrière-plan (optimiste)
    final ref = notification.referenceTmdb;
    if (ref != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => notification.cible == 'film'
              ? EcranFicheFilm(referenceTmdb: ref)
              : EcranFicheSerie(referenceTmdb: ref)));
      return;
    }
    final acteur = notification.idActeur;
    if (acteur != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EcranProfilPublic(idUtilisateur: acteur)));
    }
  }

  Future<void> _toutMarquerLu() async {
    final nonLues = _notifications?.where((n) => !n.lue).toList() ?? [];
    for (final notification in nonLues) {
      await _marquerLue(notification);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    final notifications = _notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications != null && notifications.any((n) => !n.lue))
            TextButton(
                onPressed: _toutMarquerLu, child: const Text('Tout marquer lu')),
          const SizedBox(width: 8),
        ],
      ),
      body: _erreur != null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_erreur!,
                      style: typo.bodySmall, textAlign: TextAlign.center)))
          : notifications == null
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_none,
                              size: 48, color: CouleursSW.texteSecondaire),
                          const SizedBox(height: 12),
                          Text('Rien pour l’instant.', style: typo.bodySmall),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _CarteNotification(
                                notification: notifications[i],
                                surTape: () => _ouvrir(notifications[i])),
                      ),
                    ),
    );
  }
}

class _CarteNotification extends StatelessWidget {
  final NotificationPublique notification;
  final VoidCallback surTape;

  const _CarteNotification({required this.notification, required this.surTape});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: surTape,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CouleursSW.accent.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    notification.idFilm != null
                        ? Icons.movie_outlined
                        : Icons.live_tv_outlined,
                    color: CouleursSW.accent,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.contenu,
                        style: typo.bodyMedium?.copyWith(
                            fontWeight: notification.lue
                                ? FontWeight.w400
                                : FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(formatRelatif(notification.dateEnvoi),
                        style: typo.bodySmall),
                  ],
                ),
              ),
              if (!notification.lue) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: CouleursSW.accentSecondaire,
                      shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

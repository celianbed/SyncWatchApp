// Section « Avis de tes abonnements » sur une fiche de titre : les avis des
// personnes que tu suis. Se masque toute seule s'il n'y en a pas.
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../ecrans/ecran_profil_public.dart';
import '../modeles/modeles.dart';
import '../theme.dart';
import 'avatar_utilisateur.dart';

class AvisAbonnements extends StatefulWidget {
  final String cle; // 'id_serie' | 'id_film'
  final int id;
  const AvisAbonnements({super.key, required this.cle, required this.id});

  @override
  State<AvisAbonnements> createState() => _AvisAbonnementsState();
}

class _AvisAbonnementsState extends State<AvisAbonnements> {
  late final Future<List<AvisAmi>> _avis = _charger();

  Future<List<AvisAmi>> _charger() async {
    final d = await api
        .get('/avis/abonnements', params: {widget.cle: '${widget.id}'}) as List;
    return [for (final a in d) AvisAmi.depuisJson(a as Map<String, dynamic>)];
  }

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return FutureBuilder<List<AvisAmi>>(
      future: _avis,
      builder: (context, snap) {
        final avis = snap.data;
        if (avis == null || avis.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Avis de tes abonnements', style: typo.titleMedium),
            const SizedBox(height: 12),
            for (final a in avis)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CarteAvisAmi(avis: a),
              ),
          ],
        );
      },
    );
  }
}

class _CarteAvisAmi extends StatelessWidget {
  final AvisAmi avis;
  const _CarteAvisAmi({required this.avis});

  @override
  Widget build(BuildContext context) {
    final typo = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EcranProfilPublic(idUtilisateur: avis.idAuteur))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarUtilisateur(
                      pseudo: avis.pseudo, avatar: avis.avatar, taille: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(avis.pseudo,
                        style: typo.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (avis.note != null) ...[
                    const SizedBox(width: 8),
                    Text('★ ${avis.note}/10',
                        style: typo.bodyMedium?.copyWith(
                            color: CouleursSW.accentSecondaire,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
              if (avis.masque) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.visibility_off_outlined,
                        size: 14, color: CouleursSW.texteSecondaire),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Avis masqué — ${avis.pseudo} est plus avancé que toi',
                          style: typo.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ] else if ((avis.commentaire ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(avis.commentaire!, style: typo.bodySmall?.copyWith(height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Petits formats français — évite d'embarquer intl pour si peu.

const _mois = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

const _joursSemaine = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];

String formatDateCourte(DateTime date) =>
    '${date.day} ${_mois[date.month - 1]}';

/// « mardi 21 juil. » — avec Aujourd'hui / Demain pour les dates proches.
String formatJourLong(DateTime date) {
  final aujourdHui = DateTime.now();
  final difference = DateTime(date.year, date.month, date.day)
      .difference(DateTime(aujourdHui.year, aujourdHui.month, aujourdHui.day))
      .inDays;
  if (difference == 0) return 'Aujourd’hui';
  if (difference == 1) return 'Demain';
  return '${_joursSemaine[date.weekday - 1]} ${formatDateCourte(date)}';
}

String formatRelatif(DateTime date) {
  final ecart = DateTime.now().difference(date.toLocal());
  if (ecart.inMinutes < 1) return 'à l’instant';
  if (ecart.inHours < 1) return 'il y a ${ecart.inMinutes} min';
  if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
  if (ecart.inDays < 2) return 'hier';
  return formatDateCourte(date.toLocal());
}

String formatDuree(int minutes) {
  final h = minutes ~/ 60, min = minutes % 60;
  if (h == 0) return '$min min';
  return min == 0 ? '$h h' : '$h h $min';
}

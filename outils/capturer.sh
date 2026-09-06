#!/bin/bash
# Capture l'écran du simulateur toutes les N secondes pendant une durée donnée,
# pendant que vous naviguez dans l'app à la main. Les images sortent à la taille
# exacte exigée par l'App Store (1320 × 2868 sur iPhone 6,9").
#
#   ./outils/capturer.sh [secondes entre captures] [durée totale]
#
# Le pilotage automatique n'est pas possible : le harnais d'intégration coupe le
# chargement des images, et scripter des clics demande d'accorder l'accessibilité
# au terminal (Réglages › Confidentialité et sécurité › Accessibilité).
set -euo pipefail

SIMU=${SIMU:-6C6175EE-27CC-4205-9D4E-A2EC3FC82BD6}   # iPhone 17 Pro Max
PAS=${1:-3}
DUREE=${2:-90}
DOSSIER=captures/manuel
mkdir -p "$DOSSIER"

echo "Naviguez dans l'app : une capture toutes les ${PAS}s pendant ${DUREE}s."
FIN=$(( $(date +%s) + DUREE ))
N=1
while [ "$(date +%s)" -lt "$FIN" ]; do
  F=$(printf "%s/%03d.png" "$DOSSIER" "$N")
  xcrun simctl io "$SIMU" screenshot "$F" 2>/dev/null && echo "  $F"
  N=$((N + 1))
  sleep "$PAS"
done
echo "Terminé. Gardez les bonnes, supprimez le reste."

#!/bin/bash
# Branche Google Sign-In sur iOS à partir de ios/Runner/GoogleService-Info.plist.
#
# À lancer après avoir déposé un nouveau GoogleService-Info.plist (changement de
# projet Firebase, ou premier ajout du client OAuth iOS). Sans ces deux clés dans
# Info.plist, le plugin google_sign_in échoue nativement au lancement.
#
#   ./ios/scripts/configurer_google_signin.sh
set -euo pipefail

cd "$(dirname "$0")/../.."
PB=/usr/libexec/PlistBuddy
SOURCE=ios/Runner/GoogleService-Info.plist
CIBLE=ios/Runner/Info.plist

[ -f "$SOURCE" ] || { echo "Absent : $SOURCE"; exit 1; }

CLIENT_ID=$($PB -c "Print :CLIENT_ID" "$SOURCE" 2>/dev/null || true)
REVERSED=$($PB -c "Print :REVERSED_CLIENT_ID" "$SOURCE" 2>/dev/null || true)

if [ -z "$CLIENT_ID" ] || [ -z "$REVERSED" ]; then
  echo "CLIENT_ID / REVERSED_CLIENT_ID absents de $SOURCE."
  echo "→ Le projet Firebase n'a pas de client OAuth iOS : ajoute l'app iOS dans"
  echo "  la console Firebase, puis retélécharge GoogleService-Info.plist."
  exit 1
fi

# GIDClientID : lu par google_sign_in au démarrage
$PB -c "Delete :GIDClientID" "$CIBLE" 2>/dev/null || true
$PB -c "Add :GIDClientID string $CLIENT_ID" "$CIBLE"

# Schéma d'URL : c'est par là que Safari renvoie l'utilisateur dans l'app
$PB -c "Delete :CFBundleURLTypes" "$CIBLE" 2>/dev/null || true
$PB -c "Add :CFBundleURLTypes array" "$CIBLE"
$PB -c "Add :CFBundleURLTypes:0 dict" "$CIBLE"
$PB -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$CIBLE"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$CIBLE"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED" "$CIBLE"

plutil -lint "$CIBLE"
echo "Google Sign-In configuré (client $CLIENT_ID)."

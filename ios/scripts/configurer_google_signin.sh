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
  PROJET=$($PB -c "Print :PROJECT_ID" "$SOURCE" 2>/dev/null || echo "inconnu")
  echo "CLIENT_ID / REVERSED_CLIENT_ID absents de $SOURCE (projet : $PROJET)."
  echo
  echo "Firebase ne met ces clés dans le fichier que s'il existe un client OAuth"
  echo "iOS. Deux causes possibles, dans cet ordre de probabilité :"
  echo
  echo "  1. Google n'est pas activé comme fournisseur de connexion. C'est lui qui"
  echo "     crée les clients OAuth : console Firebase › Authentication ›"
  echo "     Sign-in method › Google › Activer."
  echo "  2. L'app iOS n'est pas enregistrée dans ce projet Firebase."
  echo
  echo "Dans les deux cas, retélécharge ensuite GoogleService-Info.plist : le"
  echo "fichier n'est pas mis à jour tout seul."
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

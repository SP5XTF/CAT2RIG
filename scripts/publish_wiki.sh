#!/bin/bash
# Publikuje folder wiki/ do GitHub Wiki projektu.
#   bash scripts/publish_wiki.sh TWOJ-LOGIN
# Wymaga: włączonego Wiki w repozytorium i utworzonej pierwszej strony (przez przeglądarkę).
set -euo pipefail
cd "$(dirname "$0")/.."
USER_NAME="${1:?Podaj login GitHub, np. bash scripts/publish_wiki.sh sp5abc}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git clone "https://github.com/${USER_NAME}/CAT2RIG.wiki.git" "$TMP/wiki"
cp wiki/*.md "$TMP/wiki/"
sed -i '' "s/<your-user>/${USER_NAME}/g" "$TMP"/wiki/*.md
cd "$TMP/wiki"
git add -A
git commit -m "Wiki: dokumentacja CAT2RIG" || { echo "Brak zmian."; exit 0; }
git push
echo "Gotowe: https://github.com/${USER_NAME}/CAT2RIG/wiki"

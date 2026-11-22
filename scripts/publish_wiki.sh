#!/bin/bash
# Publikuje folder wiki/ do GitHub Wiki projektu.
#   bash scripts/publish_wiki.sh        (wiki: https://github.com/SP5XTF/CAT2RIG.wiki.git)
# Wymaga: włączonego Wiki w repozytorium i utworzonej pierwszej strony (przez przeglądarkę).
set -euo pipefail
cd "$(dirname "$0")/.."
USER_NAME="${1:-SP5XTF}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git clone "https://github.com/${USER_NAME}/CAT2RIG.wiki.git" "$TMP/wiki"
cp wiki/*.md "$TMP/wiki/"
true   # login jest już wpisany w plikach wiki
cd "$TMP/wiki"
git add -A
git commit -m "Wiki: dokumentacja CAT2RIG" || { echo "Brak zmian."; exit 0; }
git push
echo "Gotowe: https://github.com/${USER_NAME}/CAT2RIG/wiki"

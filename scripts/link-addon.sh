#!/bin/sh
# Verlinkt dieses Repo als Addon "FolioSwap" in den WoW-AddOns-Ordner (macOS).
# Aufruf: scripts/link-addon.sh ["/Applications/World of Warcraft/_retail_"]
set -eu
repo="$(cd "$(dirname "$0")/.." && pwd)"
retail="${1:-/Applications/World of Warcraft/_retail_}"
[ -d "$retail" ] || { echo "WoW-_retail_-Ordner nicht gefunden: $retail" >&2; exit 1; }

addons="$retail/Interface/AddOns"
target="$addons/FolioSwap"
mkdir -p "$addons"

if [ -L "$target" ]; then
  echo "Link existiert bereits: $target -> $(readlink "$target")"
elif [ -e "$target" ]; then
  echo "$target existiert bereits als echter Ordner (z. B. CurseForge-Installation). Bitte zuerst entfernen." >&2
  exit 1
else
  ln -s "$repo" "$target"
  echo "Verlinkt: $target -> $repo"
fi

#!/bin/sh
# Richtet beim ersten Lauf Lua 5.1 + busted + luacheck projektlokal ein (.lua/), dann Lint und Tests.
set -eu
cd "$(dirname "$0")/.."
if [ ! -x .lua/bin/busted ] || [ ! -x .lua/bin/luacheck ]; then
  command -v uvx >/dev/null || { echo "uv fehlt (brew install uv)"; exit 1; }
  uvx hererocks .lua -l 5.1 -r latest
  .lua/bin/luarocks install busted
  .lua/bin/luarocks install luacheck
fi
.lua/bin/luacheck .
.lua/bin/busted "$@"

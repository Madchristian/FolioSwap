#!/bin/sh
# Richtet beim ersten Lauf Lua 5.1 + busted + luacheck projektlokal ein (.lua/), dann Lint und Tests.
set -eu
cd "$(dirname "$0")/.."
if [ ! -x .lua/bin/busted ]; then
  uvx hererocks .lua -l 5.1 -r latest
  .lua/bin/luarocks install busted
  .lua/bin/luarocks install luacheck
fi
.lua/bin/luacheck .
.lua/bin/busted "$@"

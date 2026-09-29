-- Projektlokaler Runner, auch ohne Windows-.bat-Wrapper. Vom Repository-Wurzelverzeichnis starten.
assert(_VERSION == "Lua 5.1", "WoW verification requires Lua 5.1, got " .. _VERSION)
package.path = ".lua/share/lua/5.1/?.lua;.lua/share/lua/5.1/?/init.lua;" .. package.path
package.cpath = ".lua/lib/lua/5.1/?.dll;.lua/lib/lua/5.1/?.so;" .. package.cpath
local mode = table.remove(arg, 1)
print("Runtime: " .. _VERSION)
if mode == "lint" then
  if #arg == 0 then table.insert(arg, ".") end
  os.exit(require("luacheck.main").main())
elseif mode == "test" then
  require("busted.runner")({ standalone = false })
elseif mode == "parse" then
  local count = 0
  for line in io.lines("FolioSwap.toc") do
    local path = line:gsub("\\", "/"):match("^%s*(.-)%s*$")
    if path:match("%.lua$") then
      assert(loadfile(path))
      count = count + 1
    end
  end
  print("Lua 5.1 parse: " .. count .. " TOC files OK")
else
  error("Usage: .lua/bin/lua scripts/verify.lua lint|test|parse [arguments]")
end

local _, ns = ...
local actions = ns.actions

local slash_commands = {}
ns.slash_commands = slash_commands

local HANDLERS = {
  list = actions.list,
  apply = actions.apply,
  save = actions.save_current,
  delete = actions.delete,
  active = actions.set_active,
  dump = actions.dump,
  check = actions.check,
  help = actions.help,
  skin = function() ns.skin_options.show() end,
}

function slash_commands.handle(input)
  local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  local handler = HANDLERS[command:lower()] or actions.help
  handler(argument)
end

SLASH_FOLIOSWAP1 = "/folio"
SLASH_FOLIOSWAP2 = "/folioswap"
SlashCmdList.FOLIOSWAP = slash_commands.handle

-- Fake-Omniumfoliant: bildet die genutzte C_Traits-API mit einem kleinen Baum nach.
local c_traits_mock = {}

-- Frische Tabelle pro Aufruf, damit Tests sich nicht gegenseitig verändern.
function c_traits_mock.default_tree()
  return {
    config_id = 7,
    nodes = {
      { id = 100, entries = { 1001, 1002 }, active = 1001 },                -- Kern
      { id = 200, entries = { 2001, 2002, 2003 }, active = 2001 },          -- Defensiv
      { id = 300, entries = { 3001 }, active = 3001 },                      -- Lingering, keine Wahl
      { id = 400, entries = { 4001, 4002, 4003, 4004 }, active = 4001 },    -- Sekundärwert
      { id = 500, entries = { 5001, 5002, 5003 }, available = false },      -- Capstone, gesperrt
    },
  }
end

function c_traits_mock.install(tree)
  local state = {
    set_calls = {}, commits = 0, commit_ok = true, reject = {},
    ready = true, can_edit = true, rollbacks = 0, delayed = false,
  }
  local by_id, node_ids = {}, {}
  for _, node in ipairs(tree.nodes) do
    by_id[node.id] = { id = node.id, entries = node.entries, active = node.active,
      committed = node.active, available = node.available }
    node_ids[#node_ids + 1] = node.id
  end

  -- Server resolution is separate from SetSelection and CommitConfig acceptance.
  function state.complete(success)
    for _, node in pairs(by_id) do
      if success then node.committed = node.active else node.active = node.committed end
    end
    state.ready = true
  end
  state.nodes = by_id

  C_Traits = {
    GetConfigIDBySystemID = function(system_id)
      if system_id == 48 then return tree.config_id end
    end,
    GetTreeNodes = function(tree_id)
      return tree_id == 1186 and node_ids or {}
    end,
    GetNodeInfo = function(config_id, node_id)
      assert(config_id == tree.config_id, "falsche config_id")
      local node = by_id[node_id]
      return {
        ID = node_id,
        entryIDs = node.entries,
        entryIDsWithCommittedRanks = node.committed and { node.committed } or {},
        activeEntry = node.active and { entryID = node.active, rank = 1 } or nil,
        isAvailable = node.available ~= false,
      }
    end,
    GetEntryInfo = function(config_id, entry_id)
      assert(config_id == tree.config_id, "falsche config_id")
      return { definitionID = entry_id * 10 }
    end,
    GetDefinitionInfo = function(definition_id)
      return { spellID = definition_id * 10 }
    end,
    ConfigHasStagedChanges = function(config_id)
      assert(config_id == tree.config_id, "falsche config_id")
      for _, node in pairs(by_id) do
        if node.active ~= node.committed then return true end
      end
      return false
    end,
    IsReadyForCommit = function() return state.ready end,
    CanEditConfig = function(config_id)
      assert(config_id == tree.config_id, "falsche config_id")
      return state.can_edit, state.can_edit and nil or "locked"
    end,
    SetSelection = function(config_id, node_id, entry_id)
      assert(config_id == tree.config_id, "falsche config_id")
      table.insert(state.set_calls, { node_id, entry_id })
      if state.reject[node_id] then return false end
      by_id[node_id].active = entry_id
      return true
    end,
    CommitConfig = function(config_id)
      assert(config_id == tree.config_id, "falsche config_id")
      state.commits = state.commits + 1
      if state.commit_ok then
        if state.delayed then state.ready = false else state.complete(true) end
      end
      return state.commit_ok
    end,
    RollbackConfig = function(config_id)
      assert(config_id == tree.config_id, "falsche config_id")
      state.rollbacks = state.rollbacks + 1
      state.complete(false)
      return true
    end,
  }
  return state
end

return c_traits_mock

local wow_env = require("spec.helpers.wow_env")

local function sample_presets()
  return { [62] = { { name = "Guide M+", selections = { [100] = 1002, [400] = 4003 } } } }
end

describe("actions", function()
  local env, actions
  before_each(function()
    env = wow_env.new({ presets = sample_presets() })
    actions = env.ns.actions
  end)

  local function last_message()
    return env.messages[#env.messages]
  end

  it("wendet ein Profil per Name an", function()
    actions.apply("Guide M+")
    assert.same({ { 100, 1002 }, { 400, 4003 } }, env.traits.set_calls)
    assert.matches("applied %(2 rune", last_message())
  end)

  it("meldet beim manuellen Anwenden, wenn schon alles passt", function()
    actions.apply("Guide M+")
    actions.apply("Guide M+")
    assert.matches("already active", last_message())
  end)

  it("wendet im Kampf nichts an", function()
    env.in_combat = true
    actions.apply("Guide M+")
    assert.same({}, env.traits.set_calls)
    assert.matches("combat", last_message())
  end)

  it("meldet unbekannte Profile", function()
    actions.apply("Fehlt")
    assert.matches("No profile \"Fehlt\"", last_message())
  end)

  it("speichert den aktuellen Foliant als eigenes Profil", function()
    actions.save_current("Mein Setup")
    local profile = env.ns.profile_store.get(62, "Mein Setup")
    assert.same({ [100] = 1001, [200] = 2001, [400] = 4001 }, profile.selections)
    assert.matches("saved", last_message())
  end)

  it("meldet Fehler beim Speichern unter einem Preset-Namen", function()
    actions.save_current("Guide M+")
    assert.matches("guide preset", last_message())
  end)

  it("aktiviert und löscht Profile mit Rückmeldung", function()
    actions.save_current("Mein Setup")
    actions.set_active("Mein Setup")
    assert.matches("now active", last_message())
    actions.delete("Mein Setup")
    assert.matches("deleted", last_message())
  end)

  it("listet Profile mit Markierungen", function()
    actions.save_current("Mein Setup")
    actions.list()
    assert.equals("  Guide M+ [Guide] (active)", env.messages[#env.messages - 1])
    assert.equals("  Mein Setup", last_message())
  end)

  it("gibt ohne Spezialisierung einen Hinweis", function()
    env.spec_id = nil
    actions.list()
    assert.matches("No specialization", last_message())
  end)

  it("wendet automatisch das aktive Profil an und schweigt danach", function()
    actions.apply_active()
    assert.equals(2, #env.traits.set_calls)
    local message_count = #env.messages
    actions.apply_active()
    assert.equals(message_count, #env.messages)
  end)

  it("liefert beim automatischen Anwenden das Ergebnis zurück", function()
    assert.same({ 100, 400 }, actions.apply_active().applied)
    env.spec_id = 63
    assert.is_nil(actions.apply_active())
  end)

  it("speichert den Dump in der Datenbank", function()
    actions.dump()
    assert.equals(4, #env.ns.profile_store.db.dump)
    assert.matches("4 rune row", last_message())
  end)

  it("prüft die Presets gegen den Foliant", function()
    actions.check()
    assert.matches("All guide presets match", last_message())
    env.ns.presets.data[63] = { { name = "Kaputt", selections = { [900] = 9001 } } }
    actions.check()
    assert.matches("node 900 / entry 9001", last_message())
  end)

  it("meldet fehlenden Foliant bei /folio dump trotz Drosselung jedes Mal", function()
    env = wow_env.new({ tree = { config_id = nil, nodes = {} } })
    actions = env.ns.actions
    actions.dump()
    actions.dump()
    assert.equals(2, #env.messages)
  end)

  it("meldet beim manuellen Anwenden fehlenden Foliant, auch wenn die Automatik zuvor still blieb", function()
    env = wow_env.new({ tree = { config_id = nil, nodes = {} }, presets = sample_presets() })
    actions = env.ns.actions
    actions.apply_active()
    assert.equals(0, #env.messages)
    actions.apply("Guide M+")
    assert.equals(1, #env.messages)
    assert.matches("not unlocked", last_message())
  end)

  it("weist leere oder fehlende Profilnamen ab, statt zu crashen", function()
    actions.apply("")
    assert.matches("Please enter a name%.", last_message())
    actions.delete(nil)
    assert.matches("Please enter a name%.", last_message())
  end)

  it("trimmt den Namen beim Speichern auch in der Rückmeldung", function()
    actions.save_current("  Mein  ")
    assert.matches("Profile \"Mein\" saved", last_message())
  end)

  it("meldet busy beim manuellen Anwenden", function()
    env.traits.ready = false
    actions.apply("Guide M+")
    assert.matches("still saving", last_message())
  end)

  it("meldet cannot_edit beim manuellen Anwenden", function()
    env.traits.can_edit = false
    actions.apply("Guide M+")
    assert.matches("can't be changed", last_message())
  end)

  it("schützt Guide-Presets beim Löschen", function()
    actions.delete("Guide M+")
    assert.matches("Guide preset \"Guide M%+\" can't be changed", last_message())
  end)

  it("meldet unbekannte Profile beim Aktivsetzen", function()
    actions.set_active("Fehlt")
    assert.matches("No profile \"Fehlt\"", last_message())
  end)

  it("meldet fehlenden Foliant beim Speichern", function()
    env = wow_env.new({ tree = { config_id = nil, nodes = {} } })
    actions = env.ns.actions
    actions.save_current("X")
    assert.matches("not unlocked", last_message())
  end)
end)

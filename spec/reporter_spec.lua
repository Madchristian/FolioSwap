local wow_env = require("spec.helpers.wow_env")

local PROFILE = { name = "Guide M+" }

describe("reporter", function()
  local env, reporter
  before_each(function()
    env = wow_env.new()
    reporter = env.ns.reporter
  end)

  it("meldet angewendete Runen mit Präfix", function()
    reporter.report_apply(PROFILE, { applied = { 100, 400 }, skipped = {} })
    assert.same({ "|cff66ccffFolioSwap|r: Profile \"Guide M+\" applied (2 rune(s) changed)." }, env.messages)
  end)

  it("schweigt, wenn nichts zu tun war", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {} })
    assert.same({}, env.messages)
  end)

  it("meldet auf Wunsch, dass schon alles passt", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {} }, true)
    assert.matches("already active", env.messages[1])
  end)

  it("listet übersprungene Runen mit Grund", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = { { node_id = 500, reason = "locked" } } })
    assert.matches("500 %(row still locked%)", env.messages[1])
  end)

  it("zeigt den Runennamen statt der node_id, wenn FolioApi ihn liefert", function()
    reporter.report_apply(PROFILE, {
      applied = {},
      skipped = { { node_id = 500, reason = "locked", name = "Spell 500100" } },
    })
    assert.matches("Spell 500100 %(row still locked%)", env.messages[1])
  end)

  it("meldet dieselbe übersprungene Kombination in der Automatik nur einmal pro Sitzung", function()
    local result = { applied = {}, skipped = { { node_id = 500, reason = "locked" } } }
    reporter.report_apply(PROFILE, result)
    reporter.report_apply(PROFILE, result)
    assert.equals(1, #env.messages)
  end)

  it("meldet dieselbe übersprungene Kombination beim manuellen Anwenden jedes Mal", function()
    local result = { applied = {}, skipped = { { node_id = 500, reason = "locked" } } }
    reporter.report_apply(PROFILE, result, true)
    reporter.report_apply(PROFILE, result, true)
    assert.equals(2, #env.messages)
  end)

  it("meldet abweichende übersprungene Kombinationen in der Automatik erneut", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = { { node_id = 500, reason = "locked" } } })
    reporter.report_apply(PROFILE, { applied = {}, skipped = { { node_id = 500, reason = "rejected" } } })
    assert.equals(2, #env.messages)
  end)

  it("schweigt bei unavailable in der Automatik", function()
    -- Der SwapController meldet unavailable erst selbst, wenn alle Retries gescheitert sind.
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "unavailable" })
    assert.same({}, env.messages)
  end)

  it("meldet unavailable beim manuellen Anwenden jedes Mal", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "unavailable" }, true)
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "unavailable" }, true)
    assert.equals(2, #env.messages)
  end)

  it("meldet den fehlenden Foliant nur einmal pro Sitzung ohne force", function()
    reporter.report_unavailable()
    reporter.report_unavailable()
    assert.equals(1, #env.messages)
  end)

  it("meldet einen fehlgeschlagenen Commit", function()
    -- FolioApi leert applied nach einem Rollback wieder: "zurückgerollt" heißt nichts übernommen.
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "commit_failed" })
    assert.matches("Could not save", env.messages[1])
  end)

  it("meldet einen fehlgeschlagenen Commit auch beim manuellen Anwenden ohne zusätzliches 'schon aktiv'", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "commit_failed" }, true)
    assert.equals(1, #env.messages)
    assert.matches("Could not save", env.messages[1])
  end)

  it("meldet busy nur beim manuellen Anwenden", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "busy" })
    assert.same({}, env.messages)
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "busy" }, true)
    assert.matches("still saving", env.messages[1])
  end)

  it("meldet cannot_edit", function()
    reporter.report_apply(PROFILE, { applied = {}, skipped = {}, reason = "cannot_edit" })
    assert.matches("can't be changed", env.messages[1])
  end)

  it("beschriftet Profile mit Guide- und Aktiv-Markierung", function()
    local preset = { name = "Guide M+", source = "preset" }
    assert.equals("Guide M+ [Guide] (active)", reporter.profile_label(preset, "Guide M+"))
    assert.equals("Mein", reporter.profile_label({ name = "Mein", source = "user" }, "Guide M+"))
  end)
end)

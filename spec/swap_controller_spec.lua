local wow_env = require("spec.helpers.wow_env")

local function sample_presets()
  return { [62] = { { name = "Guide M+", selections = { [100] = 1002 } } } }
end

describe("swap_controller", function()
  local env, controller
  before_each(function()
    env = wow_env.new({ presets = sample_presets() })
    controller = env.ns.swap_controller
  end)

  it("stellt beim Spec-Wechsel des Spielers um", function()
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert.same({ { 100, 1002 } }, env.traits.set_calls)
  end)

  it("ignoriert Spec-Wechsel anderer Einheiten", function()
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "party1")
    assert.same({}, env.traits.set_calls)
  end)

  it("stellt bei Login und Reload um, nicht bei Ladebildschirmen", function()
    controller.on_event("PLAYER_ENTERING_WORLD", false, false)
    assert.same({}, env.traits.set_calls)
    controller.on_event("PLAYER_ENTERING_WORLD", true, false)
    assert.equals(1, #env.traits.set_calls)
  end)

  it("merkt im Kampf vor und stellt nach dem Kampf einmal um", function()
    env.in_combat = true
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert.same({}, env.traits.set_calls)
    assert.equals(1, #env.messages)
    assert.matches("after combat", env.messages[1])

    env.in_combat = false
    controller.on_event("PLAYER_REGEN_ENABLED")
    assert.same({ { 100, 1002 } }, env.traits.set_calls)
    controller.on_event("PLAYER_REGEN_ENABLED")
    assert.equals(1, #env.traits.set_calls)
  end)

  it("versucht es nach dem nächsten Speichern erneut, wenn das Spiel beschäftigt war", function()
    env.traits.ready = false
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert.same({}, env.traits.set_calls)
    assert.same({}, env.messages)

    env.traits.ready = true
    controller.on_event("TRAIT_CONFIG_UPDATED", 7)
    assert.same({ { 100, 1002 } }, env.traits.set_calls)
    controller.on_event("TRAIT_CONFIG_UPDATED", 7)
    assert.equals(1, #env.traits.set_calls)
  end)

  it("nennt die benötigten Events", function()
    assert.same(
      { "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED", "TRAIT_CONFIG_UPDATED" },
      controller.EVENTS
    )
  end)
end)

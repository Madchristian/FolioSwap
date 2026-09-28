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

  it("stellt bei Login um, nicht bei Ladebildschirmen", function()
    controller.on_event("PLAYER_ENTERING_WORLD", false, false)
    assert.same({}, env.traits.set_calls)
    controller.on_event("PLAYER_ENTERING_WORLD", true, false)
    assert.equals(1, #env.traits.set_calls)
  end)

  it("stellt bei einem Reload um", function()
    controller.on_event("PLAYER_ENTERING_WORLD", false, true)
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

  it("versucht es nach einer kurzen Pause erneut, wenn das Spiel beim Speichern beschäftigt war", function()
    env.traits.ready = false
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert.same({}, env.traits.set_calls)
    assert.same({}, env.messages)
    assert.equals(1, #env.timers)

    env.traits.ready = true
    env.run_timers()
    assert.same({ { 100, 1002 } }, env.traits.set_calls)
  end)

  it("versucht es beim Login erneut, wenn der Foliant noch nicht geladen ist", function()
    local original_get_config_id = C_Traits.GetConfigIDBySystemID
    C_Traits.GetConfigIDBySystemID = function() return nil end
    controller.on_event("PLAYER_ENTERING_WORLD", true, false)
    assert.same({}, env.traits.set_calls)
    assert.same({}, env.messages)
    assert.equals(1, #env.timers)

    C_Traits.GetConfigIDBySystemID = original_get_config_id
    env.run_timers()
    assert.same({ { 100, 1002 } }, env.traits.set_calls)
    assert.equals(1, #env.messages)
    assert.matches("applied", env.messages[1])
  end)

  it("gibt nach MAX_RETRIES erfolglosen Versuchen auf und meldet es genau einmal", function()
    env.traits.ready = false
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    for _ = 1, 5 do
      assert.equals(1, #env.timers)
      env.run_timers()
    end
    assert.same({}, env.traits.set_calls)
    assert.equals(1, #env.messages)
    assert.matches("still saving", env.messages[1])
    assert.equals(0, #env.timers)
  end)

  it("verschiebt einen fälligen Retry in den Kampf hinein auf danach", function()
    env.traits.ready = false
    controller.on_event("PLAYER_SPECIALIZATION_CHANGED", "player")
    assert.equals(1, #env.timers)

    env.traits.ready = true
    env.in_combat = true
    env.run_timers()
    assert.same({}, env.traits.set_calls)
    assert.equals(1, #env.messages)
    assert.matches("after combat", env.messages[1])
    assert.equals(0, #env.timers)

    env.in_combat = false
    controller.on_event("PLAYER_REGEN_ENABLED")
    assert.same({ { 100, 1002 } }, env.traits.set_calls)
  end)

  it("nennt die benötigten Events", function()
    assert.same(
      { "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED" },
      controller.EVENTS
    )
  end)
end)

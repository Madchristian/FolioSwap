local _, ns = ...

local player = {}
ns.player = player

function player.current_spec_id()
  local index = GetSpecialization()
  if not index then return nil end
  return (GetSpecializationInfo(index))
end

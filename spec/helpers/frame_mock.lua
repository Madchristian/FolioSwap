-- Nur dokumentierte, hier benötigte Widget-Methoden; unbekannte Methoden schlagen fehl.
local mock = {}
function mock.install()
  local frames = {}
  local region = {}
  function region:SetPoint(...) self.point = { ... } end
  function region:SetAllPoints() self.all_points = true end
  function region:SetSize(w, h) self.width, self.height = w, h end
  function region:SetWidth(w) self.width = w end
  function region:SetHeight(h) self.height = h end
  function region:SetColorTexture(...) self.color = { ... } end
  function region:SetTexture(value) self.texture = value end
  function region:SetText(value) self.text = value end
  function region:GetText() return self.text or "" end
  function region:SetTextColor(...) self.text_color = { ... } end
  function region:SetJustifyH(value) self.justify = value end
  function region:SetWordWrap(value) self.wrap = value end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end
  function region:IsShown() return self.shown end
  local frame = setmetatable({}, { __index = region })
  function frame:SetScript(key, fn) self.scripts[key] = fn end
  function frame:HookScript(key, fn) self.scripts[key] = fn end
  function frame:RegisterEvent(key) self.events[key] = true end
  function frame:SetScale(value) self.scale = value end
  function frame:GetEffectiveScale()
    return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
  end
  function frame:GetWidth() return self.width or 0 end
  function frame:GetHeight() return self.height or 0 end
  function frame:ClearAllPoints() self.point = nil end
  function frame:SetClampedToScreen(value) self.clamped = value end
  local function fraction(point)
    local x = point:find("LEFT") and 0 or (point:find("RIGHT") and 1 or 0.5)
    local y = point:find("BOTTOM") and 0 or (point:find("TOP") and 1 or 0.5)
    return x, y
  end
  local function bounds(self)
    if self == UIParent then return 0, 0 end
    if self.unlaid or not self.point then return nil end
    local p = self.point
    local relative, relative_point, x, y
    if type(p[2]) == "table" then
      relative, relative_point, x, y = p[2], p[3], p[4] or 0, p[5] or 0
    else
      relative, relative_point, x, y = self.parent or UIParent, p[1], p[2] or 0, p[3] or 0
    end
    local left, bottom = bounds(relative)
    if not left then return nil end
    local rs, s = relative:GetEffectiveScale(), self:GetEffectiveScale()
    local rx, ry = fraction(relative_point)
    local ax, ay = fraction(p[1])
    return (left + relative:GetWidth() * rx) * rs / s + x - self:GetWidth() * ax,
      (bottom + relative:GetHeight() * ry) * rs / s + y - self:GetHeight() * ay
  end
  function frame:GetLeft() local left = bounds(self); return left end
  function frame:GetBottom() local _, bottom = bounds(self); return bottom end
  function frame:GetRight() local left = self:GetLeft(); return left and left + self:GetWidth() end
  function frame:GetTop() local bottom = self:GetBottom(); return bottom and bottom + self:GetHeight() end
  function frame:SetFrameStrata(value) self.strata = value end
  function frame:GetFrameStrata()
    return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM"
  end
  function frame:SetFrameLevel(value) self.level = value end
  function frame:GetFrameLevel() return self.level or 1 end
  function frame:EnableMouse(value) self.mouse = value end
  function frame:GetParent() return self.parent end
  -- SetGradient belongs to Texture, not FontString/Frame (Retail 12.1.0 TextureBase).
  local texture = setmetatable({}, { __index = region })
  function texture:SetGradient(orientation, low, high)
    self.gradient = { orientation = orientation, low = low, high = high }
  end
  _G.CreateColor = function(r, g, b, a) return { r, g, b, a } end
  function frame.CreateTexture()
    local t = setmetatable({ shown = true }, { __index = texture })
    return t
  end
  function frame.CreateFontString() return setmetatable({ shown = true }, { __index = region }) end
  local button = setmetatable({}, { __index = frame })
  function button:SetEnabled(value)
    self.enabled = value
    local fn = self.scripts[value and "OnEnable" or "OnDisable"]
    if fn then fn(self) end
  end
  function button:IsEnabled() return self.enabled end
  function button:RegisterForClicks(...) self.clicks = { ... } end
  local edit = setmetatable({}, { __index = frame })
  function edit:SetFontObject(value) self.font = value end
  function edit:SetTextInsets(...) self.insets = { ... } end
  function edit:SetAutoFocus(value) self.auto_focus = value end
  function edit:SetMaxLetters(value) self.max_letters = value end
  function edit:SetFocus() self.focus = true end
  function edit:ClearFocus() self.focus = false end
  function frame:SetupMenu(fn) self.menu = fn end
  function frame.GenerateMenu() end
  local types = { Frame = frame, Button = button, EditBox = edit, DropdownButton = frame }
  _G.CreateFrame = function(kind, name, parent, template)
    assert(types[kind], "unsupported widget: " .. kind)
    local f = setmetatable({ kind = kind, name = name, parent = parent, template = template,
      scripts = {}, events = {}, shown = true, enabled = true }, { __index = types[kind] })
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
  end
  _G.UIParent = CreateFrame("Frame")
  UIParent:SetSize(1366, 768)
  _G.UISpecialFrames = {}
  mock.categories, mock.opened = {}, {}
  _G.Settings = {
    RegisterCanvasLayoutCategory = function(canvas, name)
      return { canvas = canvas, name = name, GetID = function() return 42 end }
    end,
    RegisterAddOnCategory = function(category)
      mock.categories[#mock.categories + 1] = category
    end,
    OpenToCategory = function(id)
      mock.opened[#mock.opened + 1] = id
      local canvas = assert(mock.categories[1]).canvas
      -- Blizzard besitzt Parent, Größe und Position des Canvas.
      canvas.parent = UIParent
      canvas:SetSize(700, 500)
      canvas:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
      canvas:Show()
      mock.fire(canvas, "OnShow")
    end,
  }
  _G.hooksecurefunc = function() end
  _G.RunesOfPowerMixin = {}
  _G.ExpansionLandingPage = { Overlay = { MidnightLandingOverlay = {
    RunesOfPowerFrame = CreateFrame("Frame", nil, UIParent),
  } } }
  _G.StaticPopupDialogs = {}
  _G.ACCEPT, _G.CANCEL = "Accept", "Cancel"
  _G.StaticPopup_Show = function(key) mock.popup = StaticPopupDialogs[key] end
  _G.StaticPopup_StandardEditBoxOnEscapePressed = function() end
  function mock.fire(f, event, ...)
    if event == "OnClick" and not f.enabled then return end
    if f.scripts[event] then return f.scripts[event](f, ...) end
  end
  mock.frames = frames
  return mock
end
return mock

local _, ns = ...
local ui = { widgets = {}, roots = {} }
ns.flat_ui = ui

local function paint(widget)
  local settings = ns.skin.get()
  local c = ns.skin.accents[settings.accent]
  if widget.kind == "surface" then
    widget.surface:SetColorTexture(0.055, 0.064, 0.078, settings.opacity)
    return
  end
  local enabled = widget:IsEnabled()
  local active = enabled and (widget.hovered or widget.selected)
  widget.surface:SetColorTexture(active and c[1] * 0.28 or 0.105,
    active and c[2] * 0.28 or 0.12, active and c[3] * 0.28 or 0.145, 1)
  widget.marker:SetColorTexture(c[1], c[2], c[3], enabled and (active and 1 or 0.25) or 0.08)
  local shade = enabled and 0.92 or 0.4
  widget.label:SetTextColor(shade, shade, shade, 1)
end

function ui.refresh()
  for _, widget in ipairs(ui.widgets) do paint(widget) end
  for _, root in ipairs(ui.roots) do root:SetScale(ns.skin.get().scale) end
  for _, root in ipairs(ui.roots) do if root.layout then root.layout() end end
end
ns.skin.refresh = ui.refresh

-- Frame bounds are in the frame's effective-scale units, not UIParent units.
-- Nil coordinates are normal before the first layout; retry on the next update.
function ui.keep_on_screen(frame)
  local left, bottom = frame:GetLeft(), frame:GetBottom()
  if not left or not bottom then return end
  local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
  local width, height = UIParent:GetWidth() * ratio, UIParent:GetHeight() * ratio
  local x = math.max(0, math.min(left, width - frame:GetWidth()))
  local y = math.max(0, math.min(bottom, height - frame:GetHeight()))
  if x ~= left or y ~= bottom then
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
  end
end

function ui.label(parent, text, width)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetText(text)
  label:SetWidth(width)
  label:SetWordWrap(false)
  label:SetJustifyH("LEFT")
  return label
end

function ui.surface(parent, name, width, height, scaled)
  local f = CreateFrame("Frame", name, parent)
  f:SetSize(width, height)
  f:EnableMouse(true)
  f.kind = "surface"
  f.surface = f:CreateTexture(nil, "BACKGROUND")
  f.surface:SetAllPoints()
  ui.widgets[#ui.widgets + 1] = f
  if scaled then ui.roots[#ui.roots + 1] = f end
  ui.refresh()
  return f
end

function ui.button(parent, text, width, on_click)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 26)
  b:RegisterForClicks("LeftButtonUp")
  b.surface = b:CreateTexture(nil, "BACKGROUND")
  b.surface:SetAllPoints()
  b.marker = b:CreateTexture(nil, "BORDER")
  b.marker:SetPoint("BOTTOMLEFT")
  b.marker:SetPoint("BOTTOMRIGHT")
  b.marker:SetHeight(1)
  b.label = ui.label(b, text, width - 16)
  b.label:SetPoint("LEFT", 8, 0)
  b.label:SetJustifyH("CENTER")
  b:SetScript("OnClick", function(self) if self:IsEnabled() then on_click(self) end end)
  b:SetScript("OnEnter", function(self) self.hovered = true; paint(self) end)
  b:SetScript("OnLeave", function(self) self.hovered = false; paint(self) end)
  b:SetScript("OnEnable", paint)
  b:SetScript("OnDisable", function(self) self.hovered = false; paint(self) end)
  ui.widgets[#ui.widgets + 1] = b
  paint(b)
  return b
end

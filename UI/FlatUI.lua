local _, ns = ...
local ui = { widgets = {}, roots = {}, labels = {} }
ns.flat_ui = ui

-- Eigene ColorTextures statt Artwork/Backdrop-Templates. Alle Linien liegen innerhalb der Bounds.
local function rgb(r, g, b) return { r/255, g/255, b/255 } end
local foliant = {
  bottom = rgb(26, 24, 27), top = rgb(49, 39, 32), border = rgb(117, 96, 132),
  inner = rgb(33, 27, 38), shine = rgb(160, 138, 173), text = rgb(233, 222, 203),
  button_bottom = rgb(41, 36, 43), button_top = rgb(57, 48, 56), button_border = rgb(102, 84, 110),
  hover = rgb(73, 54, 81), hover_border = rgb(177, 156, 194), gold = rgb(213, 184, 126),
  selected_bottom = rgb(51, 46, 40), selected_top = rgb(73, 62, 48), selected_border = rgb(148, 120, 80),
  primary_bottom = rgb(58, 48, 36), primary_top = rgb(93, 73, 48), primary_border = rgb(170, 135, 82),
}
local function tint(texture, color, alpha)
  texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
end
local function gradient(texture, bottom, top, alpha)
  texture:SetColorTexture(1, 1, 1, 1)
  texture:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], alpha),
    CreateColor(top[1], top[2], top[3], alpha))
end
local function border(frame, inset)
  local edges = {}
  for i, anchors in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
    { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local edge = frame:CreateTexture(nil, "BORDER")
    for _, anchor in ipairs(anchors) do
      edge:SetPoint(anchor, frame, anchor, anchor:find("LEFT") and inset or -inset,
        anchor:find("TOP") and -inset or inset)
    end
    if i <= 2 then edge:SetHeight(1) else edge:SetWidth(1) end
    edges[i] = edge
  end
  return edges
end
local function paint_edges(edges, color, alpha, show)
  for _, edge in ipairs(edges) do
    tint(edge, color, alpha)
    if show then edge:Show() else edge:Hide() end
  end
end
local function paint_label(label)
  local c = foliant.text
  if label.assigned then c = foliant.gold end
  if ns.skin.get().theme == "foliant" then label:SetTextColor(c[1], c[2], c[3], 1)
  else label:SetTextColor(0.92, 0.92, 0.92, 1) end
end
local function paint_foliant(widget, settings)
  if widget.kind == "surface" then
    gradient(widget.surface, foliant.bottom, foliant.top, settings.opacity)
    paint_edges(widget.border, foliant.border, 1, true)
    paint_edges(widget.inner_border, foliant.inner, 1, true)
    tint(widget.shine, foliant.shine, 0.27)
    widget.shine:Show()
    return
  end
  local enabled = widget:IsEnabled()
  local bottom, top, edge, text = foliant.button_bottom, foliant.button_top, foliant.button_border, foliant.text
  if enabled then
    if widget.selected or widget.assigned then
      bottom, top, edge, text = foliant.selected_bottom, foliant.selected_top, foliant.selected_border, foliant.gold
    elseif widget.primary then
      bottom, top, edge, text = foliant.primary_bottom, foliant.primary_top, foliant.primary_border, foliant.gold
    end
    if widget.hovered then bottom, top, edge = foliant.hover, foliant.hover, foliant.hover_border end
  end
  gradient(widget.surface, bottom, top, 1)
  paint_edges(widget.border, edge, enabled and 1 or 0.3, true)
  widget.marker:Hide()
  if enabled then widget.label:SetTextColor(text[1], text[2], text[3], 1)
  else widget.label:SetTextColor(0.4, 0.4, 0.4, 1) end
end
local function paint(widget)
  local settings = ns.skin.get()
  if settings.theme == "foliant" then return paint_foliant(widget, settings) end
  -- Gradient explizit neutralisieren: SetColorTexture allein setzt Vertexfarben nicht zurück.
  local white = CreateColor(1, 1, 1, 1)
  widget.surface:SetGradient("VERTICAL", white, white)
  paint_edges(widget.border, foliant.border, 1, false)
  local c = ns.skin.accents[settings.accent]
  if widget.kind == "surface" then
    paint_edges(widget.inner_border, foliant.inner, 1, false)
    widget.shine:Hide()
    widget.surface:SetColorTexture(0.055, 0.064, 0.078, settings.opacity)
    return
  end
  local enabled = widget:IsEnabled()
  widget.marker:Show()
  local active = enabled and (widget.hovered or widget.selected)
  widget.surface:SetColorTexture(active and c[1] * 0.28 or 0.105,
    active and c[2] * 0.28 or 0.12, active and c[3] * 0.28 or 0.145, 1)
  widget.marker:SetColorTexture(c[1], c[2], c[3], enabled and (active and 1 or 0.25) or 0.08)
  local shade = enabled and 0.92 or 0.4
  widget.label:SetTextColor(shade, shade, shade, 1)
end

function ui.refresh()
  for _, label in ipairs(ui.labels) do paint_label(label) end
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
  ui.labels[#ui.labels + 1] = label
  paint_label(label)
  return label
end

function ui.surface(parent, name, width, height, scaled)
  local f = CreateFrame("Frame", name, parent)
  f:SetSize(width, height)
  f:EnableMouse(true)
  f.kind = "surface"
  f.surface = f:CreateTexture(nil, "BACKGROUND")
  f.surface:SetAllPoints()
  f.border = border(f, 0)
  f.inner_border = border(f, 1)
  f.shine = f:CreateTexture(nil, "BORDER")
  f.shine:SetPoint("TOPLEFT", 12, -2)
  f.shine:SetPoint("TOPRIGHT", -12, -2)
  f.shine:SetHeight(1)
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
  b.border = border(b, 0)
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

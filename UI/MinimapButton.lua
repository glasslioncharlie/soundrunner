local addonName, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local EDGE_MARGIN = 6

local ICON_SIZE = 18

local function orbitRadius()
  return (Minimap:GetWidth() / 2) + EDGE_MARGIN
end

local function updatePosition(button)
  local angle = math.rad(ns.db.minimap.angle)
  local radius = orbitRadius()
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER",
    math.cos(angle) * radius, math.sin(angle) * radius)
end

local function onDragUpdate(button)
  local centerX, centerY = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  cursorX, cursorY = cursorX / scale, cursorY / scale

  ns.db.minimap.angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
  updatePosition(button)
end

function MinimapButton:Create()
  if self.button then return self.button end

  local button = CreateFrame("Button", "SoundrunnerMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(ICON_SIZE + 5, ICON_SIZE + 5)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("CENTER")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("CENTER")
  ns.Fader.SetSpeakerArt(icon, false)

  button:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" then
      MinimapButton:ShowMenu(self)
    else
      ns.Mixer:Toggle()
    end
  end)

  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", onDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Soundrunner")
    GameTooltip:AddLine("Click to open the mixer.", 1, 1, 1)
    GameTooltip:AddLine("Right-click to switch presets.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button.", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.button = button
  self:Update()
  return button
end

function MinimapButton:ShowMenu(owner)
  MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
    rootDescription:CreateTitle("Soundrunner")
    for index = 1, ns.Slots.COUNT do
      rootDescription:CreateRadio(ns.Slots:GetName(index),
        function() return ns.Slots:GetActive() == index end,
        function()
          ns.Slots:Apply(index)
          ns.Mixer:Refresh()
        end)
    end
    rootDescription:CreateDivider()
    rootDescription:CreateButton("Hide Minimap Button", function()
      MinimapButton:SetHidden(true)
    end)
  end)
end

function MinimapButton:SetHidden(hidden)
  ns.db.minimap.hide = hidden
  self:Update()
  ns.Mixer:Refresh()
  if hidden then
    print("|cff33ff99Soundrunner|r: minimap button hidden. Type /vol to open the mixer, or /vol minimap to bring the button back.")
  end
end

function MinimapButton:Update()
  if not self.button then return end
  updatePosition(self.button)
  self.button:SetShown(not ns.db.minimap.hide)
end

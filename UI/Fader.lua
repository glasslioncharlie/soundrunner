local addonName, ns = ...

local Fader = {}
ns.Fader = Fader

Fader.COLUMN_WIDTH = 52
local SLIDER_HEIGHT = 178
Fader.COLUMN_HEIGHT = SLIDER_HEIGHT + 66

local SPEAKER_ON_ATLAS  = "chatframe-button-icon-voicechat"
local SPEAKER_OFF_ATLAS = "voicechat-icon-speaker-mute"

local DIMMED_ALPHA = 0.45

local function setSpeakerArt(texture, muted)
  texture:SetAtlas(muted and SPEAKER_OFF_ATLAS or SPEAKER_ON_ATLAS)
end

Fader.SetSpeakerArt = setSpeakerArt

-- WoW vertical sliders put the minimum at the top; invert so up is louder.
local function sliderToVolume(sliderValue)
  return ns.Channels.Clamp01(1 - sliderValue)
end

local function volumeToSlider(volume)
  return ns.Channels.Clamp01(1 - volume)
end

function Fader.Create(parent, channel)
  local column = CreateFrame("Frame", nil, parent)
  column:SetSize(Fader.COLUMN_WIDTH, Fader.COLUMN_HEIGHT)
  column.channel = channel

  local label = column:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label:SetPoint("TOP", 0, 0)
  label:SetWidth(Fader.COLUMN_WIDTH)
  label:SetWordWrap(false)
  label:SetText(channel.label)
  column.label = label

  local labelHit = CreateFrame("Frame", nil, column)
  labelHit:SetPoint("TOPLEFT", label, "TOPLEFT")
  labelHit:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT")
  labelHit:EnableMouse(true)
  labelHit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(channel.tooltip or channel.label)
    GameTooltip:Show()
  end)
  labelHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local readout = column:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  readout:SetPoint("TOP", label, "BOTTOM", 0, -2)
  column.readout = readout

  local slider = CreateFrame("Slider", nil, column, "BackdropTemplate")
  slider:SetOrientation("VERTICAL")
  slider:SetSize(18, SLIDER_HEIGHT)
  slider:SetPoint("TOP", readout, "BOTTOM", 0, -6)
  slider:SetMinMaxValues(0, 1)
  slider:SetValueStep(0.01)
  slider:SetObeyStepOnDrag(true)
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
  slider:SetBackdrop({
    bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  column.slider = slider

  slider:SetScript("OnValueChanged", function(self, value, userInput)
    local volume = sliderToVolume(value)
    if userInput then
      ns.Channels:SetVolume(channel.key, volume)
      volume = ns.Channels:GetVolume(channel.key)
      ns.Slots:SyncActive()
    end
    readout:SetText(ns.Channels:FormatPercent(volume))
  end)

  -- Suppress Refresh mid-drag so CVAR_UPDATE doesn't fight the thumb.
  slider:SetScript("OnMouseDown", function()
    ns.Mixer.draggingFader = true
  end)
  slider:SetScript("OnMouseUp", function()
    ns.Mixer.draggingFader = false
    ns.Mixer:Refresh()
  end)

  slider:EnableMouseWheel(true)
  slider:SetScript("OnMouseWheel", function(self, delta)
    local target = ns.Channels.Clamp01(sliderToVolume(self:GetValue()) + delta * 0.05)
    ns.Channels:SetVolume(channel.key, target)
    ns.Slots:SyncActive()
    column:Refresh()
  end)

  local speaker = CreateFrame("Button", nil, column)
  speaker:SetSize(22, 22)
  speaker:SetPoint("TOP", slider, "BOTTOM", 0, -8)
  local icon = speaker:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  speaker.icon = icon
  column.speaker = speaker

  speaker:SetScript("OnClick", function()
    ns.Channels:SetToggle(channel.key, not ns.Channels:GetToggle(channel.key))
    ns.Mixer:OnUserEdit()
  end)
  speaker:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(channel.tooltip or channel.label)
    GameTooltip:AddLine(ns.Channels:GetToggle(channel.key) and "Click to mute"
      or "Click to unmute", 1, 1, 1)
    GameTooltip:Show()
  end)
  speaker:SetScript("OnLeave", function() GameTooltip:Hide() end)

  if not channel.hasToggle then
    speaker:Hide()
  end

  function column:Refresh()
    local volume = ns.Channels:GetVolume(channel.key)
    slider:SetValue(volumeToSlider(volume))
    readout:SetText(ns.Channels:FormatPercent(volume))

    if channel.hasToggle then
      local enabled = ns.Channels:GetToggle(channel.key)
      setSpeakerArt(icon, not enabled)
      local alpha = enabled and 1 or DIMMED_ALPHA
      slider:SetAlpha(alpha)
      readout:SetAlpha(alpha)
      label:SetAlpha(alpha)
    end
  end

  column:Refresh()
  return column
end

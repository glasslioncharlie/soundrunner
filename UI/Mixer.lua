local addonName, ns = ...

local Mixer = {}
ns.Mixer = Mixer

local PADDING = 14
local COLUMN_SPACING = 6
local CHIP_SIZE = 26
local CHIP_SPACING = 4
local OPTION_ROW_HEIGHT = 22
local HEADER_HEIGHT = 58

local RENAME_POPUP = "SOUNDRUNNER_RENAME"

StaticPopupDialogs[RENAME_POPUP] = {
  text = "Rename this slot:",
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  maxLetters = ns.Slots.MAX_NAME_LENGTH,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  OnShow = function(self, data)
    self.EditBox:SetText(ns.Slots:GetName(data.index))
    self.EditBox:HighlightText()
    self.EditBox:SetFocus()
  end,
  OnAccept = function(self, data)
    ns.Slots:Rename(data.index, self.EditBox:GetText())
    Mixer:Refresh()
  end,
  EditBoxOnEnterPressed = function(self)
    local dialog = self:GetParent()
    ns.Slots:Rename(dialog.data.index, self:GetText())
    Mixer:Refresh()
    dialog:Hide()
  end,
  EditBoxOnEscapePressed = function(self)
    self:GetParent():Hide()
  end,
}

local function savePosition(frame)
  local point, _, relPoint, x, y = frame:GetPoint()
  local ui = ns.db.ui
  ui.point = point
  ui.relPoint = relPoint
  ui.x = x
  ui.y = y
end

local function restorePosition(frame)
  local ui = ns.db.ui
  frame:ClearAllPoints()
  frame:SetPoint(ui.point, UIParent, ui.relPoint, ui.x, ui.y)
end

function Mixer:ShowChipMenu(chip)
  local index = chip.index
  MenuUtil.CreateContextMenu(chip, function(_, rootDescription)
    rootDescription:CreateTitle(ns.Slots:GetName(index))
    rootDescription:CreateButton("Apply", function()
      ns.Slots:Apply(index)
      Mixer:Refresh()
    end)
    rootDescription:CreateButton("Rename", function()
      StaticPopup_Show(RENAME_POPUP, nil, nil, { index = index })
    end)
  end)
end

local function onChipClick(chip, button)
  local index = chip.index

  if button == "RightButton" then
    Mixer:ShowChipMenu(chip)
    return
  end

  ns.Slots:Apply(index)
  Mixer:Refresh()
end

function Mixer:Create()
  if self.frame then return self.frame end

  local channels = ns.Channels.channels
  local options = ns.Channels.options

  local columnsWidth = #channels * ns.Fader.COLUMN_WIDTH
    + math.max(0, #channels - 1) * COLUMN_SPACING
  local width = math.max(columnsWidth + PADDING * 2, 280)
  local height = HEADER_HEIGHT + ns.Fader.COLUMN_HEIGHT
    + (#options + 1) * OPTION_ROW_HEIGHT + PADDING * 3

  local frame = CreateFrame("Frame", "SoundrunnerMixer", UIParent,
    "BasicFrameTemplateWithInset")
  frame:SetSize(width, height)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition(self)
  end)
  -- Hide before setting OnHide, or it overwrites the saved shown state.
  frame:Hide()

  frame:SetScript("OnShow", function()
    ns.db.ui.shown = true
    Mixer:Refresh()
  end)
  frame:SetScript("OnHide", function()
    ns.db.ui.shown = false
  end)
  frame.TitleText:SetText("Soundrunner")
  restorePosition(frame)
  self.frame = frame

  tinsert(UISpecialFrames, "SoundrunnerMixer")

  self.chips = {}
  for index = 1, ns.Slots.COUNT do
    local chip = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    chip:SetSize(CHIP_SIZE, CHIP_SIZE)
    chip:SetText(index)
    chip.index = index
    chip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    chip:SetScript("OnClick", onChipClick)
    chip:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(ns.Slots:GetName(self.index))
      GameTooltip:AddLine("Click to apply.", 1, 1, 1)
      GameTooltip:AddLine("Right-click to rename.", 1, 1, 1)
      GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local selection = chip:CreateTexture(nil, "BACKGROUND")
    selection:SetPoint("TOPLEFT", -2, 2)
    selection:SetPoint("BOTTOMRIGHT", 2, -2)
    selection:SetColorTexture(1, 0.82, 0, 0.35)
    selection:Hide()
    chip.selection = selection

    if index == 1 then
      chip:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -30)
    else
      chip:SetPoint("LEFT", self.chips[index - 1], "RIGHT", CHIP_SPACING, 0)
    end
    self.chips[index] = chip
  end

  local nameLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  nameLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -36)
  nameLabel:SetWidth(width - (PADDING * 2) - (ns.Slots.COUNT * (CHIP_SIZE + CHIP_SPACING)))
  nameLabel:SetJustifyH("RIGHT")
  nameLabel:SetWordWrap(false)
  self.nameLabel = nameLabel

  self.faders = {}
  for index, channel in ipairs(channels) do
    local column = ns.Fader.Create(frame, channel)
    if index == 1 then
      column:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -HEADER_HEIGHT - PADDING)
    else
      column:SetPoint("TOPLEFT", self.faders[index - 1], "TOPRIGHT", COLUMN_SPACING, 0)
    end
    self.faders[index] = column
  end

  local previousCheck
  local function addCheck(label, onClick)
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetScript("OnClick", onClick)

    local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetText(label)

    if previousCheck then
      check:SetPoint("TOPLEFT", previousCheck, "BOTTOMLEFT", 0, -2)
    else
      check:SetPoint("TOPLEFT", self.faders[1], "BOTTOMLEFT", 0, -PADDING)
    end
    previousCheck = check
    return check
  end

  self.optionChecks = {}
  for index, option in ipairs(options) do
    local check = addCheck(option.label, function(self)
      ns.Channels:SetOption(self.optionKey, self:GetChecked() and true or false)
      Mixer:OnUserEdit()
    end)
    check.optionKey = option.key
    self.optionChecks[index] = check
  end

  self.minimapCheck = addCheck("Show Minimap Button", function(self)
    ns.MinimapButton:SetHidden(not self:GetChecked())
  end)

  return frame
end

function Mixer:Refresh()
  if not self.frame then return end
  if self.draggingFader then return end

  local active = ns.Slots:GetActive()
  self.nameLabel:SetText(ns.Slots:GetName(active))

  for index, chip in ipairs(self.chips) do
    if index == active then chip.selection:Show() else chip.selection:Hide() end
  end

  for _, column in ipairs(self.faders) do
    column:Refresh()
  end

  for _, check in ipairs(self.optionChecks) do
    check:SetChecked(ns.Channels:GetOption(check.optionKey))
  end

  self.minimapCheck:SetChecked(not ns.db.minimap.hide)
end

function Mixer:OnUserEdit()
  ns.Slots:SyncActive()
  self:Refresh()
end

function Mixer:Show()
  self:Create()
  self.frame:Show()
end

function Mixer:Hide()
  if self.frame then self.frame:Hide() end
end

function Mixer:Toggle()
  self:Create()
  if self.frame:IsShown() then
    self:Hide()
  else
    self:Show()
  end
end

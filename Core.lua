local addonName, ns = ...

local Core = {}
ns.Core = Core

local DB_VERSION = 1

local function applyDefaults(db)
  if type(db.version) ~= "number" then db.version = DB_VERSION end

  if type(db.ui) ~= "table" then db.ui = {} end
  local ui = db.ui
  if type(ui.point) ~= "string" then ui.point = "CENTER" end
  if type(ui.relPoint) ~= "string" then ui.relPoint = "CENTER" end
  if type(ui.x) ~= "number" then ui.x = 0 end
  if type(ui.y) ~= "number" then ui.y = 0 end
  if type(ui.shown) ~= "boolean" then ui.shown = false end

  if type(db.minimap) ~= "table" then db.minimap = {} end
  local minimap = db.minimap
  if type(minimap.angle) ~= "number" then minimap.angle = 200 end
  if type(minimap.hide) ~= "boolean" then minimap.hide = false end

  return db
end

Core.ApplyDefaults = applyDefaults

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      SoundrunnerDB = SoundrunnerDB or {}
      ns.db = applyDefaults(SoundrunnerDB)
    end

  elseif event == "PLAYER_LOGIN" then
    ns.Channels:Probe()
    ns.Slots:Init(ns.db)
    ns.MinimapButton:Create()
    ns.Mixer:Create()
    if ns.db.ui.shown then
      ns.Mixer:Show()
    end

  elseif event == "CVAR_UPDATE" then
    if type(arg1) == "string" and arg1:find("^Sound_") and ns.Mixer and ns.Mixer.frame then
      ns.Slots:SyncActive()
      ns.Mixer:Refresh()
    end
  end
end)

SLASH_SOUNDRUNNER1 = "/vol"
SLASH_SOUNDRUNNER2 = "/soundrunner"
SLASH_SOUNDRUNNER3 = "/sr"
SlashCmdList["SOUNDRUNNER"] = function(message)
  if message:lower():match("^%s*minimap%s*$") then
    ns.MinimapButton:SetHidden(not ns.db.minimap.hide)
  else
    ns.Mixer:Toggle()
  end
end

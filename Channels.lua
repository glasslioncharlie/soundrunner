local addonName, ns = ...

local Channels = {}
ns.Channels = Channels

Channels.CHANNEL_DEFS = {
  { key = "master",   label = "Master",   tooltip = "Master Volume",
    volumeCVar = "Sound_MasterVolume",
    toggleKey  = "enableAll",      toggleCVar = "Sound_EnableAllSound" },
  { key = "music",    label = "Music",    tooltip = "Music Volume",
    volumeCVar = "Sound_MusicVolume",
    toggleKey  = "enableMusic",    toggleCVar = "Sound_EnableMusic" },
  { key = "sfx",      label = "SFX",      tooltip = "Sound Effects Volume",
    volumeCVar = "Sound_SFXVolume",
    toggleKey  = "enableSFX",      toggleCVar = "Sound_EnableSFX" },
  { key = "dialog",   label = "Dialog",   tooltip = "Dialog Volume",
    volumeCVar = "Sound_DialogVolume",
    toggleKey  = "enableDialog",   toggleCVar = "Sound_EnableDialog" },
  { key = "ambience", label = "Ambience", tooltip = "Ambience Volume",
    volumeCVar = "Sound_AmbienceVolume",
    toggleKey  = "enableAmbience", toggleCVar = "Sound_EnableAmbience" },
}

Channels.OPTION_DEFS = {
  { key = "bgSound",     label = "Sound in Background", cvar = "Sound_EnableSoundWhenGameIsInBG" },
  { key = "errorSpeech", label = "Error Speech",        cvar = "Sound_EnableErrorSpeech" },
  { key = "emoteSounds", label = "Emote Sounds",        cvar = "Sound_EnableEmoteSounds" },
  { key = "loopMusic",   label = "Loop Music",          cvar = "Sound_ZoneMusicNoDelay" },
}

Channels.DEFAULTS = {
  master   = 1, music        = 1, sfx          = 1,
  dialog   = 1, ambience     = 1,
  enableAll     = true, enableMusic    = true, enableSFX = true,
  enableDialog  = true, enableAmbience = true,
  bgSound       = false, errorSpeech   = true,
  emoteSounds   = true,  loopMusic     = false,
}

Channels.MASTER_KEY = "master"

local function cvarExists(name)
  return name ~= nil and C_CVar.GetCVar(name) ~= nil
end

function Channels:Probe()
  self.channels = {}
  self.channelsByKey = {}
  for _, def in ipairs(self.CHANNEL_DEFS) do
    if cvarExists(def.volumeCVar) then
      local channel = {
        key        = def.key,
        label      = def.label,
        tooltip    = def.tooltip,
        volumeCVar = def.volumeCVar,
        toggleKey  = def.toggleKey,
        toggleCVar = def.toggleCVar,
        hasToggle  = cvarExists(def.toggleCVar),
      }
      table.insert(self.channels, channel)
      self.channelsByKey[channel.key] = channel
    end
  end

  self.options = {}
  self.optionsByKey = {}
  for _, def in ipairs(self.OPTION_DEFS) do
    if cvarExists(def.cvar) then
      local option = { key = def.key, label = def.label, cvar = def.cvar }
      table.insert(self.options, option)
      self.optionsByKey[option.key] = option
    end
  end

  return self.channels, self.options
end

function Channels:ResetWriteWarning()
  self.warnedAboutWrite = false
end

local function clamp01(value)
  value = tonumber(value) or 0
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

Channels.Clamp01 = clamp01

function Channels:FormatPercent(value)
  return string.format("%d%%", math.floor(clamp01(value) * 100 + 0.5))
end

function Channels:Write(cvar, value)
  local ok = C_CVar.SetCVar(cvar, value)
  if not ok and not self.warnedAboutWrite then
    self.warnedAboutWrite = true
    print("|cffff4040Soundrunner|r: this client refused a sound setting change ("
      .. tostring(cvar) .. "). The panel shows the client's actual values.")
  end
  return ok and true or false
end

function Channels:GetVolume(key)
  local channel = self.channelsByKey[key]
  if not channel then return 0 end
  return clamp01(C_CVar.GetCVar(channel.volumeCVar))
end

function Channels:SetVolume(key, value)
  local channel = self.channelsByKey[key]
  if not channel then return false end
  return self:Write(channel.volumeCVar, string.format("%.4f", clamp01(value)))
end

function Channels:GetToggle(key)
  local channel = self.channelsByKey[key]
  if not channel or not channel.hasToggle then return true end
  return C_CVar.GetCVar(channel.toggleCVar) == "1"
end

function Channels:SetToggle(key, enabled)
  local channel = self.channelsByKey[key]
  if not channel or not channel.hasToggle then return false end
  return self:Write(channel.toggleCVar, enabled and "1" or "0")
end

function Channels:GetOption(key)
  local option = self.optionsByKey[key]
  if not option then return false end
  return C_CVar.GetCVar(option.cvar) == "1"
end

function Channels:SetOption(key, enabled)
  local option = self.optionsByKey[key]
  if not option then return false end
  return self:Write(option.cvar, enabled and "1" or "0")
end

function Channels:Capture()
  local snapshot = {}
  for _, channel in ipairs(self.channels) do
    snapshot[channel.key] = self:GetVolume(channel.key)
    if channel.hasToggle then
      snapshot[channel.toggleKey] = self:GetToggle(channel.key)
    end
  end
  for _, option in ipairs(self.options) do
    snapshot[option.key] = self:GetOption(option.key)
  end
  return snapshot
end

function Channels:Apply(snapshot)
  if type(snapshot) ~= "table" then return false end

  local master = self.channelsByKey[self.MASTER_KEY]

  -- Explicit nil check: `a and b or c` would turn a stored false into nil.
  local masterTarget
  if master and master.hasToggle and snapshot[master.toggleKey] ~= nil then
    masterTarget = snapshot[master.toggleKey]
  end

  -- Mute first and unmute last, so the volume changes in between are never heard.
  if masterTarget == false then
    self:SetToggle(self.MASTER_KEY, false)
  end

  for _, channel in ipairs(self.channels) do
    if snapshot[channel.key] ~= nil then
      self:SetVolume(channel.key, snapshot[channel.key])
    end
  end

  for _, option in ipairs(self.options) do
    if snapshot[option.key] ~= nil then
      self:SetOption(option.key, snapshot[option.key])
    end
  end

  for _, channel in ipairs(self.channels) do
    if channel.key ~= self.MASTER_KEY and channel.hasToggle
      and snapshot[channel.toggleKey] ~= nil then
      self:SetToggle(channel.key, snapshot[channel.toggleKey])
    end
  end

  if masterTarget == true then
    self:SetToggle(self.MASTER_KEY, true)
  end

  return true
end

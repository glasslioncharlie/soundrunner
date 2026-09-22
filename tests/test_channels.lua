package.path = "tests/?.lua;" .. package.path
local Runner = require("runner")
local Stubs = require("wow_stubs")

local FULL_CVARS = {
  Sound_MasterVolume   = "1.0",  Sound_EnableAllSound  = "1",
  Sound_MusicVolume    = "0.6",  Sound_EnableMusic     = "1",
  Sound_SFXVolume      = "0.75", Sound_EnableSFX       = "1",
  Sound_DialogVolume   = "1.0",  Sound_EnableDialog    = "1",
  Sound_AmbienceVolume = "1.0",  Sound_EnableAmbience  = "1",
  Sound_EnableSoundWhenGameIsInBG = "0",
  Sound_EnableErrorSpeech         = "1",
  Sound_EnableEmoteSounds         = "1",
  Sound_ZoneMusicNoDelay          = "0",
}

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

local function newChannels(cvars)
  local env = Stubs.new(cvars or copy(FULL_CVARS))
  local ns = {}
  Stubs.loadAddonFile("Channels.lua", ns, env)
  ns.Channels:ResetWriteWarning()
  ns.Channels:Probe()
  return ns.Channels, env
end

local M = { FULL_CVARS = FULL_CVARS, copy = copy, newChannels = newChannels }

Runner.test("probe keeps every channel on a full client", function()
  local Channels = newChannels()
  Runner.eq(#Channels.channels, 5, "channel count")
  Runner.eq(Channels.channels[1].key, "master", "master is first")
  Runner.eq(Channels.channels[5].key, "ambience", "ambience is last")
  Runner.eq(#Channels.options, 4, "option count")
end)

Runner.test("probe drops a channel whose volume cvar is absent", function()
  local cvars = copy(FULL_CVARS)
  cvars.Sound_DialogVolume = nil
  local Channels = newChannels(cvars)
  Runner.eq(#Channels.channels, 4, "dialog column removed")
  Runner.isNil(Channels.channelsByKey.dialog, "dialog not indexed")
  Runner.isTrue(Channels.channelsByKey.music ~= nil, "surviving channels still indexed")
end)

Runner.test("probe keeps a channel without its toggle but marks hasToggle false", function()
  local cvars = copy(FULL_CVARS)
  cvars.Sound_EnableAmbience = nil
  local Channels = newChannels(cvars)
  Runner.isTrue(Channels.channelsByKey.ambience ~= nil, "channel survives")
  Runner.isFalse(Channels.channelsByKey.ambience.hasToggle, "hasToggle is false")
  Runner.isTrue(Channels.channelsByKey.music.hasToggle, "unaffected channel keeps its toggle")
end)

Runner.test("probe drops an absent option", function()
  local cvars = copy(FULL_CVARS)
  cvars.Sound_ZoneMusicNoDelay = nil
  local Channels = newChannels(cvars)
  Runner.eq(#Channels.options, 3, "option removed")
  Runner.isNil(Channels.optionsByKey.loopMusic, "loopMusic not indexed")
end)

Runner.test("probe is idempotent", function()
  local Channels = newChannels()
  Channels:Probe()
  Channels:Probe()
  Runner.eq(#Channels.channels, 5, "repeat probe does not duplicate channels")
  Runner.eq(#Channels.options, 4, "repeat probe does not duplicate options")
end)

Runner.test("format percent rounds and clamps", function()
  local Channels = newChannels()
  Runner.eq(Channels:FormatPercent(0), "0%", "zero")
  Runner.eq(Channels:FormatPercent(1), "100%", "one")
  -- Exactly representable as a double, so this pins round-half-up (0.755 would not).
  Runner.eq(Channels:FormatPercent(0.125), "13%", "rounds half up")
  Runner.eq(Channels:FormatPercent(0.004), "0%", "rounds down below .5")
  Runner.eq(Channels:FormatPercent(1.9), "100%", "clamps above one")
  Runner.eq(Channels:FormatPercent(-0.5), "0%", "clamps below zero")
  Runner.eq(Channels:FormatPercent(nil), "0%", "nil is treated as zero")
end)

Runner.test("get volume reads and clamps the cvar", function()
  local cvars = copy(FULL_CVARS)
  cvars.Sound_MusicVolume = "0.6"
  cvars.Sound_SFXVolume = "3.0"
  local Channels = newChannels(cvars)
  Runner.eq(Channels:GetVolume("music"), 0.6, "in-range value")
  Runner.eq(Channels:GetVolume("sfx"), 1, "out-of-range value clamps")
  Runner.eq(Channels:GetVolume("nosuch"), 0, "unknown channel reads zero")
end)

Runner.test("set volume writes a clamped value", function()
  local Channels, env = newChannels()
  Runner.isTrue(Channels:SetVolume("music", 0.25), "write succeeds")
  Runner.eq(Channels:GetVolume("music"), 0.25, "round-trips")
  Channels:SetVolume("music", 5)
  Runner.eq(Channels:GetVolume("music"), 1, "clamps high")
  Channels:SetVolume("music", -2)
  Runner.eq(Channels:GetVolume("music"), 0, "clamps low")
  Runner.isFalse(Channels:SetVolume("nosuch", 0.5), "unknown channel refuses")
  Runner.isNil(env:indexOf("nosuch"), "unknown channel writes nothing")
end)

Runner.test("toggles round-trip as 1 and 0", function()
  local Channels = newChannels()
  Channels:SetToggle("music", false)
  Runner.isFalse(Channels:GetToggle("music"), "false round-trips")
  Channels:SetToggle("music", true)
  Runner.isTrue(Channels:GetToggle("music"), "true round-trips")
end)

Runner.test("a channel with no toggle reports enabled and refuses writes", function()
  local cvars = copy(FULL_CVARS)
  cvars.Sound_EnableAmbience = nil
  local Channels, env = newChannels(cvars)
  Runner.isTrue(Channels:GetToggle("ambience"), "defaults to enabled")
  Runner.isFalse(Channels:SetToggle("ambience", false), "write refused")
  Runner.eq(#env.writeLog, 0, "nothing written")
end)

Runner.test("options round-trip as 1 and 0", function()
  local Channels = newChannels()
  Runner.isFalse(Channels:GetOption("bgSound"), "seeded as off")
  Channels:SetOption("bgSound", true)
  Runner.isTrue(Channels:GetOption("bgSound"), "turns on")
  Runner.isFalse(Channels:SetOption("nosuch", true), "unknown option refuses")
end)

Runner.test("a rejected write warns exactly once per session", function()
  local Channels, env = newChannels()
  env.failWrites.Sound_MusicVolume = true
  Runner.isFalse(Channels:SetVolume("music", 0.1), "first write fails")
  Runner.isFalse(Channels:SetVolume("music", 0.2), "second write fails")
  Runner.eq(#env.printed, 1, "warned once, not twice")
  Runner.isTrue(env.printed[1]:find("Sound_MusicVolume", 1, true) ~= nil,
    "warning names the cvar")

  Channels:ResetWriteWarning()
  Channels:SetVolume("music", 0.3)
  Runner.eq(#env.printed, 2, "warning re-arms after reset")
end)

Runner.test("capture records every channel, toggle and option", function()
  local Channels = newChannels()
  local snap = Channels:Capture()
  Runner.eq(snap.master, 1, "master volume")
  Runner.eq(snap.music, 0.6, "music volume")
  Runner.eq(snap.sfx, 0.75, "sfx volume")
  Runner.isTrue(snap.enableAll, "master toggle")
  Runner.isTrue(snap.enableMusic, "music toggle")
  Runner.isFalse(snap.bgSound, "background option")
  Runner.isTrue(snap.errorSpeech, "error speech option")
  Runner.isFalse(snap.loopMusic, "loop music option")
end)

Runner.test("capture omits keys the client does not expose", function()
  local cvars = copy(FULL_CVARS)
  cvars.Sound_DialogVolume = nil
  cvars.Sound_EnableAmbience = nil
  local Channels = newChannels(cvars)
  local snap = Channels:Capture()
  Runner.isNil(snap.dialog, "absent channel omitted")
  Runner.isNil(snap.enableAmbience, "absent toggle omitted")
  Runner.isTrue(snap.ambience ~= nil, "present volume still captured")
end)

Runner.test("capture then apply round-trips the client state", function()
  local Channels = newChannels()
  local snap = Channels:Capture()

  Channels:SetVolume("music", 0.1)
  Channels:SetVolume("sfx", 0.2)
  Channels:SetToggle("music", false)
  Channels:SetOption("bgSound", true)

  Runner.isTrue(Channels:Apply(snap), "apply succeeds")
  Runner.eq(Channels:GetVolume("music"), 0.6, "music restored")
  Runner.eq(Channels:GetVolume("sfx"), 0.75, "sfx restored")
  Runner.isTrue(Channels:GetToggle("music"), "music toggle restored")
  Runner.isFalse(Channels:GetOption("bgSound"), "option restored")
end)

Runner.test("applying an unmuted preset writes the master toggle last", function()
  local Channels, env = newChannels()
  local snap = Channels:Capture()
  snap.enableAll = true
  env:clearWrites()

  Channels:Apply(snap)
  local order = env:writeOrder()
  Runner.eq(order[#order], "Sound_EnableAllSound", "master toggle is the final write")
  Runner.isTrue(env:indexOf("Sound_MasterVolume") < env:indexOf("Sound_EnableAllSound"),
    "volumes precede the master toggle")
  Runner.isTrue(env:indexOf("Sound_EnableMusic") < env:indexOf("Sound_EnableAllSound"),
    "per-channel toggles precede the master toggle")
end)

Runner.test("applying a muted preset writes the master toggle first", function()
  local Channels, env = newChannels()
  local snap = Channels:Capture()
  snap.enableAll = false
  env:clearWrites()

  Channels:Apply(snap)
  local order = env:writeOrder()
  Runner.eq(order[1], "Sound_EnableAllSound", "master toggle is the first write")
  Runner.eq(env.cvars.Sound_EnableAllSound, "0", "and it lands muted")
  Runner.isTrue(env:indexOf("Sound_MasterVolume") > 1, "volumes follow the mute")
end)

Runner.test("apply ignores a snapshot that is not a table", function()
  local Channels, env = newChannels()
  env:clearWrites()
  Runner.isFalse(Channels:Apply(nil), "nil refused")
  Runner.isFalse(Channels:Apply("nonsense"), "string refused")
  Runner.eq(#env.writeLog, 0, "nothing written")
end)

Runner.test("apply skips keys absent from the snapshot", function()
  local Channels, env = newChannels()
  env:clearWrites()
  Channels:Apply({ music = 0.3 })
  Runner.eq(Channels:GetVolume("music"), 0.3, "present key applied")
  Runner.isNil(env:indexOf("Sound_SFXVolume"), "absent key not written")
  Runner.isNil(env:indexOf("Sound_EnableAllSound"), "absent master toggle not written")
end)

Runner.test("muting preserves the channel volume", function()
  local Channels, env = newChannels()
  Channels:SetVolume("music", 0.42)
  env:clearWrites()

  Channels:SetToggle("music", false)
  Runner.eq(env.cvars.Sound_MusicVolume, "0.4200", "volume cvar untouched")
  Runner.isNil(env:indexOf("Sound_MusicVolume"), "no volume write at all")

  Channels:SetToggle("music", true)
  Runner.eq(Channels:GetVolume("music"), 0.42, "unmute returns to the same level")
end)

Runner.test("defaults are the full-volume, nothing-looping baseline", function()
  local Channels = newChannels()
  local d = Channels.DEFAULTS
  for _, key in ipairs({ "master", "music", "sfx", "dialog", "ambience" }) do
    Runner.eq(d[key], 1, key .. " defaults to 100%")
  end
  Runner.isTrue(d.enableAll, "sound enabled")
  Runner.isFalse(d.loopMusic, "music does not loop")
end)

Runner.test("applying defaults restores a mangled client", function()
  local Channels = newChannels()
  Channels:SetVolume("master", 0)
  Channels:SetToggle("master", false)
  Channels:SetOption("loopMusic", true)

  Channels:Apply(Channels.DEFAULTS)
  Runner.eq(Channels:GetVolume("master"), 1, "master restored")
  Runner.isTrue(Channels:GetToggle("master"), "sound back on")
  Runner.isFalse(Channels:GetOption("loopMusic"), "loop music back off")
end)

return M

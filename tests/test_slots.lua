package.path = "tests/?.lua;" .. package.path
local Runner = require("runner")
local Stubs = require("wow_stubs")
local Channels = require("test_channels")

local function newNs(cvars, db)
  local env = Stubs.new(cvars or Channels.copy(Channels.FULL_CVARS))
  local ns = {}
  Stubs.loadAddonFile("Channels.lua", ns, env)
  Stubs.loadAddonFile("Slots.lua", ns, env)
  ns.Channels:ResetWriteWarning()
  ns.Channels:Probe()
  db = db or {}
  ns.Slots:Init(db)
  return ns, db, env
end

local function editSlot(ns, index, key, volume)
  ns.Slots:Apply(index)
  ns.Channels:SetVolume(key, volume)
  ns.Slots:SyncActive()
end

Runner.test("init seeds five named slots with Blizzard defaults", function()
  local ns, db = newNs()
  Runner.eq(ns.Slots.COUNT, 5, "slot count")
  for i = 1, 5 do
    Runner.eq(db.slots[i].name, "Slot " .. i, "default name " .. i)
    Runner.eq(db.slots[i].data.master, 1, "slot " .. i .. " master at 100%")
    Runner.isFalse(db.slots[i].data.loopMusic, "slot " .. i .. " loop music off")
  end
  Runner.eq(db.activeSlot, 1, "active slot defaults to 1")
end)

Runner.test("seeded slots do not share one table", function()
  local ns, db = newNs()
  db.slots[1].data.master = 0.25
  Runner.eq(db.slots[2].data.master, 1, "editing slot 1 leaves slot 2 alone")
  Runner.eq(db.slots[5].data.master, 1, "and leaves slot 5 alone")
end)

Runner.test("init preserves existing valid slots", function()
  local existing = {
    slots = { [2] = { name = "Raid", data = { music = 0.2 } } },
    activeSlot = 2,
  }
  local ns, db = newNs(nil, existing)
  Runner.eq(db.slots[2].name, "Raid", "name preserved")
  Runner.eq(db.slots[2].data.music, 0.2, "data preserved")
  Runner.eq(db.activeSlot, 2, "active slot preserved")
  Runner.eq(db.slots[1].data.master, 1, "missing slots seeded with defaults")
end)

Runner.test("init repairs corrupt saved data", function()
  local corrupt = {
    slots = {
      [1] = "not a table",
      [2] = { name = 42, data = "not a table" },
      [3] = { name = "" },
    },
    activeSlot = 99,
  }
  local ns, db = newNs(nil, corrupt)
  Runner.eq(db.slots[1].name, "Slot 1", "non-table slot replaced")
  Runner.eq(db.slots[2].name, "Slot 2", "non-string name replaced")
  Runner.eq(db.slots[2].data.master, 1, "non-table data replaced with defaults")
  Runner.eq(db.slots[3].name, "Slot 3", "empty name replaced")
  Runner.eq(db.activeSlot, 1, "out-of-range active slot reset")
end)

Runner.test("init discards slots beyond the supported count", function()
  local ns, db = newNs(nil, { slots = { [6] = { name = "Ghost", data = {} } } })
  Runner.isNil(db.slots[6], "orphan slot removed")
end)

Runner.test("get refuses out-of-range indices", function()
  local ns = newNs()
  Runner.isNil(ns.Slots:Get(0), "zero")
  Runner.isNil(ns.Slots:Get(6), "above count")
  Runner.isNil(ns.Slots:Get("2"), "non-number")
  Runner.isTrue(ns.Slots:Get(3) ~= nil, "valid index")
end)

Runner.test("rename trims, rejects blanks and truncates", function()
  local ns = newNs()
  Runner.isTrue(ns.Slots:Rename(1, "  Raid Night  "), "accepts padded name")
  Runner.eq(ns.Slots:GetName(1), "Raid Night", "whitespace trimmed")

  Runner.isFalse(ns.Slots:Rename(1, "   "), "whitespace-only rejected")
  Runner.eq(ns.Slots:GetName(1), "Raid Night", "name unchanged after rejection")

  Runner.isFalse(ns.Slots:Rename(1, ""), "empty rejected")
  Runner.isFalse(ns.Slots:Rename(1, nil), "nil rejected")
  Runner.isFalse(ns.Slots:Rename(9, "Nope"), "bad index rejected")

  ns.Slots:Rename(2, string.rep("x", 40))
  Runner.eq(#ns.Slots:GetName(2), 24, "truncated to 24 characters")
end)

Runner.test("apply restores a slot and makes it active", function()
  local ns = newNs()
  editSlot(ns, 2, "music", 0.9)
  ns.Slots:Apply(1)
  Runner.eq(ns.Channels:GetVolume("music"), 1, "slot 1 defaults applied")

  Runner.isTrue(ns.Slots:Apply(2), "apply succeeds")
  Runner.eq(ns.Channels:GetVolume("music"), 0.9, "volume restored")
  Runner.eq(ns.Slots:GetActive(), 2, "applied slot becomes active")
end)

Runner.test("applying an out-of-range slot is a no-op", function()
  local ns, _, env = newNs()
  env:clearWrites()
  Runner.isFalse(ns.Slots:Apply(0), "zero refused")
  Runner.isFalse(ns.Slots:Apply(6), "above count refused")
  Runner.eq(#env.writeLog, 0, "nothing written")
end)

Runner.test("renaming a slot does not disturb its data", function()
  local ns = newNs()
  editSlot(ns, 1, "sfx", 0.33)
  ns.Slots:Rename(1, "Dungeon")
  Runner.eq(ns.Slots:GetName(1), "Dungeon", "renamed")
  ns.Slots:Apply(2)
  ns.Slots:Apply(1)
  Runner.eq(ns.Channels:GetVolume("sfx"), 0.33, "data intact after rename")
end)

Runner.test("sync active writes live sound into the active slot", function()
  local ns, db = newNs()
  ns.Slots:Apply(3)
  ns.Channels:SetVolume("sfx", 0.2)

  Runner.isTrue(ns.Slots:SyncActive(), "sync succeeds")
  Runner.eq(db.slots[3].data.sfx, 0.2, "active slot captured the change")
  Runner.eq(ns.Slots:GetActive(), 3, "sync does not move the active slot")
end)

Runner.test("sync active leaves other slots alone", function()
  local ns, db = newNs()
  editSlot(ns, 2, "sfx", 0.9)
  editSlot(ns, 1, "sfx", 0.1)
  Runner.eq(db.slots[2].data.sfx, 0.9, "the inactive slot is untouched")
end)

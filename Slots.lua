local addonName, ns = ...

local Slots = {}
ns.Slots = Slots

Slots.COUNT = 5
Slots.MAX_NAME_LENGTH = 24

local function defaultName(index)
  return "Slot " .. index
end

local function defaultData()
  local data = {}
  for key, value in pairs(ns.Channels.DEFAULTS) do
    data[key] = value
  end
  return data
end

function Slots:Init(db)
  self.db = db
  db.slots = db.slots or {}

  for index = 1, self.COUNT do
    local slot = db.slots[index]
    if type(slot) ~= "table" then
      slot = { name = defaultName(index) }
      db.slots[index] = slot
    end
    if type(slot.name) ~= "string" or slot.name == "" then
      slot.name = defaultName(index)
    end
    if type(slot.data) ~= "table" then
      slot.data = defaultData()
    end
  end

  for index = self.COUNT + 1, #db.slots do
    db.slots[index] = nil
  end

  if type(db.activeSlot) ~= "number"
    or db.activeSlot < 1
    or db.activeSlot > self.COUNT then
    db.activeSlot = 1
  end

  return db
end

function Slots:Get(index)
  if type(index) ~= "number" or index < 1 or index > self.COUNT then
    return nil
  end
  return self.db.slots[index]
end

function Slots:GetName(index)
  local slot = self:Get(index)
  return slot and slot.name or nil
end

function Slots:Rename(index, name)
  local slot = self:Get(index)
  if not slot or type(name) ~= "string" then return false end

  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return false end
  if #name > self.MAX_NAME_LENGTH then
    name = name:sub(1, self.MAX_NAME_LENGTH)
  end

  slot.name = name
  return true
end

function Slots:Apply(index)
  local slot = self:Get(index)
  if not slot then return false end

  -- Set before applying: the CVAR_UPDATEs it fires sync into the active slot.
  self.db.activeSlot = index
  ns.Channels:Apply(slot.data)
  return true
end

function Slots:SyncActive()
  local slot = self:Get(self.db.activeSlot)
  if not slot then return false end

  slot.data = ns.Channels:Capture()
  return true
end

function Slots:GetActive()
  return self.db.activeSlot
end

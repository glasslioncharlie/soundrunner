package.path = "tests/?.lua;" .. package.path
local Runner = require("runner")
local Stubs = require("wow_stubs")
local Channels = require("test_channels")

local function newCoreNs()
  local env = Stubs.new(Channels.copy(Channels.FULL_CVARS))
  local noop = function() end
  local frameStub = {
    RegisterEvent = noop,
    SetScript = noop,
  }
  env.globals.CreateFrame = function() return frameStub end
  env.globals.SlashCmdList = {}

  local ns = {}
  Stubs.loadAddonFile("Channels.lua", ns, env)
  Stubs.loadAddonFile("Slots.lua", ns, env)
  Stubs.loadAddonFile("Core.lua", ns, env)
  return ns, env
end

Runner.test("apply defaults fills a blank database", function()
  local ns = newCoreNs()
  local db = ns.Core.ApplyDefaults({})
  Runner.eq(db.version, 1, "version stamped")
  Runner.eq(db.ui.point, "CENTER", "ui point")
  Runner.eq(db.ui.relPoint, "CENTER", "ui relative point")
  Runner.eq(db.ui.x, 0, "ui x")
  Runner.eq(db.ui.y, 0, "ui y")
  Runner.isFalse(db.ui.shown, "panel starts hidden")
  Runner.eq(db.minimap.angle, 200, "minimap angle")
  Runner.isFalse(db.minimap.hide, "minimap visible")
end)

Runner.test("apply defaults preserves existing values", function()
  local ns = newCoreNs()
  local db = ns.Core.ApplyDefaults({
    ui = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 120, y = -40, shown = true },
    minimap = { angle = 15, hide = true },
  })
  Runner.eq(db.ui.point, "TOPLEFT", "point kept")
  Runner.eq(db.ui.x, 120, "x kept")
  Runner.isTrue(db.ui.shown, "shown kept")
  Runner.eq(db.minimap.angle, 15, "angle kept")
  Runner.isTrue(db.minimap.hide, "hide kept")
end)

Runner.test("apply defaults repairs wrong types", function()
  local ns = newCoreNs()
  local db = ns.Core.ApplyDefaults({
    ui = { point = 5, x = "nope", shown = "yes" },
    minimap = { angle = "round", hide = 1 },
  })
  Runner.eq(db.ui.point, "CENTER", "bad point replaced")
  Runner.eq(db.ui.x, 0, "bad x replaced")
  Runner.isFalse(db.ui.shown, "bad shown replaced")
  Runner.eq(db.minimap.angle, 200, "bad angle replaced")
  Runner.isFalse(db.minimap.hide, "bad hide replaced")
end)

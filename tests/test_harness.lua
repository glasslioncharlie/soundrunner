package.path = "tests/?.lua;" .. package.path
local Runner = require("runner")
local Stubs = require("wow_stubs")

Runner.test("stub reads seeded cvars", function()
  local env = Stubs.new({ Sound_MasterVolume = "0.5" })
  Runner.eq(env.globals.C_CVar.GetCVar("Sound_MasterVolume"), "0.5", "seeded read")
  Runner.isNil(env.globals.C_CVar.GetCVar("Sound_Nonexistent"), "absent cvar reads nil")
end)

Runner.test("stub records writes in order", function()
  local env = Stubs.new({})
  env.globals.C_CVar.SetCVar("A", "1")
  env.globals.C_CVar.SetCVar("B", "0")
  local order = env:writeOrder()
  Runner.eq(order[1], "A", "first write")
  Runner.eq(order[2], "B", "second write")
  Runner.eq(env:indexOf("B"), 2, "indexOf finds position")
end)

Runner.test("stub can force a write failure", function()
  local env = Stubs.new({})
  env.failWrites["A"] = true
  Runner.isFalse(env.globals.C_CVar.SetCVar("A", "1"), "forced failure returns false")
  Runner.eq(#env.writeLog, 0, "failed write is not logged")
end)

Runner.test("stub captures print output", function()
  local env = Stubs.new({})
  env.globals.print("hello", "world")
  Runner.eq(env.printed[1], "hello world", "print captured")
end)

Runner.test("loadAddonFile passes addon name and namespace", function()
  local env = Stubs.new({})
  local f = assert(io.open("tests/fixture_probe.lua", "w"))
  f:write("local name, ns = ...\nns.seen = name\nns.sawCVar = C_CVar ~= nil\n")
  f:close()

  local ns = {}
  Stubs.loadAddonFile("tests/fixture_probe.lua", ns, env)
  Runner.eq(ns.seen, "Soundrunner", "addon name reaches the chunk")
  Runner.isTrue(ns.sawCVar, "stub globals are visible to the chunk")

  os.remove("tests/fixture_probe.lua")
end)

package.path = "tests/?.lua;" .. package.path
local Runner = require("runner")

require("test_harness")
require("test_channels")
require("test_slots")
require("test_core")

Runner.finish()

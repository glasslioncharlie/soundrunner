local Stubs = {}

function Stubs.new(initialCVars)
  local env = {
    cvars = {},
    writeLog = {},
    printed = {},
    failWrites = {},
  }

  for k, v in pairs(initialCVars or {}) do
    env.cvars[k] = v
  end

  local function getCVar(name)
    return env.cvars[name]
  end

  local function setCVar(name, value)
    if env.failWrites[name] then
      return false
    end
    value = tostring(value)
    env.cvars[name] = value
    table.insert(env.writeLog, { name = name, value = value })
    return true
  end

  env.globals = {
    GetCVar = getCVar,
    SetCVar = setCVar,
    C_CVar = { GetCVar = getCVar, SetCVar = setCVar },
    print = function(...)
      local parts = {}
      for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
      end
      table.insert(env.printed, table.concat(parts, " "))
    end,
  }

  env.sandbox = setmetatable(env.globals, { __index = _G })

  function env:writeOrder()
    local names = {}
    for i, w in ipairs(self.writeLog) do
      names[i] = w.name
    end
    return names
  end

  function env:indexOf(cvarName)
    for i, w in ipairs(self.writeLog) do
      if w.name == cvarName then return i end
    end
    return nil
  end

  function env:clearWrites()
    self.writeLog = {}
  end

  return env
end

function Stubs.loadAddonFile(path, ns, env)
  local chunk = assert(loadfile(path))
  setfenv(chunk, env.sandbox)
  return chunk("Soundrunner", ns)
end

return Stubs

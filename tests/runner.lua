local Runner = { passed = 0, failed = 0 }

function Runner.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    Runner.passed = Runner.passed + 1
    print("  PASS  " .. name)
  else
    Runner.failed = Runner.failed + 1
    print("  FAIL  " .. name)
    print("        " .. tostring(err))
  end
end

function Runner.eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s\n        expected: %s\n        actual:   %s",
      msg or "values differ", tostring(expected), tostring(actual)), 2)
  end
end

function Runner.isTrue(value, msg)
  if not value then
    error(msg or ("expected truthy, got " .. tostring(value)), 2)
  end
end

function Runner.isFalse(value, msg)
  if value then
    error(msg or ("expected falsey, got " .. tostring(value)), 2)
  end
end

function Runner.isNil(value, msg)
  if value ~= nil then
    error(msg or ("expected nil, got " .. tostring(value)), 2)
  end
end

function Runner.finish()
  print(string.format("\n%d passed, %d failed", Runner.passed, Runner.failed))
  if Runner.failed > 0 then
    os.exit(1)
  end
  os.exit(0)
end

return Runner

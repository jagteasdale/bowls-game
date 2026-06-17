-- run.lua -- tiny headless test runner for the pure-lua core.
-- usage:  lua tests/run.lua          (run from the repo root)
-- needs no pico-8: it dofile()s the pure modules and exercises them.

-- locate src/ relative to this file so it works from any cwd
local here = (arg and arg[0] or "tests/run.lua"):gsub("[^/\\]+$", "")
local root = here .. "../"

-- load the pure-lua modules (they define globals: physics, score; plus data tables)
dofile(root .. "src/data.lua")
dofile(root .. "src/physics.lua")
dofile(root .. "src/score.lua")

-- ---- assertion helpers ------------------------------------------------------
local passed, failed = 0, 0
local failures = {}

local T = {}

function T.ok(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = msg or "assertion failed"
  end
end

function T.eq(a, b, msg)
  T.ok(a == b, (msg or "eq") .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end

function T.near(a, b, eps, msg)
  eps = eps or 1e-6
  T.ok(a >= b - eps and a <= b + eps,
    (msg or "near") .. " (got " .. tostring(a) .. ", want ~" .. tostring(b) .. ")")
end

-- ---- run the suites ---------------------------------------------------------
local suites = {
  "test_physics.lua",
  "test_score.lua",
}

for _, file in ipairs(suites) do
  local chunk = assert(loadfile(here .. file))
  local suite = chunk()   -- each file returns a function(T)
  suite(T)                -- run the suite with the assertion helpers
end

-- ---- report -----------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
for _, m in ipairs(failures) do
  print("  FAIL: " .. m)
end
os.exit(failed == 0 and 0 or 1)

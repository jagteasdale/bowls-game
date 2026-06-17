-- integration.lua -- drives a FULL end through the real pico-8 game code with the
-- pico-8 API stubbed out. catches undefined globals, bad cross-references and
-- state-machine dead-ends that the headless unit tests can't see.
--
-- usage:  lua tests/integration.lua

local out = print -- keep a handle before we stub pico-8's print

-- ---- pico-8 api shims -------------------------------------------------------
sqrt = math.sqrt
flr = math.floor
abs = math.abs
function sgn(x) return (x or 0) < 0 and -1 or 1 end
function mid(a, b, c)
  -- median of three (pico-8 clamp)
  local lo = math.min(a, b, c)
  local hi = math.max(a, b, c)
  return a + b + c - lo - hi
end
function rnd(x) x = x or 1; return math.random() * x end
function tostr(x) return tostring(x) end
function add(t, v) t[#t + 1] = v; return v end
function del(t, v)
  for i = 1, #t do if t[i] == v then table.remove(t, i); return v end end
end
function all(t)
  local i = 0
  return function() i = i + 1; return t[i] end
end
-- graphics: no-ops (we only care that they're CALLED without error)
local function noop() end
cls, pset, line, rect, rectfill, circ, circfill, oval, ovalfill = noop, noop, noop, noop, noop, noop, noop, noop, noop
function print(...) end -- stubbed; use out() for harness messages

-- button state, controlled by the harness
local BTN = {}
function btnp(b) return BTN[b] == true end
function btn(b) return BTN[b] == true end

-- ---- load the game in cart order -------------------------------------------
local root = "/Users/josephteasdale/bowls-game/"
for _, f in ipairs({
  "src/data.lua", "src/physics.lua", "src/score.lua",
  "src/state.lua", "src/aim.lua", "src/render.lua", "src/ai.lua", "src/main.lua",
}) do
  dofile(root .. f)
end

-- ---- drive a full end -------------------------------------------------------
local function press(b) BTN = {}; BTN[b] = true end
local function release() BTN = {} end

_init()
assert(G.phase == "title", "should start on title")
_draw() -- must not error on the title screen (the nil-jack guard)

press(5); _update60(); release() -- start the end
out("after start: phase=" .. G.phase .. "  jack=(" ..
  string.format("%.1f,%.1f", G.jack.x, G.jack.y) .. ")")

-- run frames until the end is scored, supplying confirm presses when a phase
-- is waiting on the player. guard against an infinite loop.
local frames = 0
while G.phase ~= "result" and frames < 6000 do
  local p = G.phase
  if p == "wood_select" or p == "aim" or p == "power" then
    press(5) -- confirm wood / lock aim / lock power
  else
    release() -- deliver, cpu_think advance on their own
  end
  _update60()
  _draw() -- render every frame too, to exercise all the draw paths
  frames = frames + 1
end

assert(G.phase == "result", "end did not reach result (stuck in '" .. G.phase ..
  "' after " .. frames .. " frames)")
assert(#G.woods >= 1, "expected at least one wood on the green, got " .. #G.woods)
assert(G.result ~= nil, "no result computed")

out(string.format("end scored in %d frames: %d woods on green, holder=%s points=%d",
  frames, #G.woods, tostring(G.result.holder), G.result.points))
out("score: you=" .. G.score[TEAM_PLAYER] .. " cap=" .. G.score[TEAM_CPU])

-- start a second end to confirm the result->next-end transition works
press(5); _update60(); release()
assert(G.phase ~= "result", "should have left result on confirm")
out("second end started ok (phase=" .. G.phase .. ")")

-- ---- swing-back check: aiming WIDE should hook BACK toward the line of play ----
-- this validates the sign convention in side_from_t against the real physics.
do
  local function offset_from_line(t, biasturn)
    local dx, dy = dir_from_t(t)
    local w = physics.new_wood(GREEN.mat_x, GREEN.mat_y, dx, dy, 0.7, WOODS[1], side_from_t(t), TEAM_PLAYER)
    local c = {}; for k, v in pairs(CFG) do c[k] = v end
    c.bias_turn = biasturn
    physics.simulate(w, c, 3000)
    -- perpendicular distance of the resting wood from the mat->jack line
    local bx, by = aim_base()
    local px, py = w.x - GREEN.mat_x, w.y - GREEN.mat_y
    return abs(bx * py - by * px)
  end
  local with_bias = offset_from_line(0.4, CFG.bias_turn)
  local no_bias = offset_from_line(0.4, 0)
  out(string.format("swing-back: wide aim offset from line  with-bias=%.1f  no-bias=%.1f", with_bias, no_bias))
  assert(with_bias < no_bias, "bias must pull a wide delivery BACK toward the line (flip side_from_t)")
end

out("\nINTEGRATION OK")

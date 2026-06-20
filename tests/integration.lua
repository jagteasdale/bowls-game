-- integration.lua -- drives whole MATCHES through the real pico-8 game code with the
-- pico-8 API stubbed. catches undefined globals, bad cross-references and state-machine
-- dead-ends. (logic only -- stubbed graphics can't see visual bugs.)
--
-- usage:  lua tests/integration.lua

local out = print -- keep a handle before we stub pico-8's print

-- ---- pico-8 api shims -------------------------------------------------------
sqrt = math.sqrt
flr = math.floor
abs = math.abs
function sgn(x) return (x or 0) < 0 and -1 or 1 end
function mid(a, b, c)
  local lo = math.min(a, b, c); local hi = math.max(a, b, c)
  return a + b + c - lo - hi
end
function rnd(x) x = x or 1; return math.random() * x end
function tostr(x) return tostring(x) end
function sub(s, i, j) return string.sub(s, i, j or #s) end
function add(t, v) t[#t + 1] = v; return v end
function del(t, v)
  for i = 1, #t do if t[i] == v then table.remove(t, i); return v end end
end
function all(t)
  local i = 0
  return function() i = i + 1; return t[i] end
end
local function noop() end
cls, pset, line, rect, rectfill, circ, circfill, oval, ovalfill = noop, noop, noop, noop, noop, noop, noop, noop, noop
function print(...) end -- stubbed; use out() for harness messages

function poke() end
function stat(n) return "" end -- no devkit keyboard in the harness -> cheats stay inert

local BTN = {}
function btnp(b) return BTN[b] == true end
function btn(b) return BTN[b] == true end

-- ---- load the game in cart order -------------------------------------------
local root = "/Users/josephteasdale/bowls-game/"
for _, f in ipairs({
  "src/data.lua", "src/physics.lua", "src/score.lua",
  "src/state.lua", "src/aim.lua", "src/menu.lua", "src/ai.lua", "src/render.lua",
  "src/debug.lua", "src/main.lua",
}) do
  dofile(root .. f)
end

-- run one frame with the given buttons pressed (single-frame = edge press)
local function frame(buttons)
  BTN = {}
  if buttons then for _, b in ipairs(buttons) do BTN[b] = true end end
  _update60()
  _draw() -- exercise every draw path each frame
  BTN = {}
end

-- play frames until phase==target (or cap). interactive phases get a confirm; aim/power
-- lock after a UNIFORMLY random delay so the locked sweep position is well spread (a fixed
-- per-frame probability would bias toward the start of the sweep -> degenerate shots).
local function run_until(target, cap)
  local n, watching, countdown = 0, nil, 0
  while G.phase ~= target and n < cap do
    local p = G.phase
    local press = {}
    if p == "aim" or p == "power" then
      if watching ~= p then watching = p; countdown = math.random(4, 90) end
      if countdown <= 0 then press = { 5 } else countdown = countdown - 1 end
    else
      watching = nil
      if p == "wood_select" or p == "handoff" or p == "result" then press = { 5 } end
    end
    frame(press)
    n = n + 1
  end
  assert(G.phase == target, "did not reach '" .. target .. "' (stuck in '" .. G.phase ..
    "' after " .. n .. " frames; score " .. G.score[TEAM_PLAYER] .. "-" .. G.score[TEAM_CPU] .. ")")
  return n
end

-- ============================================================================
out("== name-entry machinery ==")
begin_name_entry()
assert(entry_to_name() == "red", "player-1 default name should be 'red', got " .. entry_to_name())
G.entry[1] = letter_index("z")
assert(entry_to_name() == "zed", "editing first letter should give 'zed', got " .. entry_to_name())
G.entry_team = TEAM_CPU; set_entry_default(TEAM_CPU)
assert(entry_to_name() == "blue", "player-2 default name should be 'blue', got " .. entry_to_name())

-- ============================================================================
out("\n== solo match (1 player vs the captain, first to " .. TARGET_SCORE .. ") ==")
_init()
assert(G.phase == "title", "boots to title menu")
_draw()

frame({ 5 }) -- title: option 1 (1 player) is default-selected
assert(G.mode == "solo" and G.phase == "wood_select", "1-player pick enters wood select")
assert(G.human[TEAM_PLAYER] and not G.human[TEAM_CPU], "solo: only team 1 is human")
local mat1x, mat1y = G.mat.x, G.mat.y
assert(mat1x * G.jack.x < 0 and mat1y * G.jack.y < 0, "jack sits in the opposite corner to the mat")

-- play the FIRST end, confirm the up/down flip and winner-leads on the second
run_until("result", 6000)
local end1_holder = G.result.holder
frame({ 5 }) -- after_result -> next end (no winner yet)
assert(G.phase ~= "result", "left the result screen")
assert(G.mat.x == -mat1x and G.mat.y == -mat1y, "end 2 plays from the opposite corner (up/down)")
-- the end-1 winner leads end 2 (or, on a no-score end, team 1 still leads)
assert(G.order[1] == (end1_holder or TEAM_PLAYER), "winner of the last end bowls first next end")

-- now run the whole match out to a winner
run_until("match_over", 200000)
assert(G.winner ~= nil, "a winner is set")
assert(G.score[G.winner] >= TARGET_SCORE, "winner reached the target score")
out(string.format("solo match over: %s %d - %d %s", G.names[TEAM_PLAYER], G.score[TEAM_PLAYER],
  G.score[TEAM_CPU], G.names[TEAM_CPU]))
frame({ 5 }) -- match_over -> back to title
assert(G.phase == "title", "match over returns to the title menu")

-- ============================================================================
out("\n== versus match (2 players, hotseat) ==")
_init()
frame({ 3 }); frame({ 3 }) -- title: down twice to "2 players" (3rd option)
assert(G.menu_sel == 3, "menu moved to the 2-player option")
frame({ 5 }) -- select -> name entry
assert(G.phase == "name_entry", "2-player pick enters name entry")
frame({ 5 }) -- accept player-1 default (red)
frame({ 5 }) -- accept player-2 default (blue) -> start match
assert(G.mode == "versus", "versus mode set")
assert(G.human[TEAM_PLAYER] and G.human[TEAM_CPU], "both teams are human")
assert(G.names[TEAM_PLAYER] == "red" and G.names[TEAM_CPU] == "blue", "default hotseat names")
assert(G.phase == "handoff", "first human turn opens with a controller handoff")

-- both teams human => no cpu_think; the match runs entirely through handoffs/aim/power
run_until("match_over", 300000)
assert(G.winner ~= nil and G.score[G.winner] >= TARGET_SCORE, "versus match produced a winner at target")
out(string.format("versus match over: %s %d - %d %s", G.names[TEAM_PLAYER], G.score[TEAM_PLAYER],
  G.score[TEAM_CPU], G.names[TEAM_CPU]))

-- ============================================================================
out("\n== shield (knockout tournament) ==")
-- progression logic: beating every opponent in turn wins the shield
_init()
start_shield()
for s = 1, #ROSTER do
  assert(G.phase == "intro", "round " .. s .. " opens on the intro screen")
  assert(G.opponent == ROSTER[s], "intro shows roster opponent " .. s)
  assert(G.names[TEAM_CPU] == ROSTER[s].name, "team 2 is named for the opponent")
  G.winner = TEAM_PLAYER -- simulate winning this round's match
  after_match()
end
assert(G.phase == "shield_won", "beating the whole bracket wins the shield")
out("beat all " .. #ROSTER .. " opponents -> shield_won")

-- menu -> shield -> intro -> a REAL match, then routing by who wins
_init()
frame({ 3 }) -- title: move down to "shield" (option 2)
assert(G.menu_sel == 2, "menu sits on the shield option")
frame({ 5 }) -- select shield -> round 1 intro
assert(G.phase == "intro" and G.mode == "shield", "shield enters the intro screen")
assert(G.opponent == ROSTER[1] and G.names[TEAM_CPU] == ROSTER[1].name, "round-1 opponent set")
frame({ 5 }) -- intro -> start the match
assert(G.mode == "shield" and G.opponent == ROSTER[1], "match runs vs the round-1 opponent")
run_until("match_over", 200000)
local sw = G.winner
frame({ 5 }) -- after_match routes by result
if sw == TEAM_PLAYER then
  assert(G.phase == "intro" and G.shield_stage == 2, "a win advances to round 2")
  out("shield match: player won round 1 -> round 2 intro")
else
  assert(G.phase == "title", "a loss knocks you out to the title")
  out("shield match: player lost round 1 -> back to title")
end

-- ============================================================================
out("\n== debug cheats ==")
_init(); frame({ 5 }) -- quick match (option 1) -> into the match
debug_win_match(TEAM_PLAYER)
assert(G.phase == "match_over" and G.winner == TEAM_PLAYER and G.score[TEAM_PLAYER] == G.target,
  "debug_win_match ends the match for the player")
out("debug_win_match -> match_over as winner OK")

-- ============================================================================
out("\n== swing-back physics (aim wide -> hook back to the line) ==")
_init(); frame({ 5 }) -- into a solo end so G.mat / G.jack exist
do
  local function offset_from_line(t, biasturn)
    local dx, dy = dir_from_t(t)
    local w = physics.new_wood(G.mat.x, G.mat.y, dx, dy, 0.7, WOODS[1], side_from_t(t), TEAM_PLAYER)
    local c = {}; for k, v in pairs(CFG) do c[k] = v end
    c.bias_turn = biasturn
    physics.simulate(w, c, 3000)
    local bx, by = aim_base()
    return abs(bx * (w.y - G.mat.y) - by * (w.x - G.mat.x))
  end
  local with_bias = offset_from_line(0.4, CFG.bias_turn)
  local no_bias = offset_from_line(0.4, 0)
  out(string.format("offset from line  with-bias=%.1f  no-bias=%.1f", with_bias, no_bias))
  assert(with_bias < no_bias, "bias must pull a wide delivery back toward the line")
end

out("\nINTEGRATION OK")

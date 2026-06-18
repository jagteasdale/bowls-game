-- state.lua -- the game-state machine and the shared game table G.
-- (pico-8 file: uses rnd/flr etc. not headless-tested.)

-- phases:
--  "title"       attract / opponent intro
--  "wood_select" player chooses ONE wood for the whole end (both their woods)
--  "aim"         pivoting aim line; lock the angle
--  "power"       rising/falling power bar; lock the weight
--  "cpu_think"   the captain decides (brief pause)
--  "deliver"     a wood is rolling
--  "result"      the end is scored

G = {}

-- ---- pure helpers shared by player + ai ------------------------------------

-- the line of play: a unit vector from the (current) mat toward the jack (the "head").
function aim_base()
  local bx = G.jack.x - G.mat.x
  local by = G.jack.y - G.mat.y
  local m = sqrt(bx * bx + by * by)
  return bx / m, by / m
end

-- aim parameter t in [-1,1] -> a normalised launch direction. t opens the aim off the
-- line of play to either hand; AIM.spread sets how wide. you aim WIDE and let the bias
-- hook the wood back onto the jack.
function dir_from_t(t)
  local bx, by = aim_base()
  local px, py = -by, bx -- left-normal of the line of play
  local dx = bx + t * AIM.spread * px
  local dy = by + t * AIM.spread * py
  local m = sqrt(dx * dx + dy * dy)
  return dx / m, dy / m
end

-- which way the wood hooks, derived from the aim so a wide delivery swings BACK toward
-- the line of play. (sign verified by the swing-back check in tests/integration.lua.)
function side_from_t(t)
  if t <= 0 then return 1 else return -1 end
end

-- is a point on the (rectangular) green, or has it gone into the ditch?
function on_green(x, y)
  return abs(x) <= GREEN.hw and abs(y) <= GREEN.hl
end

-- power p in [0,1] -> launch speed.
function speed_from_p(p)
  return AIM.speed_min + p * (AIM.speed_max - AIM.speed_min)
end

-- ---- game lifecycle ---------------------------------------------------------

function new_game()
  G.phase = "title"
  G.woods = {}
  G.order = {} -- no end in progress yet; keeps the hud safe on the title screen
  G.turn = 1
  G.sel = 1
  G.player_wood = 1 -- the wood chosen for the current end (both of the player's woods)
  G.end_no = 0
  G.mat = nil
  G.jack = nil
  G.live = nil
  G.result = nil
  G.score = { [TEAM_PLAYER] = 0, [TEAM_CPU] = 0 }
  G.msg = ""
end

function start_end()
  G.woods = {}
  G.live = nil
  G.result = nil
  -- ends are played "up" then "down": the mat alternates corner each end (odd = corner A,
  -- even = the opposite corner) and the jack goes out toward the far corner.
  G.end_no = G.end_no + 1
  local s = (G.end_no % 2 == 1) and 1 or -1
  G.mat = { x = GREEN.mat_x * s, y = GREEN.mat_y * s }
  -- jack toward the OPPOSITE corner, at a variable length so reading the weight
  -- ("will it get there?") is the core tension.
  G.jack = { x = -s * (3 + rnd(15)), y = -s * (2 + rnd(13)) }
  -- singles, two woods each, alternating; player leads
  G.order = { TEAM_PLAYER, TEAM_CPU, TEAM_PLAYER, TEAM_CPU }
  G.turn = 1
  -- choose your wood ONCE for the whole end before the first delivery
  G.phase = "wood_select"
  G.msg = "choose your wood for this end"
end

function begin_turn()
  local team = G.order[G.turn]
  if team == TEAM_PLAYER then
    start_player_aim()
  else
    G.phase = "cpu_think"
    G.timer = 40
    G.cpu = ai_choose(CAPTAIN, G.jack, G.woods)
    G.msg = CAPTAIN.name .. " lines it up..."
  end
end

-- start the player's aim sweep for a delivery (wood already chosen for the end)
function start_player_aim()
  G.aim_t = -1
  G.aim_dir = 1
  G.phase = "aim"
  G.msg = "press x to set the line"
end

-- build a live wood and start it rolling from the current mat
function launch_wood(team, wood, t, p)
  local dx, dy = dir_from_t(t)
  local spd = speed_from_p(p)
  G.live = physics.new_wood(G.mat.x, G.mat.y, dx, dy, spd, wood, side_from_t(t), team)
  G.phase = "deliver"
end

-- called when the live wood stops (or runs off into the ditch)
function settle_wood()
  local w = G.live
  G.live = nil
  if on_green(w.x, w.y) then
    add(G.woods, w) -- a wood resting on the green counts; ditched woods are dead
  end
  G.turn = G.turn + 1
  if G.turn > #G.order then
    score_end()
  else
    begin_turn()
  end
end

function score_end()
  G.result = score.count(G.jack, G.woods, SCORE_RADIUS)
  local holder = G.result.holder
  if holder == TEAM_PLAYER then
    G.score[TEAM_PLAYER] = G.score[TEAM_PLAYER] + G.result.points
    G.msg = "you win the end +" .. G.result.points
  elseif holder == TEAM_CPU then
    G.score[TEAM_CPU] = G.score[TEAM_CPU] + G.result.points
    G.msg = CAPTAIN.name .. " wins the end +" .. G.result.points
  else
    G.msg = "no score"
  end
  G.phase = "result"
end

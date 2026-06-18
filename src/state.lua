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

-- which team is bowling right now
function current_team()
  return G.order[G.turn]
end

-- the team that has reached the target score, or nil if the match is still on
function match_winner()
  if G.score[TEAM_PLAYER] >= G.target then return TEAM_PLAYER end
  if G.score[TEAM_CPU] >= G.target then return TEAM_CPU end
  return nil
end

function new_game()
  G.phase = "title"
  G.menu_sel = 1
  G.woods = {}
  G.order = {} -- no end in progress yet; keeps the hud safe on the title/menu screens
  G.turn = 1
  G.sel = 1
  G.team_wood = {} -- per-team wood choice for the current end
  G.end_no = 0
  G.target = TARGET_SCORE
  G.mat = nil
  G.jack = nil
  G.live = nil
  G.result = nil
  G.winner = nil
  G.score = { [TEAM_PLAYER] = 0, [TEAM_CPU] = 0 }
  G.lead = TEAM_PLAYER -- which team bowls first this end (the previous end's winner)
  -- default to a 1-player setup until a mode is chosen
  G.mode = "solo"
  G.human = { [TEAM_PLAYER] = true, [TEAM_CPU] = false }
  G.names = { [TEAM_PLAYER] = "you", [TEAM_CPU] = CAPTAIN.name }
  G.msg = ""
end

-- start a 1-player match vs The Captain
function start_solo()
  G.mode = "solo"
  G.human = { [TEAM_PLAYER] = true, [TEAM_CPU] = false }
  G.names = { [TEAM_PLAYER] = "you", [TEAM_CPU] = CAPTAIN.name }
  start_match()
end

-- start a 2-player hotseat match (names already in G.names)
function start_versus()
  G.mode = "versus"
  G.human = { [TEAM_PLAYER] = true, [TEAM_CPU] = true }
  start_match()
end

function start_match()
  G.score = { [TEAM_PLAYER] = 0, [TEAM_CPU] = 0 }
  G.end_no = 0
  G.winner = nil
  G.lead = TEAM_PLAYER -- team 1 leads the first end of the match
  start_end()
end

function start_end()
  G.woods = {}
  G.live = nil
  G.result = nil
  G.team_wood = {} -- each side picks a wood for THIS end
  -- ends are played "up" then "down": the mat alternates corner each end and the jack
  -- goes out toward the far corner.
  G.end_no = G.end_no + 1
  local s = (G.end_no % 2 == 1) and 1 or -1
  G.mat = { x = GREEN.mat_x * s, y = GREEN.mat_y * s }
  G.jack = { x = -s * (3 + rnd(15)), y = -s * (2 + rnd(13)) }
  -- singles, two woods each, alternating; the previous end's winner (G.lead) bowls first
  local other = (G.lead == TEAM_PLAYER) and TEAM_CPU or TEAM_PLAYER
  G.order = { G.lead, other, G.lead, other }
  G.turn = 1
  begin_turn()
end

function begin_turn()
  local team = current_team()
  if G.human[team] then
    if G.mode == "versus" then
      -- hotseat: hand the controller over before this player bowls
      G.handoff_team = team
      G.phase = "handoff"
      G.msg = ""
    else
      enter_human_turn(team)
    end
  else
    G.phase = "cpu_think"
    G.timer = 40
    G.cpu = ai_choose(CAPTAIN, G.jack, G.woods)
    G.msg = CAPTAIN.name .. " lines it up..."
  end
end

-- a human team's turn: pick a wood on their first delivery of the end, then aim
function enter_human_turn(team)
  if not G.team_wood[team] then
    G.sel = 1
    G.phase = "wood_select"
    G.msg = "choose your wood for this end"
  else
    start_player_aim()
  end
end

-- start the aim sweep (the team's wood for the end is already chosen)
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
  if holder then
    G.score[holder] = G.score[holder] + G.result.points
    G.lead = holder -- the end winner leads the next end
    G.msg = G.names[holder] .. " wins the end +" .. G.result.points
  else
    G.msg = "no score" -- lead unchanged: the same side leads again
  end
  G.phase = "result"
end

-- from the result screen: play the next end, or end the match
function after_result()
  local w = match_winner()
  if w then
    G.winner = w
    G.phase = "match_over"
    G.msg = G.names[w] .. " wins the match!"
  else
    start_end()
  end
end

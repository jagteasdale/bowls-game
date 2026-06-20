-- debug.lua -- developer cheats for testing flow without grinding matches.
-- toggle with DEBUG_CHEATS in data.lua. uses the pico-8 devkit KEYBOARD, so the keys
-- work in the pico-8 app (and the desktop web export when the canvas is focused) but
-- NOT on touch / handhelds. (kept free of pico-8-only syntax so the harness can load it.)
--
-- keys (during a match):  w = win match   l = lose match   g = give yourself +1
--        (shield mode):   k = jump to the final round

function debug_init()
  if DEBUG_CHEATS then poke(0x5f2d, 1) end -- enable devkit keyboard reads
end

-- is a match actually in progress (so ending/scoring it makes sense)?
local function in_match()
  local p = G.phase
  return p == "handoff" or p == "wood_select" or p == "aim" or p == "power"
    or p == "cpu_think" or p == "deliver" or p == "result"
end

-- jump straight to the match-over screen with `team` as the winner
function debug_win_match(team)
  G.score[team] = G.target
  G.winner = team
  G.live = nil
  G.phase = "match_over"
  G.msg = G.names[team] .. " wins the match!"
end

function debug_update()
  if not DEBUG_CHEATS then return end
  local k = stat(31) -- last key typed this frame, or ""
  if k == "" then return end
  if k == "w" and in_match() then
    debug_win_match(TEAM_PLAYER)
  elseif k == "l" and in_match() then
    debug_win_match(TEAM_CPU)
  elseif k == "g" and in_match() then
    G.score[TEAM_PLAYER] = G.score[TEAM_PLAYER] + 1
  elseif k == "k" and G.mode == "shield" then
    G.shield_stage = #ROSTER
    show_intro()
  end
end

function debug_draw()
  if not DEBUG_CHEATS then return end
  print("dbg w/l/g/k", 80, 122, 5)
end

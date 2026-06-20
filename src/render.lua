-- render.lua -- top-down / 3-4 angled view of the flat rectangular green, plus HUD.
-- (pico-8 file: uses cls/circfill/rectfill/line/print.)

-- world->screen projection: scale + a vertical squash for the 3/4 tilt.
local SCALE = 2.4   -- pixels per foot (horizontal)
local TILT  = 0.62  -- vertical squash (the angled look)
local OX, OY = 64, 62 -- screen position of the green centre

function project(x, y)
  return OX + x * SCALE, OY + y * SCALE * TILT
end

-- pico-8 has no string.format; show a non-negative number to one decimal place.
local function fmt1(x)
  local s = flr(x * 10 + 0.5) -- rounded tenths
  return tostr(flr(s / 10)) .. "." .. tostr(s % 10)
end

-- an axis-aligned ellipse outline for a world circle of `r` feet centred at (cx,cy)
local function world_oval_outline(cx, cy, r, col)
  local sx, sy = project(cx, cy)
  local rx = r * SCALE
  local ry = r * SCALE * TILT
  oval(sx - rx, sy - ry, sx + rx, sy + ry, col)
end

-- ---- the green ------------------------------------------------------------

local function draw_green()
  -- bank / ditch surround (brown), then the flat green surface (dark green)
  local bx0, by0 = project(-GREEN.hw - 2, -GREEN.hl - 2)
  local bx1, by1 = project(GREEN.hw + 2, GREEN.hl + 2)
  rectfill(bx0, by0, bx1, by1, 4)
  local gx0, gy0 = project(-GREEN.hw, -GREEN.hl)
  local gx1, gy1 = project(GREEN.hw, GREEN.hl)
  rectfill(gx0, gy0, gx1, gy1, 3)
  rect(gx0, gy0, gx1, gy1, 11) -- rink edge
  -- line of play + mat: only once an end is set up (G.mat alternates corner each end)
  if G.mat then
    local mx, my = project(G.mat.x, G.mat.y)
    local ox, oy = project(-G.mat.x, -G.mat.y)
    line(mx, my, ox, oy, 5) -- the long diagonal, this end's direction
    rectfill(mx - 4, my - 2, mx + 4, my + 2, 4) -- the mat
  end
end

-- ---- woods + jack ---------------------------------------------------------

-- team 1 = red, team 2 = blue (matches the default hotseat names Red / Blue)
local function team_col(owner)
  if owner == TEAM_PLAYER then return 8 else return 12 end
end

local function draw_wood(w)
  local sx, sy = project(w.x, w.y)
  circfill(sx, sy, 2, team_col(w.owner))
  pset(sx, sy, 7) -- little highlight / bias mark
end

local function draw_jack()
  -- the 3ft scoring band, then the jack
  world_oval_outline(G.jack.x, G.jack.y, SCORE_RADIUS, 5)
  local jx, jy = project(G.jack.x, G.jack.y)
  circfill(jx, jy, 1, 10)
end

-- ---- aim + power overlays -------------------------------------------------

local function draw_aim_line(t)
  local dx, dy = dir_from_t(t)
  local x0, y0 = project(G.mat.x, G.mat.y)
  local x1, y1 = project(G.mat.x + dx * 34, G.mat.y + dy * 34)
  line(x0, y0, x1, y1, 7)
  circfill(x1, y1, 1, 7)
end

local function draw_power_bar(p)
  local x, y0, y1 = 120, 40, 100
  rect(x - 1, y0 - 1, x + 4, y1 + 1, 6)
  local h = (y1 - y0) * p
  rectfill(x, y1 - h, x + 3, y1, p > 0.85 and 8 or 11)
end

-- ---- hud ------------------------------------------------------------------

local function woods_left(team)
  local n = 0
  for i = G.turn, #G.order do
    if G.order[i] == team then n = n + 1 end
  end
  return n
end

local function draw_hud()
  rectfill(0, 0, 127, 7, 1)
  -- team 1 name + score (left), team 2 name + score (right, target shown)
  print(G.names[TEAM_PLAYER] .. " " .. G.score[TEAM_PLAYER], 2, 1, team_col(TEAM_PLAYER))
  local r = G.names[TEAM_CPU] .. " " .. G.score[TEAM_CPU]
  print(r, 126 - #r * 4, 1, team_col(TEAM_CPU))
  -- woods remaining this end, as pips
  for i = 1, woods_left(TEAM_PLAYER) do circfill(50 + i * 5, 3, 1, team_col(TEAM_PLAYER)) end
  for i = 1, woods_left(TEAM_CPU) do circfill(78 - i * 5, 3, 1, team_col(TEAM_CPU)) end
  if G.msg ~= "" then
    print(G.msg, 2, 120, 7)
  end
end

-- ---- per-phase composite --------------------------------------------------

local function draw_wood_select()
  local w = WOODS[G.sel]
  rectfill(28, 50, 99, 78, 0)
  rect(28, 50, 99, 78, 7)
  print("\f7" .. w.name, 34, 54)
  print("bias " .. w.bias, 34, 62, 6)
  print("carry " .. (w.drag >= 0.985 and "high" or "med"), 34, 70, 6)
  print("\f6<      >", 34, 44)
end

local function draw_result()
  rectfill(20, 40, 107, 96, 0)
  rect(20, 40, 107, 96, 7)
  print("end result", 42, 44, 10)
  local r = G.result
  local y = 54
  for i = 1, #r.ranked do
    local e = r.ranked[i]
    local c = team_col(e.wood.owner)
    print(sub(G.names[e.wood.owner], 1, 3) .. " " .. fmt1(e.dist) .. "ft", 30, y, c)
    y = y + 7
  end
  print(G.msg, 26, y + 2, 7)
  print("x: continue", 36, 88, 6)
end

-- ---- front-end screens ----------------------------------------------------

local function draw_title_menu()
  rectfill(10, 28, 117, 100, 0)
  rect(10, 28, 117, 100, 7)
  print("elizabethan bowls", 22, 34, 11)
  local opts = { "quick match", "shield", "2 players" }
  for i = 1, 3 do
    local y = 46 + i * 9
    local sel = (G.menu_sel == i)
    if sel then print(">", 24, y, 7) end
    print(opts[i], 32, y, sel and 7 or 5)
  end
  print("first to " .. TARGET_SCORE .. " wins", 30, 84, 6)
  print("up/down   x: ok", 32, 92, 6)
end

-- placeholder opponent portrait. swap the body for spr(opp.face, x0, y0, 5, 6)
-- once you've drawn the pixel-art faces in the PICO-8 sprite editor.
local function draw_portrait(opp, x0, y0, x1, y1)
  rectfill(x0, y0, x1, y1, 5)
  rect(x0, y0, x1, y1, 7)
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - 2
  circfill(cx, cy, 11, 15)            -- head
  circ(cx, cy, 11, 4)
  pset(cx - 4, cy - 2, 0); pset(cx + 4, cy - 2, 0) -- eyes
  line(cx - 3, cy + 5, cx + 3, cy + 5, 0)          -- mouth
  print(sub(opp.name, 5, 5), cx - 1, y1 - 7, 6)    -- initial (skips "the ")
end

local function draw_intro()
  cls(1)
  local opp = G.opponent
  print("shield  round " .. G.shield_stage .. "/" .. #ROSTER, 28, 12, 10)
  draw_portrait(opp, 10, 28, 50, 76)
  rectfill(56, 28, 120, 76, 0)
  rect(56, 28, 120, 76, 7)
  print(opp.name, 60, 33, team_col(TEAM_CPU))
  local y = 44
  for i = 1, #opp.dialogue do
    print(opp.dialogue[i], 60, y, 7)
    y = y + 7
  end
  print("x: bowl", 48, 92, 6)
end

local function draw_shield_won()
  cls(1)
  print("shield won!", 38, 28, 10)
  local cx = 64
  rectfill(cx - 8, 50, cx + 8, 52, 9) -- rim
  circfill(cx, 54, 7, 9)              -- cup
  rectfill(cx - 2, 60, cx + 2, 68, 9) -- stem
  rectfill(cx - 9, 68, cx + 9, 71, 4) -- base
  print("champion of the club", 22, 86, 7)
  print("x: title", 46, 98, 6)
end

local function draw_name_entry()
  rectfill(10, 34, 117, 94, 0)
  rect(10, 34, 117, 94, 7)
  local who = (G.entry_team == TEAM_PLAYER) and "player 1" or "player 2"
  print("enter name - " .. who, 22, 40, team_col(G.entry_team))
  local x0 = 64 - NAME_MAX * 4
  for i = 1, NAME_MAX do
    local x = x0 + (i - 1) * 8
    if i == G.entry_cursor then rectfill(x - 1, 57, x + 5, 67, 5) end
    print(sub(NAME_LETTERS, G.entry[i], G.entry[i]), x, 59, 7)
    print("-", x, 67, 6)
  end
  print("arrows: edit    x: ok", 20, 82, 6)
end

local function draw_handoff()
  rectfill(14, 44, 113, 86, 0)
  rect(14, 44, 113, 86, 7)
  print("pass the controller to", 22, 52, 7)
  local nm = G.names[G.handoff_team]
  print(nm, 64 - #nm * 2, 64, team_col(G.handoff_team))
  print("x: ready", 46, 76, 6)
end

local function draw_match_over()
  rectfill(14, 40, 113, 92, 0)
  rect(14, 40, 113, 92, 7)
  print("match over", 44, 46, 10)
  local nm = G.names[G.winner]
  print(nm .. " wins!", 64 - (#nm + 6) * 2, 58, team_col(G.winner))
  print(G.names[TEAM_PLAYER] .. " " .. G.score[TEAM_PLAYER] .. " - " ..
    G.score[TEAM_CPU] .. " " .. G.names[TEAM_CPU], 24, 70, 6)
  print("x: title", 46, 84, 6)
end

-- the main draw, dispatched by phase
function draw_game()
  cls(3)
  draw_green()
  -- only draw the play field once an end is set up (jack placed)
  if G.jack then
    draw_jack()
    for w in all(G.woods) do draw_wood(w) end
    if G.live then draw_wood(G.live) end
  end

  if G.phase == "aim" then draw_aim_line(G.aim_t) end
  if G.phase == "power" then
    draw_aim_line(G.aim_locked_t)
    draw_power_bar(G.pow_p)
  end

  -- the score HUD only belongs on play screens, not the front-end / intro / win screens
  if G.phase ~= "title" and G.phase ~= "name_entry" and G.phase ~= "intro"
      and G.phase ~= "shield_won" then
    draw_hud()
  end

  if G.phase == "title" then
    draw_title_menu()
  elseif G.phase == "name_entry" then
    draw_name_entry()
  elseif G.phase == "intro" then
    draw_intro()
  elseif G.phase == "handoff" then
    draw_handoff()
  elseif G.phase == "wood_select" then
    draw_wood_select()
  elseif G.phase == "result" then
    draw_result()
  elseif G.phase == "match_over" then
    draw_match_over()
  elseif G.phase == "shield_won" then
    draw_shield_won()
  end
end

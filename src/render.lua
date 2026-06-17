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
  -- the line of play: mat corner -> opposite corner (the long diagonal)
  local mx, my = project(GREEN.mat_x, GREEN.mat_y)
  local ox, oy = project(-GREEN.mat_x, -GREEN.mat_y)
  line(mx, my, ox, oy, 5)
  -- the mat
  rectfill(mx - 4, my - 2, mx + 4, my + 2, 4)
end

-- ---- woods + jack ---------------------------------------------------------

local function team_col(owner)
  if owner == TEAM_PLAYER then return 12 else return 8 end
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
  local x0, y0 = project(GREEN.mat_x, GREEN.mat_y)
  local x1, y1 = project(GREEN.mat_x + dx * 34, GREEN.mat_y + dy * 34)
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
  print("you " .. G.score[TEAM_PLAYER], 2, 1, 12)
  print("cap " .. G.score[TEAM_CPU], 90, 1, 8)
  -- woods remaining this end, as pips
  for i = 1, woods_left(TEAM_PLAYER) do circfill(40 + i * 5, 3, 1, 12) end
  for i = 1, woods_left(TEAM_CPU) do circfill(74 - i * 5, 3, 1, 8) end
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
    local tag = e.wood.owner == TEAM_PLAYER and "you" or "cap"
    print(tag .. " " .. fmt1(e.dist) .. "ft", 30, y, c)
    y = y + 7
  end
  print(G.msg, 26, y + 2, 7)
  print("x: next end", 36, 88, 6)
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

  draw_hud()

  if G.phase == "title" then
    rectfill(10, 36, 117, 92, 0)
    rect(10, 36, 117, 92, 7)
    print("elizabethan bowls", 22, 44, 11)
    print("vs " .. CAPTAIN.name, 30, 56, 8)
    print(CAPTAIN.blurb, 16, 66, 6)
    print("x: bowl", 48, 82, 7)
  elseif G.phase == "wood_select" then
    draw_wood_select()
  elseif G.phase == "result" then
    draw_result()
  end
end

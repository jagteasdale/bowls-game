-- ai.lua -- the opponent "thinks" by actually simulating candidate deliveries with the
-- real physics, then picking the one that draws closest to the jack, then fuzzing the
-- choice by its skill (lower skill jitter = more consistent). (pico-8 file.)

-- predict where a delivery (t, p) with this wood comes to rest.
local function predict(wood, t, p)
  local dx, dy = dir_from_t(t)
  local spd = speed_from_p(p)
  local w = physics.new_wood(G.mat.x, G.mat.y, dx, dy, spd, wood, side_from_t(t), TEAM_CPU)
  physics.simulate(w, CFG, 1200) -- woods rest well within this; caps the per-think cost
  return w
end

local function dist_to(w, jack)
  local dx, dy = w.x - jack.x, w.y - jack.y
  return sqrt(dx * dx + dy * dy)
end

-- choose a delivery for `persona`. returns { wood=, t=, p= }.
function ai_choose(persona, jack, woods_on_green)
  local wood = WOODS[persona.wood_pref]

  -- coarse search over the aim arc and a sensible power band for a draw shot
  local best_t, best_p, best_d = 0, 0.8, 9999
  local t = -1
  while t <= 1.0001 do
    local p = 0.5
    while p <= 1.05001 do
      local w = predict(wood, t, p)
      local d = dist_to(w, jack)
      -- only consider deliveries that stay on the green
      if on_green(w.x, w.y) and d < best_d then
        best_d, best_t, best_p = d, t, p
      end
      p = p + 0.08
    end
    t = t + 0.25
  end

  -- skill jitter: a steadier captain (low skill) lands closer to his intended line
  local jt = (rnd(2) - 1) * persona.skill * 0.6
  local jp = (rnd(2) - 1) * persona.skill * 0.4
  local t_final = mid(-1, best_t + jt, 1)
  local p_final = mid(0, best_p + jp, 1)

  return { wood = wood, t = t_final, p = p_final }
end

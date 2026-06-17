-- test_physics.lua -- invariants of the delivery simulation.
-- receives T (assertion helpers); uses globals physics, CFG, WOODS, GREEN, TEAM_PLAYER.
--
-- design note: a dished green is a centering spring, so "more power = further" and
-- "bias curves the path" are only clean with the dish ISOLATED OFF. We test those with
-- a dish-off config, and test the dish itself as a DIFFERENTIAL (on vs off). This keeps
-- the invariants honest regardless of how the feel params are later tuned.
return function(T)
  local std = WOODS[1]

  -- shallow-copy CFG with overrides, e.g. cfg{dish_gain=0}
  local function cfg(over)
    local c = {}
    for k, v in pairs(CFG) do c[k] = v end
    if over then for k, v in pairs(over) do c[k] = v end end
    return c
  end
  local NODISH = cfg({ dish_gain = 0 })

  -- launch a wood from the mat aiming straight up the green (-y) at a speed
  local function launch(speed, side, wood)
    return physics.new_wood(GREEN.mat_x, GREEN.mat_y, 0, -1, speed, wood or std, side or 0, TEAM_PLAYER)
  end

  -- 1. every delivery comes to rest under the real (dished) config
  do
    local w = launch(0.9, 1)
    local steps = physics.simulate(w, CFG, 6000)
    T.ok(w.resting, "wood comes to rest")
    T.ok(steps < 6000, "wood rests before the safety cap (" .. steps .. " steps)")
  end

  -- 2. a mid-power draw carries roughly a green-length (sanity on calibration)
  do
    local w = launch(0.9, 0, std)
    physics.simulate(w, NODISH)
    local carried = GREEN.mat_y - w.y
    T.ok(carried > 15 and carried < 60,
      "mid-power carry is green-scaled (" .. string.format("%.1f", carried) .. " ft)")
  end

  -- 3. more power => travels further (friction law, dish off so it isn't masked)
  do
    local function travel(speed)
      local w = launch(speed, 0, std)
      physics.simulate(w, NODISH)
      return GREEN.mat_y - w.y
    end
    T.ok(travel(1.0) > travel(0.6), "more power carries further")
    T.ok(travel(0.6) > travel(0.4), "and again at lower powers")
  end

  -- lateral deflection from the straight-up launch line (the mat is in a corner, so
  -- measure x relative to mat_x, not absolute x).
  local function deflect(speed, side, wood)
    local w = launch(speed, side, wood)
    physics.simulate(w, NODISH)
    return w.x - GREEN.mat_x
  end

  -- 4. bias curves the wood to its bias side (dish off so the curve is purely bias).
  do
    T.ok(deflect(0.9, 1, std) > 0.5, "positive bias side deflects +")
    T.ok(deflect(0.9, -1, std) < -0.5, "negative bias side deflects -")
  end

  -- 5. higher bias => more hook, isolated (same drag, vary only bias; dish off).
  -- comparing the real woods would confound bias with carry, so use synthetic woods.
  do
    local function defl_bias(bias) return deflect(0.9, 1, { drag = 0.983, bias = bias }) end
    T.ok(defl_bias(1.6) > defl_bias(1.0), "higher bias hooks more (isolated)")
    -- and the real SWINGER (same drag, higher bias) out-hooks STANDARD
    T.ok(deflect(0.9, 1, WOODS[3]) > deflect(0.9, 1, WOODS[1]), "SWINGER hooks more than STANDARD")
  end

  -- 6. the green is FLAT by default; the optional contour term, when enabled, gathers a
  -- wood toward centre. (the mechanism must still work if we reintroduce a subtle slope.)
  do
    T.eq(CFG.dish_gain, 0, "green is flat by default (contour off)")
    local DISH = cfg({ dish_gain = 0.0010 })
    local function end_dist(use_cfg)
      local w = physics.new_wood(-18, 6, 1, 0, 0.7, std, 0, TEAM_PLAYER)
      physics.simulate(w, use_cfg)
      return math.sqrt(w.x * w.x + w.y * w.y)
    end
    T.ok(end_dist(DISH) < end_dist(NODISH), "contour term gathers toward centre when enabled")
  end

  -- 7. no bias side + dish off => effectively straight (no lateral deflection)
  do
    T.near(deflect(0.9, 0, std), 0, 0.001, "no bias side stays straight")
  end
end

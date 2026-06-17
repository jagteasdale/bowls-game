-- physics.lua -- delivery simulation for elizabethan bowls.
-- PURE LUA: no pico-8 api beyond the sqrt shim below, so this runs headless
-- under a stock lua interpreter (see tests/) as well as inside pico-8.

-- math compat: pico-8 exposes a global sqrt; stock lua has math.sqrt.
local _sqrt = sqrt or math.sqrt

physics = {}

-- clamp v into [lo,hi]
local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- build a fresh wood state at the mat, launched along (dx,dy) at given speed.
-- wood = the chosen wood's stats {drag,bias}; side = +1/-1 bias hand; owner = team id.
function physics.new_wood(x, y, dx, dy, speed, wood, side, owner)
  return {
    x = x, y = y,
    vx = dx * speed, vy = dy * speed,
    drag = wood.drag,
    bias = wood.bias,
    biasside = side,
    launch_speed = speed,
    owner = owner,
    resting = false,
  }
end

-- advance one wood by a single frame. mutates w; sets w.resting when stopped.
function physics.step(w, cfg)
  if w.resting then return end

  local vx, vy = w.vx, w.vy
  local speed = _sqrt(vx * vx + vy * vy)

  -- 1. come to rest below threshold
  if speed <= cfg.stop_speed then
    w.vx, w.vy = 0, 0
    w.resting = true
    return
  end

  -- 2. friction: multiplicative drag + constant rolling resistance (guarantees a stop)
  local newspeed = speed * w.drag - cfg.roll_resist
  if newspeed < 0 then newspeed = 0 end
  local scale = newspeed / speed
  vx, vy = vx * scale, vy * scale

  -- recompute working speed after friction for the accel terms
  speed = newspeed

  if speed > 0 then
    -- 3. bias: ROTATE the velocity toward the bias side, turning harder as the wood slows
    -- (the late hook). rotation curves the path WITHOUT adding speed -- applying bias as a
    -- raw perpendicular accel would inflate |v| and pump the wood into an eternal orbit.
    -- slowness^2 keeps the wood running straight early, then hooks hard LATE as it dies.
    local slowness = clamp(1 - speed / w.launch_speed, 0, 1)
    local theta = cfg.bias_turn * w.bias * slowness * slowness
    if theta > cfg.bias_turn_max then theta = cfg.bias_turn_max end
    -- perp nudge by angle theta, then renormalise back to the pre-bias speed
    local px = -vy * w.biasside
    local py = vx * w.biasside
    local nvx = vx + px * theta
    local nvy = vy + py * theta
    local nmag = _sqrt(nvx * nvx + nvy * nvy)
    if nmag > 0 then
      local k = speed / nmag
      vx, vy = nvx * k, nvy * k
    end
  end

  -- 4. green contour (optional): radial accel toward centre, proportional to distance.
  -- OFF by default (dish_gain = 0) -- the green is flat. kept so a SUBTLE shape effect can
  -- be reintroduced later without it ever becoming a gravity sink.
  if cfg.dish_gain ~= 0 then
    local dist = _sqrt(w.x * w.x + w.y * w.y)
    if dist > 0 then
      local amt = cfg.dish_gain * dist
      vx = vx + (-w.x / dist) * amt
      vy = vy + (-w.y / dist) * amt
    end
  end

  -- 5. integrate position
  w.vx, w.vy = vx, vy
  w.x = w.x + vx
  w.y = w.y + vy
end

-- run a wood to rest (or until maxsteps). returns number of steps taken.
function physics.simulate(w, cfg, maxsteps)
  maxsteps = maxsteps or 4000
  local n = 0
  while not w.resting and n < maxsteps do
    physics.step(w, cfg)
    n = n + 1
  end
  -- force-rest if we hit the cap, so callers never hang on a never-settling wood
  if not w.resting then
    w.vx, w.vy = 0, 0
    w.resting = true
  end
  return n
end

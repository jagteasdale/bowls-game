-- score.lua -- nearest-to-jack scoring for elizabethan bowls.
-- PURE LUA (sqrt shim only), so it runs headless under stock lua.
--
-- rules modelled:
--   * the team with the closest wood "holds shot".
--   * each of the holder's woods within score_radius (3 ft) of the jack scores 1 point,
--     counting outward from the jack, UNTIL a rival (opponent) wood is reached.

local _sqrt = sqrt or math.sqrt

score = {}

local function dist(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return _sqrt(dx * dx + dy * dy)
end

-- returns a list of {wood=w, dist=d} sorted ascending by distance to the jack.
-- jack = {x,y}; woods = array of wood states (each has x,y,owner).
function score.measure(jack, woods)
  local ranked = {}
  for i = 1, #woods do
    local w = woods[i]
    ranked[i] = { wood = w, dist = dist(w.x, w.y, jack.x, jack.y) }
  end
  -- simple insertion sort (stable, tiny n, pico-8 friendly)
  for i = 2, #ranked do
    local cur = ranked[i]
    local j = i - 1
    while j >= 1 and ranked[j].dist > cur.dist do
      ranked[j + 1] = ranked[j]
      j = j - 1
    end
    ranked[j + 1] = cur
  end
  return ranked
end

-- returns { holder = owner_id_or_nil, points = n, ranked = <measure result> }.
-- holder is nil only when there are no woods at all.
function score.count(jack, woods, score_radius)
  local ranked = score.measure(jack, woods)
  if #ranked == 0 then
    return { holder = nil, points = 0, ranked = ranked }
  end

  local holder = ranked[1].wood.owner
  local points = 0
  for i = 1, #ranked do
    local entry = ranked[i]
    if entry.wood.owner ~= holder then
      break -- a rival wood cuts scoring off
    end
    if entry.dist > score_radius then
      break -- outside 3 ft: nothing further can count
    end
    points = points + 1
  end

  return { holder = holder, points = points, ranked = ranked }
end

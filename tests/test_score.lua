-- test_score.lua -- the nearest-to-jack / 3ft / no-closer-rival scoring rules.
-- receives T; uses globals score, TEAM_PLAYER, TEAM_CPU, SCORE_RADIUS.
return function(T)
  local P, C = TEAM_PLAYER, TEAM_CPU
  local R = SCORE_RADIUS -- 3 ft

  -- jack at origin; helper to make a wood at a distance straight up the y axis
  local jack = { x = 0, y = 0 }
  local function w(owner, d) return { x = 0, y = d, owner = owner } end

  -- 1. holder is whoever has the closest wood
  do
    local res = score.count(jack, { w(P, 1.0), w(C, 2.0) }, R)
    T.eq(res.holder, P, "closest wood sets the holder")
    T.eq(res.points, 1, "one player wood inside 3ft, rival further => 1")
  end

  -- 2. two of the holder's woods inside 3ft, rival outside => 2
  do
    local res = score.count(jack, { w(P, 0.5), w(P, 2.0), w(C, 5.0) }, R)
    T.eq(res.holder, P, "player holds")
    T.eq(res.points, 2, "both player woods within 3ft count")
  end

  -- 3. a rival wood between the holder's woods cuts scoring off
  do
    -- player closest, but a cpu wood sits inside 3ft nearer than player's 2nd wood
    local res = score.count(jack, { w(P, 0.5), w(C, 1.5), w(P, 2.0) }, R)
    T.eq(res.holder, P, "player holds (closest)")
    T.eq(res.points, 1, "rival wood at 1.5 cuts off the player's 2.0 wood")
  end

  -- 4. holder's 2nd wood is within 3ft but the FIRST rival is still further => still counts
  do
    local res = score.count(jack, { w(P, 1.0), w(P, 2.9), w(C, 2.95) }, R)
    T.eq(res.points, 2, "both inside 3ft and ahead of the rival => 2")
  end

  -- 5. the 3-foot band: a wood just outside does not score
  do
    local res = score.count(jack, { w(P, 1.0), w(P, 3.5), w(C, 9.0) }, R)
    T.eq(res.points, 1, "wood at 3.5ft is outside the band")
  end

  -- 6. exactly on the 3ft line counts (<= radius)
  do
    local res = score.count(jack, { w(P, 1.0), w(P, 3.0), w(C, 9.0) }, R)
    T.eq(res.points, 2, "a wood exactly on 3ft counts")
  end

  -- 7. cpu can hold and score too (symmetry)
  do
    local res = score.count(jack, { w(C, 0.4), w(C, 1.2), w(P, 2.0) }, R)
    T.eq(res.holder, C, "cpu holds when it has the closest wood")
    T.eq(res.points, 2, "both cpu woods score")
  end

  -- 8. full end (2 woods each), realistic mix
  do
    local res = score.count(jack, { w(P, 0.8), w(C, 1.1), w(P, 4.0), w(C, 6.0) }, R)
    T.eq(res.holder, P, "player holds by a whisker")
    T.eq(res.points, 1, "cpu's 1.1 wood cuts off the player's distant 2nd")
  end

  -- 9. measure() returns ascending distances
  do
    local ranked = score.measure(jack, { w(P, 5.0), w(C, 1.0), w(P, 3.0) })
    T.near(ranked[1].dist, 1.0, 1e-9, "nearest first")
    T.near(ranked[2].dist, 3.0, 1e-9, "then 3.0")
    T.near(ranked[3].dist, 5.0, 1e-9, "then 5.0")
  end

  -- 10. distance is euclidean (off-axis jack)
  do
    local j = { x = 3, y = 4 }
    local ranked = score.measure(j, { { x = 0, y = 0, owner = P } })
    T.near(ranked[1].dist, 5.0, 1e-9, "3-4-5 distance")
  end

  -- 11. no woods => no holder, no points (defensive)
  do
    local res = score.count(jack, {}, R)
    T.eq(res.holder, nil, "no holder with no woods")
    T.eq(res.points, 0, "no points with no woods")
  end
end

-- data.lua -- tunables, the green geometry, wood definitions, and the opponent.
-- kept free of pico-8 api so tests can require it too.

-- world geometry (1 unit = 1 foot; origin = centre of a flat, RECTANGULAR green).
-- ends are played CORNER TO CORNER: the mat sits in one corner and the jack out near
-- the opposite corner, so a small green plays long along its diagonal.
GREEN = {
  cx = 0, cy = 0,           -- centre
  hw = 22,                  -- half-width  (x extent, feet)
  hl = 18,                  -- half-length (y extent, feet)
  mat_x = 19, mat_y = 15,   -- delivery corner (near the +x,+y corner)
}

SCORE_RADIUS = 3 -- feet: the "within 3 feet" scoring band

-- physics tunables (see docs/physics-notes.md). feel-tune these in pico-8;
-- the headless tests assert invariants, not these exact numbers.
-- the green is FLAT for now (dish_gain = 0): all curve comes from the woods' bias.
-- friction is gentle so a wood rolls for ~3-4 seconds -- a long, anticipatory draw that
-- runs fairly straight, then hooks in late as it loses pace. carry ~= speed / (1 - drag).
-- tuned (see docs/physics-notes.md) for the classic bowls arc: a typical draw runs fairly
-- straight, reaches its widest "shoulder" ~70% along, then draws hard onto the head over the
-- final third. ~2.5-3s of roll. lateral movement comes mostly from BIAS, not the aim angle
-- (hence the small AIM.spread) -- otherwise the wood just flies off at an angle.
CFG = {
  roll_resist   = 0.0008,  -- constant (Coulomb) speed bled off each frame; guarantees a stop
  bias_turn     = 0.030,   -- base heading turn/frame per unit bias (scaled by slowness^2)
  bias_turn_max = 0.050,   -- cap so a near-stopped wood can't spin on the spot
  dish_gain     = 0,       -- FLAT green: no gravity sink. (a subtle contour drift can return here)
  stop_speed    = 0.009,   -- rest threshold (lower = a longer, creeping finish)
}

-- the woods you can choose from. trade-offs, not strict upgrades:
--   drag : carry (nearer 1 = travels further); from weight
--   bias : curve amount (higher = swingier, harder to control)
--   radius : draw size / footprint
-- identities: HEAVY owns CARRY; SWINGER owns HOOK; STANDARD is the all-rounder.
WOODS = {
  { name = "STANDARD", drag = 0.983, bias = 1.00, radius = 2 },
  { name = "HEAVY",    drag = 0.986, bias = 0.70, radius = 3 }, -- carries far, swings less
  { name = "SWINGER",  drag = 0.983, bias = 1.45, radius = 2 }, -- same carry, big hook
}

-- delivery controls / aiming feel. the aim arc is centred on the line of play
-- (mat -> jack); t in [-1,1] opens it to either hand.
AIM = {
  spread    = 0.45,  -- how wide the aim arc opens off the line of play (small: bias does the curving)
  sweep     = 0.018, -- aim line oscillation speed (t per frame, t in [-1,1])
  pow_sweep = 0.014, -- power bar oscillation speed (p per frame, p in [0,1])
  speed_min = 0.42,  -- launch speed at 0% power (falls short)
  speed_max = 1.00,  -- launch speed at 100% power (sails through)
}

-- team ids (in 2-player mode TEAM_CPU is simply the second human)
TEAM_PLAYER = 1
TEAM_CPU    = 2

-- match / multiplayer
TARGET_SCORE = 11   -- first to this many points wins the match
NAME_MAX     = 6    -- max characters in a hotseat player name
NAME_LETTERS = " abcdefghijklmnopqrstuvwxyz" -- index 1 is space

-- an AI opponent persona.
--   skill:      aim/power error (0 = perfect; HIGHER = easier opponent)
--   aggression: 0 = always draw to jack; 1 = will gamble on a firing shot
--   wood_pref:  which WOODS entry it favours
--   face:       reserved sprite id for portrait art (draw later in the sprite editor)
--   dialogue:   intro lines, pre-wrapped to fit the box
CAPTAIN = {
  name = "the captain",
  blurb = "runs a tight ship. steady draw, no heroics.",
  wood_pref = 2,     -- favours the dependable HEAVY wood
  skill = 0.10,      -- consistent (the toughest)
  aggression = 0.15, -- rarely gambles
  face = 4,
  dialogue = { "so. you think", "you can take my", "shield from me.", "we'll see." },
}

-- the shield tournament roster, in bracket order (last entry = final boss).
-- difficulty rises through the bracket (skill/error falls).
ROSTER = {
  {
    name = "the wanderer", face = 1, wood_pref = 1, skill = 0.30, aggression = 0.45,
    dialogue = { "you must be new.", "i've bowled greens", "everywhere. this one's", "nothing special." },
  },
  {
    name = "the hustler", face = 2, wood_pref = 3, skill = 0.24, aggression = 0.65,
    dialogue = { "fancy a small", "wager on it?", "...suit yourself." },
  },
  {
    name = "the stalwart", face = 3, wood_pref = 2, skill = 0.18, aggression = 0.10,
    dialogue = { "forty years i've", "bowled this rink.", "forty years." },
  },
  CAPTAIN, -- the final
}

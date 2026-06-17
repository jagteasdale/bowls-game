# Physics & scoring notes (living)

This documents the model implemented in `src/physics.lua` and `src/score.lua`. Both are **pure
Lua** (no PICO-8 API) so they run under a stock interpreter for headless tests. The only math
they need is `sqrt`, obtained via a shim that works in both environments:

```lua
local _sqrt = sqrt or math.sqrt   -- pico-8 has global sqrt; stock lua has math.sqrt
```

## Coordinate system & units

- **1 world unit = 1 foot.** Origin `(0,0)` is the **centre of the green**.
- The green is a **flat rectangle**, `GREEN.hw`×`GREEN.hl` half-extents.
- Ends are played **corner to corner**: the **mat** sits in one corner (`mat_x,mat_y`) and the
  **jack** out near the opposite corner, at a variable length — so a small green plays long
  along its diagonal, and reading the weight ("will it get there?") is the core tension.
- Woods launch from the mat along an aim direction at a chosen speed.
- **Scoring radius = 3 feet** around the jack. `on_green(x,y)` is a rectangular bounds test;
  woods that finish outside it are in the ditch and **dead**.

> **On "bowl-shaped":** the real Elizabethan green is gently dished, which adds swing. We model
> it **flat for now** and let the woods' high bias produce all the curve (see the contour term
> below, kept but disabled). A *subtle* contour drift can return later — but never as a gravity
> sink that woods settle into.

## A wood's state

```
w = { x, y, vx, vy,        -- position & velocity (feet, feet/frame)
      drag,                -- per-wood multiplicative carry (from weight)
      bias, biasside,      -- curve strength, and +1/-1 forehand/backhand
      launch_speed,        -- speed at delivery (for the "late hook" scaling)
      owner,               -- which side bowled it
      resting }            -- true once stopped
```

## Per-frame integration (`physics.step`)

Each frame (designed for 60 fps via `_update60`):

1. **Speed:** `speed = sqrt(vx^2 + vy^2)`. If `speed <= cfg.stop_speed`, the wood **rests**.
2. **Friction (weight loss):** combine a multiplicative drag with a constant rolling
   resistance, so woods always come to rest:
   ```
   newspeed = speed * w.drag - cfg.roll_resist      -- clamp to 0
   scale    = newspeed / speed
   vx, vy  *= scale
   ```
   Heavier woods get a `drag` closer to 1 → they carry further.
3. **Bias — the wood's late hook (this is where ALL the curve comes from):** **rotate** the
   velocity toward the wood's bias side, turning harder as the wood slows. We rotate (and
   renormalise back to the same speed) rather than add a perpendicular *force* — a raw
   perpendicular accel inflates `|v|` each frame and pumps the wood into an eternal orbit (a bug
   we hit and fixed). Rotation curves the path without adding energy:
   ```
   slowness = clamp(1 - speed / launch_speed, 0, 1)
   theta    = min(cfg.bias_turn * w.bias * slowness*slowness, cfg.bias_turn_max)  -- turn this frame
   (px,py)  = (-vy, vx) * biasside            -- perpendicular nudge
   v        = renormalise(v + (px,py)*theta, to: speed)   -- rotate, keep speed
   ```
   The **`slowness²`** weighting keeps the wood running fairly straight early, then hooking hard
   LATE as it dies. The `bias_turn_max` cap stops a near-stationary wood spinning on the spot.

   **The arc (target feel):** the lateral movement must come mostly from this bias curve, **not**
   the aim angle — so `AIM.spread` is deliberately small (the wood launches nearly along the line
   of play). A tuned draw bows out to its widest "shoulder" ~70% of the way down, then draws hard
   onto the head over the final third. You **aim a little wide** and let the wood swing back.
   (If you instead make `AIM.spread` large, the wood just flies off at an angle and never draws.)
4. **Green contour (OPTIONAL, OFF by default):** a radial acceleration **toward the centre**,
   proportional to distance from centre. Guarded by `cfg.dish_gain ~= 0`, and `dish_gain` is
   **0** — the green is flat. Kept only so a *subtle* shape effect can be reintroduced later
   without it ever becoming a gravity sink that woods settle into.
   ```
   if cfg.dish_gain ~= 0 then
     dist = sqrt(x^2 + y^2)
     amt  = cfg.dish_gain * dist
     vx += (-x/dist)*amt ; vy += (-y/dist)*amt
   end
   ```
5. **Move:** `x += vx ; y += vy`.

`physics.simulate(w, cfg, maxsteps)` just steps until `w.resting` (or a safety cap) and returns
the step count — handy for tests and for the AI to predict outcomes.

### Tunables (in `src/data.lua` → `CFG`)
| Param | Meaning | Feel knob |
|---|---|---|
| `roll_resist` | constant (Coulomb) speed lost per frame | higher = woods stop sooner; also damps the dish's spring so woods don't ring forever |
| `bias_turn` | base heading turn/frame per unit bias | higher = more dramatic hook |
| `bias_turn_max` | cap on the per-frame turn | stops a near-stopped wood spinning on the spot |
| `dish_gain` | strength of the green's gather | higher = more swing toward centre |
| `stop_speed` | rest threshold | — |
| per-wood `drag` | carry from weight | nearer 1 = travels further |
| per-wood `bias` | curve amount | higher = swingier wood |

Tune these by feel in PICO-8; the headless tests assert *invariants* (woods always stop, a
biased wood curves to its bias side, the dish pulls an off-centre wood inward), not exact values,
so tuning won't break the suite.

## Scoring (`score.lua`)

```
score.measure(jack, woods)  -> list of {wood, dist} sorted ascending by distance to jack
score.count(jack, woods, score_radius) -> { holder, points }
```

Algorithm (mirrors real bowls):
1. Measure every wood's distance to the jack; sort ascending.
2. The **closest wood overall** sets the **holder** (the team that "holds shot").
3. Walk outward from closest: each consecutive wood **belonging to the holder** and **within
   `score_radius` (3 ft)** scores 1 point — **stop at the first rival wood**, which cuts scoring
   off, and stop once outside 3 ft.

So a team can score 0 (if even their closest is > 3 ft — unusual but possible) up to all of
their woods, depending on how the rival woods sit.

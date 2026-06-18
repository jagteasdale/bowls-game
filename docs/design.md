# Elizabethan Bowls — Game Design Document (living)

This is the north-star document. The current build is only the **vertical slice**; everything
here is the intended whole, kept so setup decisions don't foreclose the vision.

## 1. The pitch

A NES-era-looking bowls game with surprising depth. On the surface: a charming, tricky
sports/skill game about reading bias and swing. Underneath, revealed gradually: a social sim /
visual novel about the cast of characters at a small, eccentric bowling club and the drama
between them.

## 2. The real game it models

**Elizabethan Bowls** as played at Barnes Bowling Club:
- **High-bias woods** — every wood curves hard, more so as it slows. This is the dominant
  shaping force: you aim a little wide and the wood draws back onto the head late.
- **A small, gently dished green, played corner to corner** — the green is rectangular and
  small, but ends run along its long **diagonal**, giving a real sense of distance. The green's
  shape subtly affects the woods as they travel, but it is **not** a gravity sink.
  *(In the build we currently model the green as flat and let bias do all the curving; a subtle
  contour effect can return later — see `physics-notes.md`.)*
- Each player bowls **two woods**. Doubles play is possible.
- **Scoring:** the team with the wood closest to the jack "holds shot". Each of that team's
  woods **within 3 feet** of the jack scores **1 point**, counting outward until a rival
  (opponent) wood is reached — the rival cuts scoring off.

## 3. Core mechanic (the moment-to-moment)

Inspired by NES golf:
1. **Select a wood (once per end)** — woods differ in size, weight, and bias (trade-offs, not
   strict upgrades). You pick your wood at the start of each end; both of your woods that end are
   that style. (Realistically players pick per match, but per-end keeps it lively.)
2. **Aim** — a line pivots back and forth across an arc; time a button press to lock the angle.
   Because woods are heavily biased, you aim *wide* and let the curve bring the wood in.
3. **Power** — a bar fills up and down; time a button press to lock delivery weight (speed).
4. **Deliver** — the wood rolls a long way, running fairly straight before its bias draws it in
   late, and comes to rest. Read the result, adjust, bowl again.

Ends are played **"up" then "down"**: each end the mat switches to the opposite corner and you
bowl back down the diagonal, just like crossing ends on a real green.

## 4. Game modes

### 4a. Knockout tournament (core single-player)
A bracket of opponents, each a distinct personality and playstyle. Beat them in sequence to win
a shield. Difficulty and "tells" vary per opponent. This is the spine of the single-player game.

### 4b. Hotseat multiplayer (core)
Two players pass the controller. Enter names before playing (defaults **"Red"** and **"Blue"**).
**First to 11** points wins. Singles first, doubles later (two woods each, alternating).

### 4c. The hidden layer (long-term ambition)
A social-sim / visual-novel mode that reveals itself gradually once you reach the podium —
the clubhouse, the pub, club politics, and an arc that builds toward challenging for the
captaincy. The drama between the personalities is the real long-term draw. Built as a **separate
cart** that shares save state via `cartdata` (see Architecture). *Detailed design is kept
local-only in `social-sim.md` (not in this public repo) — it's pointed satire of real members.*

## 5. Characters

Approach: **original archetype personas** (e.g. "The Captain") that draw **composite,
affectionate-satire** elements from recognisable club personalities — a gentler GTA. No
one-to-one real people. *The roster bible is kept local-only in `characters.md` (not published
to this public repo).*

## 6. Look & feel

- 128×128, 16-colour PICO-8 palette; chunky, readable, NES-golf legibility.
- **Top-down / ¾ angled** view of the rectangular green, played along the diagonal so the screen
  reads open and long, and the player can follow the curving line of a wood as it draws in.
- Diegetic club charm: a slightly run-down pavilion, tea urn, hand-painted shield.

## 7. Roadmap (after the slice)

1. **Slice (done):** one end, one opponent, full mechanic, headless-tested core.
2. **Gameplay (done):** wood-per-end selection; ends played up/down (mat alternates corners).
3. **Match structure:** play ends to a target — **first to 11** — with running score and the
   up/down rhythm. (Single-player vs The Captain and multiplayer both ride on this.)
4. **Hotseat multiplayer:** name entry (defaults Red / Blue), pass-the-controller, first to 11.
5. **Knockout bracket + shield + 3–5 opponents** with distinct AI and tells.
6. Music, polish, title/menu, save system (`cartdata`).
7. **Social-sim layer as a second cart** (see `social-sim.md`, local-only); prove the
   multi-cart + web export path early (the plan's export spike).

## 8. Platform & risks

PICO-8 chosen for: retro aesthetic, one-click HTML export (mobile web), and native retro-handheld
support. Known risks and mitigations:
- **Token limit (~8192):** keep modes loosely coupled; split the social layer into its own cart.
- **Multi-cart in exports:** runtime `load()` works if carts are bundled; cross-cart `cstore`
  writes are blocked in exports — use `cartdata` (256 bytes) for saves; design a compact schema.
- **No headless engine:** keep `physics.lua`/`score.lua` pure Lua so the important logic is
  unit-tested off-engine; feel is QA'd by hand.
- **Escape hatch:** core logic is engine-agnostic, so a port to TIC-80 (bigger code budget)
  stays cheap if the social layer outgrows PICO-8.

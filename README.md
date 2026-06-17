# Elizabethan Bowls (working title)

A retro, NES-golf-flavoured video game based on **Elizabethan Bowls** — an obscure variant of
lawn bowls played almost exclusively at Barnes Bowling Club. High-bias woods that draw in late,
a small rectangular green played corner-to-corner, and the eternal hunt to rest closest to the
jack.

Built for **PICO-8**, so it exports to a mobile-friendly HTML build and runs on retro handhelds.

## Status: vertical slice

The current build proves the **core bowling mechanic** end-to-end against one AI opponent
("The Captain") over a single end. See [`docs/design.md`](docs/design.md) for the full vision
(knockout tournament, hotseat multiplayer, and the eventual hidden social-sim layer).

## How it's organised

The Lua source lives in `src/*.lua` and is stitched into `bowls.p8` via `#include`, so the code
stays modular and git-friendly. The `.p8` file also holds sprite/sound/map data.

```
bowls.p8       PICO-8 cart (the build artifact + gfx/sfx data)
src/           Lua modules (#included by bowls.p8)
tests/         Headless Lua tests for the pure-logic core
docs/          Design doc, character bible, physics notes
```

`physics.lua` and `score.lua` are **pure Lua** (no PICO-8 API), so their logic is unit-tested
headlessly under a normal Lua interpreter.

## Running the game

You need PICO-8 (a $15 fantasy console from <https://www.lexaloffle.com/pico-8.php>).

```
pico8 bowls.p8        # or: load bowls.p8  then  run   inside PICO-8
```

Controls (slice): **⬅️/➡️** to choose, **❎** to confirm and to lock the aim / power timing.

## Running the tests (no PICO-8 needed)

```
lua tests/run.lua          # unit suites: physics invariants + scoring rules
lua tests/integration.lua  # drives a whole end through the game code with the pico-8 api stubbed
```

`run.lua` exercises the pure-logic core under a stock Lua interpreter (fast, CI-friendly).
`integration.lua` stubs the PICO-8 API and plays a full end, catching undefined globals,
bad cross-references, and state-machine dead-ends before you ever open PICO-8.

## Exporting to web

Inside PICO-8:

```
export bowls.html
```

Then open `bowls.html` in a desktop or mobile browser.

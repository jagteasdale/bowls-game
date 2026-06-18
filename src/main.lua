-- main.lua -- entry points and the per-phase update dispatch.
-- (pico-8 file. _update60 runs at 60fps for smooth deliveries.)

-- physics steps advanced per displayed frame while a wood rolls. 1 = the full, slow,
-- anticipatory roll (a draw takes ~3-4 seconds before it hooks in and stops).
local DELIVER_STEPS = 1

function _init()
  new_game()
end

local function update_deliver()
  for _ = 1, DELIVER_STEPS do
    physics.step(G.live, CFG)
    -- a wood that runs off into the ditch is dead; let it cross the edge, then stop it
    if abs(G.live.x) > GREEN.hw + 2 or abs(G.live.y) > GREEN.hl + 2 then
      G.live.resting = true
    end
    if G.live.resting then break end
  end
  if G.live.resting then
    settle_wood()
  end
end

local function update_cpu_think()
  G.timer = G.timer - 1
  if G.timer <= 0 then
    launch_wood(TEAM_CPU, G.cpu.wood, G.cpu.t, G.cpu.p)
  end
end

function _update60()
  if G.phase == "title" then
    update_title_menu()
  elseif G.phase == "name_entry" then
    update_name_entry()
  elseif G.phase == "handoff" then
    update_handoff()
  elseif G.phase == "wood_select" then
    update_wood_select()
  elseif G.phase == "aim" then
    update_aim()
  elseif G.phase == "power" then
    update_power()
  elseif G.phase == "cpu_think" then
    update_cpu_think()
  elseif G.phase == "deliver" then
    update_deliver()
  elseif G.phase == "result" then
    if btnp(5) then after_result() end
  elseif G.phase == "match_over" then
    if btnp(5) then new_game() end
  end
end

function _draw()
  draw_game()
end

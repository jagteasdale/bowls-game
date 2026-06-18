-- aim.lua -- the player's input phases: pick a wood, time the aim, time the power.
-- (pico-8 file. button 5 = X/x button = confirm/lock; 0/1 = left/right.)

-- pick ONE wood for the whole end; on confirm, hand off to the first delivery.
function update_wood_select()
  if btnp(0) then
    G.sel = G.sel - 1
    if G.sel < 1 then G.sel = #WOODS end
  elseif btnp(1) then
    G.sel = G.sel + 1
    if G.sel > #WOODS then G.sel = 1 end
  end
  if btnp(5) then
    G.player_wood = G.sel -- locked in for both of the player's woods this end
    begin_turn()
  end
end

-- the aim line pivots back and forth across the arc; lock it with X.
function update_aim()
  G.aim_t = G.aim_t + G.aim_dir * AIM.sweep
  if G.aim_t > 1 then
    G.aim_t = 1
    G.aim_dir = -1
  elseif G.aim_t < -1 then
    G.aim_t = -1
    G.aim_dir = 1
  end
  if btnp(5) then
    G.aim_locked_t = G.aim_t
    -- begin the power bar
    G.pow_p = 0
    G.pow_dir = 1
    G.phase = "power"
    G.msg = "press x to set the weight"
  end
end

-- the power bar fills up and down; lock it with X to deliver.
function update_power()
  G.pow_p = G.pow_p + G.pow_dir * AIM.pow_sweep
  if G.pow_p > 1 then
    G.pow_p = 1
    G.pow_dir = -1
  elseif G.pow_p < 0 then
    G.pow_p = 0
    G.pow_dir = 1
  end
  if btnp(5) then
    launch_wood(TEAM_PLAYER, WOODS[G.player_wood], G.aim_locked_t, G.pow_p)
    G.msg = ""
  end
end

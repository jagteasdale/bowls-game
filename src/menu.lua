-- menu.lua -- front-end input phases: title menu, hotseat name entry, controller handoff.
-- (pico-8 file. buttons: 0/1 left/right, 2/3 up/down, 5 = X confirm.)

-- ---- title: choose 1 or 2 players ------------------------------------------

-- menu options: 1 = quick match (vs the captain), 2 = shield, 3 = 2 players
function update_title_menu()
  if btnp(2) and G.menu_sel > 1 then G.menu_sel = G.menu_sel - 1 end
  if btnp(3) and G.menu_sel < 3 then G.menu_sel = G.menu_sel + 1 end
  if btnp(5) then
    if G.menu_sel == 1 then
      start_solo()
    elseif G.menu_sel == 2 then
      start_shield()
    else
      begin_name_entry()
    end
  end
end

-- opponent intro screen: press X to start the round's match
function update_intro()
  if btnp(5) then
    start_match()
  end
end

-- ---- hotseat name entry (2 players) ----------------------------------------

-- find a character's index in NAME_LETTERS (defaults to space)
function letter_index(c)
  for i = 1, #NAME_LETTERS do
    if sub(NAME_LETTERS, i, i) == c then return i end
  end
  return 1
end

-- prefill the entry field for a team from a default name, padded with spaces
function set_entry_default(team)
  local d = (team == TEAM_PLAYER) and "red" or "blue"
  G.entry = {}
  for i = 1, NAME_MAX do
    local c = (i <= #d) and sub(d, i, i) or " "
    G.entry[i] = letter_index(c)
  end
  G.entry_cursor = 1
end

function begin_name_entry()
  G.entry_team = TEAM_PLAYER
  set_entry_default(TEAM_PLAYER)
  G.phase = "name_entry"
end

-- assemble the typed name: trim trailing spaces, fall back to the default if empty
function entry_to_name()
  local s = ""
  for i = 1, NAME_MAX do
    s = s .. sub(NAME_LETTERS, G.entry[i], G.entry[i])
  end
  while #s > 0 and sub(s, #s, #s) == " " do s = sub(s, 1, #s - 1) end
  if s == "" then s = (G.entry_team == TEAM_PLAYER) and "red" or "blue" end
  return s
end

function update_name_entry()
  local n = #NAME_LETTERS
  if btnp(0) and G.entry_cursor > 1 then G.entry_cursor = G.entry_cursor - 1 end
  if btnp(1) and G.entry_cursor < NAME_MAX then G.entry_cursor = G.entry_cursor + 1 end
  if btnp(2) then -- up: next letter
    G.entry[G.entry_cursor] = G.entry[G.entry_cursor] % n + 1
  end
  if btnp(3) then -- down: previous letter
    G.entry[G.entry_cursor] = (G.entry[G.entry_cursor] - 2) % n + 1
  end
  if btnp(5) then
    G.names[G.entry_team] = entry_to_name()
    if G.entry_team == TEAM_PLAYER then
      G.entry_team = TEAM_CPU
      set_entry_default(TEAM_CPU)
    else
      start_versus()
    end
  end
end

-- ---- hotseat handoff (pass the controller) ---------------------------------

function update_handoff()
  if btnp(5) then
    enter_human_turn(G.handoff_team)
  end
end

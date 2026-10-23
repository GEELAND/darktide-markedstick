--[[
	MarkedStick -- a neon stick skeleton on enemies the game has marked.

	WHY THIS IS NOT AN OUTLINE MOD
	  An outline is drawn in 3D and sorted by depth, so a nearer outline always
	  paints over a farther one. No amount of outline work can change that
	  ordering: it lives below the point where Lua has any say. A UI widget is
	  drawn after every 3D pass by construction, so it cannot be covered at all.

	WHAT THIS FILE DOES
	  1. registers a marker template with the engine's HudElementWorldMarkers;
	  2. watches the outline system for the class-mark outline names;
	  3. keeps only elites and specials -- a marked horde body gets no skeleton;
	  4. asks the engine to draw a skeleton on each kept unit;
	  5. takes the skeleton back the moment the unit stops qualifying.

	WHY STEP 5 EXISTS, AND WHY IT IS PER-FRAME
	  A world marker is owned by the engine, not by us. Dropping our own
	  bookkeeping entry does not delete the widget: it keeps drawing at the
	  unit's last node, which is exactly how a frame ends up welded to a corpse,
	  or left standing over an enemy the player has already re-tagged onto
	  somebody else. So every frame we re-ask the two questions that make a
	  skeleton legitimate -- is the unit still alive, and is it still marked --
	  and call `remove_world_marker` with the id the engine handed us when it
	  was created.

	THE RIG, AND WHY /stick_rig EXISTS
	  The skeleton is drawn from real bones. Six names are verified on a live
	  unit (j_head / j_neck / j_spine1 / j_spine / j_hips / j_hip /
	  root_point); the twelve limb names are still a guess built from
	  Fatshark's j_ convention. A wrong name does not error -- it silently
	  draws nothing -- so the geometry tolerates missing joints (a segment
	  whose joint did not resolve is skipped whole) and /stick_rig dumps the
	  real skeleton of a live marked unit. Bone names live in exactly one
	  place: the RIG table at the top of stick_marker.lua.

	DISCIPLINE
	  * every Unit.* call is pcall'd -- Stingray throws on a destroyed unit, and
	    one unguarded call aborts the whole frame, every frame;
	  * nothing is printed automatically, ever; diagnostics are chat commands;
	  * the expensive scan is throttled; only the cheap validity check runs
	    every frame, and it degrades silently when the outline system or the
	    HUD is not up yet.
]]

local mod = get_mod("MarkedStick")

local StickMarker = mod:io_dofile("MarkedStick/scripts/mods/MarkedStick/stick_marker")

local TEMPLATE = StickMarker.name
local RIG = StickMarker.rig or {}
local RIG_ORDER = StickMarker.rig_order or {}

-- The outline names the two class marks resolve to, from
-- scripts/settings/outline/outline_settings.lua. Verified in game on 2026-10-18.
-- The two adamant_* entries are the same mechanism and cost nothing to accept,
-- but we have not seen them on a live unit.
local GAME_MARK_NAMES = {
	veteran_smart_tag = true,
	smart_tagged_enemy = true,
	smart_tagged_enemy_passive = true,
	psyker_marked_target = true,
	adamant_smart_tag = true,
	adamant_mark_target = true,
}

local SCAN_PERIOD = 0.2

-- [unit] = { id = <engine marker id>, name = <outline name that marked it> }
-- The id is what `remove_world_marker` takes. A record exists only while the
-- skeleton is supposed to be on screen.
local live = {}

local registered = false
local cached_wm = nil
local accum = 0
local error_count = 0
local skipped = 0
local no_breed = 0
local dropped = 0

-- Reused every frame, so the per-frame path allocates nothing.
local scratch = {}

local function get_outline_system()
	local manager = Managers.state and Managers.state.extension

	if manager and manager:has_system("outline_system") then
		return manager:system("outline_system")
	end

	return nil
end

local function unit_alive(unit)
	local ok, alive = pcall(Unit.alive, unit)

	return ok and alive and true or false
end

-- `Unit.alive` stays true through the death animation: the unit is only gone
-- once it is destroyed, which can be a second or two after the enemy dies. The
-- health extension is the only thing that flips the instant the enemy dies,
-- and that instant is when the skeleton has to go.
--
-- No health extension -> fall back to `unit_alive` (return true here).
local function health_alive(unit)
	local ok, extension = pcall(ScriptUnit.has_extension, unit, "health_system")

	if not ok or not extension then
		return true
	end

	local ok2, alive = pcall(extension.is_alive, extension)

	if not ok2 then
		return true
	end

	return alive == true
end

-- The breed table carries the only stable classification the game offers:
-- a hand-written list of breed names would rot with every content patch.
local function breed_of(unit)
	local ok, extension = pcall(ScriptUnit.has_extension, unit, "unit_data_system")

	if not ok or not extension then
		return nil
	end

	local ok2, breed = pcall(extension.breed, extension)

	return ok2 and breed or nil
end

-- Only elites and specials get skeletons: a marked poxwalker is not worth a
-- reticle, and drawing one on every horde body is the fastest way to make the
-- HUD unreadable. Bosses / monsters / captains go with the elites.
--
-- When the breed lookup fails we FAIL OPEN. A HUD that draws nothing is harder
-- to diagnose than one that draws too much, and `/stick_diag` reports the
-- count so the difference is visible instead of silent.
local function is_target(unit)
	local breed = breed_of(unit)

	if not breed then
		no_breed = no_breed + 1

		return true
	end

	if breed.is_boss or breed.boss then
		return true
	end

	local tags = breed.tags or {}

	return tags.elite == true
		or tags.special == true
		or tags.monster == true
		or tags.boss == true
		or tags.captain == true
end

local function is_marked(ext)
	local outlines = ext and ext.outlines

	if not outlines then
		return nil
	end

	for i = 1, #outlines do
		local outline = outlines[i]
		local name = outline and outline.name

		if name and GAME_MARK_NAMES[name] then
			return name
		end
	end

	return nil
end

local function current_world_markers()
	local ui_manager = Managers.ui

	if not ui_manager or not ui_manager.get_hud then
		return nil
	end

	local hud = ui_manager:get_hud()

	if not hud or not hud.element then
		return nil
	end

	return hud:element("HudElementWorldMarkers")
end

local function ensure_registered()
	local world_markers = current_world_markers()

	if not world_markers then
		return false
	end

	-- A new level, a respawn or a character swap rebuilds the HUD. The fresh
	-- element starts with an empty marker list, so everything we were tracking
	-- belongs to an element that no longer draws anything: forget it and let
	-- the scan re-add the units that are still alive and still marked.
	if world_markers ~= cached_wm then
		cached_wm = world_markers
		registered = false
		live = {}
	end

	if registered then
		return true
	end

	local templates = world_markers._marker_templates

	if not templates then
		return false
	end

	templates[TEMPLATE] = StickMarker

	registered = true

	return true
end

-- The engine keeps its own list of live widgets per marker type. It is the
-- only authoritative answer to "what am I currently drawing", which makes it
-- the right thing to sweep: it catches markers whose creation callback never
-- reached us, duplicates, and leftovers from a previous HUD.
local function engine_marker_list()
	local by_type = cached_wm and cached_wm._markers_by_type

	return by_type and by_type[TEMPLATE] or nil
end

local function remove_marker_id(event_manager, id)
	if id == nil then
		return false
	end

	return pcall(event_manager.trigger, event_manager, "remove_world_marker", id)
end

-- Drop one unit: forget it and take its widget with it.
local function drop_unit(event_manager, unit)
	local record = live[unit]

	live[unit] = nil

	if record then
		remove_marker_id(event_manager, record.id)
	end
end

-- Everything that has to be true for a skeleton to stay on screen.
local function still_valid(unit, data)
	if not unit_alive(unit) then
		return false
	end

	if not health_alive(unit) then
		return false
	end

	-- The mark itself is the source of truth, not our own memory. When the
	-- player tags a second enemy the game moves the outline off the first one,
	-- so this goes false the same frame the tag moves.
	return is_marked(data and data[unit]) ~= nil
end

-- Cheap check, run every frame. Never mutates `live` while iterating it.
local function enforce()
	local event_manager = Managers.event

	if not event_manager then
		return
	end

	local system = get_outline_system()
	local data = system and system._unit_extension_data
	local count = 0

	for unit in pairs(live) do
		count = count + 1
		scratch[count] = unit
	end

	for i = 1, count do
		local unit = scratch[i]

		scratch[i] = nil

		local ok, keep = pcall(still_valid, unit, data)

		if not ok or not keep then
			drop_unit(event_manager, unit)
			dropped = dropped + 1
		end
	end
end

-- Second line of defence, run per scan. Anything the engine is drawing for our
-- template whose unit we do not track is stale. Walking its own list needs no
-- id bookkeeping at all, and backfills an id if the creation callback was late.
local function sweep()
	local list = engine_marker_list()
	local event_manager = Managers.event

	if not list or not event_manager then
		return
	end

	for i = #list, 1, -1 do
		local marker = list[i]
		local unit = marker and marker.unit
		local record = unit and live[unit]

		if not record then
			remove_marker_id(event_manager, marker.id)
		elseif record.id == nil then
			record.id = marker.id
		end
	end
end

local function tick()
	if not ensure_registered() then
		return
	end

	enforce()

	local system = get_outline_system()
	local data = system and system._unit_extension_data

	if not data then
		return
	end

	local event_manager = Managers.event

	if not event_manager then
		return
	end

	for unit, ext in pairs(data) do
		if not live[unit] then
			local mark_name = is_marked(ext)

			if mark_name and unit_alive(unit) and health_alive(unit) then
				if is_target(unit) then
					local record = { name = mark_name }

					-- Recorded before the trigger: the engine may create the
					-- marker and answer synchronously, and a re-entrant scan
					-- must not add the same unit twice.
					live[unit] = record

					-- The engine hands back the new marker's id here. That id
					-- is the only handle `remove_world_marker` accepts; if the
					-- callback ever comes late, the sweep finds it by unit.
					pcall(event_manager.trigger, event_manager, "add_world_marker_unit", TEMPLATE, unit, function(marker_id)
						record.id = marker_id
					end)
				else
					skipped = skipped + 1
				end
			end
		end
	end

	sweep()
end

-- Remove every widget of ours from the engine. Used when the player switches
-- the mod off, so nothing is left frozen on screen.
local function drop_all()
	local list = engine_marker_list()
	local event_manager = Managers.event

	if list and event_manager then
		for i = #list, 1, -1 do
			remove_marker_id(event_manager, list[i] and list[i].id)
		end
	end

	live = {}
end

-- DMF has called this both as mod.update(dt) and mod:update(dt) depending on
-- version. Accept either shape instead of guessing.
function mod.update(a, b)
	local dt = type(a) == "number" and a or b

	if type(dt) ~= "number" then
		dt = 0
	end

	if not mod:get("stick_enabled") then
		return
	end

	-- Per frame, not per scan: re-tagging and dying both have to look instant.
	local ok_enforce = pcall(enforce)

	if not ok_enforce then
		error_count = error_count + 1
	end

	accum = accum + dt

	if accum < SCAN_PERIOD then
		return
	end

	accum = 0

	local ok = pcall(tick)

	if not ok then
		error_count = error_count + 1
	end
end

mod.on_enabled = function()
	accum = 0
end

mod.on_disabled = function()
	drop_all()

	registered = false
	cached_wm = nil
	error_count = 0
	skipped = 0
	no_breed = 0
	dropped = 0
end

mod.on_game_state_changed = function(status, state_name)
	if status == "enter" then
		live = {}
		registered = false
		cached_wm = nil
		skipped = 0
		no_breed = 0
		dropped = 0
	end
end

mod:command("stick_diag", "MarkedStick: print the current state", function()
	local system = get_outline_system()
	local data = system and system._unit_extension_data

	local total, marked = 0, 0
	local seen = {}

	if data then
		for unit, ext in pairs(data) do
			total = total + 1

			local outlines = ext and ext.outlines

			if outlines then
				for i = 1, #outlines do
					local name = outlines[i] and outlines[i].name

					if name then
						seen[name] = true
					end
				end
			end

			if is_marked(ext) then
				marked = marked + 1
			end
		end
	end

	local names = {}

	for name in pairs(seen) do
		names[#names + 1] = name
	end

	table.sort(names)

	-- Keep the echo to a readable width; the interesting part is whether the
	-- mark names show up at all.
	while #names > 5 do
		table.remove(names)
	end

	local live_count = 0
	local no_id = 0

	for _, record in pairs(live) do
		live_count = live_count + 1

		if record.id == nil then
			no_id = no_id + 1
		end
	end

	local engine_count = 0
	local list = engine_marker_list()

	if list then
		engine_count = #list
	end

	mod:echo(string.format(
		"stick: registered=%s units=%d marked=%d live=%d engine=%d noid=%d",
		tostring(registered),
		total,
		marked,
		live_count,
		engine_count,
		no_id
	))

	mod:echo(string.format(
		"counters: dropped=%d skipped=%d nobreed=%d err=%d",
		dropped,
		skipped,
		no_breed,
		error_count
	))

	mod:echo("layers: " .. (#names > 0 and table.concat(names, ", ") or "none"))
end)

-- ---------------------------------------------------------------------------
-- /stick_rig -- the rig probe. This build's whole reason to exist.
--
-- Three independent sources of bone truth, dumped per marked unit:
--   1. node enumeration -- every node the API will name, if it allows it;
--   2. the candidate matrix -- each RIG joint with the first candidate that
--      exists and its world position (z is how left/right and up/down get
--      checked: a swapped pair of bones is visible in the numbers);
--   3. the breed's hit_zones -- Darktide's hit-zone table usually carries node
--      names, an independent confirmation of the same rig.
--
-- A full dump is longer than one chat window, so each run prints the next
-- RIG_LINES_PER_PAGE lines and says how many batches are left. The page counter
-- resets at the end of the dump, and whenever there is nothing to dump.
-- ---------------------------------------------------------------------------

local RIG_LINES_PER_PAGE = 40

-- Which candidate actually resolves a joint, with its world position. The
-- has_node -> node -> world_position chain is the proven one; if has_node
-- itself is missing the probe falls through to Unit.node rather than
-- reporting every joint missing.
local function node_handle(unit, name)
	local ok_has, has = pcall(Unit.has_node, unit, name)

	if ok_has and not has then
		return nil
	end

	local ok_node, node = pcall(Unit.node, unit, name)

	if ok_node and node then
		return node
	end

	return nil
end

local function probe_joint(unit, candidates)
	for i = 1, #candidates do
		local node = node_handle(unit, candidates[i])

		if node then
			local ok_pos, pos = pcall(Unit.world_position, unit, node)

			if ok_pos and pos and type(pos.x) == "number" and type(pos.z) == "number" then
				return candidates[i], pos
			end
		end
	end

	return nil, nil
end

-- Node enumeration. Neither the index base (0 or 1) nor the argument shape
-- (index vs node handle) of Unit.node_name is documented, so BOTH bases are
-- tried and the larger result wins: a 1-based API asked 0..n-1 still answers
-- for 1..n-1, and a 0-based API asked 1..n still answers for 1..n-1, so "more
-- names" identifies the real convention without guessing it.
local function enumerate_nodes(unit, limit)
	local ok_num, num = pcall(Unit.num_nodes, unit)

	if not ok_num or type(num) ~= "number" or num <= 0 then
		return nil
	end

	local best = {}

	for _, base in ipairs({ 0, 1 }) do
		local names = {}
		local marks = {}

		for i = base, num - 1 + base do
			if #names >= limit then
				break
			end

			local ok, name = pcall(Unit.node_name, unit, i)

			if ok and type(name) == "string" and name ~= "" and not marks[name] then
				marks[name] = true
				names[#names + 1] = name
			end

			-- node_name may also take the handle Unit.node returns.
			local ok2, node = pcall(Unit.node, unit, i)

			if ok2 and node then
				local ok3, handle_name = pcall(Unit.node_name, unit, node)

				if ok3 and type(handle_name) == "string" and handle_name ~= "" and not marks[handle_name] then
					marks[handle_name] = true
					names[#names + 1] = handle_name
				end
			end
		end

		if #names > #best then
			best = names
		end
	end

	if #best == 0 then
		return nil
	end

	return best
end

-- Sorted key walk, strings and numbers only, depth 3: a nested table cannot
-- flood the chat, and the output stays comparable between two runs.
local function sorted_keys(t)
	local keys = {}

	for k in pairs(t) do
		keys[#keys + 1] = k
	end

	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	return keys
end

local function dump_hit_zones(breed, lines, budget)
	local zones = breed and breed.hit_zones

	if type(zones) ~= "table" then
		lines[#lines + 1] = "hit_zones: none on the breed table"
		return
	end

	local keys = sorted_keys(zones)

	lines[#lines + 1] = "hit_zones: " .. #keys .. " entries"

	local function walk(t, prefix, depth)
		if depth > 3 or #lines >= budget then
			return
		end

		for _, k in ipairs(sorted_keys(t)) do
			if #lines >= budget then
				return
			end

			local v = t[k]

			if type(v) == "string" or type(v) == "number" then
				lines[#lines + 1] = "  " .. prefix .. tostring(k) .. " = " .. tostring(v)
			elseif type(v) == "table" and depth < 3 then
				walk(v, prefix .. tostring(k) .. ".", depth + 1)
			end
		end
	end

	walk(zones, "", 1)
end

local function collect_rig_lines(unit, index, lines)
	local breed = breed_of(unit)
	local tags = breed and breed.tags or {}
	local flags = {}

	for _, name in ipairs({ "elite", "special", "monster", "boss", "captain", "horde", "roamer" }) do
		if tags[name] then
			flags[#flags + 1] = name
		end
	end

	lines[#lines + 1] = string.format(
		"unit %d: breed=%s height=%s tags=[%s]",
		index,
		tostring(breed and breed.name),
		tostring(breed and breed.base_height),
		table.concat(flags, ",")
	)

	-- 1) every node the skeleton has, if the API allows enumeration
	local names = enumerate_nodes(unit, 40)

	if names then
		lines[#lines + 1] = "nodes(" .. #names .. "): " .. table.concat(names, " ")
	else
		lines[#lines + 1] = "nodes: no enumeration API (Unit.num_nodes / Unit.node_name unavailable)"
	end

	-- 2) the candidate matrix: first existing candidate per joint, with position
	local missing = {}

	for i = 1, #RIG_ORDER do
		local key = RIG_ORDER[i]
		local candidates = RIG[key]

		if not candidates then
			missing[#missing + 1] = key .. "(not in RIG)"
		else
			local name, pos = probe_joint(unit, candidates)

			if name then
				lines[#lines + 1] = string.format(
					"%s: %s x=%.2f y=%.2f z=%.2f",
					key, name, pos.x, pos.y, pos.z
				)
			else
				missing[#missing + 1] = key .. "(" .. table.concat(candidates, "/") .. ")"
			end
		end
	end

	if #missing > 0 then
		lines[#lines + 1] = "MISSING: " .. table.concat(missing, " ")
	else
		lines[#lines + 1] = "MISSING: none -- every joint resolved"
	end

	-- 3) hit zones: an independent source of node names
	dump_hit_zones(breed, lines, #lines + 12)

	-- 4) projection sanity: the marker anchor has to land on screen
	local state = Managers.state and Managers.state.camera
	local camera = state and select(2, pcall(state.camera, state, "first_person"))

	if camera then
		local ok_pos, unit_pos = pcall(Unit.world_position, unit, 1)
		local ok_screen, screen = false, nil

		if ok_pos and unit_pos then
			ok_screen, screen = pcall(Camera.world_to_screen, camera, unit_pos)
		end

		if ok_screen and screen and type(screen.x) == "number" then
			lines[#lines + 1] = string.format("screen: x=%.1f y=%.1f z=%.1f", screen.x, screen.y, screen.z)
		else
			lines[#lines + 1] = "screen: projection failed"
		end
	else
		lines[#lines + 1] = "screen: no first_person camera"
	end
end

local rig_page = 0

mod:command("stick_rig", "MarkedStick: dump the skeleton rig of marked units", function()
	local lines = {}
	local shown = 0

	for unit in pairs(live) do
		if shown >= 2 then
			break
		end

		if unit_alive(unit) then
			shown = shown + 1

			collect_rig_lines(unit, shown, lines)
		end
	end

	if shown == 0 then
		rig_page = 0
		mod:echo("stick_rig: no marked unit right now -- mark an elite or special, then run /stick_rig again")
		return
	end

	local pages = math.max(1, math.ceil(#lines / RIG_LINES_PER_PAGE))

	if rig_page >= pages then
		rig_page = 0
	end

	local first = rig_page * RIG_LINES_PER_PAGE + 1
	local last = math.min(#lines, first + RIG_LINES_PER_PAGE - 1)

	for i = first, last do
		mod:echo(lines[i])
	end

	rig_page = rig_page + 1

	if rig_page >= pages then
		rig_page = 0
		mod:echo(string.format("stick_rig: end of dump (%d lines)", #lines))
	else
		mod:echo(string.format("stick_rig: batch %d/%d -- run /stick_rig again for the rest", rig_page, pages))
	end
end)

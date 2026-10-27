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
	  3. keeps elites and specials -- a marked horde body gets no skeleton, with
	     one exception: the class keystones mark trash that cannot be tagged by
	     hand at all, and those are drawn (see KEYSTONE_MARKS);
	  4. asks the game's own smart tag who made the mark, so an enemy a teammate
	     tagged can be told apart from one the player tagged;
	  5. asks the engine to draw a skeleton on each kept unit;
	  6. takes the skeleton back the moment the unit stops qualifying.

	WHY STEP 4 IS A FACT AND NOT A GUESS
	  A marked enemy carries a smart tag, and the game records which player made
	  it: the tag stores tagger_unit / tagger_player, and the tagger's own
	  extension lists the tag ids it created (owned_tag_ids). The scan compares
	  ids, which is integer equality and cannot be fooled by a respawn or a
	  stale player_unit. A target holds at most one tag at a time, so the two
	  cases are exclusive: an enemy is either the player's mark or somebody
	  else's. The class keystones that mark without a tag
	  (psyker_marked_target and friends) are personal by construction, so "no
	  tag" counts as the player's own.

	MINE IS STICKY
	  Because a target holds only one tag, a teammate re-tagging the player's
	  enemy takes that tag for themselves. The skeleton still must not change
	  owner under the player's eyes, so the verdict is one-way while a marker
	  lives: once mine, always mine. Ship it the other way and the mark the
	  player just made turns blue a moment later, which reads as a fault.

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

-- The keystone marks. These are exempt from the elite/special filter below,
-- because they are the only way their targets can be marked at all: the psyker
-- keystone also lands on scabs and dregs, and a scab cannot be tagged by hand
-- (the game refuses), so filtering those out means the player never sees the
-- mark their own talent put there.
local KEYSTONE_MARKS = {
	psyker_marked_target = true,
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
-- Marks owned by other players that were not drawn because the player turned
-- that set off. Counted so /stick_diag can tell "nothing to show" apart from
-- "filtered on purpose".
local other_hidden = 0
-- Same idea for the keystone set: marks the talent put there that were not
-- drawn because that set is switched off.
local keystone_hidden = 0
-- Whether the previous frame was actually drawing. Drives the one-shot teardown
-- when the master switch goes off.
local running = false

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

-- The local player. `local_player` takes a player INDEX: called with no
-- argument it answers nil, and a nil answer here used to make every tagged
-- enemy look like somebody else's, because "who am I" was empty.
local function local_player()
	local manager = Managers.player

	if not manager then
		return nil
	end

	local ok, player = pcall(manager.local_player, manager, 1)

	if ok and player then
		return player
	end

	-- Some builds resolve the index themselves; keep that as a fallback rather
	-- than hard-coding a single call shape.
	ok, player = pcall(manager.local_player, manager)

	return ok and player or nil
end

local function smart_tag_system()
	local manager = Managers.state and Managers.state.extension

	if not manager or not manager.has_system then
		return nil
	end

	local ok_has, has = pcall(manager.has_system, manager, "smart_tag_system")

	if not ok_has or not has then
		return nil
	end

	local ok_get, system = pcall(manager.system, manager, "smart_tag_system")

	return ok_get and system or nil
end

-- The ids this unit has tagged, straight from the game's own bookkeeping: the
-- tagger's smart-tag extension appends every tag id it creates
-- (`register_owned_tag` / `owned_tag_ids`). Comparing ids is integer equality,
-- so it cannot be fooled by a respawn, a proxy object or a stale player_unit.
local function owned_tag_ids(system, unit)
	local data = system and system._unit_extension_data
	local extension = data and data[unit]

	if not extension then
		return nil
	end

	local ok, ids = pcall(extension.owned_tag_ids, extension)

	if not ok or type(ids) ~= "table" then
		return nil
	end

	return ids
end

local function same_player(a, b)
	if not a or not b then
		return false
	end

	if a == b then
		return true
	end

	local unit_a, unit_b = a.player_unit, b.player_unit

	return unit_a ~= nil and unit_a == unit_b
end

-- Whose tag is on this unit.
--
-- The game keeps the answer itself. Every smart tag carries the unit and the
-- Player that created it (`tagger_unit` / `tagger_player`), and the tagger's
-- own extension lists the ids it owns, which is the primary check below: tag
-- ids are integers, so there is no identity assumption to get wrong. One target
-- holds at most ONE tag at a time (the extension keeps a single tag id, and a
-- second tag only lands if its template allows overriding), so a marked enemy
-- is either yours or somebody else's.
--
--   true  -> the local player tagged it
--   false -> another player tagged it, or the tag outlived the player who made
--            it (a tag whose owner left keeps no tagger, and it cannot be ours)
--   nil   -> unknown, or there is no smart tag at all. The class keystones
--            (`psyker_marked_target`, `adamant_mark_target`) mark without a
--            tag and are personal by construction, so the caller reads nil as
--            "mine"; so does a frame in which the local player is not resolvable
--            yet. Painting an unknown tag with the player's own colours is
--            wrong in the harmless direction, accusing the player's own mark of
--            being a teammate's is the bug this function kept shipping.
local function tag_owner(unit)
	local system = smart_tag_system()

	if not system then
		return nil
	end

	local ok_tag, tag = pcall(system.unit_tag, system, unit)

	if not ok_tag then
		return nil
	end

	if not tag then
		return nil
	end

	local player = local_player()
	local my_unit = player and player.player_unit
	local ok_id, tag_id = pcall(system.unit_tag_id, system, unit)

	-- Primary: is this tag id in my own list?
	if my_unit and ok_id and tag_id then
		local ids = owned_tag_ids(system, my_unit)

		if ids then
			for i = 1, #ids do
				if ids[i] == tag_id then
					return true
				end
			end

			-- A tag is on the enemy and it is not mine.
			return false
		end
	end

	-- Fallback: the tag's own record.
	local ok_player, tagger_player = pcall(tag.tagger_player, tag)

	if ok_player and tagger_player then
		if player and same_player(tagger_player, player) then
			return true
		end

		local tagger_unit = tagger_player.player_unit

		if tagger_unit and my_unit then
			return tagger_unit == my_unit
		end
	end

	local ok_unit, tagger_unit = pcall(tag.tagger_unit, tag)

	if ok_unit and tagger_unit then
		if my_unit then
			return tagger_unit == my_unit
		end

		-- We could not establish our own unit this frame. Do not accuse.
		return nil
	end

	-- A tag with no tagger at all: its owner is gone, so it cannot be ours.
	return false
end

-- Which colour set a mark belongs to: "own", "other" or "keystone".
--
-- A keystone mark is the talent's own bookkeeping rather than a tag -- the
-- psyker keystone also lands on scabs and dregs, which cannot be tagged by hand
-- at all -- so it is a third category with its own set, exactly like the split
-- between the player's marks and a teammate's. The one thing that outranks it
-- is the player hand-tagging the same enemy afterwards, because that is a
-- deliberate act and it should look like one.
--
-- Sticky by design: a frame in which the tag cannot be attributed keeps the
-- previous verdict instead of repainting the skeleton a different colour.
local function side_of(mark_name, unit, previous)
	if mark_name and KEYSTONE_MARKS[mark_name] then
		if tag_owner(unit) == true then
			return "own"
		end

		return "keystone"
	end

	local verdict = tag_owner(unit)

	if verdict == nil then
		return previous or "own"
	end

	return verdict and "own" or "other"
end

-- Only elites and specials get skeletons: a marked poxwalker is not worth a
-- reticle, and drawing one on every horde body is the fastest way to make the
-- HUD unreadable. Bosses / monsters / captains go with the elites.
--
-- When the breed lookup fails we FAIL OPEN. A HUD that draws nothing is harder
-- to diagnose than one that draws too much, and `/stick_diag` reports the
-- count so the difference is visible instead of silent.
local function is_target(unit, mark_name)
	-- Keystone marks go through: their targets include trash a player cannot
	-- tag by hand, and the whole point is to see the mark the talent applied.
	if mark_name and KEYSTONE_MARKS[mark_name] then
		return true
	end

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
	StickMarker.forget_own(unit)

	if record then
		remove_marker_id(event_manager, record.id)
	end
end

-- Whether marks made by other players are drawn at all. Their own colour set
-- exists either way; this switch is for the player who only cares about what
-- they tagged themselves.
local function others_enabled()
	local ok, value = pcall(mod.get, mod, "stick_other_enabled")

	if not ok then
		return true
	end

	return value ~= false
end

-- The keystone set has the same switch for the same reason: a psyker who wants
-- only the enemies they marked themselves can turn the talent's marks off
-- without touching the colour set.
local function keystone_enabled()
	local ok, value = pcall(mod.get, mod, "stick_keystone_enabled")

	if not ok then
		return true
	end

	return value ~= false
end

-- Ownership can change while a skeleton is already up: the instant another
-- player re-tags the same enemy, the tag on that body stops being ours. It is
-- one table lookup and one assignment, so it rides the same per-frame pass
-- that decides whether the marker belongs on screen at all.
local function refresh_side(unit)
	local record = live[unit]

	if not record then
		return
	end

	-- MINE IS STICKY, and this is deliberate.
	--
	-- A target unit holds exactly one tag, so when a teammate re-tags an enemy
	-- the game moves the tag to them and the record stops pointing at us. From
	-- the player's chair that enemy is still the one they marked, and a skeleton
	-- that changes owner mid-fight reads as a fault, so the verdict only ever
	-- moves in one direction while the marker is alive: an enemy never stops
	-- being mine. A body that was somebody else's all along can still become
	-- mine the moment the player tags it.
	if record.side == "own" then
		return
	end

	local next_side = side_of(record.name, unit, record.side)

	if next_side == record.side then
		return
	end

	record.side = next_side
	StickMarker.set_side(unit, next_side)
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
	-- One settings read for the whole pass: switching "teammates' marks" off has
	-- to take the skeletons that are already on screen with it, not wait for
	-- the affected enemy to be re-tagged.
	local keep_others = others_enabled()
	local keep_keystone = keystone_enabled()

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
		else
			pcall(refresh_side, unit)

			local record = live[unit]

			if record then
				if record.side == "other" and not keep_others then
					drop_unit(event_manager, unit)
				elseif record.side == "keystone" and not keep_keystone then
					drop_unit(event_manager, unit)
				end
			end
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
				if is_target(unit, mark_name) then
					local side = side_of(mark_name, unit, nil)
					local wanted = side == "own"
						or (side == "other" and others_enabled())
						or (side == "keystone" and keystone_enabled())

					if wanted then
						local record = { name = mark_name, side = side }

						-- Recorded before the trigger: the engine may create the
						-- marker and answer synchronously, and a re-entrant scan
						-- must not add the same unit twice.
						live[unit] = record
						StickMarker.set_side(unit, side)

						-- The engine hands back the new marker's id here. That id
						-- is the only handle `remove_world_marker` accepts; if the
						-- callback ever comes late, the sweep finds it by unit.
						pcall(event_manager.trigger, event_manager, "add_world_marker_unit", TEMPLATE, unit, function(marker_id)
							record.id = marker_id
						end)
					elseif side == "other" then
						other_hidden = other_hidden + 1
					else
						keystone_hidden = keystone_hidden + 1
					end
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

-- ---------------------------------------------------------------------------
-- Performance accounting
-- ---------------------------------------------------------------------------
-- The marker module counts; this file decides when a session starts and ends
-- and where the report goes. It goes BOTH to chat and to the DMF log, because
-- the log line is what survives an alt-F4, a crash or simply closing the game
-- before anyone takes a screenshot.

-- true / false / nil. nil is "cannot tell right now" -- loading, or no game mode
-- yet. That distinction matters: reading nil as "left the mission" would end the
-- session and reset the counters on every loading screen.
local function mission_state()
	local gm = Managers.state and Managers.state.game_mode

	if not gm then
		return nil
	end

	local ok, name = pcall(gm.game_mode_name, gm)

	if not ok or type(name) ~= "string" then
		return nil
	end

	return name ~= "hub"
end

local function print_perf(final)
	local lines = StickMarker.perf_report()

	-- mod.info is the log channel; a DMF build without it must not turn a
	-- diagnostic into a per-frame error.
	local log = mod.info and function(line) mod:info(line) end or nil

	for i = 1, #lines do
		if log then
			log(lines[i])
		end

		if final then
			mod:echo(lines[i])
		end
	end

	-- A periodic report is a snapshot of the session so far, not its end.
	-- Resetting here is what made every two-minute window cover only the last
	-- two minutes: the final line never described the whole match.
	if final then
		StickMarker.perf_reset()
	end
end

local function perf_frame(dt)
	local count = 0

	for _ in pairs(live) do
		count = count + 1
	end

	local due = StickMarker.perf_tick(dt, count, mission_state())

	if due then
		print_perf(due == "final")
	end
end

local function update_body(dt)
	if not mod:get("stick_enabled") then
		-- The master switch owns the skeletons too. Without this the markers
		-- stayed up, frozen on their last frame, and the switch looked dead.
		if running then
			running = false
			pcall(drop_all)
		end

		return
	end

	running = true

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

-- DMF has called this both as mod.update(dt) and mod:update(dt) depending on
-- version. Accept either shape instead of guessing.
function mod.update(a, b)
	local dt = type(a) == "number" and a or b

	if type(dt) ~= "number" then
		dt = 0
	end

	-- Accounting runs before the early returns inside update_body: comparing
	-- "mod on" against "mod off" within one session is the whole point, so a
	-- switched-off mod still has to report its frames.
	perf_frame(dt)

	if StickMarker.perf_started() then
		local t0 = StickMarker.clock_ms()

		update_body(dt)
		StickMarker.perf_scan(StickMarker.clock_ms() - t0)
	else
		update_body(dt)
	end
end

mod.on_enabled = function()
	accum = 0
end

mod.on_disabled = function()
	drop_all()

	registered = false
	cached_wm = nil
	running = false
	error_count = 0
	skipped = 0
	no_breed = 0
	dropped = 0
	other_hidden = 0
	keystone_hidden = 0
end

mod.on_game_state_changed = function(status, state_name)
	if status == "enter" then
		live = {}
		registered = false
		cached_wm = nil
		running = false
		skipped = 0
		no_breed = 0
		dropped = 0
		other_hidden = 0
	keystone_hidden = 0
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
	local own_count, other_count, keystone_count = 0, 0, 0

	for _, record in pairs(live) do
		live_count = live_count + 1

		if record.side == "other" then
			other_count = other_count + 1
		elseif record.side == "keystone" then
			keystone_count = keystone_count + 1
		else
			own_count = own_count + 1
		end

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

	mod:echo(string.format(
		"owners: mine=%d theirs=%d keystone=%d hidden=%d/%d",
		own_count,
		other_count,
		keystone_count,
		other_hidden,
		keystone_hidden
	))

	mod:echo("layers: " .. (#names > 0 and table.concat(names, ", ") or "none"))
end)

-- The glow knob, as the last drawn frame saw it. Two chat lines, because
-- "the neon strength does nothing" splits into two causes that look identical
-- on screen: a zero computed here, or an engine that ignores a non-zero.
mod:command("stick_glow", "MarkedStick: print the glow numbers of the last drawn frame", function()
	local last = StickMarker.last

	if not last or not last.glow then
		mod:echo("glow: nothing drawn yet -- mark an elite or special, then run this again")
		return
	end

	local pads = last.pads

	mod:echo(string.format(
		"glow: setting=%d ratio=%.3f core=%.2f bead=%.2f lift=%.2f own=%s dist=%s",
		math.floor(last.glow * 100 + 0.5),
		last.ratio,
		last.core,
		last.bead,
		last.gain,
		tostring(last.own),
		last.dist and string.format("%.1f", last.dist) or "?"
	))

	mod:echo(string.format(
		"bands: out=%s mid=%s inn=%s",
		pads and string.format("%.2f", pads.out) or "off",
		pads and string.format("%.2f", pads.mid) or "off",
		pads and string.format("%.2f", pads.inn) or "off"
	))
end)

-- The numbers behind "this build costs frames". Printed on demand, and also
-- written to the log automatically every two minutes and once when you get back
-- to the hub, so a session does not have to end politely to be measurable.
-- Deliberately does NOT reset: typing it mid-mission must not throw the data
-- away. A new session starts by itself when the next mission begins.
mod:command("stick_perf", "MarkedStick: print the frame-time statistics", function()
	local lines = StickMarker.perf_report()

	for i = 1, #lines do
		mod:echo(lines[i])
		mod:info(lines[i])
	end
end)

-- Attribution, as the game reports it. `my_tags` is the number of tag ids the
-- engine says this player owns; a mark whose id is not in that list belongs to
-- somebody else, and that is the whole rule. One line here settles "my marks
-- are painted a teammate's colour" without guessing.
mod:command("stick_own", "MarkedStick: print how the marks were attributed", function()
	local player = local_player()
	local system = smart_tag_system()
	local my_unit = player and player.player_unit
	local ids = my_unit and owned_tag_ids(system, my_unit)

	mod:echo(string.format(
		"owner: player=%s unit=%s my_tags=%s",
		player and "yes" or "NO",
		my_unit and tostring(my_unit) or "none",
		ids and tostring(#ids) or "?"
	))

	local shown = 0

	for unit, record in pairs(live) do
		if shown < 4 then
			shown = shown + 1

			local tag_id = nil

			if system then
				local ok, id = pcall(system.unit_tag_id, system, unit)

				tag_id = ok and id or nil
			end

			mod:echo(string.format(
				"  %s -> %s (tag=%s, mark=%s)",
				tostring(unit),
				string.upper(record.side or "own"),
				tostring(tag_id),
				tostring(record.name)
			))
		end
	end
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

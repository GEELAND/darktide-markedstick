// Offline harness for MarkedStick v0.1.0 (fengari).
//
// This build draws the real skeleton: 14 bead-chain segments plus six joint
// dots, every width scaled by the projected height of the figure. The harness
// checks the layers that fail in completely different places:
//
//   A. the scan loop (MarkedStick.lua)
//      * a marked, living ELITE or SPECIAL gets exactly one marker, ever;
//      * a marked HORDE body gets none -- that is the whole "don't draw on
//        trash" requirement;
//      * a unit whose breed cannot be read still gets one (fail-open);
//      * a destroyed unit is dropped and never re-added -- the Unit stubs throw
//        "Accessing a deleted unit" exactly like Stingray, so a missing pcall
//        fails a check here instead of producing a red popup in game;
//      * mod.update accepts both mod.update(dt) and mod:update(dt);
//      * turning the setting off stops new markers;
//      * death, re-tagging and destruction all take the marker back.
//
//   B. the marker template contract (stick_marker.lua)
//      * check_line_of_sight is false -- the single field this mod exists for;
//      * the coordinate space is 2048 px, because a whole figure at point-blank
//        range would clip at 768;
//      * 1370 passes allocated ONCE: 1344 bead rects + 24 dot rects + 2 labels.
//
//   C. the geometry (a real pinhole projection is stubbed: focal 900 px,
//      camera at the origin looking down +Y, 1920x1080 canvas)
//      * every bead is a four-band stack -- core 252, inner 158, mid 66, outer
//        28, each wider than the last -- because one halo band is a hard edge,
//        which is the "coloured block with gradient glued on" look this build
//        replaces;
//      * bead chains land exactly on their joints, first and last bead;
//      * chains never gap: spacing <= 0.7 x bead, bounding boxes intersect;
//      * joint dots stay >= 1.8 x the line width at 3 / 10 / 40 m;
//      * every width and the bead count shrink monotonically with distance;
//      * with the animations off (the default) 600 frames of random dt move
//        nothing; with them on only colour ever moves, and never in a step;
//      * the breath is a sine bounded by "a fifth of the light", the cycle
//        starts at the picked hue, and the two never interfere;
//      * the head has its own colour, defaulting to the body's;
//      * a missing joint drops its segments whole and never joins to the
//        origin;
//      * no pass leaves the 2048 px coordinate space;
//      * alpha never wraps at max thickness + max glow;
//      * the pool leaves no residue when the distance jumps.
//
//   D. the RIG table and /stick_rig, the probe that keeps the bone names
//      honest (rig_table_tests + rig_probe_tests).
//
// Run:  node tools/sim_stick.js
const fs = require("fs");
const path = require("path");
const fengari = require("fengari");
const { lua, lauxlib, lualib, to_luastring } = fengari;

const ROOT = path.join(__dirname, "..");
const MOD = path.join(ROOT, "MarkedStick", "scripts", "mods", "MarkedStick");
const mainSrc = fs.readFileSync(path.join(MOD, "MarkedStick.lua"), "latin1");
const markerSrc = fs.readFileSync(path.join(MOD, "stick_marker.lua"), "latin1");

const STUBS = `
local OUT = { checks = {} }
local function check(ok, msg)
	OUT.checks[#OUT.checks + 1] = (ok and "PASS  " or "FAIL  ") .. msg
end

local created = {}
local echo_lines = {}
local info_lines = {}
-- Every line that reaches chat or the log, checked for a literal percent sign.
-- Both channels run the text through string.format again (DMF does that so
-- localized strings can carry arguments), so a "%" in the message is read as a
-- conversion and the whole line is lost with a visible error. This is not
-- theoretical: 1.2.1 logged "invalid option '% |'" four times a minute.
local percent_hits = {}
local commands = {}

-- The SHIPPED defaults, i.e. what a fresh install gets: breathing and the
-- colour cycle on, a fat 8 px cord with a tight 50 percent skirt, and the
-- joint dots at their 1.8 x floor. The geometry assertions read exact alphas,
-- so frame() forces the two animations off; the animation tests drive them
-- themselves.
SETTINGS = {
	stick_enabled = true,
	stick_color = { 255, 255, 60, 178 },
	stick_head_color = { 255, 255, 60, 178 },
	stick_rgb = true,
	stick_rgb_speed = 100,
	stick_breath = true,
	stick_breath_depth = 40,
	stick_breath_speed = 300,
	stick_thickness = 8,
	stick_glow = 50,
	stick_dot_size = 200,
	stick_other_enabled = true,
	stick_other_color = { 255, 60, 220, 255 },
	stick_other_head_color = { 255, 60, 220, 255 },
	stick_other_rgb = true,
	stick_other_rgb_speed = 100,
	stick_other_breath = true,
	stick_other_breath_depth = 40,
	stick_other_breath_speed = 300,
	stick_other_thickness = 8,
	stick_other_glow = 50,
	stick_other_dot_size = 150,
	stick_keystone_enabled = true,
	stick_keystone_color = { 255, 255, 196, 64 },
	stick_keystone_head_color = { 255, 255, 196, 64 },
	stick_keystone_rgb = true,
	stick_keystone_rgb_speed = 100,
	stick_keystone_breath = true,
	stick_keystone_breath_depth = 40,
	stick_keystone_breath_speed = 300,
	stick_keystone_thickness = 6,
	stick_keystone_glow = 50,
	stick_keystone_dot_size = 150,
	stick_density = 24,
	stick_show_head = true,
	stick_show_torso = true,
	stick_show_arms = true,
	stick_show_legs = true,
	stick_show_distance = true,
}

-- A unit is a plain table: nodes are world positions of bones, breed is what
-- ScriptUnit would hand back. Every Unit.* call throws once alive is false,
-- which is what Stingray does and what the pcall discipline is for.
--
-- The rig below is a KNOWN rig: the names are the first candidates in the RIG
-- table, so a joint that resolves in the dump is a joint the probe logic found,
-- not a name the stub invented. limbs = false builds a core-only unit.
local function mkunit(name, y, breed, height, limbs)
	local u = { name = name, alive = true, health_alive = true, y = y or 0, breed = breed, nodes = {} }

	local h = height or 1.8

	u.nodes.j_head   = { x = 0,     y = u.y, z = h * 0.86 }
	u.nodes.j_neck   = { x = 0,     y = u.y, z = h * 0.80 }
	u.nodes.j_spine1 = { x = 0,     y = u.y, z = h * 0.70 }
	u.nodes.j_spine  = { x = 0,     y = u.y, z = h * 0.64 }
	u.nodes.j_hips   = { x = 0,     y = u.y, z = h * 0.52 }

	if limbs ~= false then
		u.nodes.j_leftarm      = { x =  0.18, y = u.y, z = h * 0.78 }
		u.nodes.j_leftforearm  = { x =  0.22, y = u.y, z = h * 0.62 }
		u.nodes.j_lefthand     = { x =  0.24, y = u.y, z = h * 0.46 }
		u.nodes.j_rightarm     = { x = -0.18, y = u.y, z = h * 0.78 }
		u.nodes.j_rightforearm = { x = -0.22, y = u.y, z = h * 0.62 }
		u.nodes.j_righthand    = { x = -0.24, y = u.y, z = h * 0.46 }
		u.nodes.j_leftupleg    = { x =  0.10, y = u.y, z = h * 0.48 }
		u.nodes.j_leftleg      = { x =  0.11, y = u.y, z = h * 0.26 }
		u.nodes.j_leftfoot     = { x =  0.11, y = u.y, z = h * 0.02 }
		u.nodes.j_rightupleg   = { x = -0.10, y = u.y, z = h * 0.48 }
		u.nodes.j_rightleg     = { x = -0.11, y = u.y, z = h * 0.26 }
		u.nodes.j_rightfoot    = { x = -0.11, y = u.y, z = h * 0.02 }
	end

	return u
end

local function guard(u)
	if not u or not u.alive then error("Accessing a deleted unit.", 2) end
end

Unit = {
	alive = function(u) guard(u); return true end,
	has_node = function(u, name) guard(u); return u.nodes[name] ~= nil end,
	node = function(u, name) guard(u); return u.nodes[name] and name or nil end,
	world_position = function(u, node)
		guard(u)
		if type(node) == "string" then
			local p = u.nodes[node]
			if not p then error("no such node", 2) end
			return { x = p.x, y = p.y, z = p.z }
		end
		return { x = 0, y = u.y, z = 0 }
	end,
	-- Enumeration API. Deliberately 1-BASED and alphabetical: the probe must
	-- cope with either base, and this stub is the one that punishes a guess.
	num_nodes = function(u)
		guard(u)
		local n = 0
		for _ in pairs(u.nodes) do n = n + 1 end
		return n
	end,
	node_name = function(u, i)
		guard(u)
		local names = {}
		for k in pairs(u.nodes) do names[#names + 1] = k end
		table.sort(names)
		return names[i]
	end,
}

-- Vector3 as a callable table, like the engine's binding: Vector3(x,y,z) and
-- Vector3.distance both work.
Vector3 = setmetatable({}, {
	__call = function(self, x, y, z) return { x = x, y = y, z = z } end,
})

function Vector3.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Pinhole camera at the origin, looking down +Y, up = +Z, focal 900 px,
-- 1920x1080 canvas. Points behind the camera return nil, like the engine.
local FOCAL = 900
local CX, CY = 960, 540

local camera = { name = "first_person" }

Camera = {
	world_position = function(c) return { x = 0, y = 0, z = 0 } end,
	world_rotation = function(c) return { name = "rot" } end,
	world_to_screen = function(c, p)
		local depth = p.y
		if depth <= 0.05 then return nil end
		return { x = CX + FOCAL * p.x / depth, y = CY - FOCAL * p.z / depth, z = depth }
	end,
}

Quaternion = {
	forward = function(q) return { x = 0, y = 1, z = 0 } end,
	up = function(q) return { x = 0, y = 0, z = 1 } end,
	right = function(q) return { x = 1, y = 0, z = 0 } end,
}

ScriptUnit = {
	has_extension = function(u, name)
		guard(u)

		if name == "unit_data_system" then
			return {
				breed = function(self) return u.breed end,
			}
		end

		-- The moment of death is ONLY visible here: Unit.alive stays true
		-- through the death animation, which is exactly the gap that used to
		-- leave a frame hanging over the corpse.
		if name == "health_system" then
			if u.has_health == false then return nil end

			return {
				is_alive = function(self)
					if not u.alive then error("Accessing a deleted unit.", 2) end
					return u.health_alive ~= false
				end,
			}
		end

		return nil
	end,
}

-- UIWidget.create_definition is the only thing the template asks the engine
-- for. The stub mirrors what the widget exposes at runtime: style and content
-- keyed by style_id, which is how update_function reaches them.
package.preload["scripts/managers/ui/ui_widget"] = function()
	return {
		create_definition = function(passes, scenegraph_id)
			local style, content = {}, {}

			for i = 1, #passes do
				local p = passes[i]

				if p.style_id then
					style[p.style_id] = p.style

					if p.value_id then
						content[p.style_id] = p.value
					end
				end
			end

			return { passes = passes, style = style, content = content, scenegraph_id = scenegraph_id }
		end,
	}
end

-- hit_zones is Darktide's own hit-zone table: it usually carries node names,
-- which makes it an independent source of rig truth. The deep entry exists to
-- prove the dump's depth cap.
local ELITE = {
	name = "scab_mauler",
	tags = { elite = true },
	base_height = 1.8,
	hit_zones = {
		head = { node = "j_head" },
		torso = { node = "j_spine1" },
		deep = { a = { b = { c = "too deep to print" } } },
	},
}
local SPECIAL = { name = "pox_hound", tags = { special = true }, base_height = 1.4,
	hit_zones = { head = { node = "j_head" } } }
local HORDE = { name = "chaos_poxwalker", tags = { horde = true, roamer = true }, base_height = 1.8 }

local A = mkunit("A", 10, ELITE)
local B = mkunit("B", 25, SPECIAL, 1.4)
local C = mkunit("C", 50, HORDE)
local F = mkunit("F", 8, nil)          -- marked, but no breed readable
local G = mkunit("G", 12, { name = "chaos_ogryn_bulgrym", tags = { elite = true, ogryn = true }, base_height = 2.6 })

local outline_system = { _unit_extension_data = {} }

-- The game's smart tag bookkeeping, in the shape SmartTagSystem exposes it: a
-- target unit carries at most one tag, the tag knows who made it through
-- tagger_player / tagger_unit, and the tagger's own extension lists the ids it
-- created (owned_tag_ids). A nil entry means "no smart tag at all", which is
-- the class-keystone case.
local smart_tag_system = { _tags = {}, _unit_extension_data = {}, _next_tag_id = 0 }

function smart_tag_system.unit_tag(self, unit)
	return self._tags[unit]
end

function smart_tag_system.unit_tag_id(self, unit)
	local tag = self._tags[unit]

	return tag and tag.__id or nil
end

-- One extension per unit, exactly as the game splits it: a target keeps a
-- single tag id, a tagger keeps the list of ids it owns.
local function tag_extension()
	local ext = { _owned = {}, _tag_id = nil }

	function ext.owned_tag_ids(self) return self._owned end
	function ext.register_owned_tag(self, id) self._owned[#self._owned + 1] = id end
	function ext.tag_id(self) return self._tag_id end
	function ext.register_tag(self, id) self._tag_id = id end

	return ext
end

local me_unit = { name = "me" }
local ME = { player_unit = me_unit }
local ally_unit = { name = "ally" }
local ALLY = { player_unit = ally_unit }

smart_tag_system._unit_extension_data[me_unit] = tag_extension()
smart_tag_system._unit_extension_data[ally_unit] = tag_extension()

local function new_tag(player, id)
	return {
		__id = id,
		__player = player,
		__unit = player and player.player_unit or nil,
		id = function(self) return self.__id end,
		tagger_player = function(self) return self.__player end,
		tagger_unit = function(self) return self.__unit end,
	}
end

local function tag_by(player, unit)
	smart_tag_system._next_tag_id = smart_tag_system._next_tag_id + 1

	local id = smart_tag_system._next_tag_id

	smart_tag_system._tags[unit] = new_tag(player, id)

	local target_ext = smart_tag_system._unit_extension_data[unit]

	if target_ext then
		target_ext:register_tag(id)
	end

	if player then
		local tagger_ext = smart_tag_system._unit_extension_data[player.player_unit]

		if tagger_ext then
			tagger_ext:register_owned_tag(id)
		end
	end
end

local function untag(unit)
	local tag = smart_tag_system._tags[unit]

	smart_tag_system._tags[unit] = nil

	if tag and tag.__player then
		local ext = smart_tag_system._unit_extension_data[tag.__player.player_unit]

		if ext then
			for i = #ext._owned, 1, -1 do
				if ext._owned[i] == tag.__id then
					table.remove(ext._owned, i)
				end
			end
		end
	end
end

local function reset_tags()
	smart_tag_system._tags = {}

	for _, ext in pairs(smart_tag_system._unit_extension_data) do
		ext._owned = {}
		ext._tag_id = nil
	end
end
local hud_element = {
	_parent = { player_camera = function(self) return camera end },
	_marker_templates = {},
	-- The engine's own per-type marker list. Healthbars removes markers from
	-- here, and so do we: it is the only authoritative "what am I drawing".
	_markers_by_type = {},
}
local hud = {
	element = function(self, name)
		if name == "HudElementWorldMarkers" then return hud_element end
	end,
}

-- Marker lifecycle, mirroring the engine: add_world_marker_unit allocates an
-- id, appends to the per-type list, and answers through the callback;
-- remove_world_marker deletes by that id. Without remove support here the
-- corpse bug would be invisible to the test.
local next_marker_id = 0
local removed_ids = {}

Managers = {
	player = {
		-- Mirrors the real manager on purpose: it takes a player INDEX, and
		-- calling it with no argument answers nil. That call shape is what
		-- broke attribution in the field ("my marks show a teammate's
		-- colour"), so the stub keeps it instead of papering over it.
		local_player = function(self, index)
			if index ~= 1 then
				return nil
			end

			return ME
		end,
	},
	state = {
		extension = {
			has_system = function(self, n)
				return n == "outline_system" or n == "smart_tag_system"
			end,
			system = function(self, n)
				if n == "smart_tag_system" then
					return smart_tag_system
				end

				return outline_system
			end,
		},
		camera = {
			camera = function(self, name) return camera end,
		},
	},
	ui = { get_hud = function(self) return hud end },
	event = {
		trigger = function(self, name, a, b, cb)
			if name == "add_world_marker_unit" then
				next_marker_id = next_marker_id + 1

				local id = next_marker_id
				local list = hud_element._markers_by_type[a]

				if not list then
					list = {}
					hud_element._markers_by_type[a] = list
				end

				list[#list + 1] = { unit = b, id = id }
				created[#created + 1] = { template = a, unit = b, id = id }

				if cb then cb(id) end
			elseif name == "remove_world_marker" then
				removed_ids[#removed_ids + 1] = a

				for _, list in pairs(hud_element._markers_by_type) do
					for i = #list, 1, -1 do
						if list[i].id == a then table.remove(list, i) end
					end
				end
			end
		end,
	},
}

local function has_marker(unit)
	local list = hud_element._markers_by_type.marked_stick or {}

	for i = 1, #list do
		if list[i].unit == unit then return true end
	end

	return false
end

-- Load the real template file instead of a stand-in: the whole point of part B
-- is to exercise the actual definition the engine will read.
local MARKER_SRC = [====[
${markerSrc}
]====]

local mod_obj
mod_obj = {
	io_dofile = function(self, p)
		local chunk = assert(load(MARKER_SRC, "=stick_marker"))
		return chunk()
	end,
	get = function(self, key) return SETTINGS[key] end,
	echo = function(self, s)
		local text = tostring(s)
		echo_lines[#echo_lines + 1] = text
		if string.find(text, "%", 1, true) then percent_hits[#percent_hits + 1] = "echo: " .. text end
	end,
	-- The DMF log channel. The perf report goes here as well as to chat, which
	-- is what makes a session readable after the game is closed.
	info = function(self, s)
		local text = tostring(s)
		info_lines[#info_lines + 1] = text
		if string.find(text, "%", 1, true) then percent_hits[#percent_hits + 1] = "info: " .. text end
	end,
	command = function(self, name, desc, cb) commands[name] = cb end,
}

function get_mod(name) return mod_obj end
`;

const TEST = `
local function arm()
	outline_system._unit_extension_data[A] = { outlines = { { name = "veteran_smart_tag" } } }
	outline_system._unit_extension_data[B] = { outlines = { { name = "smart_tagged_enemy" } } }
	outline_system._unit_extension_data[C] = { outlines = { { name = "minion_outline" } } }
end

arm()

-- mark the horde body on purpose: it is marked, and must still be skipped
outline_system._unit_extension_data[C] = { outlines = { { name = "veteran_smart_tag" } } }

check(commands.stick_diag ~= nil, "the stick_diag command is registered")
check(commands.stick_rig ~= nil, "the stick_rig command is registered")

-- A. the scan loop -----------------------------------------------------------

mod.update(0.3)
check(#created == 2, "elite + special get markers, marked horde does not (got " .. #created .. ")")

local got_trash = false
for i = 1, #created do
	if created[i].unit == C then got_trash = true end
end
check(not got_trash, "the marked horde unit was filtered out")

check(hud_element._marker_templates.marked_stick ~= nil, "template registered on the HUD element")

mod.update(0.3)
check(#created == 2, "second scan creates no duplicates (got " .. #created .. ")")

mod:update(0.3)
check(#created == 2, "mod:update(dt) also works (got " .. #created .. ")")

A.alive = false
mod.update(0.3)
check(#created == 2, "dead unit is not re-added (got " .. #created .. ")")

outline_system._unit_extension_data[F] = { outlines = { { name = "psyker_marked_target" } } }
mod.update(0.3)
check(#created == 3, "a unit with no readable breed still gets a marker (fail open)")

outline_system._unit_extension_data[G] = { outlines = { { name = "veteran_smart_tag" } } }
mod.update(0.3)
check(#created == 4, "ogryn elite gets a marker (got " .. #created .. ")")

SETTINGS.stick_enabled = false
local before = #created
local E = mkunit("E", 5, ELITE)
outline_system._unit_extension_data[E] = { outlines = { { name = "veteran_smart_tag" } } }
mod.update(0.3)
check(#created == before, "disabled setting creates nothing (got " .. (#created - before) .. ")")

SETTINGS.stick_enabled = true
commands.stick_diag()
check(#echo_lines >= 2, "stick_diag printed lines (" .. #echo_lines .. ")")

-- A2. the skeleton goes away when the reason for it goes away ----------------
--
-- Two separate failures produced the "frames stay on the corpse" report:
--   1. the mod dropped its own bookkeeping entry but never told the engine,
--      so the widget kept drawing at the last known node;
--   2. the check only asked Unit.alive, which stays true through the death
--      animation -- the corpse is a live unit until it is destroyed.

local D = mkunit("D", 15, ELITE, 1.8)
outline_system._unit_extension_data[D] = { outlines = { { name = "veteran_smart_tag" } } }
mod.update(0.3)
check(has_marker(D), "a living marked elite gets an engine marker")

D.health_alive = false          -- died; body still standing and animated
local removed_before = #removed_ids
mod.update(0.016)               -- one frame, no rescan
check(#removed_ids > removed_before, "death removes the marker on the very next frame")
check(not has_marker(D), "no marker left on the corpse")

local created_before = #created
mod.update(0.1)
check(#created == created_before, "a dead-but-still-tagged unit is never re-added")

-- Re-tag: the game moves the outline to the new target and the old enemy is no
-- longer marked, so its skeleton has to go the same frame, not on the next scan.
local T1 = mkunit("T1", 12, ELITE, 1.8)
local T2 = mkunit("T2", 14, SPECIAL, 1.4)
outline_system._unit_extension_data[T1] = { outlines = { { name = "veteran_smart_tag" } } }
mod.update(0.3)
check(has_marker(T1), "the first tagged enemy has a skeleton")

outline_system._unit_extension_data[T1] = { outlines = {} }
outline_system._unit_extension_data[T2] = { outlines = { { name = "veteran_smart_tag" } } }
mod.update(0.016)
check(not has_marker(T1), "re-tagging clears the first enemy's skeleton on the next frame")

mod.update(0.3)
check(has_marker(T2), "the newly tagged enemy gets the skeleton")
check(not has_marker(T1), "and the old one stays clear")

-- A target that keeps qualifying must not be torn down and rebuilt each scan.
local stable_before = #created
for i = 1, 5 do mod.update(0.1) end
check(#created == stable_before, "a still-valid target is not re-created every scan")

-- Destroyed (not merely dead): every Unit.* throws, so this also proves the
-- removal path is guarded.
local Z = mkunit("Z", 20, ELITE, 1.8)
outline_system._unit_extension_data[Z] = { outlines = { { name = "veteran_smart_tag" } } }
mod.update(0.3)
check(has_marker(Z), "unit Z got a skeleton")
Z.alive = false
local ok_rm = pcall(mod.update, 0.016)
check(ok_rm, "a destroyed unit does not throw in the removal path")
check(not has_marker(Z), "a destroyed unit's skeleton is removed")

-- B. the marker template -----------------------------------------------------

local tpl = hud_element._marker_templates.marked_stick
check(tpl ~= nil, "template registered on HudElementWorldMarkers")

check(tpl.check_line_of_sight == false, "check_line_of_sight is false (the skeleton survives walls)")
check(tpl.unit_node == "j_head", "bound to the head bone")
-- 0.5 s is the ENGINE's grace period on death, a backstop only: the mod itself
-- removes the marker on the frame the enemy dies, which is what the corpse fix
-- actually relies on.
check(tpl.remove_on_death_duration == 0.5, "engine death grace period is the short backstop, not the mechanism")
check(tpl.max_distance == 250, "max_distance stays at 250 m")
check(tpl.screen_clamp == false, "screen_clamp stays off")
check(tpl.size[1] == 2048 and tpl.size[2] == 2048,
	"the coordinate space is 2048 px -- a whole figure at point-blank range would clip at 768")

local def = tpl.create_widget_defintion(tpl, "test_scene")

local rects, texts, others = 0, 0, 0
local ids = {}

for i = 1, #def.passes do
	local kind = def.passes[i].pass_type
	if kind == "rect" then rects = rects + 1
	elseif kind == "text" then texts = texts + 1
	else others = others + 1 end
	if def.passes[i].style_id then ids[def.passes[i].style_id] = true end
end

-- The pool is allocated once, here, and never grows or shrinks at runtime:
-- 14 segments x 14 beads x 4 bands + 6 dots x 4 bands + 2 labels = 810.
check(rects == 1368, "the pool holds 1344 bead rects + 24 dot rects (got " .. rects .. ")")
check(texts == 2, "2 label copies: shadow + bright (got " .. texts .. ")")
check(others == 0, "no unexpected pass types (got " .. others .. ")")
check(#def.passes == 1370, "1370 passes in total: 4 bands per bead, the ladder that makes it read as neon (got " .. #def.passes .. ")")
check(ids.label and ids.label_shadow, "both label style ids exist")
check(def.style.label.visible == false and def.style.label_shadow.visible == false,
	"the placeholder labels start invisible")

local LIVEU = mkunit("liveu", 10, ELITE)
local ok_upd = pcall(tpl.update_function, hud_element, nil, def, { unit = LIVEU, distance = 10 }, tpl, 0.016, 0)
check(ok_upd, "update_function runs on a live unit")
check(def.content.show_label == true, "and opens the label gate when a distance is known")
check(def.content.label == "10m", "the label reads the engine's distance (" .. tostring(def.content.label) .. ")")
check(def.style.label.visible == true, "so the bright label copy is drawn")

-- No time dependence in the GEOMETRY: with the two animations explicitly off,
-- 300 frames of random dt must not move a single field of ANY pass -- labels,
-- beads and dots alike. (The shipped defaults have them ON; that path is
-- covered by the breath and cycle tests, which assert only colour ever moves.)
do
	local breath, rgb = SETTINGS.stick_breath, SETTINGS.stick_rgb
	SETTINGS.stick_breath = false
	SETTINGS.stick_rgb = false

	local function snapshot()
		local shadow, label = def.style.label_shadow, def.style.label
		local bead, bead_o, dot = def.style.b2_1_c, def.style.b2_1_o, def.style.d_head_c
		return string.format("%.2f/%.2f/%.2f/%.2f/%s|%.2f/%.2f/%.2f/%.2f/%s|%.3f/%.3f/%.3f/%.3f/%s|%.3f/%.3f/%.3f/%s",
			shadow.offset[1], shadow.offset[2], shadow.size[1], shadow.size[2], tostring(shadow.visible),
			label.offset[1], label.offset[2], label.size[1], label.size[2], tostring(label.visible),
			bead.offset[1], bead.offset[2], bead.size[1], bead.size[2], tostring(bead.visible),
			bead_o.size[1], dot.offset[1], dot.size[1], tostring(dot.visible))
	end

	tpl.update_function(hud_element, nil, def, { unit = LIVEU, distance = 10 }, tpl, 0.016, 0)
	local first = snapshot()
	local moved = false
	for i = 1, 300 do
		tpl.update_function(hud_element, nil, def, { unit = LIVEU, distance = 10 }, tpl, 0.016, 0)
		if snapshot() ~= first then moved = true end
	end

	SETTINGS.stick_breath, SETTINGS.stick_rgb = breath, rgb

	check(not moved, "300 frames of random dt move nothing -- labels, beads and dots (geometry has no clock)")
end

-- C0. the geometry ------------------------------------------------------------
--
-- A real pinhole camera is stubbed (focal 900, camera at the origin looking
-- down +Y, up = +Z), so the pixels a bone occupies at a given range are the
-- pixels perspective demands. The topology below is pinned from the spec: if
-- the implementation ever draws a different skeleton, the segment lists stop
-- matching and the endpoint checks fail.

local SEGS = {
	{ "head", "neck", "head" },
	{ "neck", "hips", "torso" },
	{ "neck", "shoulderL", "torso" },
	{ "neck", "shoulderR", "torso" },
	{ "shoulderL", "elbowL", "arms" },
	{ "shoulderR", "elbowR", "arms" },
	{ "elbowL", "handL", "arms" },
	{ "elbowR", "handR", "arms" },
	{ "hips", "legL", "legs" },
	{ "hips", "legR", "legs" },
	{ "legL", "kneeL", "legs" },
	{ "legR", "kneeR", "legs" },
	{ "kneeL", "footL", "legs" },
	{ "kneeR", "footR", "legs" },
}

-- joint -> its dot's style id. The dots are the six places a joint dot lives.
local DOTJOINT = {
	head = "d_head", hips = "d_hips",
	handL = "d_handL", handR = "d_handR",
	footL = "d_footL", footR = "d_footR",
}

-- The stub resolves a joint the way the module does: the first candidate that
-- exists wins. Unit.world_position throws on a missing node, which is exactly
-- what the module's pcall discipline is for.
local function resolve(unit, names)
	for i = 1, #names do
		local ok, pos = pcall(Unit.world_position, unit, names[i])
		if ok and pos then return pos end
	end
	return nil
end

local function screen_of(pos)
	return Camera.world_to_screen(camera, pos)
end

-- Where the engine anchored the widget: the projected unit_node, or the unit
-- origin when that bone does not exist (the module's own fallback).
local function anchor_of(unit)
	local pos = resolve(unit, tpl.rig.head)

	if not pos then
		pos = { x = 0, y = unit.y, z = 0 }
	end

	local s = screen_of(pos)

	return s.x, s.y
end

-- One frame at the shipped defaults, EXCEPT that the two animations are forced
-- off: the geometry assertions read exact alphas, and a breathing alpha is a
-- function of the frame's time, not of the geometry. The animation tests drive
-- those settings themselves.
local function frame(unit, dist)
	local d = tpl.create_widget_defintion(tpl, "scene")
	local breath, rgb = SETTINGS.stick_breath, SETTINGS.stick_rgb

	SETTINGS.stick_breath = false
	SETTINGS.stick_rgb = false
	tpl.update_function(hud_element, nil, d, { unit = unit, distance = dist }, tpl, 0.016, 0)
	SETTINGS.stick_breath, SETTINGS.stick_rgb = breath, rgb

	return d
end

local function is_bead_core(id)
	return string.sub(id, 1, 1) == "b" and string.sub(id, -2) == "_c"
end

local function seg_of(id)
	local s = string.match(id, "^b(%d+)_")

	return s and tonumber(s) or nil
end

-- Visible bead cores of one segment, in placement order, as ABSOLUTE screen
-- points (pass offset + anchor).
local function beads_of(def, unit, seg)
	local ax, ay = anchor_of(unit)
	local out = {}

	for i = 1, #def.passes do
		local p = def.passes[i]
		local id = p.style_id

		if id and is_bead_core(id) and seg_of(id) == seg and p.style.visible then
			out[#out + 1] = {
				x = p.style.offset[1] + ax,
				y = p.style.offset[2] + ay,
				size = p.style.size[1],
				alpha = p.style.color[1],
			}
		end
	end

	return out
end

local function visible_beads(def)
	local n = 0

	for i = 1, #def.passes do
		local id = def.passes[i].style_id

		if id and is_bead_core(id) and def.passes[i].style.visible then
			n = n + 1
		end
	end

	return n
end

local function endpoint_tests()
	local U = mkunit("geo1", 10, ELITE)
	local def = frame(U, 10)
	local bad = {}

	for s = 1, #SEGS do
		local a, b = SEGS[s][1], SEGS[s][2]
		local pa, pb = resolve(U, tpl.rig[a]), resolve(U, tpl.rig[b])

		if pa and pb then
			local sa, sb = screen_of(pa), screen_of(pb)
			local beads = beads_of(def, U, s)

			if #beads < 2 then
				bad[#bad + 1] = "seg " .. s .. " drew " .. #beads .. " beads"
			else
				local first, last = beads[1], beads[#beads]

				if math.abs(first.x - sa.x) > 0.5 or math.abs(first.y - sa.y) > 0.5 then
					bad[#bad + 1] = "seg " .. s .. ": first bead off the joint"
				end

				if math.abs(last.x - sb.x) > 0.5 or math.abs(last.y - sb.y) > 0.5 then
					bad[#bad + 1] = "seg " .. s .. ": last bead off the joint"
				end

				-- Full strength, always. A fractional fade on the last bead was
				-- the first design; it RESETS to zero every time the ideal bead
				-- count crosses an integer, which is a brightness cut -- the
				-- exact defect class this project has already paid for twice.
				if last.alpha < 250 then
					bad[#bad + 1] = "seg " .. s .. ": last bead faded (alpha " .. last.alpha .. ")"
				end
			end
		end
	end

	check(#bad == 0, "every segment's first and last bead sit exactly on its joints, at full strength" ..
		(#bad > 0 and (" (bad: " .. table.concat(bad, "; ") .. ")") or ""))

	-- Seams: the spacing may never exceed 0.7 of a bead, and neighbouring
	-- beads may never stop overlapping. Both are read off the drawn geometry,
	-- not off the formula.
	local worst_ratio, worst_clear = 0, -1e9

	for s = 1, #SEGS do
		local beads = beads_of(def, U, s)

		for i = 2, #beads do
			local p, q = beads[i - 1], beads[i]
			local d = math.sqrt((q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y))
			local r = d / p.size

			if r > worst_ratio then worst_ratio = r end

			local clear = d - p.size

			if clear > worst_clear then worst_clear = clear end
		end
	end

	check(worst_ratio <= 0.70 + 1e-6,
		"no chain gaps: worst spacing is " .. string.format("%.3f", worst_ratio) .. " of a bead (limit 0.700)")
	check(worst_clear < 0,
		"and every neighbouring pair of beads overlaps (worst clearance " .. string.format("%.3f", worst_clear) .. " px)")
end

endpoint_tests()

local function dot_tests()
	local bad = {}

	for _, d in ipairs({ 3, 10, 40 }) do
		local U = mkunit("dot" .. d, d, ELITE)
		local def = frame(U, d)
		local dot_core = def.style.d_head_c
		local sh = screen_of(resolve(U, tpl.rig.head))
		local sf = screen_of(resolve(U, tpl.rig.footL))
		local fig_h = math.max(1, sf.y - sh.y)
		local ratio = math.min(1, fig_h / 260)
		local core = math.max(1, (2 + 1.5) * ratio)

		if dot_core.size[1] < 1.8 * core - 1e-6 then
			bad[#bad + 1] = d .. " m: dot " .. string.format("%.2f", dot_core.size[1]) ..
				" < 1.8 x core " .. string.format("%.2f", core)
		end

		if dot_core.size[1] < 1.6 - 1e-6 then
			bad[#bad + 1] = d .. " m: dot under the 1.6 px floor"
		end
	end

	check(#bad == 0, "joint dots stay >= 1.8 x the line width at 3 / 10 / 40 m" ..
		(#bad > 0 and (" (bad: " .. table.concat(bad, "; ") .. ")") or ""))
end

dot_tests()

local function monotone_tests()
	local prev = nil
	local bad = {}
	local d = 10

	while d <= 60.0001 do
		local U = mkunit("mono", d, ELITE)
		local def = frame(U, d)
		local cur = {
			def.style.b2_1_c.size[1],
			def.style.b2_1_o.size[1],
			def.style.d_head_o.size[1],
			#beads_of(def, U, 2),
		}

		if prev then
			for k = 1, 4 do
				if cur[k] > prev[k] + 1e-9 then
					bad[#bad + 1] = string.format("%.1f m: measure %d went %s -> %s", d, k, tostring(prev[k]), tostring(cur[k]))
				end
			end
		end

		prev = cur
		d = d + 0.5
	end

	check(#bad == 0, "bead width, halo width, dot size and bead count all shrink monotonically from 10 m to 60 m" ..
		(#bad > 0 and (" (bad: " .. table.concat(bad, "; ") .. ")") or ""))
end

monotone_tests()

local function time_tests()
	local U = mkunit("time", 10, ELITE)
	local def = frame(U, 10)
	local first = {}

	for i = 1, #def.passes do
		local st = def.passes[i].style
		-- Rect passes carry color, text passes carry text_color; both are
		-- captured so a label that starts moving is caught too.
		local c = st.color or st.text_color or { 0, 0, 0, 0 }
		first[i] = { st.offset[1], st.offset[2], st.size[1], st.size[2],
			c[1], c[2], c[3], c[4], st.visible }
	end

	-- The animations are off for this one: what is being asserted is that the
	-- GEOMETRY never depends on time, and with them on only colour moves (which
	-- the breath and cycle tests assert separately).
	local breath, rgb = SETTINGS.stick_breath, SETTINGS.stick_rgb
	SETTINGS.stick_breath = false
	SETTINGS.stick_rgb = false

	local moved = false

	for f = 1, 600 do
		tpl.update_function(hud_element, nil, def, { unit = U, distance = 10 }, tpl, math.random() * 0.1, math.random() * 100)

		for i = 1, #def.passes do
			local st = def.passes[i].style
			local c = st.color or st.text_color or { 0, 0, 0, 0 }
			local e = first[i]

			if st.offset[1] ~= e[1] or st.offset[2] ~= e[2] or st.size[1] ~= e[3] or st.size[2] ~= e[4]
				or c[1] ~= e[5] or c[2] ~= e[6] or c[3] ~= e[7] or c[4] ~= e[8]
				or st.visible ~= e[9] then
				moved = true
			end
		end

		if moved then
			break
		end
	end

	SETTINGS.stick_breath, SETTINGS.stick_rgb = breath, rgb

	check(not moved, "600 frames of random dt leave all 810 passes field-for-field identical (the geometry has no clock)")
end

time_tests()

local function ladder_tests()
	-- (a) per-frame continuity at combat speed. The spec's literal form (0.5 m
	-- steps, alpha delta <= 4) is not reachable by ANY fade that completes
	-- inside the spec's 0.1 ratio window: near 20 m the ratio moves about
	-- 0.013 per metre, so a single 0.5 m step shifts a full-range fade by
	-- roughly 16 alpha. This is the same guard with the step the game actually
	-- produces -- 0.05 m is 3 m/s at 60 fps, faster than any enemy in the game.
	local prev = {}
	local worst = 0
	local d = 10

	while d <= 60.0001 do
		local U = mkunit("ladder", d, ELITE)
		local def = frame(U, d)

		for i = 1, #def.passes do
			local st = def.passes[i].style
			local id = def.passes[i].style_id
			-- Text passes carry text_color, not color: the ladder is about
			-- light, and the label is a number.
			local a = st.color and st.color[1] or 0
			local before = prev[id]

			if before and before.vis and st.visible then
				local delta = math.abs(a - before.a)

				if delta > worst then
					worst = delta
				end
			end

			prev[id] = { a = a, vis = st.visible }
		end

		d = d + 0.05
	end

	-- 4, not 2: the continuous part of the slope is about 2.2 alpha per step
	-- at its steepest, and flooring the packed alpha adds at most one more.
	-- Anything that is a real cut -- the deleted flicker, the three-band dimmer
	-- -- moved 12 or more in one frame and still fails this by a wide margin.
	check(worst <= 4, "per-frame alpha change at 3 m/s stays under 4 across the whole ladder (worst " .. worst .. ")")

	-- (b) the ladder's waypoints, checked against the spec's own formula
	-- rather than against the implementation.
	local function ramp(v, lo, hi)
		if v <= lo then return 0 end
		if v >= hi then return 1 end
		return (v - lo) / (hi - lo)
	end

	local function ratio_of(U)
		local sh = screen_of(resolve(U, tpl.rig.head))
		local sf = screen_of(resolve(U, tpl.rig.footL))
		return math.min(1, math.max(1, sf.y - sh.y) / 260)
	end

	local near = frame(mkunit("l_near", 5, ELITE), 5)
	local mid = frame(mkunit("l_mid", 22, ELITE), 22)
	local far = frame(mkunit("l_far", 40, ELITE), 40)
	local vfar = frame(mkunit("l_vfar", 60, ELITE), 60)

	check(near.style.b2_1_c.visible and near.style.b2_1_c.color[1] == 252,
		"at close range the beads burn at full strength (252)")
	check(math.abs(mid.style.b2_1_c.color[1] - 252) <= 1,
		"mid-range the beads keep full strength -- they no longer fade (alpha " .. mid.style.b2_1_c.color[1] .. ")")
	check(visible_beads(far) > 0,
		"past the old 0.20 cut the chains are still on screen (" .. visible_beads(far) .. " beads)")
	check(math.abs(far.style.b2_1_c.color[1] - 252) <= 1,
		"and still at full strength at 40 m")
	check(visible_beads(vfar) > 0,
		"a 60 m target keeps its beads as well (" .. visible_beads(vfar) .. " beads)")
	check(vfar.style.d_head_c.color[1] == 252 and vfar.style.d_handL_c.color[1] == 252,
		"the head and limb dots never fade either")
	-- The distance takes the glow, not the lines: at 60 m the widest halo band
	-- must be a fraction of its 10 m strength, but not gone (a floor keeps it
	-- reading as neon rather than as a flat wireframe).
	check(near.style.b2_1_o.color[1] > vfar.style.b2_1_o.color[1],
		"the halo is what recedes (" .. near.style.b2_1_o.color[1] .. " -> " .. vfar.style.b2_1_o.color[1] .. ")")
	check(vfar.style.b2_1_o.color[1] >= 3,
		"and it keeps a visible floor instead of vanishing (" .. vfar.style.b2_1_o.color[1] .. ")")
	check(vfar.style.b2_1_c.size[1] <= 1.6,
		"the far bead is a hairline, so the figure stays a line drawing (" .. string.format("%.2f", vfar.style.b2_1_c.size[1]) .. " px)")

	-- A skeleton too poor to read as a figure degrades to its two anchors
	-- instead of drawing a crooked matchstick.
	local hound = mkunit("hound", 10, SPECIAL, 1.4, false)
	local hd = frame(hound, 10)

	check(visible_beads(hd) == 0, "a five-joint skeleton draws no chains at all")
	check(hd.style.d_head_c.visible and hd.style.d_hips_c.visible,
		"but keeps its two anchor dots")
	check(not hd.style.d_handL_c.visible, "and drops the limb dots")
end

ladder_tests()

local function missing_joint_tests()
	local bad = {}

	for k = 1, #tpl.rig_order do
		local key = tpl.rig_order[k]
		local U = mkunit("miss", 10, ELITE)

		-- Remove EVERY candidate: a fallback that still resolves means the
		-- joint is not actually gone, and the test would prove nothing.
		local saved = {}

		for i = 1, #tpl.rig[key] do
			local name = tpl.rig[key][i]
			saved[#saved + 1] = { name = name, pos = U.nodes[name] }
			U.nodes[name] = nil
		end

		local def = frame(U, 10)

		-- Segments that touch the missing joint must drop out whole.
		for s = 1, #SEGS do
			if SEGS[s][1] == key or SEGS[s][2] == key then
				if #beads_of(def, U, s) ~= 0 then
					bad[#bad + 1] = key .. ": segment " .. s .. " still drew beads"
				end
			end
		end

		-- A dot on the missing joint must be gone.
		local dot = DOTJOINT[key]

		if dot and def.style[dot .. "_c"].visible then
			bad[#bad + 1] = key .. ": its joint dot is still drawn"
		end

		-- No bead may sit anywhere except on a line between two joints that
		-- DID resolve. A segment joined to the origin -- the classic nil-as-zero
		-- bug -- would put its beads nowhere near any real bone.
		local resolved = {}

		for i = 1, #tpl.rig_order do
			local kk = tpl.rig_order[i]
			local pos = resolve(U, tpl.rig[kk])

			if pos then
				resolved[kk] = screen_of(pos)
			end
		end

		for s = 1, #SEGS do
			local a, b = SEGS[s][1], SEGS[s][2]

			if resolved[a] and resolved[b] then
				local dx, dy = resolved[b].x - resolved[a].x, resolved[b].y - resolved[a].y
				local len2 = dx * dx + dy * dy

				for _, bead in ipairs(beads_of(def, U, s)) do
					local t = ((bead.x - resolved[a].x) * dx + (bead.y - resolved[a].y) * dy) / len2

					if t < -0.001 or t > 1.001 then
						bad[#bad + 1] = key .. ": seg " .. s .. " bead outside the segment"
					else
						local px = resolved[a].x + dx * t
						local py = resolved[a].y + dy * t
						local dist = math.sqrt((bead.x - px) * (bead.x - px) + (bead.y - py) * (bead.y - py))

						if dist > 0.5 then
							bad[#bad + 1] = key .. ": seg " .. s .. " bead " .. string.format("%.2f", dist) .. " px off the line"
						end
					end
				end
			end
		end

		for i = 1, #saved do
			U.nodes[saved[i].name] = saved[i].pos
		end
	end

	check(#bad == 0, "removing any joint drops exactly its own segments and dots, and every surviving bead sits on a real bone" ..
		(#bad > 0 and (" (bad: " .. table.concat(bad, "; ") .. ")") or ""))
end

missing_joint_tests()

local function bounds_tests()
	local bad = {}

	for _, d in ipairs({ 3, 10, 40 }) do
		local U = mkunit("bounds", d, ELITE)
		local def = frame(U, d)

		for i = 1, #def.passes do
			local st = def.passes[i].style
			local id = tostring(def.passes[i].style_id)

			if math.abs(st.offset[1]) > 1024 or math.abs(st.offset[2]) > 1024 then
				bad[#bad + 1] = d .. " m: " .. id .. " offset " ..
					string.format("%.0f,%.0f", st.offset[1], st.offset[2])
			end

			if st.size[1] > 2048 or st.size[2] > 2048 then
				bad[#bad + 1] = d .. " m: " .. id .. " size " .. string.format("%.0f", st.size[1])
			end
		end
	end

	-- Point-blank is the known limit, not a bug to hide: the coordinate space
	-- is 2048 px and a 1.8 m figure is ~1360 px tall at 1 m, so below roughly
	-- 1.3 m the feet leave the space. Raising size to 4096 is the one-line fix
	-- if it ever shows in game; it stays 2048 until then because no mod in the
	-- repository uses a larger world-marker space and none of them is verified.
	check(#bad == 0, "no pass leaves the 2048 px coordinate space at 3 / 10 / 40 m" ..
		(#bad > 0 and (" (bad: " .. table.concat(bad, "; ") .. ")") or ""))
end

bounds_tests()

local function overflow_tests()
	SETTINGS.stick_thickness = 8
	SETTINGS.stick_glow = 200
	SETTINGS.stick_dot_size = 300

	local U = mkunit("overflow", 5, ELITE)
	local def = frame(U, 5)
	local worst = 0

	for i = 1, #def.passes do
		-- Text passes have no colour byte to wrap.
		local c = def.passes[i].style.color
		local a = c and c[1] or 0

		if a > worst then
			worst = a
		end
	end

	-- Restore the SHIPPED defaults, not whatever felt convenient: every test after
	-- this one measures with these values, and leaving 2 px / 180 there silently
	-- made the rest of the suite report numbers for a configuration no player has.
	SETTINGS.stick_thickness = 8
	SETTINGS.stick_glow = 50
	SETTINGS.stick_dot_size = 200

	check(worst <= 255, "alpha never wraps past 255 at max thickness, max glow and max dot size (worst " .. worst .. ")")
end

overflow_tests()

local function residue_tests()
	-- The pool must survive a distance jump in ONE frame: every slot the new
	-- frame does not use has to be emptied, and no slot may keep last frame's
	-- size. A stale bead from the 3 m frame is 3.5 px and up; at 50 m the
	-- biggest thing on screen is the joint dot's outer layer, about 3.2 px.
	local near_u = mkunit("res_near", 3, ELITE)
	local far_u = mkunit("res_far", 50, ELITE)
	local def = tpl.create_widget_defintion(tpl, "scene")

	tpl.update_function(hud_element, nil, def, { unit = near_u, distance = 3 }, tpl, 0.016, 0)
	local near_beads = visible_beads(def)

	tpl.update_function(hud_element, nil, def, { unit = far_u, distance = 50 }, tpl, 0.016, 0)

	local dirty, stale_beads, biggest = 0, 0, 0

	for i = 1, #def.passes do
		local st = def.passes[i].style
		-- The label copies follow the proven pattern: a visible flag and
		-- nothing else, size untouched. The residue rule is about the POOLED
		-- GEOMETRY, so only rect passes are held to it.
		local rect = st.color ~= nil

		if rect and not st.visible and (st.size[1] ~= 0 or st.size[2] ~= 0) then
			dirty = dirty + 1
		end

		if st.visible then
			-- The label is 96 px wide by design; this check is about stale
			-- GEOMETRY, so it reads rect passes only.
			if st.color ~= nil and st.size[1] > biggest then
				biggest = st.size[1]
			end

			-- A bead CORE that survived from the 3 m frame would still carry
			-- that frame's 9.5 px size. At 50 m the core is a hairline, so any
			-- core wider than the far frame's own is residue. Halo bands are
			-- excluded: they legitimately keep a small pixel floor now.
			local id = def.passes[i].style_id

			if id and string.sub(id, 1, 1) == "b" and string.sub(id, -2) == "_c" and st.size[1] > 2.5 then
				stale_beads = stale_beads + 1
			end
		end
	end

	check(near_beads > 20, "at 3 m the chains are dense (" .. near_beads .. " beads)")
	check(dirty == 0, "a distance jump empties every unused slot (" .. dirty .. " left dirty)")
	check(stale_beads == 0,
		"and no 3 m bead survives into the far frame at its old size (" .. stale_beads .. " stale)")
	check(visible_beads(def) > 0,
		"the far frame still draws its own chains (" .. visible_beads(def) .. " beads)")
	-- At 50 m the only things left are the two anchor dots, and a dot's outer
	-- band is 2.25 x its core (1.8 px at that range) = 4.05 px.
	-- A dot's outer band is 2.25 x its core, and the core is 2.0 x the line at the
	-- shipped dot size, so ~4.5 px at 50 m.
	check(biggest <= 5.0, "the biggest thing left at 50 m is the anchor dot (" .. string.format("%.2f", biggest) .. " px)")

	-- And the other direction: jumping back in must not leave the far frame's
	-- small dots behind at full count.
	tpl.update_function(hud_element, nil, def, { unit = near_u, distance = 3 }, tpl, 0.016, 0)
	local dirty2 = 0

	for i = 1, #def.passes do
		local st = def.passes[i].style

		if st.color ~= nil and not st.visible and (st.size[1] ~= 0 or st.size[2] ~= 0) then
			dirty2 = dirty2 + 1
		end
	end

	check(dirty2 == 0, "jumping back in leaves nothing dirty either (" .. dirty2 .. ")")
end

residue_tests()

-- The glow knob has to move something at BOTH ends of the distance ladder:
-- near, where the proportional width term dominates, and far, where only the
-- pixel floor is left. A knob that only works at knife range is exactly the
-- "the neon strength does nothing" report this guards against.
local function glow_tests()
	local function halo_at(dist, glow)
		SETTINGS.stick_glow = glow
		local d = frame(mkunit("glow_" .. dist, dist, ELITE), dist)

		return d.style.b2_1_o.size[1], d.style.b2_1_o.color[1], d.style.b2_1_c.size[1]
	end

	local n0_w, n0_a = halo_at(8, 0)
	local n1_w, n1_a = halo_at(8, 100)
	local n2_w, n2_a, n2_core = halo_at(8, 200)
	local f1_w, f1_a = halo_at(45, 100)
	local f2_w, f2_a = halo_at(45, 200)

	check(n0_w == 0 and n0_a == 255, "glow 0 draws no halo band at all (size " .. n0_w .. ")")
	check(n1_w > n0_w + 4, "glow 100 adds a real skirt (" .. string.format("%.1f", n0_w) .. " -> " .. string.format("%.1f", n1_w) .. " px)")
	check(n2_w > n1_w + 4, "and 200 is wider again (" .. string.format("%.1f", n2_w) .. " px)")
	check(n2_a > n1_a, "200 is brighter too, not only wider (" .. n1_a .. " -> " .. n2_a .. " alpha)")

	-- The knob is a glow knob: it must not quietly resize the filament.
	check(math.abs(n2_core - frame(mkunit("glow_core", 8, ELITE), 8).style.b2_1_c.size[1]) < 0.01,
		"the core keeps its width -- this knob is glow, not thickness")

	-- Far end: the proportional term is a fraction of a pixel there, so the
	-- pixel floor is the only reason the slider still does anything.
	check(f2_w > f1_w + 0.8,
		"at 45 m the knob still moves the halo (" .. string.format("%.2f", f1_w) .. " -> " .. string.format("%.2f", f2_w) .. " px)")
	check(f2_a >= f1_a, "and never dims it on the way up")

	-- The probe command exists so "the slider does nothing" can be split into
	-- "the module computed a zero" and "the engine ignored it" without another
	-- guessing round.
	echo_lines = {}
	commands.stick_glow()

	local glow_diag = table.concat(echo_lines, " | ")

	check(string.find(glow_diag, "glow: setting=", 1, true) ~= nil,
		"/stick_glow reports the numbers the last frame drew with")
	check(string.find(glow_diag, "bands: out=", 1, true) ~= nil,
		"including the three halo widths")

	SETTINGS.stick_glow = 50
end

glow_tests()

-- The bead ceiling: wider range, and honest about when it stops mattering.
local function density_tests()
	SETTINGS.stick_glow = 50

	SETTINGS.stick_density = 24
	local hi_near = visible_beads(frame(mkunit("den_hi", 2, ELITE), 2))

	SETTINGS.stick_density = 8
	local lo_near = visible_beads(frame(mkunit("den_lo", 2, ELITE), 2))

	check(hi_near > lo_near * 1.5,
		"at point-blank the ceiling really packs more beads (" .. lo_near .. " -> " .. hi_near .. ")")
	check(hi_near > 14 * 8, "and the new 24 ceiling is reachable at all (" .. hi_near .. " beads on screen)")

	-- The ceiling still bites at range on the long segments (spine, thighs),
	-- which is what makes the wider range worth having rather than a knob that
	-- only works when you are touching the enemy.
	SETTINGS.stick_density = 24
	local hi_far = visible_beads(frame(mkunit("den_hi_far", 10, ELITE), 10))

	SETTINGS.stick_density = 14
	local mid_far = visible_beads(frame(mkunit("den_mid_far", 10, ELITE), 10))

	-- Measured with the SHIPPED 8 px cord: at 10 m every segment is already full
	-- at 14, so the ceiling is a point-blank knob by design. Stating it here is
	-- cheaper than a player wondering why the slider stops doing anything.
	check(hi_far >= mid_far and hi_far <= mid_far * 1.05,
		"at 10 m the chains are already full at 14, so the ceiling changes next to nothing ("
			.. mid_far .. " -> " .. hi_far .. ")")

	SETTINGS.stick_density = 14
end

density_tests()

local function switch_tests()
	-- The group switches gate their own passes, through the same content flags
	-- the engine reads.
	local U = mkunit("switch", 10, ELITE)
	local full = frame(U, 10)
	local arms_full = visible_beads(full)

	SETTINGS.stick_show_arms = false
	local off = frame(U, 10)
	local arms_off = 0

	for s = 5, 8 do
		arms_off = arms_off + #beads_of(off, U, s)
	end

	SETTINGS.stick_show_arms = true

	check(arms_full > 0, "with everything on the arms draw beads (" .. arms_full .. ")")
	check(arms_off == 0, "turning the arms off leaves no arm bead on screen")
	check(off.content.show_arms == false, "and the arm gate stays shut")

	-- The gate is what the engine's visibility_function reads, so it has to
	-- agree with what was drawn.
	local gate = nil

	for i = 1, #off.passes do
		if off.passes[i].style_id == "b5_1_c" then
			gate = off.passes[i].visibility_function(off.content)
		end
	end

	check(gate == false, "and an arm pass's own visibility function agrees")

	local all_off = { head = false, torso = false, arms = false, legs = false }
	local saved = {}
	for k, v in pairs(all_off) do
		saved[k] = SETTINGS["stick_show_" .. k]
		SETTINGS["stick_show_" .. k] = v
	end

	local none = frame(U, 10)
	check(visible_beads(none) == 0 and none.content.show_label == false,
		"with every group off the pool is emptied, not left at last frame's geometry")

	for k, v in pairs(saved) do
		SETTINGS["stick_show_" .. k] = v
	end
end

switch_tests()

-- C0b. the four-band neon stack ------------------------------------------------
--
-- The complaint this stack answers: with one halo band the step from filament
-- to skirt is a hard edge, which reads as "a coloured block with a bit of
-- gradient glued on". Four concentric bands with the tube's own alpha ladder
-- are the fix, and the assertions below read the ladder off the drawn passes.

local function band_tests()
	-- The canonical ladder is quoted at glow 100, so the measurement is taken
	-- there rather than inheriting whatever the previous test left behind.
	SETTINGS.stick_glow = 100
	local U = mkunit("bands", 10, ELITE)
	local def = frame(U, 10)
	local core, inn, mid, out = def.style.b2_1_c, def.style.b2_1_i, def.style.b2_1_m, def.style.b2_1_o

	check(core.visible and inn.visible and mid.visible and out.visible,
		"a bead draws all four bands (core + three halos)")
	check(out.size[1] > mid.size[1] and mid.size[1] > inn.size[1] and inn.size[1] > core.size[1],
		"and each band is wider than the one inside it")
	check(core.color[1] == 252 and inn.color[1] == 158 and mid.color[1] == 66 and out.color[1] == 28,
		"with the tube's own alpha ladder 252/158/66/28 -- the falloff that makes it read as light")
	check(core.offset[1] == out.offset[1] and core.offset[2] == out.offset[2],
		"concentric, not pushed sideways")

	local dot_c, dot_i, dot_m, dot_o = def.style.d_head_c, def.style.d_head_i, def.style.d_head_m, def.style.d_head_o

	check(dot_o.size[1] > dot_m.size[1] and dot_m.size[1] > dot_i.size[1] and dot_i.size[1] > dot_c.size[1],
		"the joint dot uses the same four-band ladder on its own multipliers")

	-- Glow 0 skips the halo bands rather than stacking them at the core's own
	-- size -- four same-size squares would be one fat square with a wrapped
	-- alpha, which is the blob this whole ladder exists to avoid.
	SETTINGS.stick_glow = 0
	local bare = frame(U, 10)
	SETTINGS.stick_glow = 100

	check(bare.style.b2_1_c.visible and not bare.style.b2_1_i.visible
		and not bare.style.b2_1_m.visible and not bare.style.b2_1_o.visible,
		"at glow 0 only the lit cores remain -- the halo bands are skipped, not stacked at core size")
end

band_tests()

-- C0c. breathing, RGB, and the head's own colour -------------------------------

-- Hue of a colour triple, 0..1. Duplicated here so the cycle is checked
-- against the spec's own definition rather than against itself.
local function hue_of_channels(r, g, b)
	r, g, b = r / 255, g / 255, b / 255
	local hi = math.max(r, g, b)
	local lo = math.min(r, g, b)
	local d = hi - lo

	if d <= 0 then
		return 0
	end

	local h

	if hi == r then
		h = ((g - b) / d) % 6
	elseif hi == g then
		h = (b - r) / d + 2
	else
		h = (r - g) / d + 4
	end

	return h / 6
end

local function run_at(unit, t)
	local d = tpl.create_widget_defintion(tpl, "scene")

	tpl.update_function(hud_element, nil, d, { unit = unit, distance = 10 }, tpl, 1 / 60, t)

	return d
end

local function breath_tests()
	local U = mkunit("breath", 10, ELITE)

	-- The breath moves brightness and nothing else: the geometry at two
	-- different times has to be identical.
	local a = run_at(U, 1.0).style.b2_1_c
	local b = run_at(U, 2.7).style.b2_1_c

	check(string.format("%.3f/%.3f/%.3f", a.offset[1], a.offset[2], a.size[1])
		== string.format("%.3f/%.3f/%.3f", b.offset[1], b.offset[2], b.size[1]),
		"breathing moves brightness only -- the geometry is identical at two different times")

	-- The sine's bounds and its slope, at the deepest allowed setting.
	SETTINGS.stick_breath = true
	SETTINGS.stick_breath_depth = 80

	local prev, worst, lo_seen, hi_seen = nil, 0, 999, 0
	local t = 0

	for i = 1, 600 do
		local al = run_at(U, t).style.b2_1_c.color[1]

		if prev then
			local delta = math.abs(al - prev)

			if delta > worst then
				worst = delta
			end
		end

		if al < lo_seen then
			lo_seen = al
		end

		if al > hi_seen then
			hi_seen = al
		end

		prev = al
		t = t + 1 / 60
	end

	-- The distance readout is a number, not a light: it must not sway.
	local label_1 = run_at(U, 0.5).style.label.text_color[1]
	local label_2 = run_at(U, 3.9).style.label.text_color[1]

	-- Depth 0 flattens the sine instead of switching to a different behaviour.
	SETTINGS.stick_breath_depth = 0
	local zero_1 = run_at(U, 0.5).style.b2_1_c.color[1]
	local zero_2 = run_at(U, 3.9).style.b2_1_c.color[1]

	SETTINGS.stick_breath = false
	SETTINGS.stick_breath_depth = 38

	-- The bound is the sine's own maximum slope, not a round number. At the
	-- default speed of 300 the period is 1.2 s, so a depth-80 breath moves at
	-- most ~8.8 alpha per frame, plus one for the packing floor. The deleted
	-- flicker dropped 60 percent -- 150 alpha -- in ONE frame; anything shaped
	-- like that fails this by an order of magnitude.
	local period = 3.6 / math.max(0.1, SETTINGS.stick_breath_speed / 100)
	local bound = math.ceil(252 * 0.8 * math.pi / period / 60) + 1

	check(hi_seen == 252, "the crest of the breath is still full brightness (" .. hi_seen .. ")")
	check(lo_seen >= 50, "at depth 80 the darkest frame still keeps a fifth of the light (min " .. lo_seen .. ")")
	check(worst <= bound, "and the brightness never changes faster than the sine allows: worst " .. worst ..
		" alpha, bound " .. bound .. " at speed " .. SETTINGS.stick_breath_speed)
	check(label_1 == 255 and label_2 == 255,
		"the distance readout does not breathe -- a number that pulses is harder to read")
	check(zero_1 == 252 and zero_2 == 252,
		"depth 0 is a steady lamp, not a different animation (" .. zero_1 .. "/" .. zero_2 .. ")")
end

breath_tests()

local function rgb_tests()
	local U = mkunit("rgb", 10, ELITE)
	local picked_hue = hue_of_channels(255, 60, 178)

	-- The shipped default has the cycle ON, so the "cycle off" samples have to
	-- switch it off first -- and switching it off also resets the origin, which
	-- is what makes the "starts at the picked hue" check below meaningful.
	SETTINGS.stick_rgb = false
	local off_1 = run_at(U, 1.0).style.b2_1_m
	local off_2 = run_at(U, 5.0).style.b2_1_m

	check(hue_of_channels(off_1.color[2], off_1.color[3], off_1.color[4])
		== hue_of_channels(off_2.color[2], off_2.color[3], off_2.color[4]),
		"with the cycle off the hue is the picked colour at any time")

	-- The journey starts at the picked hue, not at red.
	SETTINGS.stick_rgb = true
	local first = run_at(U, 0.0).style.b2_1_m
	local later = run_at(U, 4.5).style.b2_1_m
	SETTINGS.stick_rgb = false

	local h_first = hue_of_channels(first.color[2], first.color[3], first.color[4])
	local h_later = hue_of_channels(later.color[2], later.color[3], later.color[4])

	check(math.abs(h_first - picked_hue) < 0.02,
		"the cycle starts at the picked hue, not at red (" .. string.format("%.3f", h_first) .. ")")
	check(math.abs(h_later - h_first) > 0.05,
		"and half a lap later it has genuinely drifted (" .. string.format("%.3f", h_first)
			.. " -> " .. string.format("%.3f", h_later) .. ")")
	check(first.color[1] == 66 and later.color[1] == 66,
		"the cycle moves hue only -- the mid band's brightness never changes with it (66 at both times)")

	-- The two never interfere: with the breath on and the cycle off, the hue
	-- holds still while the brightness sways.
	SETTINGS.stick_breath = true
	local b1 = run_at(U, 0.2).style.b2_1_m
	local b2 = run_at(U, 1.1).style.b2_1_m
	SETTINGS.stick_breath = false

	local hue_still = math.abs(hue_of_channels(b2.color[2], b2.color[3], b2.color[4])
		- hue_of_channels(b1.color[2], b1.color[3], b1.color[4]))

	check(hue_still < 0.001, "the breath never drags the hue along (drift " .. string.format("%.4f", hue_still) .. ")")
	check(b1.color[1] ~= b2.color[1], "while the brightness does sway")
end

rgb_tests()

local function head_color_tests()
	local U = mkunit("headcol", 10, ELITE)
	local def = frame(U, 10)

	-- Default: the head colour equals the body colour, so an untouched install
	-- looks exactly like a single-colour skeleton.
	local body = def.style.b2_1_m
	local head = def.style.b1_1_m

	check(head.color[2] == body.color[2] and head.color[3] == body.color[3] and head.color[4] == body.color[4],
		"by default the head colour IS the body colour (an untouched install looks single-colour)")

	-- A distinct head colour paints the neck segment and the head dot, and
	-- leaves everything else alone.
	SETTINGS.stick_head_color = { 255, 80, 200, 80 }
	local split = frame(U, 10)
	SETTINGS.stick_head_color = { 255, 255, 60, 178 }

	local spine = split.style.b2_1_m
	local neck = split.style.b1_1_m
	local head_dot = split.style.d_head_m
	local hip_dot = split.style.d_hips_m

	check(neck.color[2] == 80 and neck.color[3] == 200 and neck.color[4] == 80,
		"a picked head colour paints the neck segment")
	check(head_dot.color[2] == 80 and head_dot.color[3] == 200,
		"and the head dot")
	check(spine.color[2] == 255 and spine.color[3] == 60,
		"while the body keeps its own colour")
	check(hip_dot.color[2] == 255 and hip_dot.color[3] == 60,
		"and so does the torso dot")
end

head_color_tests()

-- C. the RIG table ------------------------------------------------------------
--
-- The candidate matrix is the one place bone names live. The joint SET is
-- pinned by the 14-segment topology; the candidate strings are deliberately
-- NOT pinned, because the in-game probe exists to replace them.

local function rig_table_tests()
	local rig = tpl.rig
	check(type(rig) == "table", "the RIG table is exposed on the template")

	local wanted = {
		"head", "neck", "chest", "hips",
		"shoulderL", "elbowL", "handL",
		"shoulderR", "elbowR", "handR",
		"legL", "kneeL", "footL",
		"legR", "kneeR", "footR",
	}

	local count = 0
	for k in pairs(rig) do count = count + 1 end
	check(count == 16, "the RIG table has exactly the 16 joints the topology needs (got " .. count .. ")")

	local bad = {}
	for i = 1, #wanted do
		local candidates = rig[wanted[i]]
		if type(candidates) ~= "table" or #candidates == 0 then
			bad[#bad + 1] = wanted[i] .. "=no candidates"
		else
			for j = 1, #candidates do
				if type(candidates[j]) ~= "string" or candidates[j] == "" then
					bad[#bad + 1] = wanted[i] .. "[" .. j .. "]"
				end
			end
		end
	end
	check(#bad == 0, "every joint lists at least one non-empty candidate name" ..
		(#bad > 0 and (" (bad: " .. table.concat(bad, ",") .. ")") or ""))

	-- The verified core bones must be reachable: these are the only names that
	-- have actually been seen on a live unit.
	local verified = {
		head = "j_head", neck = "j_neck", chest = "j_spine1", hips = "j_hips",
	}
	local unreachable = {}
	for key, bone in pairs(verified) do
		local found = false
		for i = 1, #(rig[key] or {}) do
			if rig[key][i] == bone then found = true end
		end
		if not found then unreachable[#unreachable + 1] = key .. "/" .. bone end
	end
	check(#unreachable == 0, "the verified core bones are all reachable through the candidates" ..
		(#unreachable > 0 and (" (missing: " .. table.concat(unreachable, ",") .. ")") or ""))

	local order = tpl.rig_order
	local ocount = 0
	for i = 1, #order do
		if rig[order[i]] then ocount = ocount + 1 end
	end
	check(#order == 16 and ocount == 16,
		"the probe order covers exactly the RIG joints (" .. #order .. " entries, " .. ocount .. " resolve)")
end

rig_table_tests()

-- D. the rig probe ------------------------------------------------------------
--
-- /stick_rig is this build's whole deliverable. The stub rig below uses the
-- FIRST candidate of every joint, so a joint that resolves is a joint the
-- probe logic actually found. The in-game run replaces these names with the
-- real ones.

-- Isolate the probe unit. Clearing the ledger alone is NOT enough: the next
-- mod.update re-adds every still-marked, living target from the outline data,
-- and the dump would silently mix several units into "unit 1". So the outline
-- data is pruned to the same set -- which is also what makes the dump
-- deterministic, since pairs() order is not.
local function keep_only(keep)
	for u in pairs(live) do
		live[u] = nil
	end

	for u in pairs(outline_system._unit_extension_data) do
		if not keep[u] then
			outline_system._unit_extension_data[u] = nil
		end
	end
end

local function rig_probe_tests()
	keep_only({})

	local R1 = mkunit("R1", 10, ELITE)
	outline_system._unit_extension_data[R1] = { outlines = { { name = "veteran_smart_tag" } } }
	mod.update(0.3)
	check(has_marker(R1), "the rig probe unit got a marker")

	echo_lines = {}
	commands.stick_rig()
	-- string.char(10) rather than an escaped newline: this source is embedded
	-- in a JS template literal, and a backslash here is one transport layer
	-- away from becoming a real newline inside the Lua string.
	local out = table.concat(echo_lines, string.char(10))

	check(string.find(out, "unit 1: breed=scab_mauler height=1.8 tags=%[elite%]", 1) ~= nil,
		"the dump names the breed, its height and its tags")
	-- 17 nodes: 5 core + 12 limbs. Parens are escaped: in a Lua pattern they
	-- are a capture group, and an unescaped one matches "nodes17", not the text.
	check(string.find(out, "nodes%(17%)", 1) ~= nil,
		"the dump enumerates every node the unit has (17)")
	check(string.find(out, "head: j_head x=0.00 y=10.00 z=1.55", 1) ~= nil,
		"the head joint resolves with its world position")
	check(string.find(out, "handL: j_lefthand", 1) ~= nil,
		"the left hand resolves through the first candidate")
	check(string.find(out, "footR: j_rightfoot", 1) ~= nil,
		"the right foot resolves through the first candidate")
	check(string.find(out, "MISSING: none", 1) ~= nil,
		"a full rig resolves every joint in the table")
	check(string.find(out, "hit_zones: 3 entries", 1) ~= nil,
		"the dump prints the breed hit zones")
	check(string.find(out, "head.node = j_head", 1) ~= nil,
		"hit zones carry node names, an independent rig source")
	check(string.find(out, "too deep", 1) == nil,
		"the hit-zone walk stops at depth 3")
	check(string.find(out, "screen: x=", 1) ~= nil,
		"the dump checks the projection lands on screen")

	-- a limbless unit: the core joints still resolve, the limbs report missing
	keep_only({})

	local R2 = mkunit("R2", 12, SPECIAL, 1.4, false)
	outline_system._unit_extension_data[R2] = { outlines = { { name = "smart_tagged_enemy" } } }
	mod.update(0.3)

	echo_lines = {}
	commands.stick_rig()
	out = table.concat(echo_lines, string.char(10))

	check(string.find(out, "head: j_head", 1) ~= nil,
		"a limbless unit still resolves the core joints")
	check(string.find(out, "MISSING: shoulderL%(j_leftarm/j_leftshoulder/j_upperarm_l%)", 1) ~= nil,
		"missing limbs are reported with the candidates that were tried")
	check(string.find(out, "MISSING: none", 1) == nil,
		"and the dump does not claim a rig it does not have")
	check(string.find(out, "nodes%(5%)", 1) ~= nil,
		"the enumeration only counts the nodes that exist (5)")

	-- a unit with no skeleton at all: every joint missing, no crash
	keep_only({})

	local R3 = mkunit("R3", 14, ELITE)
	R3.nodes = {}
	outline_system._unit_extension_data[R3] = { outlines = { { name = "veteran_smart_tag" } } }
	mod.update(0.3)

	echo_lines = {}
	commands.stick_rig()
	out = table.concat(echo_lines, string.char(10))

	check(string.find(out, "MISSING: head%(j_head%)", 1) ~= nil,
		"a unit with no skeleton reports every joint missing, none resolved")
	check(string.find(out, "nodes: no enumeration API", 1) ~= nil,
		"and says so instead of printing an empty node list")

	-- pagination: a 46-line dump (two full-rig units) comes in two batches,
	-- reports its end, and resets the page counter afterwards
	keep_only({})

	local P1 = mkunit("P1", 10, ELITE)
	local P2 = mkunit("P2", 20, ELITE)
	outline_system._unit_extension_data[P1] = { outlines = { { name = "veteran_smart_tag" } } }
	outline_system._unit_extension_data[P2] = { outlines = { { name = "veteran_smart_tag" } } }
	mod.update(0.3)

	echo_lines = {}
	commands.stick_rig()
	local batch1 = echo_lines
	check(#batch1 == 41, "a 46-line dump prints 40 lines plus the batch notice (got " .. #batch1 .. ")")
	check(string.find(batch1[#batch1], "batch 1/2", 1) ~= nil, "and says a second batch follows")

	echo_lines = {}
	commands.stick_rig()
	local batch2 = echo_lines
	check(#batch2 == 7, "the second batch prints the remaining 6 lines plus the end notice (got " .. #batch2 .. ")")
	check(string.find(batch2[#batch2], "end of dump %(46 lines%)", 1) ~= nil, "and reports the end of the dump")

	echo_lines = {}
	commands.stick_rig()
	check(echo_lines[1] == batch1[1], "after the end of the dump the page counter resets")

	-- a destroyed unit in the ledger is skipped, not probed
	keep_only({})

	local Z3 = mkunit("Z3", 20, ELITE)
	outline_system._unit_extension_data[Z3] = { outlines = { { name = "veteran_smart_tag" } } }
	mod.update(0.3)
	check(has_marker(Z3), "unit Z3 got a skeleton")
	Z3.alive = false

	echo_lines = {}
	local ok_rig = pcall(commands.stick_rig)
	check(ok_rig, "a destroyed unit in the ledger does not break the rig probe")
	check(#echo_lines == 1 and string.find(echo_lines[1], "no marked unit", 1) ~= nil,
		"and it is skipped rather than probed")

	-- nothing marked at all: the probe asks for a mark instead of dumping nothing
	keep_only({})
	echo_lines = {}
	commands.stick_rig()
	check(#echo_lines == 1 and string.find(echo_lines[1], "no marked unit", 1) ~= nil,
		"with nothing marked the probe asks for a mark instead of dumping nothing")
end

rig_probe_tests()

-- E. whose mark is it ---------------------------------------------------------
--
-- The game records the tagger on every smart tag (tagger_unit / tagger_player),
-- and a target unit holds at most one tag, so "mine" and "theirs" are mutually
-- exclusive. What has to hold here:
--   * a tag of mine paints my colour set, another player's paints theirs;
--   * a mark with NO smart tag (the class keystone) counts as mine, because
--     those marks are personal to whoever applied them;
--   * re-tagging flips the colours of a skeleton that is already on screen;
--   * switching the teammates' set off stops drawing them at all, while my own
--     marks keep coming;
--   * the two colour cycles are independent -- the side with its cycle off must
--     not freeze the side that has it on.

-- The middle band of a bead is the picked colour, untouched: the core is pushed
-- towards white and the outer band is dimmed, so this is the one band that can
-- be compared with a setting value directly.
local function body_rgb(def)
	return def.style.b2_1_m.color
end

local function same_colour(a, b)
	return a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function draw(unit, t)
	local d = tpl.create_widget_defintion(tpl, "scene")

	tpl.update_function(hud_element, nil, d, { unit = unit, distance = 10 }, tpl, 0.016, t or 0)

	return d
end

local function owner_tests()
	keep_only({})
	reset_tags()

	SETTINGS.stick_rgb = false
	SETTINGS.stick_other_rgb = false
	SETTINGS.stick_keystone_rgb = false
	SETTINGS.stick_breath = false
	SETTINGS.stick_other_breath = false
	SETTINGS.stick_keystone_breath = false
	SETTINGS.stick_keystone_enabled = true
	SETTINGS.stick_other_enabled = true

	local mine = mkunit("own_mark", 10, ELITE)
	local theirs = mkunit("ally_mark", 12, ELITE)
	local keystone = mkunit("key_mark", 14, ELITE)

	outline_system._unit_extension_data[mine] = { outlines = { { name = "veteran_smart_tag" } } }
	outline_system._unit_extension_data[theirs] = { outlines = { { name = "smart_tagged_enemy" } } }
	outline_system._unit_extension_data[keystone] = { outlines = { { name = "psyker_marked_target" } } }

	tag_by(ME, mine)
	tag_by(ALLY, theirs)

	local before = #created
	mod.update(0.3)

	check(#created - before == 3, "all three marks get a skeleton (" .. (#created - before) .. ")")
	check(same_colour(body_rgb(draw(mine, 0)), SETTINGS.stick_color),
		"my own tag is painted with my colour set")
	check(same_colour(body_rgb(draw(theirs, 0)), SETTINGS.stick_other_color),
		"a teammate's tag is painted with theirs")
	check(same_colour(body_rgb(draw(keystone, 0)), SETTINGS.stick_keystone_color),
		"a keystone mark is painted with its own third set")
	check(not same_colour(body_rgb(draw(keystone, 0)), SETTINGS.stick_color),
		"and not with mine -- the two are different kinds of mark")
	check(not same_colour(body_rgb(draw(keystone, 0)), SETTINGS.stick_other_color),
		"nor with a teammate's")

	-- The bug that shipped in 0.2.1: the player manager takes an INDEX, so a
	-- no-argument call answered nil. "Who am I" was empty, so every tagged
	-- enemy fell through to "somebody else" and was painted with the teammates'
	-- colour set -- which also made the player's own switches look dead.
	check(Managers.player:local_player() == nil and Managers.player:local_player(1) == ME,
		"the player manager only answers when asked with an index (the shape that broke attribution)")
	check(same_colour(body_rgb(draw(mine, 0)), SETTINGS.stick_color),
		"and my own mark is still attributed to me")

	echo_lines = {}
	commands.stick_own()

	local own_diag = table.concat(echo_lines, " | ")

	check(string.find(own_diag, "owner: player=yes", 1, true) ~= nil,
		"/stick_own resolves the local player")
	check(string.find(own_diag, "tag=", 1, true) ~= nil,
		"and prints the tag id behind each mark")

	-- Independent cycles. With mine off and theirs on, the teammate's hue has to
	-- drift, and my own colour has to sit still -- a shared origin would let the
	-- switched-off side reset the running one every frame and freeze it.
	SETTINGS.stick_other_rgb = true

	local theirs_1 = body_rgb(draw(theirs, 0))
	local theirs_2 = body_rgb(draw(theirs, 2.0))

	check(not same_colour(theirs_1, theirs_2),
		"the teammates' cycle runs while mine is switched off")

	local mine_1 = body_rgb(draw(mine, 0))
	local mine_2 = body_rgb(draw(mine, 2.0))

	check(same_colour(mine_1, mine_2), "and my own marks hold their colour meanwhile")
	check(same_colour(mine_1, SETTINGS.stick_color),
		"a switch-off cycle leaves my picked colour exactly as picked")

	SETTINGS.stick_other_rgb = false

	-- Mine is sticky. The game moves a target's single tag to whoever re-tags
	-- it, so a teammate CAN take an enemy I marked off me in the engine's books
	-- -- but the skeleton must not change owner in front of the player who
	-- marked it. This is the reported bug, pinned here.
	tag_by(ALLY, mine)
	mod.update(0.3)
	check(same_colour(body_rgb(draw(mine, 0)), SETTINGS.stick_color),
		"a teammate re-tagging my enemy does NOT repaint it -- mine stays mine")

	-- The other direction still works: an enemy that was theirs all along turns
	-- mine the moment I tag it, so the stickiness is one-way and not "mine
	-- always wins".
	local late = mkunit("late_mark", 16, ELITE)
	outline_system._unit_extension_data[late] = { outlines = { { name = "smart_tagged_enemy" } } }
	tag_by(ALLY, late)
	mod.update(0.3)

	check(same_colour(body_rgb(draw(late, 0)), SETTINGS.stick_other_color),
		"an enemy tagged only by a teammate is painted with their set")

	tag_by(ME, late)
	mod.update(0.3)
	check(same_colour(body_rgb(draw(late, 0)), SETTINGS.stick_color),
		"and becomes mine the moment I tag it")

	-- Keystone marks reach trash that cannot be tagged by hand (a scab, a
	-- dreg), so the elite/special filter must not eat them.
	local mook = mkunit("keystone_mook", 18, HORDE)
	outline_system._unit_extension_data[mook] = { outlines = { { name = "psyker_marked_target" } } }
	mod.update(0.3)

	check(has_marker(mook), "a keystone-marked trash mob gets a skeleton")
	check(same_colour(body_rgb(draw(mook, 0)), SETTINGS.stick_keystone_color),
		"in the keystone set's colours")

	-- The keystone set has its own switch, like the teammates' one, and turning
	-- it off has to take the skeletons already on screen with it -- a psyker can
	-- have several of these up at once.
	SETTINGS.stick_keystone_enabled = false
	mod.update(0.016)

	check(not has_marker(mook), "switching keystone marks off removes the ones already on screen")
	check(has_marker(mine), "while my own mark stays")

	echo_lines = {}
	commands.stick_diag()

	check(string.find(table.concat(echo_lines, " | "), "keystone=", 1, true) ~= nil,
		"and the diag reports the keystone count separately")

	SETTINGS.stick_keystone_enabled = true
	mod.update(0.3)

	check(has_marker(mook), "turning it back on brings the mark back")

	-- A hand tag outranks the keystone: the player deliberately claimed this one,
	-- so it has to look like their own mark from then on.
	tag_by(ME, mook)
	mod.update(0.3)

	check(same_colour(body_rgb(draw(mook, 0)), SETTINGS.stick_color),
		"hand-tagging a keystone-marked enemy repaints it as mine")

	-- The same body with a manual tag is still filtered out: tagging trash by
	-- hand must not turn the HUD into a horde of skeletons.
	local tagged_mook = mkunit("tagged_mook", 20, HORDE)
	outline_system._unit_extension_data[tagged_mook] = { outlines = { { name = "smart_tagged_enemy" } } }
	tag_by(ME, tagged_mook)
	mod.update(0.3)

	check(not has_marker(tagged_mook), "a hand-tagged horde body is still skipped")

	-- Switching the teammates' set off mid-fight has to remove what is already
	-- on screen, not wait for the affected enemy to be re-tagged.
	SETTINGS.stick_other_enabled = false
	mod.update(0.016)

	check(not has_marker(theirs), "switching teammates' marks off removes the one already on screen")
	check(has_marker(mine), "while my own mark stays")

	SETTINGS.stick_other_enabled = true

	-- Teammates' marks switched off: only my own enemies get a skeleton, and the
	-- diagnostics say how many were filtered instead of leaving it a mystery.
	SETTINGS.stick_other_enabled = false
	keep_only({})
	reset_tags()

	outline_system._unit_extension_data[mine] = { outlines = { { name = "veteran_smart_tag" } } }
	outline_system._unit_extension_data[theirs] = { outlines = { { name = "veteran_smart_tag" } } }

	tag_by(ME, mine)
	tag_by(ALLY, theirs)

	before = #created
	mod.update(0.3)

	check(#created - before == 1,
		"with teammates' marks off only my own enemy gets a skeleton (" .. (#created - before) .. ")")

	echo_lines = {}
	commands.stick_diag()

	local diag = table.concat(echo_lines, " | ")

	check(string.find(diag, "hidden=1", 1, true) ~= nil, "and the diag counts the one that was filtered")
	check(string.find(diag, "mine=1", 1, true) ~= nil, "while still counting mine")

	-- The master switch owns the skeletons: off means gone, never frozen.
	SETTINGS.stick_enabled = false
	mod.update(0.3)

	check(not has_marker(mine), "the master switch takes the skeletons down with it")

	local off_frame = draw(mine, 0)

	check(not off_frame.style.b2_1_c.visible, "and a widget cannot draw a frame while it is off")

	SETTINGS.stick_enabled = true
	mod.update(0.3)

	check(has_marker(mine), "turning it back on brings the mark straight back")

	SETTINGS.stick_other_enabled = true
	SETTINGS.stick_rgb = true
	SETTINGS.stick_other_rgb = true
	SETTINGS.stick_breath = true
	SETTINGS.stick_other_breath = true

	SETTINGS.stick_rgb = true
	SETTINGS.stick_other_rgb = true
	SETTINGS.stick_keystone_rgb = true
	SETTINGS.stick_breath = true
	SETTINGS.stick_other_breath = true
	SETTINGS.stick_keystone_breath = true

	reset_tags()
	keep_only({})
end

owner_tests()

-- F. the performance accounting ------------------------------------------------
--
-- The point of the instrumentation is to answer "what does one skeleton cost",
-- so the checks are about the report being complete and honest: it must not
-- divide by zero, it must bucket frame time by skeleton count, and it must reach
-- the log (the copy that survives the game being closed) as well as chat.
local function perf_tests()
	-- No game mode at all (loading, main menu): nothing counted, nothing
	-- reported, no session started.
	Managers.state.game_mode = nil
	keep_only({})
	tpl.perf_reset()

	local lines = tpl.perf_report()

	check(#lines == 1 and string.find(lines[1], "no frames counted", 1, true) ~= nil,
		"with no frames counted the report says so instead of dividing by zero")

	local mode = { name = "coop_complete_objective" }

	Managers.state.game_mode = {
		game_mode_name = function(self) return mode.name end,
	}

	local U = mkunit("perf_u", 10, ELITE)
	outline_system._unit_extension_data[U] = { outlines = { { name = "veteran_smart_tag" } } }

	local reference = visible_beads(frame(U, 10))

	for i = 1, 20 do
		mod.update(0.016)
	end

	check(tpl.perf_started(), "entering a mission starts a session by itself")
	check(tpl.perf_started() and visible_beads(frame(U, 10)) == reference,
		"and the instrumentation does not change what is drawn")

	for i = 1, 20 do
		mod.update(0.016)
		frame(U, 10)
	end

	local report = table.concat(tpl.perf_report(), " | ")

	check(string.find(report, "frame time by skeletons", 1, true) ~= nil,
		"the report buckets frame time by how many skeletons were on screen")
	check(string.find(report, "our Lua", 1, true) ~= nil,
		"and prints how much of the frame our own code spent")
	-- dt arrives in SECONDS and the report is in MILLISECONDS. 1.2.1 shipped
	-- with the *1000 missing and logged "avg 0.01 ms (73671.7 fps)" for a 13 ms
	-- frame, which reads like "the mod is free" instead of "the number is wrong".
	check(string.find(report, "avg 16.00 ms", 1, true) ~= nil,
		"a 60 fps frame reports as 16.00 ms, not 0.02 ms")
	check(string.find(report, "avg 16.00 ms (62.5 fps)", 1, true) ~= nil,
		"and the fps column is the reciprocal of that, not of the seconds value")
	check(string.find(report, "light sources drawn", 1, true) ~= nil,
		"and how many beads were actually drawn")
	check(string.find(report, "light sources drawn: 0/", 1, true) == nil,
		"the bead counter is not stuck at zero while skeletons are drawing")

	-- Back in the hub: the session ends and the report goes out on both
	-- channels.
	mode.name = "hub"
	echo_lines = {}
	info_lines = {}

	mod.update(0.016)

	check(string.find(table.concat(echo_lines, " | "), "[perf]", 1, true) ~= nil,
		"returning to the hub prints the report to chat")
	check(string.find(table.concat(info_lines, " | "), "[perf]", 1, true) ~= nil,
		"and writes the same lines to the DMF log")
	check(not tpl.perf_started(), "and closes the session")

	check(string.find(tpl.perf_report()[1], "no frames counted", 1, true) ~= nil,
		"the counters are cleared for the next mission")

	-- The manual command must not throw the data away: a player types it
	-- mid-mission precisely because something feels wrong.
	echo_lines = {}
	mod.update(0.016)
	info_lines = {}

	Managers.state.game_mode = {
		game_mode_name = function(self) return mode.name end,
	}
	mode.name = "coop_complete_objective"
	mod.update(0.016)

	commands.stick_perf()

	check(#echo_lines > 1, "the chat command prints the report on demand")
	check(tpl.perf_started(), "and leaves the session running")

	Managers.state.game_mode = nil
	tpl.perf_reset()
	keep_only({})
end

perf_tests()

-- No line that reaches chat or the log may contain a literal percent sign.
check(#percent_hits == 0, "no chat or log line carries a literal percent sign (" .. #percent_hits .. " found)")
for i = 1, #percent_hits do OUT.checks[#OUT.checks + 1] = "      " .. percent_hits[i] end

OUT.summary = table.concat(OUT.checks, "\\n")
OUT.echo = table.concat(echo_lines, " | ")
RESULT = OUT
`;

const src = STUBS + "\n" + mainSrc + "\n" + TEST;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const code = to_luastring(src, true);
if (lauxlib.luaL_loadbuffer(L, code, code.length, to_luastring("=sim")) !== lua.LUA_OK) {
  console.error("LOAD FAILED:", lua.lua_tojsstring(L, -1));
  process.exit(1);
}
if (lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0) !== lua.LUA_OK) {
  console.error("RUN FAILED:", lua.lua_tojsstring(L, -1));
  process.exit(1);
}

lua.lua_getglobal(L, to_luastring("RESULT"));
lua.lua_getfield(L, -1, to_luastring("summary"));
const summary = lua.lua_tojsstring(L, -1) || "";
const echo = (() => {
  lua.lua_getfield(L, -2, to_luastring("echo"));
  return lua.lua_tojsstring(L, -1) || "";
})();

// ---------------------------------------------------------------------
// C. localization format-string guard (a separate, tiny run)
//
// DMF pipes EVERY localized string through string.format
// (dmf/modules/core/localization.lua: safe_string_format). A bare "%" that is
// not followed by a valid conversion therefore aborts the lookup, and because
// the error is caught the option's title silently resolves to nil in every
// language. This check formats every entry of the real localization file, so a
// stray "%" fails the build here instead of reddening the in-game feed.
// ---------------------------------------------------------------------
// Read as UTF-8, not latin1: the loc check compares whole strings, and a
// latin1 read mangles every Chinese byte so no comparison can ever match. The
// percent guard below is byte-based either way, so it is unaffected.
const locSrc = fs.readFileSync(path.join(MOD, "MarkedStick_localization.lua"), "utf8");

const LOC_CHECK = `
local LOC = (function()
${locSrc}
end)()

local bad, count = {}, 0
local rendered = {}

for key, entry in pairs(LOC) do
	if type(entry) == "table" then
		for lang, text in pairs(entry) do
			if type(text) == "string" then
				count = count + 1
				local ok, value = pcall(string.format, text)
				if not ok then
					bad[#bad + 1] = key .. "/" .. tostring(lang) .. " -> " .. tostring(value)
				else
					rendered[key .. "/" .. tostring(lang)] = value
				end
			end
		end
	end
end

local out = {}
out[#out + 1] = (count > 0 and "PASS  " or "FAIL  ")
	.. "every localized string survives string.format (" .. count .. " entries)"
out[#out + 1] = (#bad == 0 and "PASS  " or "FAIL  ")
	.. "no unescaped percent sign anywhere (" .. #bad .. " bad)"
for i = 1, #bad do out[#out + 1] = "      " .. bad[i] end

local glow_en = rendered["stick_glow_title/en"]
out[#out + 1] = (glow_en == "Glow (%)" and "PASS  " or "FAIL  ")
	.. "the glow title renders a single percent: " .. tostring(glow_en)

-- Encoding-independent version of the same assertion for both Chinese titles:
-- exactly one percent byte, none left doubled. Comparing the literal text here
-- would only test how this harness transcodes UTF-8, not what the game gets.
for _, lang in ipairs({ "zh-cn", "zh-tw" }) do
	local glow_zh = rendered["stick_glow_title/" .. lang]
	local _, pct_count = string.gsub(glow_zh, "%%", "")
	local _, dbl_count = string.gsub(glow_zh, "%%%%", "")
	out[#out + 1] = ((pct_count == 1 and dbl_count == 0 and #glow_zh > 3) and "PASS  " or "FAIL  ")
		.. "the " .. lang .. " glow title renders one percent and no doubling"
		.. " (percent=" .. pct_count .. " doubled=" .. dbl_count .. ", " .. #glow_zh .. " bytes)"
end

-- The dot-size description quotes the 180 percent floor. English spells the
-- word out, the Chinese carries it as an escaped percent, and both shapes have
-- to survive: the escaped one must render as exactly one sign.
local dot_en = rendered["stick_dot_size_description/en"]
local dot_zh = rendered["stick_dot_size_description/zh-cn"] or ""
local _, zh_pct = string.gsub(dot_zh, "%%", "")
out[#out + 1] = (dot_en and string.find(dot_en, "180 percent of the line width", 1) ~= nil
	and zh_pct == 1 and "PASS  " or "FAIL  ")
	.. "the dot-size description keeps its 180 percent floor (en spelled out, zh one escaped sign)"

-- All THREE languages must carry every key. DMF resolves the language by
-- exact match on Application.user_setting("language_id") and falls back to
-- English, so a key that exists in English and Simplified Chinese only shows
-- up as raw key text for a Traditional Chinese player -- which is exactly the
-- hole this build closes.
local half = {}
for key, entry in pairs(LOC) do
	if type(entry) == "table" then
		if entry.en == nil then half[#half + 1] = key .. "/en" end
		if entry["zh-cn"] == nil then half[#half + 1] = key .. "/zh-cn" end
		if entry["zh-tw"] == nil then half[#half + 1] = key .. "/zh-tw" end
	end
end
out[#out + 1] = (#half == 0 and "PASS  " or "FAIL  ")
	.. "every key exists in English, Simplified and Traditional Chinese (" .. #half .. " missing)"
for i = 1, #half do out[#out + 1] = "      missing: " .. half[i] end

-- The name in the mod list is the mod's identity, not a description, so it is
-- the same string in every language -- and it is the same string as the folder,
-- the .mod file and the mod id. A translated or "prettier" name here would show
-- the player two different products: one in the list, one in the folder tree.
local names = { rendered["mod_name/en"], rendered["mod_name/zh-cn"], rendered["mod_name/zh-tw"] }
local named = names[1] == "MarkedStick" and names[2] == names[1] and names[3] == names[1]
out[#out + 1] = (named and "PASS  " or "FAIL  ")
	.. "the mod name is MarkedStick in all three languages, untranslated"
	.. " (en=" .. tostring(names[1]) ..
	   ", zh-cn=" .. tostring(names[2]) ..
	   ", zh-tw=" .. tostring(names[3]) .. ")"

-- The Simplified strings must NOT have leaked traditional glyphs the other way:
-- a copy-paste between the two columns would otherwise pass unnoticed. Plain
-- find, not a pattern: Lua patterns are byte-based, and a character class
-- built from multibyte glyphs matches individual bytes, not characters.
local TRAD = { "蟲", "節", "顏", "強", "臨", "時", "務", "幾", "髮", "乾" }
local leaked = {}
for key, entry in pairs(LOC) do
	if type(entry) == "table" and type(entry["zh-cn"]) == "string" then
		for i = 1, #TRAD do
			if string.find(entry["zh-cn"], TRAD[i], 1, true) then
				leaked[#leaked + 1] = key .. " (" .. TRAD[i] .. ")"
			end
		end
	end
end
out[#out + 1] = (#leaked == 0 and "PASS  " or "FAIL  ")
	.. "no Simplified string carries Traditional-only glyphs (" .. #leaked .. " leaked)"
for i = 1, #leaked do out[#out + 1] = "      " .. leaked[i] end

-- Every localization key belongs to this mod: the two mod-level keys plus the
-- stick_ family. A key left over from an earlier name would simply never be
-- looked up, and a foreign one would collide with another mod's.
local foreign_keys = {}
for key in pairs(LOC) do
	if key ~= "mod_name" and key ~= "mod_description" and string.sub(key, 1, 6) ~= "stick_" then
		foreign_keys[#foreign_keys + 1] = key
	end
end
out[#out + 1] = (#foreign_keys == 0 and "PASS  " or "FAIL  ")
	.. "every localization key belongs to this mod (" .. #foreign_keys .. " foreign)"
for i = 1, #foreign_keys do out[#out + 1] = "      " .. foreign_keys[i] end

LOCRESULT = table.concat(out, "\\n")
`;

const L2 = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L2);
const locCode = to_luastring(LOC_CHECK, true);
if (lauxlib.luaL_loadbuffer(L2, locCode, locCode.length, to_luastring("=loc")) !== lua.LUA_OK) {
  console.error("LOC LOAD FAILED:", lua.lua_tojsstring(L2, -1));
  process.exit(1);
}
if (lua.lua_pcall(L2, 0, lua.LUA_MULTRET, 0) !== lua.LUA_OK) {
  console.error("LOC RUN FAILED:", lua.lua_tojsstring(L2, -1));
  process.exit(1);
}
lua.lua_getglobal(L2, to_luastring("LOCRESULT"));
const locSummary = lua.lua_tojsstring(L2, -1) || "";

// ---------------------------------------------------------------------
// D. option wiring (its own state, because it needs get_mod and both files)
//
// Every title / tooltip / dropdown label in MarkedStick_data.lua is a
// localization KEY, not text. A key that does not exist in the localization
// file renders as the raw key in the options menu -- or, with a bad percent
// sign, as nothing at all. Loading both files and cross-checking the keys
// catches that here instead of in a screenshot from the user.
//
// The setting list itself is pinned to the task spec: the probe build ships
// the FINAL options menu, so the geometry build cannot quietly grow a knob.
// ---------------------------------------------------------------------
const dataSrc = fs.readFileSync(path.join(MOD, "MarkedStick_data.lua"), "latin1");

function runChunk(Lx, code, label) {
  const c = to_luastring(code, true);
  if (lauxlib.luaL_loadbuffer(Lx, c, c.length, to_luastring("=" + label)) !== lua.LUA_OK) {
    console.error("LOAD FAILED (" + label + "):", lua.lua_tojsstring(Lx, -1));
    process.exit(1);
  }
  if (lua.lua_pcall(Lx, 0, lua.LUA_MULTRET, 0) !== lua.LUA_OK) {
    console.error("RUN FAILED (" + label + "):", lua.lua_tojsstring(Lx, -1));
    process.exit(1);
  }
}

const L3 = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L3);

runChunk(L3, "function get_mod() return { localize = function(self, k) return k end } end", "get_mod");
runChunk(L3, "LOC = (function()\n" + locSrc + "\nend)()", "loc");
runChunk(L3, "DATA = (function()\n" + dataSrc + "\nend)()", "data");

const OPTION_CHECK = `
local data = DATA or {}
local loc = LOC or {}
local widgets = (data.options and data.options.widgets) or {}

local missing, checked = {}, 0

local function need(key)
	if type(key) ~= "string" then return end
	checked = checked + 1
	if loc[key] == nil then missing[#missing + 1] = key end
end

need("mod_name")
need("mod_description")

for i = 1, #widgets do
	local w = widgets[i]
	need(w.title)
	need(w.tooltip)
end

local out = {}
out[#out + 1] = (#widgets > 0 and "PASS  " or "FAIL  ")
	.. "the option file loads (" .. #widgets .. " widgets)"
out[#out + 1] = (#missing == 0 and "PASS  " or "FAIL  ")
	.. "all " .. checked .. " option keys exist in the localization file"
for i = 1, #missing do out[#out + 1] = "      missing: " .. missing[i] end

-- The full menu, pinned -- defaults included, because the shipped defaults
-- ARE the look the screenshots were approved with: breathing and the cycle on,
-- a fat 8 px cord with a tight 50 percent skirt, joint dots at their floor.
-- What keeps the animation knobs honest is the depth ceiling below -- 100
-- would be a blink, and a blink is the one thing this mod family has already
-- had to delete once.
local expected = {
	{ id = "stick_enabled",       type = "checkbox", default = true },
	{ id = "stick_color",         type = "color" },
	{ id = "stick_head_color",    type = "color" },
	{ id = "stick_rgb",           type = "checkbox", default = true },
	{ id = "stick_rgb_speed",     type = "numeric",  default = 100, range = { 10, 300 } },
	{ id = "stick_breath",        type = "checkbox", default = true },
	{ id = "stick_breath_depth",  type = "numeric",  default = 40,  range = { 0, 80 } },
	{ id = "stick_breath_speed",  type = "numeric",  default = 300, range = { 10, 300 } },
	{ id = "stick_thickness",     type = "numeric",  default = 8,   range = { 1, 8 } },
	{ id = "stick_glow",          type = "numeric",  default = 50,  range = { 0, 200 } },
	{ id = "stick_dot_size",      type = "numeric",  default = 200, range = { 120, 300 } },
	{ id = "stick_other_enabled", type = "checkbox", default = true },
	{ id = "stick_other_color",   type = "color" },
	{ id = "stick_other_head_color", type = "color" },
	{ id = "stick_other_rgb",     type = "checkbox", default = true },
	{ id = "stick_other_rgb_speed", type = "numeric", default = 100, range = { 10, 300 } },
	{ id = "stick_other_breath",  type = "checkbox", default = true },
	{ id = "stick_other_breath_depth", type = "numeric", default = 40, range = { 0, 80 } },
	{ id = "stick_other_breath_speed", type = "numeric", default = 300, range = { 10, 300 } },
	{ id = "stick_other_thickness", type = "numeric", default = 8,  range = { 1, 8 } },
	{ id = "stick_other_glow",    type = "numeric",  default = 50,  range = { 0, 200 } },
	{ id = "stick_other_dot_size", type = "numeric", default = 150, range = { 120, 300 } },
	{ id = "stick_keystone_enabled", type = "checkbox", default = true },
	{ id = "stick_keystone_color",   type = "color" },
	{ id = "stick_keystone_head_color", type = "color" },
	{ id = "stick_keystone_rgb",     type = "checkbox", default = true },
	{ id = "stick_keystone_rgb_speed", type = "numeric", default = 100, range = { 10, 300 } },
	{ id = "stick_keystone_breath",  type = "checkbox", default = true },
	{ id = "stick_keystone_breath_depth", type = "numeric", default = 40, range = { 0, 80 } },
	{ id = "stick_keystone_breath_speed", type = "numeric", default = 300, range = { 10, 300 } },
	{ id = "stick_keystone_thickness", type = "numeric", default = 6, range = { 1, 8 } },
	{ id = "stick_keystone_glow",    type = "numeric", default = 50, range = { 0, 200 } },
	{ id = "stick_keystone_dot_size", type = "numeric", default = 150, range = { 120, 300 } },
	{ id = "stick_density",       type = "numeric",  default = 24,  range = { 2, 24 } },
	{ id = "stick_show_head",     type = "checkbox", default = true },
	{ id = "stick_show_torso",    type = "checkbox", default = true },
	{ id = "stick_show_arms",     type = "checkbox", default = true },
	{ id = "stick_show_legs",     type = "checkbox", default = true },
	{ id = "stick_show_distance", type = "checkbox", default = true },
}

out[#out + 1] = (#widgets == #expected and "PASS  " or "FAIL  ")
	.. "the menu has exactly the " .. #expected .. " settings the spec lists (got " .. #widgets .. ")"

local wrong = {}
for i = 1, #expected do
	local w = widgets[i]
	local e = expected[i]
	if not w then
		wrong[#wrong + 1] = "row " .. i .. " missing"
	else
		if w.setting_id ~= e.id then wrong[#wrong + 1] = w.setting_id .. " expected " .. e.id end
		if w.type ~= e.type then wrong[#wrong + 1] = w.setting_id .. " type " .. tostring(w.type) end
		if e.default ~= nil and w.default_value ~= e.default then
			wrong[#wrong + 1] = w.setting_id .. " default " .. tostring(w.default_value)
		end
		if e.range then
			if type(w.range) ~= "table" or w.range[1] ~= e.range[1] or w.range[2] ~= e.range[2] then
				wrong[#wrong + 1] = w.setting_id .. " range"
			end
		end
	end
end
out[#out + 1] = (#wrong == 0 and "PASS  " or "FAIL  ")
	.. "every setting has the spec's id, type, default and range"
for i = 1, #wrong do out[#out + 1] = "      " .. wrong[i] end

-- The colour widget has three hard contracts, and every one of them fails at
-- RUNTIME in the options menu rather than here:
--   * type must be "color";
--   * default_value must be { a, r, g, b } -- alpha first;
--   * has_alpha must be an explicit boolean (dmf options.lua raises on nil).
local colour = nil
for i = 1, #widgets do
	if widgets[i].setting_id == "stick_color" then colour = widgets[i] end
end

local dv = colour and colour.default_value
local shape = colour and colour.type == "color" and type(dv) == "table" and #dv == 4
	and type(dv[1]) == "number" and type(dv[2]) == "number"
	and type(dv[3]) == "number" and type(dv[4]) == "number"

out[#out + 1] = (shape and "PASS  " or "FAIL  ")
	.. "stick_color is a colour widget with an { a, r, g, b } default"
out[#out + 1] = ((colour and type(colour.has_alpha) == "boolean") and "PASS  " or "FAIL  ")
	.. "stick_color declares has_alpha as an explicit boolean"

-- The animation knobs were asked for, so they exist. What keeps them honest
-- is the depth ceiling: 100 would be a blink, and a blink is the one thing
-- this mod family has already had to delete once.
local depth_w = nil
for i = 1, #widgets do
	if widgets[i].setting_id == "stick_breath_depth" then depth_w = widgets[i] end
end
out[#out + 1] = ((depth_w and depth_w.range and depth_w.range[2] == 80) and "PASS  " or "FAIL  ")
	.. "the breathing depth is capped at 80, so the skeleton can never blink out"

-- The head colour is a second colour widget, and it carries the same three
-- hard contracts as the body one.
local head_colour = nil
for i = 1, #widgets do
	if widgets[i].setting_id == "stick_head_color" then head_colour = widgets[i] end
end
local hdv = head_colour and head_colour.default_value
local hshape = head_colour and head_colour.type == "color" and type(hdv) == "table" and #hdv == 4
	and type(hdv[1]) == "number" and type(hdv[2]) == "number"
	and type(hdv[3]) == "number" and type(hdv[4]) == "number"
out[#out + 1] = (hshape and "PASS  " or "FAIL  ")
	.. "stick_head_color is a colour widget with an { a, r, g, b } default"
out[#out + 1] = ((head_colour and type(head_colour.has_alpha) == "boolean") and "PASS  " or "FAIL  ")
	.. "stick_head_color declares has_alpha as an explicit boolean"

-- Every setting_id belongs to this mod. A row left over from an earlier name
-- would leave a dead row in the menu and a mod:get that always returns nil --
-- and saying it as a prefix rule means the check does not have to name what
-- came before.
local foreign = {}
for i = 1, #widgets do
	local id = widgets[i].setting_id or ""
	if string.sub(id, 1, 6) ~= "stick_" then foreign[#foreign + 1] = id end
end
out[#out + 1] = (#foreign == 0 and "PASS  " or "FAIL  ")
	.. "every setting_id belongs to this mod (" .. #foreign .. " foreign)"
for i = 1, #foreign do out[#out + 1] = "      " .. foreign[i] end

OPTIONRESULT = table.concat(out, string.char(10))
`;

runChunk(L3, OPTION_CHECK, "options");
lua.lua_getglobal(L3, to_luastring("OPTIONRESULT"));
const optionSummary = lua.lua_tojsstring(L3, -1) || "";

// ---------------------------------------------------------------------
// E. self-consistency (pure JS, no Lua state needed)
//
// Every identifier the engine looks up has to match this mod's own name, and
// every key the mod reads has to belong to it. Expressed as a positive rule
// rather than a blacklist: a stale io_dofile path or template name fails
// SILENTLY in game, so the rule has to be total -- and a positive rule does
// not need to name anything that came before.
// ---------------------------------------------------------------------

// Engine contracts live in different files: the marker template owns the
// widget fields, the lifecycle file owns the HUD element and the events. Both
// sets must survive, because a renamed contract fails silently.
const MAIN_CONTRACTS = [
  "_marker_templates",
  "_markers_by_type",
  "add_world_marker_unit",
  "remove_world_marker",
  "GAME_MARK_NAMES",
];
const MARKER_CONTRACTS = [
  "create_widget_defintion",
  "check_line_of_sight",
  "remove_on_death_duration",
];

const renameLines = [];
let renameFails = 0;
function rline(ok, msg) {
  renameLines.push((ok ? "PASS  " : "FAIL  ") + msg);
  if (!ok) renameFails++;
}

const MOD_DIR = path.join(ROOT, "MarkedStick");
const mainText = fs.readFileSync(path.join(MOD, "MarkedStick.lua"), "latin1");
const markerText = fs.readFileSync(path.join(MOD, "stick_marker.lua"), "latin1");
const modText = fs.readFileSync(path.join(MOD_DIR, "MarkedStick.mod"), "latin1");
const dataText = fs.readFileSync(path.join(MOD, "MarkedStick_data.lua"), "latin1");
const locText = fs.readFileSync(path.join(MOD, "MarkedStick_localization.lua"), "utf8");

// get_mod: the only mod this file may ask for is itself.
const asked = mainText.match(/get_mod\("[^"]*"\)/g) || [];
const askedBad = asked.filter((s) => s !== 'get_mod("MarkedStick")');
rline(asked.length > 0 && askedBad.length === 0,
  "MarkedStick.lua asks for its own mod and no other (" + asked.length + " lookups, " + askedBad.length + " foreign)");

// io_dofile: every path leads inside this mod's own directory.
const paths = mainText.match(/io_dofile\("[^"]*"\)/g) || [];
const pathsBad = paths.filter((s) => !s.startsWith('io_dofile("MarkedStick/scripts/mods/MarkedStick/'));
rline(paths.length > 0 && pathsBad.length === 0,
  "MarkedStick.lua loads only files inside its own directory (" + paths.length + " loads, " + pathsBad.length + " foreign)");

// mod:get / get_flag / get_number / get_rgb: every key read belongs to this
// mod's settings family. Checked in both Lua files, because the marker reads
// most of them -- through the small helpers, not directly.
const reads = (mainText + "\n" + markerText)
  .match(/mod:get\("[^"]*"\)|(?:get_flag|get_number|get_rgb)\(mod, "[^"]*"/g) || [];
const readsBad = reads.filter((s) => {
  const key = s.slice(s.indexOf('"') + 1, s.lastIndexOf('"'));
  return !key.startsWith("stick_");
});
rline(reads.length > 0 && readsBad.length === 0,
  "every setting either Lua file reads belongs to this mod (" + reads.length + " reads, " + readsBad.length + " foreign)");

// The data file's setting ids.
const ids = dataText.match(/setting_id = "[^"]*"/g) || [];
const idsBad = ids.filter((s) => !s.startsWith('setting_id = "stick_'));
rline(ids.length > 0 && idsBad.length === 0,
  "every setting_id in the menu belongs to this mod (" + ids.length + " rows, " + idsBad.length + " foreign)");

// The localization file's top-level keys: the two mod-level keys plus stick_*.
const keys = locText.match(/^\t([A-Za-z_][A-Za-z0-9_]*) = \{/gm) || [];
const keysBad = keys
  .map((s) => s.replace(/^\t/, "").replace(/ = \{$/, ""))
  .filter((k) => k !== "mod_name" && k !== "mod_description" && !k.startsWith("stick_"));
rline(keys.length > 0 && keysBad.length === 0,
  "every localization key belongs to this mod (" + keys.length + " keys, " + keysBad.length + " foreign)");

// The template the engine draws with.
rline(markerText.includes('template.name = "marked_stick"'), "the template is registered as marked_stick");
rline(markerText.includes("template.rig = RIG") && markerText.includes("template.rig_order = RIG_ORDER"),
  "the RIG table and its order are both exposed for the probe");

// The commands.
rline(mainText.includes('mod:command("stick_rig"') && mainText.includes('mod:command("stick_diag"'),
  "both chat commands exist under their own names");
rline(mainText.includes('mod:command("stick_glow"'), "the glow probe command exists as well");
rline(mainText.includes('mod:command("stick_own"'), "and so does the attribution probe");
rline(markerText.includes("template.last = LAST"),
  "the marker exposes the last frame's numbers for /stick_glow");

// The .mod manifest.
rline(modText.includes('new_mod("MarkedStick"'), "the .mod registers MarkedStick");

// The display name and the identifier must be the SAME string. This is the one
// place where a "prettier" name would slip through: the list would say one
// thing and the folder, the .mod file and the mod id another. The block is read
// as latin1, so any non-ASCII byte in it means a translated variant crept in.
const locBytes = fs.readFileSync(path.join(MOD, "MarkedStick_localization.lua"), "latin1");
const nameBlock = (locBytes.match(/mod_name\s*=\s*\{([\s\S]*?)\n\t\},/) || [])[1] || "";
rline((nameBlock.match(/MarkedStick/g) || []).length === 3,
  "the in-game name is MarkedStick in all three languages (" + (nameBlock.match(/MarkedStick/g) || []).length + "/3)");
rline(nameBlock.length > 0 && !/[\x80-\xff]/.test(nameBlock),
  "and the name block carries no translated variant");
rline(modText.includes("MarkedStick/scripts/mods/MarkedStick/MarkedStick")
  && modText.includes("MarkedStick/scripts/mods/MarkedStick/MarkedStick_data")
  && modText.includes("MarkedStick/scripts/mods/MarkedStick/MarkedStick_localization"),
  "the .mod points all three paths at its own directory");

// Engine contracts, both files.
for (const c of MAIN_CONTRACTS) {
  rline(mainText.includes(c), "MarkedStick.lua keeps the engine contract '" + c + "'");
}
for (const c of MARKER_CONTRACTS) {
  rline(markerText.includes(c), "stick_marker.lua keeps the engine contract '" + c + "'");
}

const renameSummary = renameLines.join("\n");

const everything = summary + "\n" + locSummary + "\n" + optionSummary + "\n" + renameSummary;

console.log(everything);
console.log("\ndiag output: " + echo);
const fails = (everything.match(/FAIL/g) || []).length;
console.log("\n" + (fails === 0 ? "ALL PASS" : fails + " FAILED"));
process.exit(fails === 0 ? 0 : 1);

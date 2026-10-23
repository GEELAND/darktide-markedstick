--[[
	stick_marker.lua -- a neon stick skeleton on a marked enemy.

	WHY A SKELETON AND NOT A BRACKET
	  A bracket says "here it is". A skeleton says "here it is, and here is
	  the part you want to hit" -- the same information an outline can never
	  carry, because an outline is the silhouette of the whole body.

	WHY BEADS AND NOT LINES
	  A rect cannot be rotated, so a line at an angle is a chain of small
	  squares along the segment. That is not a compromise: read as a whole it
	  is exactly the segmented, stick-insect look this module is for, and it
	  costs nothing the engine cannot already do.

	HOW THE SKELETON STAYS GLUED TO THE BODY
	  A world marker gets ONE screen anchor from the engine: the projected
	  unit_node point. Every pass is an offset from that anchor, so nothing
	  here can be a fixed pixel size. Each joint is projected with the same
	  Camera.world_to_screen the engine used, and the chain is laid between
	  the projected points. Perspective is then the engine's problem: the
	  skeleton hugs the bones at 3 m and at 40 m, and follows a rising or
	  falling camera for free.

	ONE SCALE FOR THE WHOLE FIGURE
	  The single scale factor is the projected HEIGHT of the resolved joints
	  (STICK_REF_H px is where it saturates). Taking the figure rather than
	  one segment is what keeps the proportions: a thigh and a forearm share
	  one factor, so the skeleton cannot come apart at range. Line, beads,
	  halos and joint dots all take it -- including the constant term of the
	  halo formulas, because a fixed 5 px halo on a 1 px line is a blob.

	THE LOOK: FOUR BANDS, THE SAME LADDER AS THE TUBE
	  A bead is a stack of four concentric squares -- near-white core at 100
	  percent, then inner / mid / outer halos at 62 / 26 / 11 percent, each
	  one wider than the last. That ladder is the entire trick: with equal
	  alphas the four squares read as one fat square, and with only ONE halo
	  the step from filament to skirt is a hard edge -- which is exactly the
	  "a coloured block with a bit of gradient glued on" look this stack
	  replaces. The joint dots use the same four-band ladder on their own
	  size multipliers, so a dot and a bead are the same light at two sizes.

	THE MOTION: A BREATH AND A COLOUR CYCLE, BOTH OPTIONAL
	  The breath is a SINE between "1 - depth" and 1, never a triangle and
	  never a step -- a level change the eye can catch as a kick is the same
	  defect as the flicker an earlier build shipped and had to delete. The
	  depth ceiling is 80 so the darkest point still keeps a fifth of the
	  light; 0 flattens the sine into a steady lamp rather than switching to
	  a different behaviour. The colour cycle rotates the hue away from the
	  colour the player picked, so the colour setting decides where the
	  journey starts. The two never interfere: the breath moves alpha and
	  nothing else, the cycle moves hue and nothing else.

	THE HEAD HAS ITS OWN COLOUR
	  The neck segment and the head dot take a second picked colour, so the
	  weakspot can be called out without repainting the whole skeleton. It
	  defaults to the body colour, so an untouched install looks exactly like
	  a single-colour skeleton.

	THE DISTANCE LADDER
	  Below the saturation point the figure first spends the scale, then
	  sheds detail: the bead chains fade out linearly between ratio 0.30 and
	  0.20, the limb dots between 0.20 and 0.12, and the head / torso dots
	  never fade -- they are the floor, the last way to find a target. Both
	  ramps are linear in the same ratio, so a target walking outward loses
	  detail smoothly instead of stepping between bands.

	WHAT IS DELIBERATELY NOT HERE
	  * no line-of-sight test -- a marked enemy behind a wall still has to
	    be findable, that is the whole point of the module;
	  * no ripple, no random flicker, nothing that changes in one frame;
	  * no automatic logging: diagnostics are chat commands only.

	A NOTE ON THE LAST BEAD
	  An earlier draft faded the chain's final bead in with the fractional
	  part of the ideal bead count, so a count changing by one would not pop
	  a bead into existence. That fade RESETS at every integer crossing: the
	  bead sitting on the far joint drops from full to nothing in a single
	  frame, which is precisely the brightness cut this project has already
	  paid for twice. So the beads are placed at full strength, evenly
	  spaced, first and last exactly on the joints. When the count does
	  change the whole chain re-spaces by at most half a bead -- a sub-pixel
	  shimmer inside a line that is already a continuous glow, not a cut.
]]

local UIWidget = require("scripts/managers/ui/ui_widget")

local MAT = "content/ui/materials/backgrounds/default_square"

local DEFAULT_THICK = 2

-- The skeleton colour the player has not touched yet. { r, g, b },
-- magenta-pink. The whole palette below is derived from this one triple, and
-- the head colour defaults to the same value.
local DEFAULT_RGB = { 255, 60, 178 }

-- The distance readout keeps the game's own gold: it is a number, not a light.
local LABEL = { 255, 255, 205, 105 }
local SHADOW = { 190, 0, 0, 0 }

-- ---------------------------------------------------------------------------
-- THE RIG TABLE -- the one place bone names live. Edit here and nowhere else.
--
-- Verified on a live unit: j_head, j_neck, j_spine1, j_spine, j_hips, j_hip,
-- root_point (all six confirmed in game).
-- UNVERIFIED (guessed from the j_ convention): every limb name below. They are
-- probed by /stick_rig before any geometry is written against them.
-- ---------------------------------------------------------------------------
local RIG = {
	head      = { "j_head" },
	neck      = { "j_neck", "j_spine1", "j_spine" },
	chest     = { "j_spine1", "j_spine", "j_neck" },
	hips      = { "j_hips", "j_hip", "root_point" },
	shoulderL = { "j_leftarm", "j_leftshoulder", "j_upperarm_l" },
	elbowL    = { "j_leftforearm", "j_leftelbow", "j_forearm_l" },
	handL     = { "j_lefthand", "j_lefthand_ik", "j_hand_l" },
	shoulderR = { "j_rightarm", "j_rightshoulder", "j_upperarm_r" },
	elbowR    = { "j_rightforearm", "j_rightelbow", "j_forearm_r" },
	handR     = { "j_righthand", "j_righthand_ik", "j_hand_r" },
	legL      = { "j_leftupleg", "j_leftthigh", "j_thigh_l" },
	kneeL     = { "j_leftleg", "j_leftknee", "j_calf_l" },
	footL     = { "j_leftfoot", "j_leftankle", "j_foot_l" },
	legR      = { "j_rightupleg", "j_rightthigh", "j_thigh_r" },
	kneeR     = { "j_rightleg", "j_rightknee", "j_calf_r" },
	footR     = { "j_rightfoot", "j_rightankle", "j_foot_r" },
}

-- Fixed iteration order for the probe dump and the segment walk. Kept next to
-- RIG so a joint added to the table is added here in the same edit; pairs()
-- order is not stable, and a dump that reshuffles itself between two runs
-- cannot be compared.
local RIG_ORDER = {
	"head", "neck", "chest", "hips",
	"shoulderL", "elbowL", "handL",
	"shoulderR", "elbowR", "handR",
	"legL", "kneeL", "footL",
	"legR", "kneeR", "footR",
}

-- The 14 segments. `group` is the setting each one answers to. The hip line
-- belongs to the legs: with the legs switched off it would be a line from the
-- hips to nothing.
local SEGMENTS = {
	{ a = "head",      b = "neck",      group = "head" },
	{ a = "neck",      b = "hips",      group = "torso" },
	{ a = "neck",      b = "shoulderL", group = "torso" },
	{ a = "neck",      b = "shoulderR", group = "torso" },
	{ a = "shoulderL", b = "elbowL",    group = "arms" },
	{ a = "shoulderR", b = "elbowR",    group = "arms" },
	{ a = "elbowL",    b = "handL",     group = "arms" },
	{ a = "elbowR",    b = "handR",     group = "arms" },
	{ a = "hips",      b = "legL",      group = "legs" },
	{ a = "hips",      b = "legR",      group = "legs" },
	{ a = "legL",      b = "kneeL",     group = "legs" },
	{ a = "legR",      b = "kneeR",     group = "legs" },
	{ a = "kneeL",     b = "footL",     group = "legs" },
	{ a = "kneeR",     b = "footR",     group = "legs" },
}

-- The six joint dots. A rect cannot draw a circle, and at these sizes a stack
-- of four squares reads as a glowing point. A real dot would need a
-- radial-gradient texture, and the material name for one is not verified --
-- guessing it produces a pass that silently never renders.
local DOTS = {
	{ joint = "head",  group = "head",  key = "d_head" },
	{ joint = "hips",  group = "torso", key = "d_hips" },
	{ joint = "handL", group = "arms",  key = "d_handL" },
	{ joint = "handR", group = "arms",  key = "d_handR" },
	{ joint = "footL", group = "legs",  key = "d_footL" },
	{ joint = "footR", group = "legs",  key = "d_footR" },
}

-- ---------------------------------------------------------------------------
-- Geometry constants
-- ---------------------------------------------------------------------------

-- Projected figure height, in pixels, at which the scale factor saturates.
-- A 1.8 m human is about 260 px tall at 6.2 m on a 1080p screen with the
-- default FOV, which is the range where the player still reads the skeleton.
local STICK_REF_H = 260

-- The core never goes below a pixel: below that the engine has nothing to
-- rasterise. The halos follow the core, not this floor.
local LINE_MIN_CORE = 1

-- The joint dot's own floor. Higher than the line's on purpose: the dot is
-- the last way to find a target, so it must not vanish before the line does.
local DOT_MIN_PX = 1.6

-- Beads: spacing as a share of the bead diameter. Below 1 the beads overlap,
-- which is what makes the chain read as one continuous line.
local BEAD_SPACING_RATIO = 0.70

-- Beads per segment, and the only performance lever in the module. When the
-- cap forces a wider spacing the beads get THICKER rather than leaving a
-- gap: a broken line reads as a bug, a fat one merely reads as close.
local BEAD_MAX = 14

-- Dot diameter as a share of the line width. 1.8 is a hard floor, not a
-- default: below it the joint stops reading as a dot and becomes another
-- bead.
local DOT_MIN_RATIO = 1.8

-- How much thicker the lit core is than a plain line.
local NEON_CORE_EXTRA = 1.5

-- Halo widths, as a multiple of the line thickness plus a constant. Wider
-- than they look on paper: half of each halo is hidden under the core's own
-- shine. The bead stack and the dot stack use the SAME four-band ladder and
-- the same width formulas, so a dot and a bead are one light at two sizes.
local NEON_OUT_PAD = { mul = 2.5, add = 5.0 }
local NEON_MID_PAD = { mul = 1.3, add = 2.5 }
local NEON_IN_PAD = { mul = 0.6, add = 1.0 }

-- Alpha ladder for the four bands, before the figure's own alpha is applied.
local NEON_ALPHA = { out = 28, mid = 66, inn = 158, core = 252 }

-- The dot stack's size multipliers, outermost first.
local DOT_OUT_MUL = 2.25
local DOT_MID_MUL = 1.75
local DOT_INN_MUL = 1.35

-- The four bands of a bead, listed widest and dimmest first, because the
-- painter's algorithm here is list order: a halo drawn after the core would
-- smear over the filament. `pad` names the halo width this band takes; the
-- core takes none.
local BEAD_LAYERS = {
	{ suffix = "_o", alpha = NEON_ALPHA.out,  pad = "out", tint = "out" },
	{ suffix = "_m", alpha = NEON_ALPHA.mid,  pad = "mid", tint = "mid" },
	{ suffix = "_i", alpha = NEON_ALPHA.inn,  pad = "inn", tint = "inn" },
	{ suffix = "_c", alpha = NEON_ALPHA.core, pad = nil,   tint = "core", core = true },
}

-- The same ladder on the dot's own multipliers.
local DOT_LAYERS = {
	{ suffix = "_o", mul = DOT_OUT_MUL, alpha = NEON_ALPHA.out,  tint = "out" },
	{ suffix = "_m", mul = DOT_MID_MUL, alpha = NEON_ALPHA.mid,  tint = "mid" },
	{ suffix = "_i", mul = DOT_INN_MUL, alpha = NEON_ALPHA.inn,  tint = "inn" },
	{ suffix = "_c", mul = 1.0,         alpha = NEON_ALPHA.core, tint = "core", core = true },
}

local TEXT_GAP = 8

-- Distance ladder waypoints, in the same ratio as the scale factor. Beads
-- fade out between 0.30 and 0.20; limb dots between 0.20 and 0.12; the head
-- and torso dots never fade.
local FADE_BEAD_LO, FADE_BEAD_HI = 0.20, 0.30
local FADE_LIMB_LO, FADE_LIMB_HI = 0.12, 0.20

-- Fewer usable joints than this and the skeleton is not drawn as one: a
-- hound or a nurgling gets its two anchor dots instead of a crooked
-- matchstick.
local MIN_JOINTS = 6

-- Breathing. A sine, never a triangle or a step: a level change the eye can
-- catch as a kick is the same defect as the flicker that had to be deleted.
--
-- How deep the dip goes is the player's choice. The setting is expressed as
-- "how much of the full brightness the trough gives up", so 38 reproduces a
-- visible sway and 0 flattens the sine into a steady lamp rather than
-- turning it into a different animation.
--
-- The ceiling is 80, not 100: a trough near zero is a blink, and a blink is
-- exactly what this build must never ship. Even at the deepest setting the
-- skeleton keeps a fifth of its light.
local BREATH_PERIOD = 3.6
local BREATH_DEPTH_PCT = 38
local BREATH_DEPTH_MAX = 80

-- The colour cycle. The hue walks a full lap in RGB_PERIOD seconds at 100
-- percent speed, always at full saturation so the palette derivation still
-- produces a near-white core. The lap starts at the hue the player picked,
-- so the colour setting doubles as the starting point rather than being
-- overruled by a rainbow that always begins at red.
local RGB_PERIOD = 9.0

-- ---------------------------------------------------------------------------
-- The pass pool
--
-- Every slot is allocated ONCE, here, and never added or removed at runtime.
-- A frame only writes offset / size / colour / visibility into the slots it
-- uses; the rest are explicitly emptied, because a slot left over from a
-- closer frame is the classic pooled-render residue bug -- a bead floating
-- where the skeleton used to be.
--
-- Budget: 14 segments x 14 beads x 4 bands = 784, plus 6 dots x 4 bands = 24,
-- plus the 2 label copies = 810. Four marked enemies at once is 3240 passes,
-- which the design case accepts; the density setting is the lever if a weak
-- machine ever says otherwise (14 -> 8 takes the pool to 474).
-- ---------------------------------------------------------------------------

-- KEYS[segment][bead] = { ["_o"] = <outer id>, ["_m"] = <mid id>,
-- ["_i"] = <inner id>, ["_c"] = <core id> } -- keyed by the band's suffix, the
-- same string BEAD_LAYERS carries, so the lookup cannot drift from the list.
local KEYS = {}
local POOL = {}

for s = 1, #SEGMENTS do
	KEYS[s] = {}

	for i = 1, BEAD_MAX do
		local keys = {
			["_o"] = "b" .. s .. "_" .. i .. "_o",
			["_m"] = "b" .. s .. "_" .. i .. "_m",
			["_i"] = "b" .. s .. "_" .. i .. "_i",
			["_c"] = "b" .. s .. "_" .. i .. "_c",
		}

		KEYS[s][i] = keys

		-- Halo first, core last: list order is draw order, and a halo drawn
		-- after its own core would smear over the filament.
		POOL[#POOL + 1] = keys["_o"]
		POOL[#POOL + 1] = keys["_m"]
		POOL[#POOL + 1] = keys["_i"]
		POOL[#POOL + 1] = keys["_c"]
	end
end

for d = 1, #DOTS do
	local key = DOTS[d].key

	-- Widest and dimmest first, same reason.
	POOL[#POOL + 1] = key .. "_o"
	POOL[#POOL + 1] = key .. "_m"
	POOL[#POOL + 1] = key .. "_i"
	POOL[#POOL + 1] = key .. "_c"
end

local template = {}

template.name = "marked_stick"

-- The widget is only a coordinate space; every pass is an offset from its
-- centre. A whole human figure at point-blank range is taller than 1000 px,
-- so a 768 px space would clip the legs. 2048 leaves room (an ogryn closer
-- than about 1.1 m still clips -- the coordinate space is finite).
template.size = { 2048, 2048 }

template.unit_node = "j_head"
template.position_offset = { 0, 0, 0 }

-- CRITICAL: no line-of-sight test. A marked enemy behind a wall still has to
-- be findable, and the UI layer is drawn after every 3D pass by construction,
-- so nothing can cover the skeleton anyway.
template.check_line_of_sight = false

template.max_distance = 250
template.screen_clamp = false

-- A grace period the engine applies when a mapped unit dies. Backstop only:
-- MarkedStick.lua removes the marker itself the frame the enemy dies.
template.remove_on_death_duration = 0.5

-- The probe command in MarkedStick.lua reads the candidate matrix from here,
-- so bone names stay in exactly one place.
template.rig = RIG
template.rig_order = RIG_ORDER

-- `UIFontSettings` is injected by the engine, not required. If it is missing
-- we fall back to a font name known to exist.
local function resolve_font()
	local settings = rawget(_G, "UIFontSettings")
	local entry = settings and (settings["nameplates"] or settings["hud_body"])

	return entry and entry.font_type or "proxima_nova_bold"
end

local function copy_color(color)
	return { color[1], color[2], color[3], color[4] }
end

-- Linear blend of one channel toward `to`, rounded. Kept local because the
-- palette has to be rebuilt whenever the player drags the colour picker.
local function blend(from, to, t)
	local value = from + (to - from) * t

	if value < 0 then
		return 0
	end

	if value > 255 then
		return 255
	end

	return math.floor(value + 0.5)
end

-- One picked colour -> the four hues the widget draws with.
--
-- The core is pulled 80 percent of the way to white: a real tube is a white
-- filament behind coloured gas, and a core painted in the picked hue makes
-- the whole skeleton look like a flat sticker. The outermost band goes the
-- other way, darker, because the farthest skirt of a real glow is the part
-- that has lost most of its energy.
local function palette_from(rgb)
	local r, g, b = rgb[1], rgb[2], rgb[3]

	local function toward(t)
		return { 255, blend(r, 255, t), blend(g, 255, t), blend(b, 255, t) }
	end

	return {
		core = toward(0.80),
		inn = toward(0.46),
		mid = { 255, r, g, b },
		out = { 255, math.floor(r * 0.72), math.floor(g * 0.72), math.floor(b * 0.72) },
	}
end

-- One pooled rect pass. `group` is the setting the pass answers to; the
-- per-frame `visible` flag then decides whether THIS slot is in use.
local function rect_pass(style_id, group)
	return {
		pass_type = "rect",
		value = MAT,
		style_id = style_id,
		style = {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			offset = { 0, 0, 0 },
			size = { 1, 1 },
			color = { 255, 255, 255, 255 },
			visible = false,
		},
		visibility_function = function(content)
			return content["show_" .. group] == true
		end,
	}
end

-- NOTE: "defintion" is misspelled on purpose. The engine looks this field up
-- by that exact spelling; correcting it silently disables the whole widget.
template.create_widget_defintion = function(definition_template, scenegraph_id)
	local passes = {}

	for s = 1, #SEGMENTS do
		local group = SEGMENTS[s].group

		for l = 1, #BEAD_LAYERS do
			local suffix = BEAD_LAYERS[l].suffix

			for i = 1, BEAD_MAX do
				passes[#passes + 1] = rect_pass(KEYS[s][i][suffix], group)
			end
		end
	end

	for d = 1, #DOTS do
		local key = DOTS[d].key
		local group = DOTS[d].group

		for l = 1, #DOT_LAYERS do
			passes[#passes + 1] = rect_pass(key .. DOT_LAYERS[l].suffix, group)
		end
	end

	-- The distance label is drawn twice: a near-black copy one pixel down,
	-- then the bright copy. The HUD is bright outdoors and dark in tunnels,
	-- and a single colour loses to one of those two.
	passes[#passes + 1] = {
		pass_type = "text",
		style_id = "label_shadow",
		value_id = "label",
		value = "",
		style = {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			offset = { 1, 4, 1 },
			size = { 96, 16 },
			font_type = resolve_font(),
			font_size = 14,
			text_horizontal_alignment = "center",
			text_vertical_alignment = "center",
			text_color = copy_color(SHADOW),
			visible = false,
		},
		visibility_function = function(content)
			return content.show_label == true
		end,
	}

	passes[#passes + 1] = {
		pass_type = "text",
		style_id = "label",
		value_id = "label",
		value = "",
		style = {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			offset = { 0, 3, 2 },
			size = { 96, 16 },
			font_type = resolve_font(),
			font_size = 14,
			text_horizontal_alignment = "center",
			text_vertical_alignment = "center",
			text_color = copy_color(LABEL),
			visible = false,
		},
		visibility_function = function(content)
			return content.show_label == true
		end,
	}

	return UIWidget.create_definition(passes, scenegraph_id)
end

-- ---------------------------------------------------------------------------
-- Engine access, every call guarded
-- ---------------------------------------------------------------------------

-- Stingray throws on any `Unit.*` of a destroyed unit -- including Unit.alive.
-- One unguarded call aborts the callback, and it aborts it again next frame.
local function try(fn, ...)
	if not fn then
		return nil
	end

	local ok, a = pcall(fn, ...)

	return ok and a or nil
end

local function node_pos(unit, names)
	for i = 1, #names do
		if try(Unit.has_node, unit, names[i]) then
			local node = try(Unit.node, unit, names[i])

			if node then
				local pos = try(Unit.world_position, unit, node)

				if pos then
					return pos
				end
			end
		end
	end

	return nil
end

-- The HUD element that owns us knows the player camera; Managers.state.camera
-- is the fallback for the first frame or two, before that link exists.
local function player_camera(parent)
	local hud = parent and parent._parent

	if hud and hud.player_camera then
		local camera = try(hud.player_camera, hud)

		if camera then
			return camera
		end
	end

	local state = Managers.state and Managers.state.camera

	if state then
		local camera = try(state.camera, state, "first_person")

		if camera then
			return camera
		end
	end

	return nil
end

local function project(camera, pos)
	local screen = try(Camera.world_to_screen, camera, pos)

	if not screen or type(screen.x) ~= "number" or type(screen.y) ~= "number" then
		return nil
	end

	-- NaN means the point is behind the camera; both comparisons are false
	-- for NaN, so this catches it without a helper.
	if screen.x ~= screen.x or screen.y ~= screen.y then
		return nil
	end

	return screen.x, screen.y
end

-- ---------------------------------------------------------------------------
-- Pool writes
-- ---------------------------------------------------------------------------

-- One rect, fully written: position, size, colour, visibility.
--
-- An alpha that floors to zero HIDES the pass and zeroes its size. That is
-- what keeps the pool invariant "invisible means size 0" -- the residue test
-- reads it, and a slot that is invisible but still carries last frame's size
-- is exactly the residue bug in its mildest form.
local function emit(pass, x, y, w, h, color, alpha)
	if not pass then
		return false
	end

	if alpha < 1 then
		pass.visible = false
		pass.size[1] = 0
		pass.size[2] = 0

		return false
	end

	if alpha > 255 then
		alpha = 255
	end

	pass.offset[1] = x
	pass.offset[2] = y
	pass.size[1] = w
	pass.size[2] = h
	pass.color[1] = math.floor(alpha)
	pass.color[2] = color[2]
	pass.color[3] = color[3]
	pass.color[4] = color[4]
	pass.visible = true

	return true
end

-- Every slot, emptied. Runs on EVERY path through the frame, including the
-- early exits, so nothing can survive a frame in which nothing qualified.
local function clear_pool(style)
	if not style then
		return
	end

	for i = 1, #POOL do
		local pass = style[POOL[i]]

		if pass then
			pass.visible = false
			pass.size[1] = 0
			pass.size[2] = 0
		end
	end
end

-- One bead: four concentric squares, widest and dimmest first. The core takes
-- no intensity gain -- losing the filament is how a glow stops reading as a
-- tube -- but the three halo bands do, so once the widths are maxed the
-- slider keeps buying brightness instead of doing nothing.
local function place_bead(style, keys, x, y, size, pads, alpha, halo_gain, palette)
	local drew = false

	for l = 1, #BEAD_LAYERS do
		local layer = BEAD_LAYERS[l]
		local pad = 0

		if layer.pad then
			pad = (pads and pads[layer.pad]) or 0
		end

		-- A band with no spread is not a band: at glow 0 the halo bands are
		-- skipped entirely instead of being drawn at the core's own size.
		if pad > 0 or layer.core then
			local s = size + pad * 2
			local lift = layer.core and 1 or halo_gain

			if emit(style[keys[layer.suffix]], x, y, s, s, palette[layer.tint], layer.alpha * alpha * lift) then
				drew = true
			end
		end
	end

	return drew
end

-- One joint dot: the same four-band ladder on the dot's own multipliers.
local function place_dot(style, key, x, y, size, alpha, halo_gain, palette)
	local drew = false

	for l = 1, #DOT_LAYERS do
		local layer = DOT_LAYERS[l]
		local lift = layer.core and 1 or halo_gain

		if emit(style[key .. layer.suffix], x, y, size * layer.mul, size * layer.mul,
			palette[layer.tint], layer.alpha * alpha * lift) then
			drew = true
		end
	end

	return drew
end

-- One segment as a chain of beads. Returns how many beads actually drew.
local function chain(style, seg, ax, ay, bx, by, bead, pads, alpha, halo_gain, max_beads, palette)
	local dx, dy = bx - ax, by - ay
	local len = math.sqrt(dx * dx + dy * dy)

	-- Coincident joints: nothing to draw, and the division below would be
	-- by zero.
	if len < 0.5 then
		return 0
	end

	local n = math.ceil(len / (BEAD_SPACING_RATIO * bead)) + 1

	if n < 2 then
		n = 2
	end

	if n > max_beads then
		n = max_beads
	end

	-- Evenly spaced, first and last exactly on the joints. If the cap forced
	-- the spacing wider than the beads allow, the beads thicken instead of
	-- leaving a gap -- a fat line reads as "close", a broken one as "bug".
	local s = len / (n - 1)

	if s > BEAD_SPACING_RATIO * bead then
		bead = s / BEAD_SPACING_RATIO
	end

	local drew = 0

	for i = 1, n do
		local t = (i - 1) / (n - 1)

		if place_bead(style, KEYS[seg][i], ax + dx * t, ay + dy * t, bead, pads, alpha, halo_gain, palette) then
			drew = drew + 1
		end
	end

	return drew
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

-- `mod:get()` returns nil for a setting the player never touched, so the
-- default has to survive that. It also has to survive `false`, which rules
-- out `value and true or default` -- that idiom collapses to the default when
-- the value IS false, i.e. it silently ignores a player who turned the
-- option off.
local function get_flag(mod, key, default)
	local ok, value = pcall(mod.get, mod, key)

	if not ok or value == nil then
		return default
	end

	return value and true or false
end

local function get_number(mod, key, default, low, high)
	local ok, value = pcall(mod.get, mod, key)

	if not ok or type(value) ~= "number" then
		return default
	end

	-- Clamped by hand rather than with math.clamp: that helper is a Stingray
	-- extension, and this file must not depend on load order to survive.
	if value < low then
		return low
	end

	if value > high then
		return high
	end

	return value
end

local function clamp_channel(value)
	if value < 0 then
		return 0
	end

	if value > 255 then
		return 255
	end

	return math.floor(value + 0.5)
end

-- The colour widget stores { a, r, g, b } -- index 1 is alpha, exactly like
-- every other colour in this file, which is why the default is written with
-- 255 in front of the three channels.
--
-- Two shapes have to be survived: a Vector4 default normalised by DMF to
-- 0..1, and a settings file from an older version that never had this key.
local function get_rgb(mod, key)
	local ok, value = pcall(mod.get, mod, key)

	if not ok or type(value) ~= "table" then
		return DEFAULT_RGB
	end

	local r, g, b = value[2], value[3], value[4]

	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return DEFAULT_RGB
	end

	if r <= 1 and g <= 1 and b <= 1 then
		r, g, b = r * 255, g * 255, b * 255
	end

	return { clamp_channel(r), clamp_channel(g), clamp_channel(b) }
end

-- Hue of a colour, 0..1. The colour cycle starts here instead of at red, so
-- turning the cycle on drifts away from the colour the player chose rather
-- than replacing it with an unrelated rainbow.
local function hue_of(rgb)
	local r, g, b = rgb[1] / 255, rgb[2] / 255, rgb[3] / 255
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

-- Hue -> RGB at full saturation and full value. Saturation stays at 1 because
-- palette_from already pulls the core 80 percent toward white; starting from
-- a muted source would only produce a grey tube.
local function hue_rgb(hue)
	local h = (hue % 1) * 6
	local i = math.floor(h)
	local f = h - i
	local q = 1 - f
	local r, g, b

	if i == 0 then
		r, g, b = 1, f, 0
	elseif i == 1 then
		r, g, b = q, 1, 0
	elseif i == 2 then
		r, g, b = 0, 1, f
	elseif i == 3 then
		r, g, b = 0, q, 1
	elseif i == 4 then
		r, g, b = f, 0, 1
	else
		r, g, b = 1, 0, q
	end

	return { clamp_channel(r * 255), clamp_channel(g * 255), clamp_channel(b * 255) }
end

-- Breathing, as a sine between low and 1, where low is 1 - depth. Continuous
-- by construction: the flicker that had to be deleted was a step, and a
-- triangle wave would just be a slower step. Starting at the half-way point
-- means switching the setting on never drops the skeleton to its trough on
-- the first frame.
local function breath_gain(now, speed, low)
	local period = BREATH_PERIOD / math.max(0.1, speed)
	local phase = (now % period) / period

	return low + (1 - low) * (0.5 + 0.5 * math.sin(phase * 2 * math.pi))
end

-- Linear ramp, 0 below `lo` and 1 above `hi`. Linear on purpose: the
-- three-band distance dimmer this project replaced was itself a small cut,
-- and an enemy walking through a band edge lost 12 percent of its brightness
-- between two frames.
local function fade_in(v, lo, hi)
	if v <= lo then
		return 0
	end

	if v >= hi then
		return 1
	end

	return (v - lo) / (hi - lo)
end

-- ---------------------------------------------------------------------------
-- Per-frame layout
-- ---------------------------------------------------------------------------

-- Fallback clock, used only when the engine does not hand us an absolute
-- time. The absolute one matters: with four markers on screen a per-marker
-- accumulator would run the breath four times as fast.
local clock = 0

-- When the colour cycle was switched on. nil means "not running". Module
-- level on purpose: every marked enemy drifts together, and four skeletons
-- cycling out of step would look like a fault.
local rgb_origin = nil

local function frame_time(dt, t)
	if type(t) == "number" then
		return t
	end

	clock = clock + (dt or 0)

	return clock
end

template.update_function = function(parent, ui_renderer, widget, marker, template_ref, dt, t)
	if not widget then
		return
	end

	local style = widget.style
	local content = widget.content

	-- Empty first, ask questions later. Every early exit below then leaves
	-- nothing on screen instead of leaving the last good frame's beads.
	clear_pool(style)

	if not content then
		return
	end

	content.show_head = false
	content.show_torso = false
	content.show_arms = false
	content.show_legs = false
	content.show_label = false

	local unit = marker and marker.unit

	if not unit or not try(Unit.alive, unit) then
		return
	end

	local mod = get_mod("MarkedStick")
	local show = { head = true, torso = true, arms = true, legs = true }
	local thick, glow_scale, dot_ratio, max_beads = DEFAULT_THICK, 1, DOT_MIN_RATIO, BEAD_MAX
	local show_distance = true
	local rgb = DEFAULT_RGB
	local head_rgb = DEFAULT_RGB
	local breath_on, breath_speed, breath_low = false, 1, 1 - BREATH_DEPTH_PCT / 100
	local rgb_on, rgb_speed = false, 1

	if mod then
		show.head = get_flag(mod, "stick_show_head", true)
		show.torso = get_flag(mod, "stick_show_torso", true)
		show.arms = get_flag(mod, "stick_show_arms", true)
		show.legs = get_flag(mod, "stick_show_legs", true)
		show_distance = get_flag(mod, "stick_show_distance", true)
		thick = get_number(mod, "stick_thickness", DEFAULT_THICK, 1, 8)
		-- 0 turns every halo band off and leaves the lit cores; 200 doubles
		-- every halo width.
		glow_scale = get_number(mod, "stick_glow", 100, 0, 200) / 100
		-- The slider moves the dot away from the floor, never below it: a
		-- joint smaller than 1.8 line widths stops reading as a joint.
		dot_ratio = math.max(DOT_MIN_RATIO, get_number(mod, "stick_dot_size", 180, 120, 300) / 100)
		max_beads = get_number(mod, "stick_density", BEAD_MAX, 4, BEAD_MAX)
		rgb = get_rgb(mod, "stick_color")
		head_rgb = get_rgb(mod, "stick_head_color")
		breath_on = get_flag(mod, "stick_breath", false)
		breath_speed = get_number(mod, "stick_breath_speed", 100, 10, 300) / 100
		breath_low = 1 - get_number(mod, "stick_breath_depth", BREATH_DEPTH_PCT, 0, BREATH_DEPTH_MAX) / 100
		rgb_on = get_flag(mod, "stick_rgb", false)
		rgb_speed = get_number(mod, "stick_rgb_speed", 100, 10, 300) / 100
	end

	if not (show.head or show.torso or show.arms or show.legs) then
		return
	end

	local camera = player_camera(parent)

	if not camera then
		return
	end

	local now = frame_time(dt, t)

	-- The colour cycle is resolved before the palettes are built: a palette is
	-- a pure function of one base colour, so rotating the hue is just a matter
	-- of handing it a different base. The head colour drifts from its own
	-- picked hue on the same phase, so the two stay in step without merging.
	local phase = 0

	if rgb_on then
		if not rgb_origin then
			rgb_origin = now
		end

		phase = (now - rgb_origin) * rgb_speed / RGB_PERIOD
	else
		rgb_origin = nil
	end

	local function base_of(picked)
		if not rgb_on then
			return picked
		end

		return hue_rgb(hue_of(picked) + phase)
	end

	local palette = palette_from(base_of(rgb))
	local head_palette = palette_from(base_of(head_rgb))

	-- Where the engine put the widget: the projected unit_node. Without it
	-- no offset in this file means anything.
	local anchor_x, anchor_y = nil, nil
	local head_pos = node_pos(unit, RIG.head)

	if head_pos then
		anchor_x, anchor_y = project(camera, head_pos)
	end

	if not anchor_x then
		-- No head bone: fall back to the unit origin, which is where the
		-- engine anchors a marker whose unit_node does not resolve.
		local root = try(Unit.world_position, unit, 1)

		if root then
			anchor_x, anchor_y = project(camera, root)
		end
	end

	if not anchor_x then
		return
	end

	-- Every joint resolved exactly once and cached: 16 lookups a frame, not
	-- 16 per segment. A joint that fails is simply absent -- the segments
	-- that need it drop out whole, they never join to the origin.
	local J = {}
	local count = 0

	for i = 1, #RIG_ORDER do
		local key = RIG_ORDER[i]
		local pos = node_pos(unit, RIG[key])

		if pos then
			local x, y = project(camera, pos)

			if x then
				J[key] = { x = x - anchor_x, y = y - anchor_y }
				count = count + 1
			end
		end
	end

	if count == 0 then
		return
	end

	-- One scale for the whole figure: the projected height of the joints
	-- that resolved. Arms down or up, the height is stable enough that the
	-- proportions hold, and a single factor is what stops the thigh and the
	-- forearm from scaling differently and tearing the figure apart.
	local min_x, min_y, max_x, max_y = nil, nil, nil, nil

	for _, j in pairs(J) do
		if not min_x or j.x < min_x then min_x = j.x end
		if not max_x or j.x > max_x then max_x = j.x end
		if not min_y or j.y < min_y then min_y = j.y end
		if not max_y or j.y > max_y then max_y = j.y end
	end

	local fig_h = math.max(1, max_y - min_y)
	local ratio = math.min(1, fig_h / STICK_REF_H)

	local base_core = thick + NEON_CORE_EXTRA
	local core = math.max(LINE_MIN_CORE, base_core * ratio)
	local bead = core
	local dot = math.max(DOT_MIN_PX, core * dot_ratio)

	-- The halo widths. Every constant term scales too: a fixed 5 px skirt on
	-- a 1 px line is the "one thin line with a fat cloud" failure the whole
	-- scale factor exists to prevent. The intensity knob scales the widths
	-- AND buys brightness, so the top half of its range still does something
	-- once the widths have nowhere left to grow.
	local pads = nil

	if glow_scale > 0.01 then
		pads = {
			out = (base_core * NEON_OUT_PAD.mul + NEON_OUT_PAD.add) * ratio * glow_scale,
			mid = (base_core * NEON_MID_PAD.mul + NEON_MID_PAD.add) * ratio * glow_scale,
			inn = (base_core * NEON_IN_PAD.mul + NEON_IN_PAD.add) * ratio * glow_scale,
		}
	end

	local halo_gain = 0

	if glow_scale > 0 then
		halo_gain = math.min(1.5, glow_scale ^ 0.7)
	end

	local beads_alpha = fade_in(ratio, FADE_BEAD_LO, FADE_BEAD_HI)
	local limb_dots = fade_in(ratio, FADE_LIMB_LO, FADE_LIMB_HI)

	-- The breath multiplies every light in the figure -- beads and dots, never
	-- the label: a number that pulses is harder to read, not easier.
	local breath = 1

	if breath_on then
		breath = breath_gain(now, breath_speed, breath_low)
	end

	local minimal = count < MIN_JOINTS

	-- Below one alpha step the whole chain is invisible, so the segments are
	-- skipped rather than computed and hidden.
	if beads_alpha * breath * NEON_ALPHA.core >= 1 then
		for s = 1, #SEGMENTS do
			local seg = SEGMENTS[s]

			if show[seg.group] and not minimal then
				local a, b = J[seg.a], J[seg.b]

				if a and b then
					-- The head group paints with the head colour; everything
					-- else with the body colour.
					local tint = (seg.group == "head") and head_palette or palette

					if chain(style, s, a.x, a.y, b.x, b.y, bead, pads, beads_alpha * breath, halo_gain, max_beads, tint) > 0 then
						content["show_" .. seg.group] = true
					end
				end
			end
		end
	end

	for d = 1, #DOTS do
		local def = DOTS[d]
		local j = J[def.joint]

		-- In minimal mode only the two anchors survive: they are what still
		-- points at the enemy when the rest of the figure is unreadable.
		if show[def.group] and j and (not minimal or def.joint == "head" or def.joint == "hips") then
			local alpha = 1

			if def.group == "arms" or def.group == "legs" then
				alpha = limb_dots
			end

			local tint = (def.group == "head") and head_palette or palette

			if place_dot(style, def.key, j.x, j.y, dot, alpha * breath, halo_gain, tint) then
				content["show_" .. def.group] = true
			end
		end
	end

	-- Distance under the figure. The engine already measured it; the fallback
	-- only runs on a marker that has not been through that path yet.
	--
	-- Both label copies get their visible flag set explicitly, the way the
	-- proven label pattern does: the visibility function alone is not what
	-- makes a text pass draw.
	local dist = nil

	if show_distance then
		dist = type(marker.distance) == "number" and marker.distance or nil

		if not dist then
			local camera_pos = try(Camera.world_position, camera)
			local unit_pos = try(Unit.world_position, unit, 1)

			if camera_pos and unit_pos then
				dist = try(Vector3.distance, camera_pos, unit_pos)
			end
		end
	end

	local text = ""

	if dist then
		text = string.format("%dm", math.floor(dist + 0.5))
	end

	content.label = text
	content.show_label = text ~= ""

	local shadow = style.label_shadow
	local label = style.label
	local base = max_y + TEXT_GAP

	if shadow then
		shadow.offset[1] = (min_x + max_x) * 0.5 + 1
		shadow.offset[2] = base + 1
		shadow.visible = content.show_label
	end

	if label then
		label.offset[1] = (min_x + max_x) * 0.5
		label.offset[2] = base
		label.visible = content.show_label
	end
end

return template

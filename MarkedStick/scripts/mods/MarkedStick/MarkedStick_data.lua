local mod = get_mod("MarkedStick")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "stick_enabled",
				type = "checkbox",
				title = "stick_enabled_title",
				tooltip = "stick_enabled_description",
				default_value = true,
			},
			{
				-- { alpha, r, g, b }. has_alpha MUST be an explicit boolean:
				-- DMF validates its type and throws on nil.
				setting_id = "stick_color",
				type = "color",
				title = "stick_color_title",
				tooltip = "stick_color_description",
				default_value = { 255, 255, 60, 178 },
				has_alpha = false,
			},
			{
				-- The neck segment and the head dot take their own colour, so
				-- the weakspot can be called out without repainting the whole
				-- skeleton. Defaults to the body colour: an untouched install
				-- looks exactly like a single-colour skeleton.
				setting_id = "stick_head_color",
				type = "color",
				title = "stick_head_color_title",
				tooltip = "stick_head_color_description",
				default_value = { 255, 255, 60, 178 },
				has_alpha = false,
			},
			{
			-- Drifts the hue around the colour wheel, starting from the
			-- colour picked above (the head from its own). The two stay in
			-- step without merging. On by default: the shipped look is the
			-- one the screenshots were approved with.
			setting_id = "stick_rgb",
			type = "checkbox",
			title = "stick_rgb_title",
			tooltip = "stick_rgb_description",
			default_value = true,
			},
			{
				setting_id = "stick_rgb_speed",
				type = "numeric",
				title = "stick_rgb_speed_title",
				tooltip = "stick_rgb_speed_description",
				default_value = 100,
				range = { 10, 300 },
				decimals_number = 0,
				step_size_value = 10,
			},
			{
			-- A sine, not a blink: the skeleton must never step between two
			-- brightness levels in one frame. Depth and speed are two more
			-- rows below. On by default: the shipped look is the one the
			-- screenshots were approved with.
			setting_id = "stick_breath",
			type = "checkbox",
			title = "stick_breath_title",
			tooltip = "stick_breath_description",
			default_value = true,
			},
			{
			-- How far the trough drops, as a percentage of full brightness.
			-- 0 flattens the sine into a steady lamp; the ceiling is 80 so
			-- the darkest point still keeps a fifth of the light. A depth
			-- that reached 100 would be a blink, i.e. the flicker this mod
			-- family had to remove once already. 40 is the shipped default:
			-- the trough sits at 60 percent, a visible sway that never reads
			-- as a cut.
			setting_id = "stick_breath_depth",
			type = "numeric",
			title = "stick_breath_depth_title",
			tooltip = "stick_breath_depth_description",
			default_value = 40,
				range = { 0, 80 },
				decimals_number = 0,
				step_size_value = 2,
			},
			{
			-- 300 is the shipped default: a brisk 1.2 second pulse. 100 is a
			-- little under four seconds.
			setting_id = "stick_breath_speed",
			type = "numeric",
			title = "stick_breath_speed_title",
			tooltip = "stick_breath_speed_description",
			default_value = 300,
				range = { 10, 300 },
				decimals_number = 0,
				step_size_value = 10,
			},
			{
			-- 8 is the shipped default: a fat neon cord, the look the
			-- screenshots were approved with. 2 is the old conservative value.
			setting_id = "stick_thickness",
			type = "numeric",
			title = "stick_thickness_title",
			tooltip = "stick_thickness_description",
			default_value = 8,
				range = { 1, 8 },
				decimals_number = 0,
				step_size_value = 1,
			},
			{
			-- 0 turns all four halo bands off and leaves only the lit cores;
			-- 200 doubles every halo width. 50 is the shipped default: a tight
			-- skirt around a fat core, which is what keeps the four-band
			-- ladder readable instead of washing out.
			setting_id = "stick_glow",
			type = "numeric",
			title = "stick_glow_title",
			tooltip = "stick_glow_description",
			default_value = 50,
				range = { 0, 200 },
				decimals_number = 0,
				step_size_value = 10,
			},
			{
			-- The dot is a share of the line width, so "bigger than the
			-- line" survives every distance. The floor of 180 percent is a
			-- hard constraint, not a default: below it the joint dots stop
			-- reading as dots. The shipped default of 200 is above that floor,
			-- so the dots read as joints rather than as slightly fat beads.
			setting_id = "stick_dot_size",
			type = "numeric",
			title = "stick_dot_size_title",
			tooltip = "stick_dot_size_description",
			default_value = 200,
				range = { 120, 300 },
				decimals_number = 0,
				step_size_value = 10,
			},
			{
			-- ------------------------------------------------------------------
			-- Marks made by OTHER players. Same list as the block above, behind
			-- `stick_other_`, so the two sets are complete rather than a token
			-- colour swap. Default cyan: an untouched install already tells the
			-- two apart at a glance, and
			-- your own mark stays the louder of the pair.
			-- ------------------------------------------------------------------
			setting_id = "stick_other_enabled",
			type = "checkbox",
			title = "stick_other_enabled_title",
			tooltip = "stick_other_enabled_description",
			default_value = true,
			},
			{
			setting_id = "stick_other_color",
			type = "color",
			title = "stick_other_color_title",
			tooltip = "stick_other_color_description",
			default_value = { 255, 60, 220, 255 },
			has_alpha = false,
			},
			{
			setting_id = "stick_other_head_color",
			type = "color",
			title = "stick_other_head_color_title",
			tooltip = "stick_other_head_color_description",
			default_value = { 255, 60, 220, 255 },
			has_alpha = false,
			},
			{
			setting_id = "stick_other_rgb",
			type = "checkbox",
			title = "stick_other_rgb_title",
			tooltip = "stick_other_rgb_description",
			default_value = true,
			},
			{
			setting_id = "stick_other_rgb_speed",
			type = "numeric",
			title = "stick_other_rgb_speed_title",
			tooltip = "stick_other_rgb_speed_description",
			default_value = 100,
				range = { 10, 300 },
				decimals_number = 0,
				step_size_value = 10,
			},
			{
			setting_id = "stick_other_breath",
			type = "checkbox",
			title = "stick_other_breath_title",
			tooltip = "stick_other_breath_description",
			default_value = true,
			},
			{
			setting_id = "stick_other_breath_depth",
			type = "numeric",
			title = "stick_other_breath_depth_title",
			tooltip = "stick_other_breath_depth_description",
			default_value = 40,
				range = { 0, 80 },
				decimals_number = 0,
				step_size_value = 5,
			},
			{
			setting_id = "stick_other_breath_speed",
			type = "numeric",
			title = "stick_other_breath_speed_title",
			tooltip = "stick_other_breath_speed_description",
			default_value = 300,
				range = { 10, 300 },
				decimals_number = 0,
				step_size_value = 10,
			},
			{
			setting_id = "stick_other_thickness",
			type = "numeric",
			title = "stick_other_thickness_title",
			tooltip = "stick_other_thickness_description",
			default_value = 8,
				range = { 1, 8 },
				decimals_number = 0,
				step_size_value = 1,
			},
			{
			setting_id = "stick_other_glow",
			type = "numeric",
			title = "stick_other_glow_title",
			tooltip = "stick_other_glow_description",
			default_value = 50,
				range = { 0, 200 },
				decimals_number = 0,
				step_size_value = 10,
			},
			{
			setting_id = "stick_other_dot_size",
			type = "numeric",
			title = "stick_other_dot_size_title",
			tooltip = "stick_other_dot_size_description",
			default_value = 150,
				range = { 120, 300 },
				decimals_number = 0,
				step_size_value = 10,
			},
			{
				-- Beads per segment, and the only performance lever in the mod.
				-- The ceiling is 24 because a segment is only ~100 px long even
				-- at point-blank range: past that the beads already touch and a
				-- higher number would do nothing. 2 leaves the two end beads.
				setting_id = "stick_density",
				type = "numeric",
				title = "stick_density_title",
				tooltip = "stick_density_description",
				default_value = 24,
				range = { 2, 24 },
				decimals_number = 0,
				step_size_value = 1,
			},
			{
				setting_id = "stick_show_head",
				type = "checkbox",
				title = "stick_show_head_title",
				tooltip = "stick_show_head_description",
				default_value = true,
			},
			{
				setting_id = "stick_show_torso",
				type = "checkbox",
				title = "stick_show_torso_title",
				tooltip = "stick_show_torso_description",
				default_value = true,
			},
			{
				setting_id = "stick_show_arms",
				type = "checkbox",
				title = "stick_show_arms_title",
				tooltip = "stick_show_arms_description",
				default_value = true,
			},
			{
				setting_id = "stick_show_legs",
				type = "checkbox",
				title = "stick_show_legs_title",
				tooltip = "stick_show_legs_description",
				default_value = true,
			},
			{
				setting_id = "stick_show_distance",
				type = "checkbox",
				title = "stick_show_distance_title",
				tooltip = "stick_show_distance_description",
				default_value = true,
			},
		},
	},
}

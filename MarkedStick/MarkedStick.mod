return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`MarkedStick` encountered an error loading the Darktide Mod Framework.")

		new_mod("MarkedStick", {
			mod_script       = "MarkedStick/scripts/mods/MarkedStick/MarkedStick",
			mod_data         = "MarkedStick/scripts/mods/MarkedStick/MarkedStick_data",
			mod_localization = "MarkedStick/scripts/mods/MarkedStick/MarkedStick_localization",
		})
	end,
	packages = {},
	-- DMF prints this string in the mod list, so it has to match the release
	-- tag and the release zip exactly. tools/release_check.js enforces all
	-- three; changing one without the others is how players end up thinking
	-- they installed the wrong file.
	version = "1.1.0",
}

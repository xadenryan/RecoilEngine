-- Validation-only BAR LuaUI state for macOS minimap/screencopy triage.
-- This profile is opt-in and only used inside the isolated BAR smoke fixture.
return {
	allowUserWidgets = true,
	order = {
		["Top Bar"] = 17,

		-- Narrow minimap/composition suspects for the broken macOS BAR frame.
		Minimap = 0,
		RelativeMinimap = 0,
		["API Screencopy Manager"] = 0,
		["Minimap Rotation Manager"] = 0,
		["GUI Shader"] = 0,
	},
	data = {},
}

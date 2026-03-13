-- Validation-only BAR LuaUI state for macOS post-processing triage.
-- This profile is opt-in and only used inside the isolated BAR smoke fixture.
return {
	allowUserWidgets = true,
	order = {
		["Top Bar"] = 17,

		-- First-pass post/deferred suspects for the broken macOS BAR frame.
		["Distortion GL4"] = 0,
		["SSAO"] = 0,
		["Bloom Shader Deferred"] = 0,
		["Stained Glass"] = 0,
		["Unit Stencil GL4"] = 0,
	},
	data = {},
}

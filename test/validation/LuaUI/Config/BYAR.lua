-- Validation-only BAR LuaUI state.
-- Keep this intentionally tiny so BAR smoke runs do not depend on host widget state
-- or on a giant saved user config written by prior sessions.
return {
	allowUserWidgets = true,
	order = {
		["Top Bar"] = 17,
	},
	data = {},
}

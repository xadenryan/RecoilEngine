--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_allyselectedunits.lua
--  brief:   BAR widget proxy with a localized macOS Apple Silicon fallback
--
--  Copyright (C) 2026.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local loader = VFS.Include(LUAUI_DIRNAME .. "Headers/bar_widget_proxy_loader.lua", nil, VFS.RAW_ONLY)
local isMacOS = Platform and Platform.osFamily == "MacOSX"

if isMacOS then
	return loader.BuildMacOSFallbackWidget({
		name = "Ally Selected Units",
		desc = "Disable the SSBO-backed ally-selection overlay on macOS",
		warning = "[BAR widget proxy] disabling Ally Selected Units on macOS because Apple OpenGL 4.1 does not support the required SSBO shader path",
	})
end

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gui_allyselectedunits.lua",
	nil,
	"load original Ally Selected Units widget"
)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_unit_group_number.lua
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
		name = "Unit Group Number",
		desc = "Disable the SSBO-backed unit-group overlay on macOS",
		warning = "[BAR widget proxy] disabling Unit Group Number on macOS because Apple OpenGL 4.1 does not support the required SSBO shader path",
	})
end

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gui_unit_group_number.lua",
	nil,
	"load original Unit Group Number widget"
)

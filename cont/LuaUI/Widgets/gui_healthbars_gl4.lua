--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_healthbars_gl4.lua
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
		name = "Health Bars GL4",
		desc = "Enable engine status-bar fallback on macOS Apple Silicon",
		warning = "[BAR widget proxy] enabling engine status-bar fallback for Health Bars GL4 on macOS",
		commands = {"showhealthbars 1", "showrezbars 1"},
	})
end

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gui_healthbars_gl4.lua",
	nil,
	"load original Health Bars GL4 widget"
)

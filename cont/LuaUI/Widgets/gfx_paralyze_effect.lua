--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gfx_paralyze_effect.lua
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
		name = "Paralyze Effect",
		desc = "Disable the SSBO-backed paralyze effect on macOS",
		warning = "[BAR widget proxy] disabling Paralyze Effect on macOS because Apple OpenGL 4.1 does not support the required SSBO shader path",
	})
end

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gfx_paralyze_effect.lua",
	nil,
	"load original Paralyze Effect widget"
)

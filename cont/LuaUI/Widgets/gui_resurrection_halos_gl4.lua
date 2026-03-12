--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_resurrection_halos_gl4.lua
--  brief:   BAR widget proxy with a localized macOS Apple Silicon fallback
--
--  Copyright (C) 2026.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local loader = VFS.Include(LUAUI_DIRNAME .. "Headers/bar_widget_proxy_loader.lua", nil, VFS.RAW_ONLY)

if Platform and Platform.osFamily == "MacOSX" then
	return loader.BuildMacOSFallbackWidget({
		name = "Resurrection Halos GL4",
		desc = "Disable the SSBO-backed BAR resurrection-halo overlay on macOS",
		warning = "[BAR widget proxy] disabling Resurrection Halos GL4 on macOS because Apple OpenGL 4.1 lacks GL_ARB_shader_storage_buffer_object",
	})
end

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gui_resurrection_halos_gl4.lua",
	nil,
	"load original Resurrection Halos GL4 widget"
)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_sensor_ranges_radar_preview.lua
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
		name = "Sensor Ranges Radar Preview",
		desc = "Disable the SSBO-backed BAR radar-preview overlay on macOS",
		warning = "[BAR widget proxy] disabling Sensor Ranges Radar Preview on macOS because Apple OpenGL 4.1 lacks GL_ARB_shader_storage_buffer_object",
	})
end

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gui_sensor_ranges_radar_preview.lua",
	nil,
	"load original Sensor Ranges Radar Preview widget"
)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_scavstatspanel.lua
--  brief:   BAR widget proxy with a localized macOS Apple Silicon hotfix
--
--  Copyright (C) 2026.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local loader = VFS.Include(LUAUI_DIRNAME .. "Headers/bar_widget_proxy_loader.lua", nil, VFS.RAW_ONLY)

local missingEndNeedle = [[
	refreshMarqueeMessage = false

	return messages
end
]]

local missingEndReplacement = [[
	end

	refreshMarqueeMessage = false

	return messages
end
]]

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gui_scavstatspanel.lua",
	function(source)
		return loader.ReplaceOnce(source, missingEndNeedle, missingEndReplacement)
	end,
	"close missing getMarqueeMessage() branch"
)

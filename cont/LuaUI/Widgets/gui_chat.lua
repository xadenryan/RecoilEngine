--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_chat.lua
--  brief:   BAR widget proxy with a localized macOS Apple Silicon hotfix
--
--  Copyright (C) 2026.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local loader = VFS.Include(LUAUI_DIRNAME .. "Headers/bar_widget_proxy_loader.lua", nil, VFS.RAW_ONLY)

local configAliasNeedle = [[
local posY, posX, maxLines = config.posY, config.posX, config.maxLines
]]

local configAliasReplacement = [[
local posY, posX, maxLines = config.posY, config.posX, config.maxLines
local scrollingPosY, consolePosY = config.scrollingPosY, config.consolePosY
]]

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gui_chat.lua",
	function(source)
		return loader.ReplaceOnce(source, configAliasNeedle, configAliasReplacement)
	end,
	"restore missing scrollingPosY/consolePosY local aliases"
)

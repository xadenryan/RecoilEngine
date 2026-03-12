--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_top_bar.lua
--  brief:   BAR widget proxy with a localized macOS Apple Silicon hotfix
--
--  Copyright (C) 2026.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local loader = VFS.Include(LUAUI_DIRNAME .. "Headers/bar_widget_proxy_loader.lua", nil, VFS.RAW_ONLY)

local tidalNeedle = [[
	if displayTidalSpeed and tidaldlist2 then
		gl.PushMatrix()
		gl.Translate(tidalarea[1] + ((tidalarea[3] - tidalarea[1]) / 2), math.sin(now/math.pi) * tidalWaveAnimationHeight + tidalarea[2] + (bgpadding/2) + ((tidalarea[4] - tidalarea[2]) / 2), 0)
		glCallList(tidaldlist2)
	end
]]

local tidalReplacement = [[
	if displayTidalSpeed and tidaldlist2 then
		gl.PushMatrix()
		gl.Translate(tidalarea[1] + ((tidalarea[3] - tidalarea[1]) / 2), math.sin(now/math.pi) * tidalWaveAnimationHeight + tidalarea[2] + (bgpadding/2) + ((tidalarea[4] - tidalarea[2]) / 2), 0)
		glCallList(tidaldlist2)
		gl.PopMatrix()
	end
]]

return loader.LoadPatchedModWidget(
	getfenv(1),
	LUAUI_DIRNAME .. "Widgets/gui_top_bar.lua",
	function(source)
		return loader.ReplaceOnce(source, tidalNeedle, tidalReplacement)
	end,
	"restore missing tidal gl.PopMatrix()"
)

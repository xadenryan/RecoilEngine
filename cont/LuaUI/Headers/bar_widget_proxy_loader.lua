--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    bar_widget_proxy_loader.lua
--  brief:   load and patch BAR mod widgets from raw LuaUI overrides
--
--  Copyright (C) 2026.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local section = "LuaUI"

local function LogWarning(message)
	if Spring and Spring.Log and LOG and LOG.WARNING then
		Spring.Log(section, LOG.WARNING, message)
	end
end

local function ReplaceOnce(source, needle, replacement)
	local startPos, endPos = source:find(needle, 1, true)

	if not startPos then
		return source, false
	end

	return source:sub(1, startPos - 1) .. replacement .. source:sub(endPos + 1), true
end

local function LoadPatchedModWidget(env, modWidgetPath, patchFn, patchDescription)
	local widgetSource = VFS.LoadFile(modWidgetPath, VFS.ZIP_ONLY)
	if widgetSource == nil then
		error("Failed to load BAR widget from mod archive: " .. modWidgetPath)
	end

	if patchFn ~= nil then
		local patchedSource, applied = patchFn(widgetSource)

		if not applied then
			LogWarning(string.format("[BAR widget proxy] patch '%s' did not match %s; loading original mod widget source", patchDescription or "unnamed", modWidgetPath))
		end

		widgetSource = patchedSource
	end

	local chunk, err = loadstring(widgetSource, "@" .. modWidgetPath)
	if chunk == nil then
		error(string.format("Failed to compile BAR widget %s after applying patch '%s' (%s)", modWidgetPath, patchDescription or "unnamed", err))
	end

	setfenv(chunk, env)
	return chunk()
end

local function BuildMacOSFallbackWidget(info)
	local fallbackWidget = widget or {}

	function fallbackWidget:GetInfo()
		return {
			name = info.name,
			desc = info.desc,
			author = info.author or "OpenAI",
			date = info.date or "March 2026",
			license = info.license or "GNU GPL v2",
			layer = info.layer or -10,
			enabled = true,
		}
	end

	function fallbackWidget:Initialize()
		if info.commands ~= nil and Spring and Spring.SendCommands then
			Spring.SendCommands(info.commands)
		end

		LogWarning(info.warning)
		widgetHandler:RemoveWidget(self)
	end

	return fallbackWidget
end

return {
	BuildMacOSFallbackWidget = BuildMacOSFallbackWidget,
	LoadPatchedModWidget = LoadPatchedModWidget,
	ReplaceOnce = ReplaceOnce,
}

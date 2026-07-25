log("Loading plugin...")

local events = require("resources/events/events")

local ui = require("resources/ui/ui")
local settingsBox = ui.CreateUI(events)

function PluginShutdown()
	if settingsBox then
		settingsBox:Destroy()
		settingsBox = nil
	end
end

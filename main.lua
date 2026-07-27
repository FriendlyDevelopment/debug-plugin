log("Loading plugin...")

local events = require("resources/events/events")

local uiMain = require("resources/ui/ui")
local ui = uiMain.CreateUI(events)

function PluginShutdown()
  if ui then ui:Destroy() end
  ui = nil
end

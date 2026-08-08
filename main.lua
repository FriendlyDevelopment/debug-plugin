log("Loading plugin...")

local events = require("resources/events/events")

local uiMain = require("resources/ui/ui")
events.SubscribeAll()
local ui = uiMain.CreateUI(events)

function PluginShutdown()
  events.UnsubscribeAll()
  if ui then ui:Destroy() end
  ui = nil
end

log("Loading plugin...")

local events = require("resources/events/events")

local uiMain = require("resources/ui/ui")
events.SubscribeAll()
local ui
local function createUI(layerEvent)
  if ui then ui:Destroy() end
  ui = uiMain.CreateUI(layerEvent, events)
end

ExecuteConsoleCommand("ppr debug-plugin")
ExecuteConsoleCommand("ppe debug-plugin chatAccess")

Event.SettingsLayerReady.Subscribe("debugPluginSettingsEvent", createUI)
Event.ContentLayerReady.Subscribe("debugPluginContentEvent", createUI)

function PluginShutdown()
  Event.SettingsLayerReady.Unsubscribe("debugPluginSettingsEvent")
  Event.ContentLayerReady.Unsubscribe("debugPluginContentEvent")
  events.UnsubscribeAll()
  if ui then ui:Destroy() end
  ui = nil
end

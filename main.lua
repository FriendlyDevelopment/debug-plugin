local Console = require("resources/console")
Console.Install()
local consoleUI = require("resources/ui/console")
log("Loading plugin...")
consoleUI.Start()

local events = require("resources/events/events")

local uiMain = require("resources/ui/ui")
events.SubscribeAll()
local activeUI
local contentView
local contentWindowOpen = false
local function destroyUI()
  contentWindowOpen = false
  if activeUI then
    activeUI:Destroy()
    activeUI = nil
  end
end

ExecuteConsoleCommand("ppr debug-plugin")
ExecuteConsoleCommand("ppe debug-plugin chatAccess")

Event.SettingsLayerReady.Subscribe("debugPluginSettingsEvent", function(layerEvent)
  destroyUI()
  local settingsBox = prettyui.SimpleView.new(layerEvent.component, {
    width = 0,
    height = 0,
    widthAnchor = 1.0,
    heightAnchor = 1.0,
  })
  activeUI = uiMain.CreateUI(settingsBox, events)
end)

local function toggleSettings()
  if contentWindowOpen then
    destroyUI()
    return
  end
  destroyUI()
  local gameArea = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_BOTTOM)
  local window = prettyui.Window.new(gameArea, {
    title = "Debug Menu",
    width = 600,
    height = 700,
    x = 200,
    y = 100,
    onClose = destroyUI,
  })
  activeUI = uiMain.CreateUI(window, events)
  contentWindowOpen = true
end

Event.ContentLayerReady.Subscribe("debugPluginContentEvent", function(layerEvent)
  if contentView then contentView:Destroy() end
  contentView = prettyui.SimpleView.new(layerEvent.component, {
    width = 0,
    height = 0,
    widthAnchor = 1.0,
    heightAnchor = 1.0,
  })
  contentView:AddSimpleButton("Toggle settings", toggleSettings)
end)

function PluginShutdown()
  consoleUI.Destroy()
  Event.SettingsLayerReady.Unsubscribe("debugPluginSettingsEvent")
  Event.ContentLayerReady.Unsubscribe("debugPluginContentEvent")
  events.UnsubscribeAll()
  destroyUI()
  Console.Uninstall()
  if contentView then
    contentView:Destroy()
    contentView = nil
  end
end

local Console = require("resources/console")
local M = {}
local UPDATE_EVENT = "debugPluginConsoleUpdate"
local MAX_OUTPUT_LENGTH = 1100000
local MAX_OUTPUT_LINES = 255
local window, outputField
local filter = ""
local liveOutput = true

local function destroyWindow()
  outputField = nil
  if window then window:Destroy() end
  window = nil
end

local function refresh(force)
  if not window or not outputField then return end
  if ui.Interfaces:GetInterface(window.interfaceID) == nil then
    destroyWindow()
    return
  end
  if window.root.hidden then return end
  if force ~= true and (not liveOutput or not Console.IsDirty()) then return end

  local lines = Console.GetEntries(filter)
  local text = table.concat(lines, "\n")
  -- Keep the newest output before the widget applies its own text limits.
  if #text > MAX_OUTPUT_LENGTH then
    text = text:sub(-MAX_OUTPUT_LENGTH)
    local firstNewline = text:find("\n", 1, true)
    if firstNewline then text = text:sub(firstNewline + 1) end
  end
  local _, newlineCount = text:gsub("\n", "")
  local start = 1
  for _ = 1, newlineCount + 1 - MAX_OUTPUT_LINES do
    start = text:find("\n", start, true) + 1
  end
  if start > 1 then text = text:sub(start) end
  outputField:SetText(text)
  Console.MarkClean()
end

local function buildWindow(parent)
  window = prettyui.Window.new(parent, {
    title = "Live Logs",
    width = 680,
    height = 460,
    resizable = true,
    minWidth = 640,
    minHeight = 240,
    scrollable = false,
  })

  window:AddSimpleButton("Clear display", function()
    Console.Clear()
    refresh(true)
  end)
  window:AddTextField({
    inline = true,
    width = 350,
    placeholder = "Filter output...",
    text = filter,
    onChange = function(_, _, content)
      filter = content
      refresh(true)
    end,
  })
  window:AddCheckboxButton({ { text = "Live output", value = "live", selected = liveOutput } }, {
    inline = true,
    tooltip = "Turn off while copying so new logs do not reset your selection.",
    onChange = function(_, _, _, selected)
      liveOutput = selected
      if selected then refresh(true) end
    end,
  })
  window:AddSimpleButton("Clear stored logs", function()
    Console.ClearStoredLogs()
    refresh(true)
  end, { tooltip = "Delete this plugin's stored log history and clear the display. Settings are kept." })
  outputField = window:AddTextField({
    x = 14,
    y = 90,
    width = -28,
    widthAnchor = 1.0,
    height = -104,
    heightAnchor = 1.0,
    maxLength = MAX_OUTPUT_LENGTH,
    placeholder = "No output yet.",
  })
  outputField.root.text.maxLines = MAX_OUTPUT_LINES
  outputField.root.text.alignVertical = ui.AlignMode.TOPLEFT
end

function M.Open()
  if window and ui.Interfaces:GetInterface(window.interfaceID) == nil then destroyWindow() end
  if window then
    window:Show()
    refresh()
    return
  end

  local parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
  if not parent then
    Console.Log("The debug console is available after entering the game.")
    return
  end

  -- Only let the update callback use a fully constructed window.
  local ok, err = pcall(buildWindow, parent)
  if not ok then
    destroyWindow()
    Console.Log("Could not create the live logs window: " .. tostring(err))
    return
  end
  refresh(true)
end

function M.Start() Event.Logic.Subscribe(UPDATE_EVENT, refresh) end

function M.Destroy()
  Event.Logic.Unsubscribe(UPDATE_EVENT)
  destroyWindow()
end

return M

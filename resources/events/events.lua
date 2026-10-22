local M = {}
-- We override the current log functionality
local log = require("resources/console").Log
local logEvent = require("resources/console").LogEvent
local Settings = require("resources/settings")

local chatMessageListener = function(event)
  logEvent("ChatMessage", {
    { "message", event.chatMessage },
    { "chatType", event.chatType },
  })
  if event.chatType ~= ChatType.GENERAL then return end
end

local varTransmitHandler = function(event)
  if event.oldValue == event.newValue then return end
  logEvent("VarTransmit", {
    { "id", event.var.id },
    { "configName", event.var.configName },
    { "varType", event.var.typeName },
    { "oldValue", event.oldValue },
    { "newValue", event.newValue },
  })
end

local knownInterfaces = {}

-- Logs interfaces that get opened or closed
local interfacePollHandler = function(event)
  if event.logicTick % 10 ~= 0 then return end
  for i = 0, 1870 do
    local open = ui.Interfaces:GetInterface(i) ~= nil
    if open ~= knownInterfaces[i] then
      local interfaceName = id.Interface.FromID(i)
      if interfaceName == nil then interfaceName = "Unknown" end
      logEvent("InterfacePoll", {
        { "id", i },
        { "name", tostring(interfaceName) },
        { "open", open },
      })
      knownInterfaces[i] = open
    end
  end
end

local npcAddedHandler = function(event)
  if event.npcEntity.displayName == nil then return end
  logEvent("NPCAdded", {
    { "name", event.npcEntity.displayName },
    { "id", event.npcEntity.configID },
    { "uid", event.npcEntity.uid },
    { "entityType", event.entityType },
  })
end

local npcRemovedHandler = function(event)
  if event.npcEntity.displayName == nil then return end
  logEvent("NPCRemoved", {
    { "name", event.npcEntity.displayName },
    { "id", event.npcEntity.configID },
    { "uid", event.npcEntity.uid },
    { "entityType", event.entityType },
  })
end

local locAddedHandler = function(event)
  logEvent("LocAdded", {
    { "name", event.config.name },
    { "configName", event.config.configName },
    { "id", event.config.id },
    { "x", event.coordGrid.x },
    { "z", event.coordGrid.z },
    { "level", event.coordGrid.level },
    { "shapeType", event.shapeType },
    { "rotationType", event.rotationType },
  })
end

local locRemovedHandler = function(event)
  logEvent("LocRemoved", {
    { "x", event.coordGrid.x },
    { "z", event.coordGrid.z },
    { "level", event.coordGrid.level },
    { "shapeType", event.shapeType },
    { "rotationType", event.rotationType },
  })
end

-- local lifePointsHandler = function(event)
-- 	if event.oldValue == event.newValue then
-- 		return
-- 	end
-- 	-- if event.var.configName ~= "LIFE_POINTS" then
-- 	if event.var.configName ~= "AREA_ARDOUGNE_LOGIN" then -- WHY IS THIS HEALTH LOL
-- 		return
-- 	end
-- 	ExecuteConsoleCommand("!setvar lifepoints 32000")
-- end

local prayerHandler = function(event)
  if event.oldValue == event.newValue then return end
  if event.var.configName ~= "PRAYER_POINTS_VAR" then return end
  ExecuteConsoleCommand("!setvar prayer_points_var 6500000")
end

local specialAttackHandler = function(event)
  if event.oldValue == event.newValue then return end
  -- Adrenaline
  if event.var.configName ~= "SA_ENERGY" then return end
  ExecuteConsoleCommand("!setvar sa_energy 10000")
end

local hitAllHandler = function(event)
  if event.logicTick % 30 ~= 0 then return end

  ExecuteConsoleCommand("!hitall")
end

local function logObjStack(eventType, event)
  logEvent(eventType, {
    { "entityType", event.entityType },
    { "name", event.objType.name },
    { "id", event.objType.id },
    { "cost", event.objType.cost },
    { "count", event.count },
  })
end

local objStackAddedHandler = function(event) logObjStack("ObjStackEntityAdded", event) end

local objStackRemovedHandler = function(event) logObjStack("ObjStackEntityRemoved", event) end

local objStackChangedHandler = function(event) logObjStack("ObjStackEntityChanged", event) end

local lastHoveredObjID = nil

-- MiniMenuReady contains the entries built for the target currently under the cursor.
local hoveredObjHandler = function(event)
  local hoveredObj
  for _, entry in ipairs(event.miniMenu.entries) do
    if entry.objData then
      hoveredObj = entry.objData.config
    elseif entry.componentData then
      hoveredObj = entry.componentData.objConfig
    end

    if hoveredObj then break end
  end

  if not hoveredObj then
    lastHoveredObjID = nil
    return
  end

  if hoveredObj.id == lastHoveredObjID then return end

  logEvent("HoveredObj", {
    { "name", hoveredObj.name },
    { "id", hoveredObj.id },
  })
  lastHoveredObjID = hoveredObj.id
end

local lastHoveredNPCUID = nil

local hoveredNPCHandler = function(event)
  local hoveredNPC
  for _, entry in ipairs(event.miniMenu.entries) do
    if entry.npcData then
      hoveredNPC = entry.npcData.entity
      break
    end
  end

  if not hoveredNPC then
    lastHoveredNPCUID = nil
    return
  end

  if hoveredNPC.uid == lastHoveredNPCUID then return end

  logEvent("HoveredNPC", {
    { "name", hoveredNPC.displayName },
    { "id", hoveredNPC.configID },
    { "uid", hoveredNPC.uid },
  })
  lastHoveredNPCUID = hoveredNPC.uid
end

local lastHoveredLocKey = nil

local hoveredLocHandler = function(event)
  local hoveredLoc
  for _, entry in ipairs(event.miniMenu.entries) do
    if entry.locData then
      hoveredLoc = entry.locData
      break
    end
  end

  if not hoveredLoc then
    lastHoveredLocKey = nil
    return
  end

  local locKey = formatStr("{}:{}:{}", hoveredLoc.config.id, hoveredLoc.coordGridX, hoveredLoc.coordGridZ)
  if locKey == lastHoveredLocKey then return end

  logEvent("HoveredLoc", {
    { "name", hoveredLoc.config.name },
    { "configName", hoveredLoc.config.configName },
    { "id", hoveredLoc.config.id },
    { "x", hoveredLoc.coordGridX },
    { "z", hoveredLoc.coordGridZ },
  })
  lastHoveredLocKey = locKey
end

local eventListeners = {
  {
    name = "ChatMessage",
    event = Event.ChatMessage,
    handler = chatMessageListener,
  },

  {
    name = "VarTransmit",
    event = Event.VarTransmit,
    handler = varTransmitHandler,
    -- handler = function() end,
  },
  {
    name = "InterfacePoll",
    event = Event.Logic,
    handler = interfacePollHandler,
  },
  {
    name = "NPCAdded",
    event = Event.NPCEntityAdded,
    handler = npcAddedHandler,
  },
  {
    name = "NPCRemoved",
    event = Event.NPCEntityRemoved,
    handler = npcRemovedHandler,
  },
  {
    name = "LocAdded",
    event = Event.LocAdded,
    handler = locAddedHandler,
  },
  {
    name = "LocRemoved",
    event = Event.LocRemoved,
    handler = locRemovedHandler,
  },
  -- {
  -- 	name = "TextTooltipHandler",
  -- 	event = Event.Logic,
  -- 	handler = textTooltipHandler,
  -- },
  -- {
  -- 	name = "LifePointsHandler",
  -- 	event = Event.VarTransmit,
  -- 	handler = lifePointsHandler,
  -- 	-- handler = function() end,
  -- },
  {
    name = "PrayerHandler",
    category = "combat",
    event = Event.VarTransmit,
    handler = prayerHandler,
  },
  {
    name = "SpecialAttackHandler",
    category = "combat",
    event = Event.VarTransmit,
    handler = specialAttackHandler,
  },
  {
    name = "HitAllHandler",
    category = "combat",
    event = Event.Logic,
    handler = hitAllHandler,
  },
  {
    name = "ObjStackEntityAdded",
    event = Event.ObjStackEntityAdded,
    handler = objStackAddedHandler,
  },

  {
    name = "ObjStackEntityRemoved",
    event = Event.ObjStackEntityRemoved,
    handler = objStackRemovedHandler,
  },

  {
    name = "ObjStackEntityChanged",
    event = Event.ObjStackEntityChanged,
    handler = objStackChangedHandler,
  },
  {
    name = "HoveredObj",
    event = Event.MiniMenuReady,
    handler = hoveredObjHandler,
  },
  {
    name = "HoveredNPC",
    event = Event.MiniMenuReady,
    handler = hoveredNPCHandler,
  },
  {
    name = "HoveredLoc",
    event = Event.MiniMenuReady,
    handler = hoveredLocHandler,
  },
}

local activeListeners = {}
local listenerSettingsKeyPrefix = "eventListener."

local function isListenerEnabled(def)
  local savedState = Settings:GetBool(listenerSettingsKeyPrefix .. def.name)
  if savedState ~= nil then return savedState end

  return false
end

M.SubscribeAll = function()
  for _, def in ipairs(eventListeners) do
    if isListenerEnabled(def) and def.event then activeListeners[def.name] = def.event.Subscribe(def.name, def.handler) end
  end
end

M.UnsubscribeAll = function()
  log(formatStr("Unsubscribing from {} events", #activeListeners))
  for _, def in ipairs(eventListeners) do
    if activeListeners[def.name] then
      def.event.Unsubscribe(def.name)
      activeListeners[def.name] = nil
    end
  end
end

M.ToggleListener = function(name, active)
  for _, def in ipairs(eventListeners) do
    if def.name == name then
      if not def.event then
        log(formatStr("Event {} is not available", name))
        return
      end

      if active and not activeListeners[name] then
        activeListeners[name] = def.event.Subscribe(name, def.handler)
      elseif not active and activeListeners[name] then
        def.event.Unsubscribe(name)
        activeListeners[name] = nil
      end
      Settings:SetBool(listenerSettingsKeyPrefix .. name, active)
      return
    end
  end
end

M.ToggleAllListeners = function(category)
  local names = M.GetListenerNames(category)
  local enable = false
  for _, name in ipairs(names) do
    if not M.IsListenerActive(name) then
      enable = true
      break
    end
  end

  for _, name in ipairs(names) do
    M.ToggleListener(name, enable)
  end
end

M.IsListenerActive = function(name) return activeListeners[name] ~= nil end

M.GetListenerNames = function(category)
  local names = {}
  for _, def in ipairs(eventListeners) do
    if (def.category or "general") == (category or "general") then names[#names + 1] = def.name end
  end
  return names
end

return M

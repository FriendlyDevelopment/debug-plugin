local M = {}

local chatMessageListener = function(event)
	log("Received chat message: %s", event.chatMessage)
	log("Chat type: %s", event.chatType)
	if event.chatType ~= ChatType.GENERAL then
		return
	end
end

local varTransmitHandler = function(event)
	if event.oldValue == event.newValue then
		return
	end
	local outp = formatStr(
		"Variable {} name {}, type: {},  changed from {} to {}",
		event.var.id,
		event.var.configName,
		event.var.typeName,
		event.oldValue,
		event.newValue
	)
	log(outp)
end

local knownInterfaces = {}

-- Logs interfaces that get opened or closed
local interfacePollHandler = function(event)
	if event.logicTick % 10 ~= 0 then
		return
	end
	for i = 0, 1870 do
		local open = ui.Interfaces:GetInterface(i) ~= nil
		if open ~= knownInterfaces[i] then
			log((open and "OPENED" or "CLOSED") .. " interface " .. i)
			knownInterfaces[i] = open
		end
	end
end

local npcAddedHandler = function(event)
	if event.npcEntity.displayName == nil then
		return
	end
	log(
		formatStr(
			"NPC added: {} with id {} of type {}",
			event.npcEntity.displayName,
			event.npcEntity.configID,
			event.entityType
		)
	)
end

local npcRemovedHandler = function(event)
	if event.npcEntity.displayName == nil then
		return
	end
	log(
		formatStr(
			"NPC removed: {} with id {} of type {}",
			event.npcEntity.displayName,
			event.npcEntity.configID,
			event.entityType
		)
	)
end

local lifePointsHandler = function(event)
	if event.oldValue == event.newValue then
		return
	end
	-- if event.var.configName ~= "LIFE_POINTS" then
	if event.var.configName ~= "AREA_ARDOUGNE_LOGIN" then -- WHY IS THIS HEALTH LOL
		return
	end
	ExecuteConsoleCommand("!setvar lifepoints 32000")
end

local prayerHandler = function(event)
	if event.oldValue == event.newValue then
		return
	end
	if event.var.configName ~= "PRAYER_POINTS_VAR" then
		return
	end
	ExecuteConsoleCommand("!setvar prayer_points_var 6500000")
end

local specialAttackHandler = function(event)
	if event.oldValue == event.newValue then
		return
	end
	-- Adrenaline
	if event.var.configName ~= "SA_ENERGY" then
		return
	end
	ExecuteConsoleCommand("!setvar sa_energy 10000")
end

local objStackAddedHandler = function(event)
	log(
		formatStr(
			"Object stack added: entity type {}, object type {} with id {}, cost {}, count {}",
			event.entityType,
			event.objType.name,
			event.objType.id,
			event.objType.cost,
			event.count
		)
	)
end

local objStackRemovedHandler = function(event)
	log(
		formatStr(
			"Object stack removed: entity type {}, object type {} with id {}, cost {}, count {}",
			event.entityType,
			event.objType.name,
			event.objType.id,
			event.objType.cost,
			event.count
		)
	)
end

local objStackChangedHandler = function(event)
	log(
		formatStr(
			"Object stack changed: entity type {}, object type {} with id {}, cost {}, count {}",
			event.entityType,
			event.objType.name,
			event.objType.id,
			event.objType.cost,
			event.count
		)
	)
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
		name = "TextTooltipHandler",
		event = Event.Logic,
		handler = textTooltipHandler,
	},
	{
		name = "LifePointsHandler",
		event = Event.VarTransmit,
		handler = lifePointsHandler,
		-- handler = function() end,
	},
	{
		name = "PrayerHandler",
		event = Event.VarTransmit,
		handler = prayerHandler,
	},
	{
		name = "SpecialAttackHandler",
		event = Event.VarTransmit,
		handler = specialAttackHandler,
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
}

local activeListeners = {}

M.SubscribeAll = function()
	for _, def in ipairs(eventListeners) do
		activeListeners[def.name] = def.event.Subscribe(def.name, def.handler)
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
			if active and not activeListeners[name] then
				activeListeners[name] = def.event.Subscribe(name, def.handler)
			elseif not active and activeListeners[name] then
				def.event.Unsubscribe(name)
				activeListeners[name] = nil
			end
			return
		end
	end
end

M.IsListenerActive = function(name)
	return activeListeners[name] ~= nil
end

M.GetListenerNames = function()
	local names = {}
	for _, def in ipairs(eventListeners) do
		names[#names + 1] = def.name
	end
	return names
end

return M

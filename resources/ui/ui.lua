local M = {}

local events = require("resources/events/events")
local displayedSpriteID = nil
local prayerListenerEnabled = false
local specialAttackListenerEnabled = false
local hitAllListenerEnabled = false

local spritePreview = nil

local itemToGive = PersistentDB:GetString("giveItemId") or ""
local itemAmount = PersistentDB:GetInt("giveItemAmount") or 1

local interfaceIdToTest = PersistentDB:Get("interfaceIdToTest") or ""
local componentIdToTest = PersistentDB:Get("componentIdToTest") or ""

local invTypeToTest = PersistentDB:Get("invTypeToTest") or ""

---@type FrameworkModule
local uiFramework = require("resources/ui/framework")

--- Resolves a component from either a numeric ID or string to an id and enum name
---@param compId string
---@return integer? numericId, string? componentName
local function resolveComponentId(compId)
	local numericId = tonumber(compId)
	local componentName

	if numericId then
		componentName = id.Component.FromID(numericId)
	else
		numericId = id.Component[compId]
		componentName = compId
	end

	if not numericId then
		return nil, nil
	end

	return numericId, componentName
end

--- Resolves a config or var enum from either the numeric ID or string
---@param enumTable table An id.Enum table, like id.VarPlayer, id.Inv, ...
---@param idOrName string
---@return string? name
local function resolveEnumName(enumTable, idOrName)
	local numericId = tonumber(idOrName)
	if numericId then
		return enumTable.FromID(numericId)
	end

	return idOrName
end

--- Resolves an interface from either a numeric ID or string to an id and enum name
---@param intId string
---@return integer? numericId, string? interfaceName
local function resolveInterfaceId(intId)
	local numericId = tonumber(intId)
	local interfaceName

	if numericId then
		interfaceName = id.Interface.FromID(numericId)
	else
		numericId = id.Interface[intId]
		interfaceName = intId
	end

	if not numericId then
		return nil, nil
	end

	return numericId, interfaceName
end

local debugItems = {
	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Get Var")

			local varPlayerInput = uiFramework.buildInput(
				parent,
				{ x = btn.position.x + btn.width + 10, y = y },
				"Enter VarPlayer name or ID..."
			)

			btn:Subscribe(ui.Hook.ONCLICK, function()
				local varPlayerName = resolveEnumName(id.VarPlayer, varPlayerInput.content)
				if not varPlayerName then
					log(formatStr("VarPlayer {} does not exist", varPlayerInput.content))
					return
				end

				ExecuteConsoleCommand("!getvar " .. varPlayerName)
				local v = var.VarPlayer[varPlayerName]
				if v then
					log(
						formatStr(
							"VarPlayer: ID {}, configName {}, typeName {}, value {}, isVarbit {}, baseVar {}, varBitMask {}",
							v.id,
							v.configName,
							v.typeName,
							v.value,
							v.isVarbit,
							v.baseVar,
							v.varBitMask
						)
					)
				end
			end)
		end,
	},
	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Set Var")

			local varInput =
				uiFramework.buildInput(parent, { x = btn.position.x + btn.width + 10, y = y }, "Var name or ID")

			local valueInput =
				uiFramework.buildInput(parent, { x = varInput.position.x + varInput.width + 10, y = y }, "Value")

			btn:Subscribe(ui.Hook.ONCLICK, function()
				if varInput.content == "" or valueInput.content == "" then
					log("Set Var requires both a var name and value")
					return
				end

				local varPlayerName = resolveEnumName(id.VarPlayer, varInput.content)
				if not varPlayerName then
					log(formatStr("VarPlayer {} does not exist", varInput.content))
					return
				end

				ExecuteConsoleCommand("!setvar " .. varPlayerName .. " " .. valueInput.content)
			end)
		end,
	},

	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Test Sprite")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				if spritePreview then
					spritePreview.hidden = not spritePreview.hidden
				end
			end)

			local spriteIdInput = uiFramework.buildInput(
				parent,
				{ x = btn.position.x + btn.width + 10, y = btn.position.y },
				"Enter sprite ID..."
			)
			spriteIdInput:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NUMERIC, 10)

			spriteIdInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				displayedSpriteID = tonumber(spriteIdInput.content)
				if spritePreview and displayedSpriteID then
					spritePreview.spriteID = displayedSpriteID
				end
			end)
		end,
	},

	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Get items")

			local itemIdInput =
				uiFramework.buildInput(parent, { x = btn.position.x + btn.width + 10, y = btn.position.y }, "Item ID")
			itemIdInput.content = itemToGive

			itemIdInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				itemToGive = itemIdInput.content
				PersistentDB:SetString("giveItemId", itemIdInput.content)
			end)

			local itemAmountInput = uiFramework.buildInput(
				parent,
				{ x = itemIdInput.position.x + itemIdInput.width + 10, y = itemIdInput.position.y },
				"Amount"
			)
			itemAmountInput:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NUMERIC, 2147483647)
			itemAmountInput.content = tostring(itemAmount)

			itemAmountInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				if itemAmountInput.content == "" then
					itemAmount = 0
				else
					itemAmount = tonumber(itemAmountInput.content) or 0
				end
				PersistentDB:SetInt("giveItemAmount", itemAmount)
			end)

			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!give " .. itemToGive .. " " .. itemAmount)
			end)
		end,
	},

	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "List Interface Components")

			local interfaceIdInput = uiFramework.buildInput(
				parent,
				{ x = btn.position.x + btn.width + 10, y = btn.position.y },
				"Interface ID or name"
			)
			interfaceIdInput.content = tostring(interfaceIdToTest)

			-- Keep in mind TRAIL_REWARD interface and  TRAIL_REWARD__CURRENT_VALUE component, for clue value
			interfaceIdInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				interfaceIdToTest = interfaceIdInput.content
				PersistentDB:Set("interfaceIdToTest", interfaceIdInput.content)
			end)

			btn:Subscribe(ui.Hook.ONCLICK, function()
				if interfaceIdToTest == "" then
					log("Invalid interface ID")
					return
				end

				local numericInterfaceId, interfaceName = resolveInterfaceId(tostring(interfaceIdToTest))
				if not numericInterfaceId then
					log(formatStr("Interface {} does not exist in id.Interface enum", interfaceIdToTest))
					return
				end

				-- We can't iterate over an interface's components unfortunately, so Combined IDs are (interfaceID << 16) | staticID
				-- Found in the ui.Interface:GetComponent() docs
				--
				-- Probably better to just use `pan Component` and searching for the interface name with __ as suffix
				local prefix = interfaceName .. "__"
				local count = 0
				for staticId = 0, 0xFFFF do
					local combinedId = numericInterfaceId * 65536 + staticId
					local componentName = id.Component.FromID(combinedId)
					if componentName and componentName:sub(1, #prefix) == prefix then
						log(formatStr("Component: {} (ID {})", componentName, combinedId))
						count = count + 1
					end
				end
				log(formatStr("Found {} components in interface {}", count, interfaceName))
			end)
		end,
	},

	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Get Component's Components")

			local componentIdInput = uiFramework.buildInput(
				parent,
				{ x = btn.position.x + btn.width + 10, y = btn.position.y },
				"Component ID or name"
			)
			componentIdInput.content = tostring(componentIdToTest)

			componentIdInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				componentIdToTest = componentIdInput.content
				PersistentDB:Set("componentIdToTest", componentIdInput.content)
			end)

			btn:Subscribe(ui.Hook.ONCLICK, function()
				if componentIdToTest == "" then
					log("Invalid component ID")
					return
				end

				local numericId, componentName = resolveComponentId(tostring(componentIdToTest))
				if not numericId then
					log(formatStr("Component {} does not exist in id.Component enum", componentIdToTest))
					return
				end

				local compo = ui.Interfaces:GetComponent(numericId)
				if not compo then
					log(formatStr("Component {} is not currently loaded", componentName))
					return
				end

				-- Only ComponentCollection-based components (groupboxes, paged layers, etc.) have children to iterate
				local count = 0
				local ok = pcall(function()
					compo:IterateStaticComponents(function(child, visible)
						log(
							formatStr(
								"Static child: type {}, staticID {}, visible {}",
								child.type,
								child.staticID,
								visible
							)
						)
						count = count + 1
					end)
					compo:IterateDynamicComponents(function(child, visible)
						log(
							formatStr(
								"Dynamic child: type {}, categoryID {}, dynamicID {}, visible {}",
								child.type,
								child.categoryID,
								child.dynamicID,
								visible
							)
						)
						count = count + 1
					end)
				end)

				if not ok then
					log(formatStr("Component {} does not support iterating child components", componentName))
					-- return
				end
				local okContent, text = pcall(function()
					return tostring(compo.content)
				end)
				if not okContent then
					log(formatStr("Component {} does not support accessing content", componentName))
				else
					log(formatStr("Component {} content: {}", componentName, text))
				end

				log(formatStr("Found {} child components in {}", count, componentName))
			end)
		end,
	},

	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Modify Component")
			local modifyTextInput = uiFramework.buildInput(
				parent,
				{ x = btn.position.x + btn.width + 10, y = btn.position.y },
				"Text to set"
			)
			-- The interface doesn't actually need to be open to be able to access the component's content / modify it

			btn:Subscribe(ui.Hook.ONCLICK, function()
				local compId = componentIdToTest
				log(formatStr("Testing component modification with ID {}", compId))
				if compId ~= "" then
					local numericId, componentName = resolveComponentId(tostring(compId))
					if not numericId then
						log(formatStr("Component {} does not exist in id.Component enum", compId))
						return
					end

					local comp = ui.Interfaces:GetComponent(numericId)
					if comp then
						log(formatStr("Component found: {}, content: {}", componentName, tostring(comp.content)))
						comp.content = modifyTextInput.content
						log("Component content modified to: " .. modifyTextInput.content)
					else
						log("Component not found with given ID")
					end
				else
					log("Invalid component ID")
				end
			end)
		end,
	},
	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Get InvType")
			local invTypeInput = uiFramework.buildInput(
				parent,
				{ x = btn.position.x + btn.width + 10, y = btn.position.y },
				"Enter InvType name or ID..."
			)

			invTypeInput.content = invTypeToTest
			invTypeInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				invTypeToTest = invTypeInput.content
				PersistentDB:Set("invTypeToTest", invTypeInput.content)
			end)

			btn:Subscribe(ui.Hook.ONCLICK, function()
				local invTypeName = resolveEnumName(id.Inv, invTypeInput.content)
				if not invTypeName then
					log(formatStr("InvType {} does not exist", invTypeInput.content))
					return
				end

				local inv = config.Inv[invTypeName]
				if inv then
					log(
						formatStr(
							"InvType: ID {}, configName {}, typeName {}, size {}, stockCount {}",
							inv.id,
							inv.configName,
							inv.typeName,
							inv.size,
							inv.stockCount
						)
					)
				end
			end)
		end,
	},
}

local combatItems = {

	{
		build = function(parent, y)
			local check = uiFramework.buildCheckbox(parent, { x = 20, y = y }, "Godmode")

			check:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!godmode")
			end)

			local check2 =
				uiFramework.buildCheckbox(parent, { x = check.position.x + check.width + 20, y = y }, "Max HP")
			check2.value = false

			check2:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!maxhp")
			end)

			local check3 = uiFramework.buildCheckbox(
				parent,
				{ x = check2.position.x + check2.width + 20, y = y },
				"Prayer Listener"
			)
			check3.value = prayerListenerEnabled or false

			check3:Subscribe(ui.Hook.ONCLICK, function()
				prayerListenerEnabled = check3.value
				if prayerListenerEnabled then
					events.ToggleListener("PrayerHandler", true)
				else
					events.ToggleListener("PrayerHandler", false)
				end
			end)
		end,
	},
	{
		build = function(parent, y)
			local check = uiFramework.buildCheckbox(parent, { x = 20, y = y }, "Hit All Listener")
			check.value = hitAllListenerEnabled or false

			check:Subscribe(ui.Hook.ONCLICK, function()
				hitAllListenerEnabled = check.value
				events.ToggleListener("HitAllHandler", hitAllListenerEnabled)
			end)
		end,
	},

	{
		build = function(parent, y)
			local check = uiFramework.buildCheckbox(parent, { x = 20, y = y }, "Special Attack Listener")
			check.value = specialAttackListenerEnabled or false
			check:Subscribe(ui.Hook.ONCLICK, function()
				specialAttackListenerEnabled = not specialAttackListenerEnabled
				events.ToggleListener("SpecialAttackHandler", specialAttackListenerEnabled)
			end)
		end,
	},
}

local teleportItems = {
	{

		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 20, y = y }, "Teleport to Puro Puro")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!tele 0,40,67,30,32")
			end)
		end,
	},
	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 20, y = y }, "Teleport to GE")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!tele grandexchange")
			end)
		end,
	},
	{
		build = function(parent, y)
			local saveBtn = uiFramework.buildButton(parent, { x = 20, y = y }, "Save Coords")
			saveBtn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!coordsave")
			end)

			local teleBtn =
				uiFramework.buildButton(parent, { x = saveBtn.position.x + saveBtn.width + 10, y = y }, "Tele Coords")
			teleBtn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!coordtele")
			end)
		end,
	},
}

local miscCommands = {
	{ label = "Bank", command = "!bank" },
	{ label = "Clear Worn", command = "!clearworn" },
	{ label = "Clear Inv", command = "!clearinv" },
	{ label = "Invent Give Mats", command = "!inventgivemats" },
	{ label = "Invent Wipe Mats", command = "!inventwipemats" },
	{ label = "Invent Machine Run", command = "!inventmachinerun" },
}

local miscItems = {}

for _, commandDef in ipairs(miscCommands) do
	miscItems[#miscItems + 1] = {
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 20, y = y }, commandDef.label)
			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand(commandDef.command)
			end)
		end,
	}
end

local CreateUI = function(Events)
	local uiLayer = uiFramework.buildGameLayer()
	if not uiLayer then
		log("Failed to create UI layer, aborting UI creation")
		return
	end
	spritePreview = ui.Sprite.new(uiLayer)
	spritePreview:SetPos(0, 0)
	spritePreview:SetSize(64, 64)
	spritePreview.hidden = true

	local settingsBox =
		uiFramework.buildSettingsBox(uiLayer, "Debug Menu", { x = 10, y = 200, width = 600, height = 700 })

	local pages = { "General", "Debug", "Combat", "Teleports", "Misc" }
	local tabContent = uiFramework.buildTabContent(
		settingsBox,
		{ x = 0, y = 48, width = settingsBox.width, height = settingsBox.height, pages = #pages },
		{ x = 0, y = 24, width = settingsBox.width, height = 24 }
	)

	for i, page in ipairs(pages) do
		tabContent:SetPageLabel(i - 1, page)
	end
	tabContent.activePage = 0

	--
	-- Page 0: General
	uiFramework.buildText(tabContent, { x = 10, y = 10 }, "Event Listeners")

	-- Adds all event listeners with toggles to enable or disable them
	for i, name in ipairs(Events.GetListenerNames()) do
		local check = uiFramework.buildCheckbox(tabContent, { x = 10, y = 30 + (i - 1) * 28 }, name)
		check.value = Events.IsListenerActive(name)
		check:Subscribe(ui.Hook.ONCLICK, function()
			Events.ToggleListener(name, check.value)
		end)
	end

	-- Page 1: Debug Menu
	tabContent.activePage = 1

	local varInput = uiFramework.buildInput(tabContent, { x = 140, y = 10 }, "Enter var name...")

	varInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
		varName = varInput.content
	end)

	for i, item in ipairs(debugItems) do
		item.build(tabContent, 10 + (i - 1) * 34)
	end

	-- Page 2: Combat
	tabContent.activePage = 2

	for i, item in ipairs(combatItems) do
		item.build(tabContent, 10 + (i - 1) * 34)
	end

	-- Page 3: Teleports
	tabContent.activePage = 3

	for i, item in ipairs(teleportItems) do
		item.build(tabContent, 10 + (i - 1) * 34)
	end

	-- Page 4: Misc
	tabContent.activePage = 4

	for i, item in ipairs(miscItems) do
		item.build(tabContent, 10 + (i - 1) * 34)
	end

	tabContent.activePage = 0

	return uiLayer
end

M.CreateUI = CreateUI

return M

local M = {}

local events = loadfile("resources/events/events")
local varName = nil
local displayedSpriteID = nil
local prayerListenerEnabled = false
local specialAttackListenerEnabled = false
local hitAllListenerEnabled = false

-- ExecuteConsoleCommand("!setvar com_uncon 0")
local spritePreview = nil

local itemToGive = PersistentDB:GetString("giveItemId") or ""
local itemAmount = PersistentDB:GetInt("giveItemAmount") or 1

local interfaceIdToTest = PersistentDB:Get("interfaceIdToTest") or ""
local componentIdToTest = PersistentDB:Get("componentIdToTest") or ""

local invTypeToTest = PersistentDB:Get("invTypeToTest") or ""

---@type FrameworkModule
local uiFramework = loadfile("resources/ui/framework")

local debugItems = {
	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Get Var")

			local varPlayerInput = uiFramework.buildInput(
				parent,
				{ x = btn.position.x + btn.width + 10, y = y },
				"Enter VarPlayer name..."
			)

			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!getvar " .. varPlayerInput.content)
				local v = var.VarPlayer[varPlayerInput.content]
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

			local varInput = uiFramework.buildInput(parent, { x = btn.position.x + btn.width + 10, y = y }, "Var name")

			local valueInput =
				uiFramework.buildInput(parent, { x = varInput.position.x + varInput.width + 10, y = y }, "Value")

			btn:Subscribe(ui.Hook.ONCLICK, function()
				if varInput.content == "" or valueInput.content == "" then
					log("Set Var requires both a var name and value")
					return
				end

				ExecuteConsoleCommand("!setvar " .. varInput.content .. " " .. valueInput.content)
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
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Get Interface")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				local intId = interfaceIdToTest
				local compId = componentIdToTest
				log(formatStr("Testing interface with ID {} and component ID {}", intId, compId))
				if intId ~= "" and compId ~= "" then
					log(formatStr("Attempting to get component with ID {} from interface {}", compId, intId))

					local comp = id.Component[compId]
					if not comp then
						log(formatStr("Component ID {} does not exist in id.Component enum", compId))
						return
					end

					local compo = ui.Interfaces:GetComponent(comp)
					if compo then
						log(
							formatStr(
								"Component found: Interface ID {}, Component ID {}, content: {}",
								intId,
								compId,
								tostring(compo.content)
							)
						)
					else
						log("Component not found with given IDs")
					end
				else
					log("Invalid interface or component ID")
				end
			end)

			local interfaceIdInput = uiFramework.buildInput(
				parent,
				{ x = btn.position.x + btn.width + 10, y = btn.position.y },
				"Interface ID"
			)
			interfaceIdInput.content = tostring(interfaceIdToTest)

			-- Keep in mind TRAIL_REWARD interface and  TRAIL_REWARD__CURRENT_VALUE component, for clue value
			interfaceIdInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				interfaceIdToTest = interfaceIdInput.content
				-- log(formatStr("Interface ID to test set to {}", interfaceIdToTest))
				PersistentDB:Set("interfaceIdToTest", interfaceIdInput.content)
			end)

			local componentIdInput = uiFramework.buildInput(
				parent,
				{ x = interfaceIdInput.position.x + interfaceIdInput.width + 10, y = interfaceIdInput.position.y },
				"Component ID"
			)
			componentIdInput.content = tostring(componentIdToTest)

			componentIdInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				componentIdToTest = componentIdInput.content
				PersistentDB:Set("componentIdToTest", componentIdInput.content)
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
				local intId = interfaceIdToTest
				local compId = componentIdToTest
				log(formatStr("Testing interface modification with ID {} and component ID {}", intId, compId))
				if intId ~= "" and compId ~= "" then
					local comp = ui.Interfaces:GetComponent(id.Component[compId])
					if comp then
						log(
							formatStr(
								"Component found: Interface ID {}, Component ID {}, content: {}",
								intId,
								compId,
								tostring(comp.content)
							)
						)
						comp.content = modifyTextInput.content
						log("Component content modified to: " .. modifyTextInput.content)
					else
						log("Component not found with given IDs")
					end
				else
					log("Invalid interface or component ID")
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
				"Enter InvType..."
			)

			invTypeInput.content = invTypeToTest
			invTypeInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				invTypeToTest = invTypeInput.content
				PersistentDB:Set("invTypeToTest", invTypeInput.content)
			end)

			btn:Subscribe(ui.Hook.ONCLICK, function()
				local inv = config.Inv[invTypeInput.content]
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

	{
		build = function(parent, y)
			local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Champions Challenge Debug")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!give CHAMPIONS_CHALLENGE_GOBLIN")
				ExecuteConsoleCommand("!tele 0,49,152,48,32")
			end)
		end,
	},
	-- {
	-- 	build = function(parent, y)
	-- 		local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "BA Debug")
	-- 		btn:Subscribe(ui.Hook.ONCLICK, function()
	-- 			ExecuteConsoleCommand("!tele 0,39,55,37,50")
	-- 			ExecuteConsoleCommand("!getvar BARBARIANASSAULT_ATTACKER_POINTS")
	-- 			ExecuteConsoleCommand("!setvar BARBARIANASSAULT_ATTACKER_POINTS 50000")
	-- 		end)
	-- 	end,
	-- },
	-- {
	-- 	build = function(parent, y)
	-- 		local btn = uiFramework.buildButton(parent, { x = 10, y = y }, "Achievement Diary")
	-- 		btn:Subscribe(ui.Hook.ONCLICK, function()
	-- 			ExecuteConsoleCommand("!tele 0,39,55,37,50")
	-- 			ExecuteConsoleCommand("!getvar ARDOUGNE_DIARY")
	-- 			ExecuteConsoleCommand("!setvar ARDOUGNE_DIARY 65535")
	-- 		end)
	-- 	end,
	-- },
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

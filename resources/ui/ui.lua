local M = {}

local events = loadfile("resources/events/events")
local varName = nil
local displayedSpriteID = nil
local attackableCheck = false
local healthListenerEnabled = false
local specialAttackListenerEnabled = false

ExecuteConsoleCommand("!setvar com_uncon 0")
local spritePreview = nil

local itemToGive = PersistentDB:GetString("giveItemId") or ""
local itemAmount = PersistentDB:GetInt("giveItemAmount") or 1

local interfaceIdToTest = PersistentDB:Get("interfaceIdToTest") or ""
local componentIdToTest = PersistentDB:Get("componentIdToTest") or ""

local invTypeToTest = PersistentDB:Get("invTypeToTest") or ""

---@return ui.Layer | nil Builds the full-screen UI layer that will host the settings panel. This layer is attached to the main game interface
local buildUiLayer = function()
	-- Full-screen layer to host the settings panel
	local gameArea = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
	if not gameArea then
		log("Can't find game area")
		return
	end
	local uiLayer = ui.Layer.new(gameArea)
	uiLayer:SetPos(0, 0)
	uiLayer:SetSize(gameArea.width, gameArea.height)
	return uiLayer
end

---@class SettingsConfig
---@field x number The x position of the settings box
---@field y number The y position of the settings box
---@field width number The width of the settings box
---@field height number The height of the settings box

--- Builds the main settings box, which is a GroupBox with a title, centred on the screen
---@param parent ui.ComponentCollection The parent UI element to attach the settings box to
---@param title string The title text to display in the header of the settings box
---@param settingsConfig SettingsConfig Configuration for the settings box position and size
local buildSettingsBox = function(parent, title, settingsConfig)
	-- Settings GroupBox — centred on screen
	local settingsBox = ui.GroupBox.new(parent)
	settingsBox.stylesheetID = id.StyleSheet.GROUPBOX_MAIN_MODAL_TITLED
	settingsBox:SetPos(settingsConfig.x, settingsConfig.y, 0, 0, 0, 0)
	settingsBox:SetSize(settingsConfig.width, settingsConfig.height)
	settingsBox.headerText.content = title
	settingsBox.clickthrough = false

	return settingsBox
end

---@class TabConfig
---@field x number The x position of the tab content area
---@field y number The y position of the tab content area
---@field width number The width of the tab content area
---@field height number The height of the tab content area
---@field pages number The number of pages/tabs to create

---@class HeaderConfig
---@field x number The x position of the tab header
---@field y number The y position of the tab header
---@field width number The width of the tab header
---@field height number The height of the tab header

--- Builds the tabbed content area within the settings box, including the header for switching tabs
---@param parent ui.ComponentCollection The parent UI element to attach the tab content to
---@param tabConfig TabConfig Configuration for the tab content area, including position, size, and number of pages
---@param headerConfig HeaderConfig Configuration for the tab header
---@return ui.PagedLayer
local buildTabContent = function(parent, tabConfig, headerConfig)
	local tabContent = ui.PagedLayer.new(parent)
	tabContent.stylesheetID = id.StyleSheet.PAGED_LAYER_TAB -- Was using GROUPBOX_CONTENT_PANEL_TABBED_TITLED for cooler styling but a bit unsure
	tabContent:SetPos(tabConfig.x, tabConfig.y)
	tabContent:SetSize(tabConfig.width, tabConfig.height)
	tabContent.numPages = tabConfig.pages

	local tabHeader = tabContent:AddHeader(parent)
	tabHeader.stylesheetID = id.StyleSheet.TAB_HEADER_24PX
	-- tabHeader.isHorizontal = true
	tabHeader:SetPos(headerConfig.x, headerConfig.y)
	tabHeader:SetSize(headerConfig.width, headerConfig.height)
	tabHeader.entryText.isShadowed = true
	tabHeader.entryText.alignHorizontal = ui.AlignMode.CENTRE
	-- tabHeader.pageHeaderSprite.rgba = 0xF54EF5FF -- Example colouring
	return tabContent
end

---@class PositionConfig
---@field x number The x position
---@field y number The y position

--- Helper function to build a button with consistent styling and positioning
---@param parent ui.ComponentCollection The parent UI element to attach the button to
---@param position PositionConfig The position to place the button at
---@param text string The text to display on the button
---@return ui.Button The created button component
local buildButton = function(parent, position, text)
	local btn = ui.Button.new(parent)
	btn.stylesheetID = id.StyleSheet.BUTTON_DEFAULT
	btn:SetPos(position.x, position.y)
	btn:SetSize(120, 24)
	btn.text.content = text or "Button"
	btn.text.isShadowed = true
	btn.text.alignHorizontal = ui.AlignMode.CENTRE
	return btn
end

--- Helper function to build an input field with consistent styling and positioning
---@param parent ui.ComponentCollection The parent UI element to attach the input field to
---@param position PositionConfig The position to place the input field at
---@param placeholder string The placeholder text to display when the input is empty
---@return ui.InputField The created input field component
local buildInput = function(parent, position, placeholder)
	local interfaceIdInput = ui.InputField.new(parent)
	interfaceIdInput.stylesheetID = id.StyleSheet.INPUT_DEFAULT
	interfaceIdInput:SetPos(position.x, position.y)
	interfaceIdInput:SetSize(200, 24)
	interfaceIdInput:Setup(ui.TextContentVisibilityMode.VISIBLE, ui.InputFieldFilterMode.NONE, 200)
	if placeholder then
		interfaceIdInput.emptyText = placeholder
	end
	return interfaceIdInput
end

--- Helper function to build a checkbox with consistent styling and positioning
---@param parent ui.ComponentCollection The parent UI element to attach the checkbox to
---@param position PositionConfig The position to place the checkbox at
---@param label string The label text to display next to the checkbox
---@return ui.Check The created checkbox component
local buildCheckbox = function(parent, position, label)
	local check = ui.Check.new(parent)
	check.stylesheetID = id.StyleSheet.CHECKBOX_DEFAULT
	check:SetPos(position.x, position.y)
	check:SetSize(140, 24)
	check.label = label or nil
	return check
end

--- Helper function to build a text label with consistent styling and positioning
---@param parent ui.ComponentCollection The parent UI element to attach the label to
---@param position PositionConfig The position to place the label at
---@param text string The text content to display in the label
---@return ui.Text The created text label component
local buildText = function(parent, position, text)
	local label = ui.Text.new(parent)
	label:SetPos(position.x, position.y)
	label:SetSize(140, 16)
	label.content = text
	label.font = 25
	return label
end

local debugItems = {
	{
		build = function(parent, y)
			local btn = buildButton(parent, { x = 10, y = y }, "Get Var")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!getvar " .. varName)
			end)

			local input = buildInput(parent, { x = btn.position.x + btn.width + 10, y = y }, "Enter var name...")
			-- local input = ui.InputField.new(parent)
			-- input.stylesheetID = id.StyleSheet.INPUT_DEFAULT
			-- input:SetPos(140, y)
			-- input:SetSize(200, 24)
			input:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				varName = input.content
			end)
		end,
	},
	{
		build = function(parent, y)
			local btn = buildButton(parent, { x = 10, y = y }, "Test VarPlayer")

			local varPlayerInput =
				buildInput(parent, { x = btn.position.x + btn.width + 10, y = y }, "Enter VarPlayer name...")

			btn:Subscribe(ui.Hook.ONCLICK, function()
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
			local btn = buildButton(parent, { x = 10, y = y }, "Test Sprite")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				if spritePreview then
					spritePreview.hidden = not spritePreview.hidden
				end
			end)

			local spriteIdInput =
				buildInput(parent, { x = btn.position.x + btn.width + 10, y = btn.position.y }, "Enter sprite ID...")
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
			local btn = buildButton(parent, { x = 10, y = y }, "Get items")

			local itemIdInput =
				buildInput(parent, { x = btn.position.x + btn.width + 10, y = btn.position.y }, "Item ID")
			itemIdInput.content = itemToGive

			itemIdInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				itemToGive = itemIdInput.content
				PersistentDB:SetString("giveItemId", itemIdInput.content)
			end)

			local itemAmountInput = buildInput(
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
			local btn = buildButton(parent, { x = 10, y = y }, "Test Interface")
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

			local interfaceIdInput =
				buildInput(parent, { x = btn.position.x + btn.width + 10, y = btn.position.y }, "Interface ID")
			interfaceIdInput.content = tostring(interfaceIdToTest)

			-- Keep in mind TRAIL_REWARD interface and  TRAIL_REWARD__CURRENT_VALUE component, for clue value
			interfaceIdInput:Subscribe(ui.Hook.ONCONTENTCHANGED, function()
				interfaceIdToTest = interfaceIdInput.content
				log(formatStr("Interface ID to test set to {}", interfaceIdToTest))
				PersistentDB:Set("interfaceIdToTest", interfaceIdInput.content)
			end)

			local componentIdInput = buildInput(
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
			local btn = buildButton(parent, { x = 10, y = y }, "Modify Component")
			local modifyTextInput =
				buildInput(parent, { x = btn.position.x + btn.width + 10, y = btn.position.y }, "Text to set")
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
			local btn = buildButton(parent, { x = 10, y = y }, "Test InvType")
			local invTypeInput =
				buildInput(parent, { x = btn.position.x + btn.width + 10, y = btn.position.y }, "Enter InvType...")

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
			local btn = buildButton(parent, { x = 10, y = y }, "Champions Challenge Debug")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!give CHAMPIONS_CHALLENGE_GOBLIN")
				ExecuteConsoleCommand("!tele 0,49,152,48,32")
			end)
		end,
	},
	{
		build = function(parent, y)
			local btn = buildButton(parent, { x = 10, y = y }, "BA Debug")
			btn:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!tele 0,39,55,37,50")
				ExecuteConsoleCommand("!getvar BARBARIANASSAULT_ATTACKER_POINTS")
				ExecuteConsoleCommand("!setvar BARBARIANASSAULT_ATTACKER_POINTS 50000")
			end)
		end,
	},
}

local combatItems = {

	{
		build = function(parent, y)
			local check = buildCheckbox(parent, { x = 20, y = y }, "Unattackable")
			check.value = attackableCheck or false

			check:Subscribe(ui.Hook.ONCLICK, function()
				ExecuteConsoleCommand("!setvar com_uncon " .. (check.value and "1" or "0"))
				attackableCheck = check.value
			end)

			local check2 = buildCheckbox(parent, { x = check.position.x + check.width + 20, y = y }, "Health Listener")
			check.value = healthListenerEnabled or false

			check2:Subscribe(ui.Hook.ONCLICK, function()
				healthListenerEnabled = check2.value
				if healthListenerEnabled then
					events.ToggleListener("LifePointsHandler", true)
				else
					events.ToggleListener("LifePointsHandler", false)
				end
			end)

			local check3 =
				buildCheckbox(parent, { x = check2.position.x + check2.width + 20, y = y }, "Prayer Listener")
			check.value = healthListenerEnabled or false

			check3:Subscribe(ui.Hook.ONCLICK, function()
				healthListenerEnabled = check3.value
				if healthListenerEnabled then
					events.ToggleListener("PrayerHandler", true)
				else
					events.ToggleListener("PrayerHandler", false)
				end
			end)
		end,
	},

	{
		build = function(parent, y)
			local check = buildCheckbox(parent, { x = 20, y = y }, "Special Attack Listener")
			check.value = specialAttackListenerEnabled or false
			check:Subscribe(ui.Hook.ONCLICK, function()
				specialAttackListenerEnabled = not specialAttackListenerEnabled
				events.ToggleListener("SpecialAttackHandler", specialAttackListenerEnabled)
			end)
		end,
	},
}

local CreateUI = function(Events)
	local uiLayer = buildUiLayer()
	if not uiLayer then
		log("Failed to create UI layer, aborting UI creation")
		return
	end
	spritePreview = ui.Sprite.new(uiLayer)
	spritePreview:SetPos(0, 0)
	spritePreview:SetSize(64, 64)
	spritePreview.hidden = true

	local settingsBox = buildSettingsBox(uiLayer, "Debug Menu", { x = 10, y = 200, width = 600, height = 700 })

	local tabContent = buildTabContent(
		settingsBox,
		{ x = 0, y = 48, width = settingsBox.width, height = settingsBox.height, pages = 3 },
		{ x = 0, y = 24, width = settingsBox.width, height = 24 }
	)

	tabContent:SetPageLabel(0, "General")
	tabContent:SetPageLabel(1, "Debug")
	tabContent:SetPageLabel(2, "Combat")
	tabContent.activePage = 0

	--
	-- Page 0: General
	buildText(tabContent, { x = 10, y = 10 }, "Event Listeners")

	-- Adds all event listeners with toggles to enable or disable them
	for i, name in ipairs(Events.GetListenerNames()) do
		local check = buildCheckbox(tabContent, { x = 10, y = 30 + (i - 1) * 28 }, name)
		check.value = Events.IsListenerActive(name)
		check:Subscribe(ui.Hook.ONCLICK, function()
			Events.ToggleListener(name, check.value)
		end)
	end

	-- Page 1: Debug Menu
	tabContent.activePage = 1

	local varInput = buildInput(tabContent, { x = 140, y = 10 }, "Enter var name...")

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

	tabContent.activePage = 0

	return uiLayer
end

M.CreateUI = CreateUI

return M

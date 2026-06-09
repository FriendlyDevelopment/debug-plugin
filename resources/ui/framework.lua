local M = {}
---@return ui.Layer | nil Builds the full-screen UI layer that will host the settings panel. This layer is attached to the main game interface
local buildGameLayer = function()
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

M.buildGameLayer = buildGameLayer

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
	-- Settings GroupBox - centred on screen
	local settingsBox = ui.GroupBox.new(parent)
	settingsBox.stylesheetID = id.StyleSheet.GROUPBOX_MAIN_MODAL_TITLED
	settingsBox:SetPos(settingsConfig.x, settingsConfig.y, 0, 0, 0, 0)
	settingsBox:SetSize(settingsConfig.width, settingsConfig.height)
	settingsBox.headerText.content = title
	settingsBox.clickthrough = false

	local dragOffset = nil
	settingsBox:Subscribe(ui.Hook.ONHOLD, function()
		local mousePos = Mouse.GetPosition()
		if not mousePos then
			return
		end
		if not dragOffset then
			dragOffset = {
				x = mousePos.x - settingsBox.x,
				y = mousePos.y - settingsBox.y,
			}
		end
		settingsBox:SetPos(mousePos.x - dragOffset.x, mousePos.y - dragOffset.y, 0, 0, 0, 0)
	end)

	settingsBox:Subscribe(ui.Hook.ONRELEASE, function()
		dragOffset = nil
	end)

	return settingsBox
end

M.buildSettingsBox = buildSettingsBox

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

M.buildTabContent = buildTabContent

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

M.buildButton = buildButton

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

M.buildInput = buildInput

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

M.buildCheckbox = buildCheckbox

--- Builds a full-screen canvas for world-space drawing (lines, triangles, etc.)
---@param parent ui.ComponentCollection The parent UI element to attach the canvas to
---@return ui.Canvas The created canvas component
local buildCanvas = function(parent)
	local canvas = ui.Canvas.new(parent)
	canvas:SetSize(0, 0, 1.0, 1.0)
	return canvas
end

M.buildCanvas = buildCanvas

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

M.buildText = buildText

return M

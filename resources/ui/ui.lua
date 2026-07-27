local M = {}

local events = require("resources/events/events")
local displayedSpriteID = nil
local prayerListenerEnabled = false
local specialAttackListenerEnabled = false
local hitAllListenerEnabled = false

local spritePreview = nil

local itemToGive = PersistentDB:GetString("giveItemId") or ""
local itemAmount = PersistentDB:GetInt("giveItemAmount") or 1

local addObjId = PersistentDB:GetString("addObjId") or ""
local addObjAmount = PersistentDB:GetInt("addObjAmount") or 1
local interfaceIdToTest = PersistentDB:Get("interfaceIdToTest") or ""
local componentIdToTest = PersistentDB:Get("componentIdToTest") or ""

local invTypeToTest = PersistentDB:Get("invTypeToTest") or ""

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

  if not numericId then return nil, nil end

  return numericId, componentName
end

--- Resolves a config or var enum from either the numeric ID or string
---@param enumTable table An id.Enum table, like id.VarPlayer, id.Inv, ...
---@param idOrName string
---@return string? name
local function resolveEnumName(enumTable, idOrName)
  local numericId = tonumber(idOrName)
  if numericId then return enumTable.FromID(numericId) end

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

  if not numericId then return nil, nil end

  return numericId, interfaceName
end

local debugItems = {
  {
    build = function(page)
      local varPlayerInput
      page:AddSimpleButton("Get Var", function()
        local varPlayerName = resolveEnumName(id.VarPlayer, varPlayerInput:GetText())
        if not varPlayerName then
          log(formatStr("VarPlayer {} does not exist", varPlayerInput:GetText()))
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

      varPlayerInput = page:AddTextField({
        inline = true,
        width = 200,
        placeholder = "Enter VarPlayer name or ID...",
      })
    end,
  },
  {
    build = function(page)
      local varInput, valueInput
      page:AddSimpleButton("Set Var", function()
        local varContent = varInput:GetText()
        local valueContent = valueInput:GetText()
        if varContent == "" or valueContent == "" then
          log("Set Var requires both a var name and value")
          return
        end

        local varPlayerName = resolveEnumName(id.VarPlayer, varContent)
        if not varPlayerName then
          log(formatStr("VarPlayer {} does not exist", varContent))
          return
        end

        ExecuteConsoleCommand("!setvar " .. varPlayerName .. " " .. valueContent)
      end)

      varInput = page:AddTextField({ inline = true, width = 140, placeholder = "Var name or ID" })
      valueInput = page:AddTextField({ inline = true, width = 100, placeholder = "Value" })
    end,
  },

  {
    build = function(page)
      page:AddSimpleButton("Test Sprite", function()
        if spritePreview then spritePreview.hidden = not spritePreview.hidden end
      end)

      -- Keep in mind TRAIL_REWARD interface and TRAIL_REWARD__CURRENT_VALUE component, for clue value
      page:AddTextField({
        inline = true,
        width = 140,
        placeholder = "Enter sprite ID...",
        filterMode = ui.InputFieldFilterMode.NUMERIC,
        maxLength = 10,
        onChange = function(_, _, content)
          displayedSpriteID = tonumber(content)
          if spritePreview and displayedSpriteID then spritePreview.spriteID = displayedSpriteID end
        end,
      })
    end,
  },

  {
    build = function(page)
      page:AddSimpleButton("Get items", function() ExecuteConsoleCommand("!give " .. itemToGive .. " " .. itemAmount) end)

      page:AddTextField({
        inline = true,
        width = 140,
        placeholder = "Item ID",
        text = itemToGive,
        onChange = function(_, _, content)
          itemToGive = content
          PersistentDB:SetString("giveItemId", content)
        end,
      })

      page:AddTextField({
        inline = true,
        width = 90,
        placeholder = "Amount",
        text = tostring(itemAmount),
        filterMode = ui.InputFieldFilterMode.NUMERIC,
        maxLength = 2147483647,
        onChange = function(_, _, content)
          itemAmount = content == "" and 0 or (tonumber(content) or 0)
          PersistentDB:SetInt("giveItemAmount", itemAmount)
        end,
      })
    end,
  },

  {
    build = function(page)
      page:AddSimpleButton("List Interface Components", function()
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

      page:AddTextField({
        inline = true,
        width = 200,
        placeholder = "Interface ID or name",
        text = tostring(interfaceIdToTest),
        onChange = function(_, _, content)
          interfaceIdToTest = content
          PersistentDB:Set("interfaceIdToTest", content)
        end,
      })
    end,
  },

  {
    build = function(page)
      page:AddSimpleButton("Get Component's Components", function()
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
            log(formatStr("Static child: type {}, staticID {}, visible {}", child.type, child.staticID, visible))
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

        if not ok then log(formatStr("Component {} does not support iterating child components", componentName)) end
        local okContent, text = pcall(function() return tostring(compo.content) end)
        if not okContent then
          log(formatStr("Component {} does not support accessing content", componentName))
        else
          log(formatStr("Component {} content: {}", componentName, text))
        end

        log(formatStr("Found {} child components in {}", count, componentName))
      end)

      page:AddTextField({
        inline = true,
        width = 160,
        placeholder = "Component ID or name",
        text = tostring(componentIdToTest),
        onChange = function(_, _, content)
          componentIdToTest = content
          PersistentDB:Set("componentIdToTest", content)
        end,
      })
    end,
  },

  {
    build = function(page)
      -- The interface doesn't actually need to be open to be able to access the component's content / modify it
      local modifyTextInput
      page:AddSimpleButton("Modify Component", function()
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
            comp.content = modifyTextInput:GetText()
            log("Component content modified to: " .. modifyTextInput:GetText())
          else
            log("Component not found with given ID")
          end
        else
          log("Invalid component ID")
        end
      end)

      modifyTextInput = page:AddTextField({ inline = true, width = 200, placeholder = "Text to set" })
    end,
  },
  {
    build = function(page)
      local invTypeInput
      page:AddSimpleButton("Get InvType", function()
        local invTypeName = resolveEnumName(id.Inv, invTypeInput:GetText())
        if not invTypeName then
          log(formatStr("InvType {} does not exist", invTypeInput:GetText()))
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

      invTypeInput = page:AddTextField({
        inline = true,
        width = 200,
        placeholder = "Enter InvType name or ID...",
        text = invTypeToTest,
        onChange = function(_, _, content)
          invTypeToTest = content
          PersistentDB:Set("invTypeToTest", content)
        end,
      })
    end,
  },
  {
    build = function(page)
      page:AddSimpleButton("Put Obj on floor", function() ExecuteConsoleCommand("!objadd " .. addObjId .. " " .. addObjAmount) end)

      page:AddTextField({
        inline = true,
        width = 140,
        placeholder = "Obj ID",
        text = addObjId,
        onChange = function(_, _, content)
          addObjId = content
          PersistentDB:SetString("addObjId", content)
        end,
      })

      page:AddTextField({
        inline = true,
        width = 90,
        placeholder = "Amount",
        text = tostring(addObjAmount),
        filterMode = ui.InputFieldFilterMode.NUMERIC,
        maxLength = 2147483647,
        onChange = function(_, _, content)
          addObjAmount = content == "" and 0 or (tonumber(content) or 0)
          PersistentDB:SetInt("addObjAmount", addObjAmount)
        end,
      })
    end,
  },
}

local combatItems = {
  {
    build = function(page)
      page:AddCheckboxButton({ { text = "Godmode", value = "godmode" } }, {
        onChange = function() ExecuteConsoleCommand("!godmode") end,
      })

      page:AddCheckboxButton({ { text = "Max HP", value = "maxhp" } }, {
        inline = true,
        onChange = function() ExecuteConsoleCommand("!maxhp") end,
      })

      page:AddCheckboxButton({
        { text = "Prayer Listener", value = "prayer", selected = prayerListenerEnabled },
      }, {
        inline = true,
        onChange = function(_, _, _, selected)
          prayerListenerEnabled = selected
          events.ToggleListener("PrayerHandler", selected)
        end,
      })
    end,
  },
  {
    build = function(page)
      page:AddCheckboxButton({
        { text = "Hit All Listener", value = "hitAll", selected = hitAllListenerEnabled },
      }, {
        onChange = function(_, _, _, selected)
          hitAllListenerEnabled = selected
          events.ToggleListener("HitAllHandler", selected)
        end,
      })
    end,
  },

  {
    build = function(page)
      page:AddCheckboxButton({
        {
          text = "Special Attack Listener",
          value = "specialAttack",
          selected = specialAttackListenerEnabled,
        },
      }, {
        onChange = function(_, _, _, selected)
          specialAttackListenerEnabled = selected
          events.ToggleListener("SpecialAttackHandler", selected)
        end,
      })
    end,
  },
}

local teleportItems = {
  {
    build = function(page)
      page:AddSimpleButton("Teleport to Puro Puro", function() ExecuteConsoleCommand("!tele 0,40,67,30,32") end)
    end,
  },
  {
    build = function(page)
      page:AddSimpleButton("Teleport to GE", function() ExecuteConsoleCommand("!tele grandexchange") end)
    end,
  },
  {
    build = function(page)
      page:AddSimpleButton("Save Coords", function() ExecuteConsoleCommand("!coordsave") end)

      page:AddSimpleButton("Tele Coords", function() ExecuteConsoleCommand("!coordtele") end, { inline = true })
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

local CreateUI = function(Events)
  local gameArea = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
  if not gameArea then
    log("Can't find game area")
    return
  end

  spritePreview = ui.Sprite.new(gameArea)
  spritePreview:SetPos(0, 0)
  spritePreview:SetSize(64, 64)
  spritePreview.hidden = true

  local settingsBox = prettyui.Window.new(gameArea, {
    title = "Debug Menu",
    x = 10,
    y = 200,
    width = 600,
    height = 700,
  })

  settingsBox.root.hidden = true
  local itemRibbon = prettyui.RibbonBar.Register({
    id = "debug-menu",
    object = config.Obj.TRH122_GLOWBUG,
    tooltip = "Open debug menu",
    onClick = function(handle, active) settingsBox.root.hidden = not active end,
  })

  local tabs = settingsBox:AddTabs({ "General", "Debug", "Combat", "Teleports", "Misc" }, { height = -20, heightAnchor = 1.0 })

  local generalPage = tabs:GetPage(1)
  local debugPage = tabs:GetPage(2)
  local combatPage = tabs:GetPage(3)
  local teleportsPage = tabs:GetPage(4)
  local miscPage = tabs:GetPage(5)

  -- Page: General
  generalPage:AddTitle("Event Listeners")

  -- Adds all event listeners with toggles to enable or disable them
  for _, name in ipairs(Events.GetListenerNames()) do
    generalPage:AddCheckboxButton({
      { text = name, value = name, selected = Events.IsListenerActive(name) },
    }, {
      onChange = function(_, _, _, selected) Events.ToggleListener(name, selected) end,
    })
  end

  -- Page: Debug
  for _, item in ipairs(debugItems) do
    item.build(debugPage)
  end

  -- Page: Combat
  for _, item in ipairs(combatItems) do
    item.build(combatPage)
  end

  -- Page: Teleports
  for _, item in ipairs(teleportItems) do
    item.build(teleportsPage)
  end

  -- Page: Misc
  for _, commandDef in ipairs(miscCommands) do
    miscPage:AddSimpleButton(commandDef.label, function() ExecuteConsoleCommand(commandDef.command) end)
  end

  return settingsBox
end

M.CreateUI = CreateUI

return M

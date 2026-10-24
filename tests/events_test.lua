local handlers = {}
local records = {}
package.loaded["resources/console"] = {
  Log = function() end,
  LogEvent = function(eventType, fields)
    local values = {}
    for _, field in ipairs(fields) do
      values[field[1]] = field[2]
    end
    records[#records + 1] = { eventType = eventType, fields = values }
  end,
}
package.loaded["resources/settings"] = {
  GetBool = function() return true end,
}
Event = setmetatable({}, {
  __index = function()
    return {
      Subscribe = function(name, handler)
        handlers[name] = handler
        return true
      end,
    }
  end,
})
formatStr = function(template, ...)
  local args = table.pack(...)
  local index = 0
  return (template:gsub("{}", function()
    index = index + 1
    return tostring(args[index])
  end))
end

require("resources/events/events").SubscribeAll()
local npc = {
  displayName = "Selected form",
  configID = 100,
  uid = 42,
  config = { configName = "SELECTED_FORM" },
  isMultiNPC = true,
  parentConfigID = 200,
  parentConfig = {
    configName = "PARENT_MULTI",
    multiVar = { id = 300, configName = "FORM_VAR" },
  },
}
for _, eventType in ipairs({ "NPCAdded", "NPCRemoved" }) do
  handlers[eventType]({ npcEntity = npc, entityType = "NPC" })
  local record = records[#records]
  assert(record.eventType == eventType)
  assert(record.fields.id == 100)
  assert(record.fields.configName == "SELECTED_FORM")
  assert(record.fields.isMultiNPC == true)
  assert(record.fields.parentConfigID == 200)
  assert(record.fields.parentConfigName == "PARENT_MULTI")
  assert(record.fields.multiVarID == 300)
  assert(record.fields.multiVarConfigName == "FORM_VAR")
end

local menu = { miniMenu = { entries = { { npcData = { entity = npc } } } } }
handlers.HoveredNPC(menu)
local count = #records
handlers.HoveredNPC(menu)
assert(#records == count)
npc.configID = 101
handlers.HoveredNPC(menu)
assert(#records == count + 1 and records[#records].fields.id == 101)
npc.parentConfigID = 201
handlers.HoveredNPC(menu)
assert(#records == count + 2 and records[#records].fields.parentConfigID == 201)
handlers.HoveredNPC({ miniMenu = { entries = {} } })
handlers.HoveredNPC(menu)
assert(#records == count + 3)

npc.isMultiNPC = false
npc.parentConfigID = nil
npc.parentConfig = nil
npc.config = nil
handlers.NPCAdded({ npcEntity = npc })
assert(records[#records].fields.isMultiNPC == false)
assert(records[#records].fields.multiVarID == nil)

local locConfig = {
  id = 400,
  name = "Multi loc",
  configName = "MULTI_LOC",
  isMultiLoc = true,
  multiVar = { id = 500, configName = "LOC_VAR" },
}
handlers.LocAdded({ config = locConfig, coordGrid = { x = 1, z = 2, level = 0 } })
assert(records[#records].fields.isMultiLoc == true)
assert(records[#records].fields.multiVarID == 500)
handlers.HoveredLoc({
  miniMenu = { entries = { { locData = { config = locConfig, coordGridX = 1, coordGridZ = 2 } } } },
})
assert(records[#records].eventType == "HoveredLoc")
assert(records[#records].fields.multiVarConfigName == "LOC_VAR")
locConfig.isMultiLoc = false
handlers.LocAdded({ config = locConfig, coordGrid = {} })
assert(records[#records].fields.isMultiLoc == false)
assert(records[#records].fields.multiVarID == nil)
print("Event metadata tests passed")

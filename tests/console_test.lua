local nativePrint = print
local warnings = {}
log = function(message) warnings[#warnings + 1] = message end
local values = {}
local failWrites = false
PersistentDB = {
  GetInt = function(_, key) return values[key] end,
  SetInt = function(_, key, value)
    if failWrites then return false end
    values[key] = value
    return true
  end,
  SetStructuredData = function(_, key, value)
    if failWrites then return false end
    values[key] = value
    return true
  end,
}

local Console = require("resources/console")
Console.Install()
local fullMessage = string.rep("x", 2500)
log(fullMessage)
assert(values["console:log:0000000000000000001"].message == fullMessage)
assert(values["console:log:0000000000000000001"].source == "log")
assert(#Console.GetEntries()[1] < #fullMessage)
for index = 2, 502 do Console.Append("message " .. index) end
assert(#Console.GetEntries() == 500)
assert(values["console:log:0000000000000000001"].message == fullMessage)
Console.Clear()
assert(#Console.GetEntries() == 0)
assert(values["console:last_id"] == 502)

-- Simulate a plugin reload to verify that the stored sequence resumes.
Console.Uninstall()
package.loaded["resources/console"] = nil
package.loaded["resources/log_store"] = nil
Console = require("resources/console")
Console.Install()
log("reload %d", 1)
assert(values["console:log:0000000000000000503"].message == "reload 1")
failWrites = true
Console.Append("still visible")
Console.Append("also visible")
assert(#Console.GetEntries() == 3)
assert(#warnings == 3) -- Two native log calls and one persistence warning.
failWrites = false
Console.Append("writes recovered")
assert(values["console:log:0000000000000000504"].message == "writes recovered")
Console.LogEvent("HoveredNPC", {
  { "id", 122 },
  { "name", 'Name with | separators and "quotes"' },
  { "enabled", false },
  { "missing", nil },
})
local eventRecord = values["console:log:0000000000000000505"]
assert(eventRecord.schema_version == 1)
assert(eventRecord.source == "event")
assert(eventRecord.event_type == "HoveredNPC")
assert(eventRecord.fields[1].name == "id" and eventRecord.fields[1].value == 122)
assert(eventRecord.fields[2].value == 'Name with | separators and "quotes"')
assert(eventRecord.fields[3].type == "boolean" and eventRecord.fields[3].value == false)
assert(eventRecord.fields[4].type == "nil" and eventRecord.fields[4].value == nil)
Console.Uninstall()
nativePrint("Console persistence tests passed")

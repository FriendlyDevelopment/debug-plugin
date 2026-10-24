local nativePrint = print
local warnings = {}
log = function(message) warnings[#warnings + 1] = message end
local values = {}
local failWrites = false
local failDeletes = false
local iterating = false
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
  IterateEntries = function(_, callback)
    iterating = true
    for key, value in pairs(values) do
      if callback(key, value) then break end
    end
    iterating = false
  end,
  Delete = function(_, key)
    assert(not iterating, "Deletion must happen after iteration finishes")
    if failDeletes then return false end
    values[key] = nil
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

-- Clearing history must preserve settings and the sequence used by ongoing capture.
values["eventListener.HoveredNPC"] = true
values["console:log:not-a-log"] = "keep"
values["console:log:123"] = "keep"
assert(Console.ClearStoredLogs())
assert(#Console.GetEntries() == 0)
assert(values["console:last_id"] == 505)
assert(values["eventListener.HoveredNPC"] == true)
assert(values["console:log:not-a-log"] == "keep")
assert(values["console:log:123"] == "keep")
assert(values["console:log:0000000000000000001"] == nil)
assert(values["console:log:0000000000000000505"] == nil)
assert(Console.ClearStoredLogs()) -- Empty history is also a successful clear.
Console.Append("after clear")
assert(values["console:log:0000000000000000506"].message == "after clear")
failDeletes = true
assert(Console.ClearStoredLogs() == false)
assert(values["console:log:0000000000000000506"].message == "after clear")
assert(#Console.GetEntries() == 2) -- Preserve output and report the deletion failure.
failDeletes = false
Console.Uninstall()
nativePrint("Console persistence tests passed")

local M = {}
local COUNTER_KEY = "console:last_id"
local LOG_PREFIX = "console:log:"
local lastID

function M.Append(message, metadata)
  if lastID == nil then lastID = PersistentDB:GetInt(COUNTER_KEY) or 0 end
  local nextID = lastID + 1
  -- Reserve the ID first so a failed log write cannot overwrite an older entry.
  if not PersistentDB:SetInt(COUNTER_KEY, nextID) then error("Could not reserve a persistent log ID") end
  lastID = nextID
  local key = LOG_PREFIX .. string.format("%019d", nextID)
  metadata = metadata or {}
  local record = {
    schema_version = 1,
    source = metadata.source or "console",
    message = message,
    event_type = metadata.event_type,
    fields = metadata.fields or {},
  }
  if not PersistentDB:SetStructuredData(key, record) then error("Could not persist log " .. tostring(nextID)) end
end

function M.Clear()
  local keys = {}
  -- Finish iteration before deleting entries from the database.
  PersistentDB:IterateEntries(function(key)
    local suffix = key:sub(#LOG_PREFIX + 1)
    if key:sub(1, #LOG_PREFIX) == LOG_PREFIX and #suffix == 19 and suffix:match("^%d+$") then
      keys[#keys + 1] = key
    end
    return false
  end)
  for _, key in ipairs(keys) do
    if not PersistentDB:Delete(key) then error("Could not delete persistent log " .. key) end
  end
  return #keys
end

return M

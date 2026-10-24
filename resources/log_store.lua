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

return M

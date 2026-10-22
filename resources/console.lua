local M = {}

local nativeLog = log
local nativePrint = print
local installed = false
local MAX_ENTRIES = 500
local MAX_ENTRY_LENGTH = 2000
local entries = {}
local dirty = true

function M.Append(message)
  message = tostring(message)
  if #message > MAX_ENTRY_LENGTH then message = message:sub(1, MAX_ENTRY_LENGTH) .. " [truncated]" end
  if #entries == MAX_ENTRIES then table.remove(entries, 1) end
  entries[#entries + 1] = message
  dirty = true
end

-- Keep native console logging, but also put the text in the inputfield
function M.Log(message, ...)
  nativeLog(message, ...)
  -- Select will return the number of arguments we passed
  if select("#", ...) > 0 then
    local ok, formatted = pcall(string.format, tostring(message), ...)
    if ok then
      message = formatted
    else
      local parts = { tostring(message) }
      for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
      end
      message = table.concat(parts, " ")
    end
  end
  M.Append(message)
end

-- Ordered field pairs retain nil values and keep related fields together.
function M.LogEvent(eventType, fields)
  local parts = { "event=" .. string.format("%q", eventType) }
  for _, field in ipairs(fields or {}) do
    local value = field[2]
    local valueType = type(value)
    local text = tostring(value)
    if valueType == "string" then
      text = '"' .. value:gsub('[%c\\"]', function(character)
        local escapes = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
        return escapes[character] or string.format("\\%03d", string.byte(character))
      end) .. '"'
    end
    parts[#parts + 1] = field[1] .. "(" .. valueType .. ")=" .. text
  end
  M.Log(table.concat(parts, " | "))
end

function M.Print(...)
  nativePrint(...)
  local parts = {}
  for index = 1, select("#", ...) do
    parts[#parts + 1] = tostring(select(index, ...))
  end
  M.Append(table.concat(parts, " "))
end

function M.Install()
  if installed then return end
  log = M.Log
  print = M.Print
  installed = true
end

function M.Uninstall()
  if not installed then return end
  -- Avoid replacing hooks installed by another module after ours
  if log == M.Log then log = nativeLog end
  if print == M.Print then print = nativePrint end
  installed = false
end

function M.Clear()
  entries = {}
  dirty = true
end

function M.IsDirty() return dirty end

function M.MarkClean() dirty = false end

function M.GetEntries(filter)
  local result = {}
  filter = (filter or ""):lower()
  for _, entry in ipairs(entries) do
    if filter == "" or entry:lower():find(filter, 1, true) then result[#result + 1] = entry end
  end
  return result
end

return M

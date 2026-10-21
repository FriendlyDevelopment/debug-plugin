---@class DebugPluginSettings
local Settings = {}
---@type table<String, Bool|Int|Float|String|Table>
local values = {}
---@type table<String, Bool>
local loaded = {}

---@param key String
---@return Bool|Int|Float|String|Table|nil
function Settings:Get(key)
  if not loaded[key] then
    values[key] = PersistentDB:Get(key)
    loaded[key] = true
  end

  return values[key]
end

---@param key String
---@param value Bool|Int|Float|String|Table
function Settings:Set(key, value)
  PersistentDB:Set(key, value)
  values[key] = value
  loaded[key] = true
end

---@param key String
---@return Bool?
function Settings:GetBool(key)
  if not loaded[key] then
    values[key] = PersistentDB:GetBool(key)
    loaded[key] = true
  end

  local value = values[key]
  ---@cast value Bool?
  return value
end

---@param key String
---@param value Bool
function Settings:SetBool(key, value)
  PersistentDB:SetBool(key, value)
  values[key] = value
  loaded[key] = true
end

---@param key String
---@return Int?
function Settings:GetInt(key)
  if not loaded[key] then
    values[key] = PersistentDB:GetInt(key)
    loaded[key] = true
  end

  local value = values[key]
  ---@cast value Int?
  return value
end

---@param key String
---@param value Int
function Settings:SetInt(key, value)
  PersistentDB:SetInt(key, value)
  values[key] = value
  loaded[key] = true
end

---@param key String
---@return Float?
function Settings:GetFloat(key)
  if not loaded[key] then
    values[key] = PersistentDB:GetFloat(key)
    loaded[key] = true
  end

  local value = values[key]
  ---@cast value Float?
  return value
end

---@param key String
---@param value Float
function Settings:SetFloat(key, value)
  PersistentDB:SetFloat(key, value)
  values[key] = value
  loaded[key] = true
end

---@param key String
---@return String?
function Settings:GetString(key)
  if not loaded[key] then
    values[key] = PersistentDB:GetString(key)
    loaded[key] = true
  end

  local value = values[key]
  ---@cast value String?
  return value
end

---@param key String
---@param value String
function Settings:SetString(key, value)
  PersistentDB:SetString(key, value)
  values[key] = value
  loaded[key] = true
end

---@param key String
---@return Table?
function Settings:GetStructuredData(key)
  if not loaded[key] then
    values[key] = PersistentDB:GetStructuredData(key)
    loaded[key] = true
  end

  local value = values[key]
  ---@cast value Table?
  return value
end

---@param key String
---@param value Table
function Settings:SetStructuredData(key, value)
  PersistentDB:SetStructuredData(key, value)
  values[key] = value
  loaded[key] = true
end

return Settings

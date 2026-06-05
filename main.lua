log("Loading plugin...")

function getPerms()
	if Plugin.HasPermission(PluginPermissions.httpAccess) then
		log("HTTP access permission granted.")
	else
		log("HTTP access permission denied.")
	end
end

local events = loadfile("resources/events/events")

local ui = loadfile("resources/ui/ui")
ui.CreateUI(events)

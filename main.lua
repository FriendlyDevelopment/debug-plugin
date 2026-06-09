log("Loading plugin...")

local events = loadfile("resources/events/events")

local ui = loadfile("resources/ui/ui")
ui.CreateUI(events)

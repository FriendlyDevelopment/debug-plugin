# Friendly's Debug Menu

This plugin lets you debug various events in the game, such as var transmits, IDs of NPCs and Locs you hover over and much more.
You can access the settings in the settings window or by pressing the plugin's button.

There's a live console you can search in, but you can also spin up a small webserver to query for relevant data.

Some of the available options are:
- Various event transmits
- Seeing the id of what you hover over
- Look up various vars
- Change various vars
- Display sprites
- Give items
- List interface compoments
- Combat helpers
- Teleports
- Misc cheats

## Log Viewer

The debug menu also stores logs in the PersistentDB database, so you can spin up a small webserver to query it.
You can spin it up by running:

```bash
uv run tools/log_server.py
```

Or if you prefer using regular python:

```bash
python tools/log_server.py
```

You can then navigate to [http://localhost:8000](http://localhost:8000) to view the logs, and [http://localhost:8000/docs](http://localhost:8000/docs) for the documentation of the API.


### Disclaimer

I did use AI to generate the webpage for the log server and the tests, because that's not really the part of the debug menu I'm interested in.
It's a very minimalistic page but it works.

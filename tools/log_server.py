"""Browse, filter, export, and clear the debug plugin's PersistentDB logs."""

import argparse
import json
import sqlite3
from contextlib import closing
from pathlib import Path
from typing import Annotated

import uvicorn
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel, Field

LOG_PREFIX = "console:log:"
DEFAULT_DB = Path(__file__).resolve().parents[3] / "plugins" / "PluginData.db"
DEFAULT_PLUGIN_ID = "Friendly's Debug Plugin"


class LogEntry(BaseModel):
    id: int
    message: str
    source: str
    event_type: str | None = None
    fields: dict[str, str | int | float | bool | None] = Field(default_factory=dict)
    field_types: dict[str, str] = Field(default_factory=dict)


class LogPage(BaseModel):
    entries: list[LogEntry]
    next_after: int | None


def field_text(value) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


class LogFilters:
    def __init__(
        self,
        event_type: Annotated[
            str | None, Query(description="Exact event type, case-insensitive")
        ] = None,
        entity_id: Annotated[
            str | None,
            Query(description="The event's id field (NPC, loc, item, var, etc.)"),
        ] = None,
        log_id: Annotated[
            int | None,
            Query(ge=1, le=9223372036854775807, description="Stored log-entry ID"),
        ] = None,
        q: Annotated[
            str | None, Query(description="Case-insensitive message search")
        ] = None,
        source: Annotated[
            str | None, Query(description="event, log, print, console, or legacy")
        ] = None,
        field: Annotated[
            list[str] | None,
            Query(description="Exact name=value; repeat to match multiple fields"),
        ] = None,
    ):
        self.event_type = event_type
        self.entity_id = entity_id
        self.log_id = log_id
        self.q = q
        self.source = source
        self.fields = []
        for item in field or []:
            name, separator, value = item.partition("=")
            if not separator or not name:
                raise HTTPException(
                    status_code=422, detail="Each field filter must be name=value"
                )
            self.fields.append((name, value))

    def matches(self, entry: LogEntry) -> bool:
        if self.log_id is not None and self.log_id != entry.id:
            return False
        if (
            self.event_type is not None
            and self.event_type.casefold() != (entry.event_type or "").casefold()
        ):
            return False
        if (
            self.source is not None
            and self.source.casefold() != entry.source.casefold()
        ):
            return False
        if self.q is not None and self.q.casefold() not in entry.message.casefold():
            return False
        fields = self.fields + (
            [("id", self.entity_id)] if self.entity_id is not None else []
        )
        return all(
            name in entry.fields
            and field_text(entry.fields[name]).casefold() == value.casefold()
            for name, value in fields
        )


def decode_table(value):
    """PersistentDB serializes Lua tables as JSON arrays of key/value pairs."""
    if isinstance(value, list):
        return {pair["key"]: decode_table(pair["value"]) for pair in value}
    return value


def decode(row) -> LogEntry:
    key, value_type, value = row
    # PersistentDB strings and structured JSON have one trailing NUL terminator.
    if isinstance(value, bytes):
        value = value.removesuffix(b"\0").decode("utf-8", errors="replace")
    entry_id = int(key[len(LOG_PREFIX) :])
    if value_type == 3:
        return LogEntry(id=entry_id, message=value, source="legacy")
    try:
        record = decode_table(json.loads(value))
        fields = list(record.get("fields", {}).values())
        return LogEntry(
            id=entry_id,
            message=record["message"],
            source=record["source"],
            event_type=record.get("event_type"),
            fields={field["name"]: field.get("value") for field in fields},
            field_types={field["name"]: field["type"] for field in fields},
        )
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        raise HTTPException(
            status_code=500, detail=f"Invalid structured log {entry_id}: {error}"
        ) from error


def create_app(
    db_path: Path = DEFAULT_DB, plugin_id: str = DEFAULT_PLUGIN_ID
) -> FastAPI:
    app = FastAPI(title="Debug Plugin Logs", version="1.0.0")
    database_uri = db_path.expanduser().resolve().as_uri()

    def open_logs(after: int = 0, log_id: int | None = None):
        connection = None
        try:
            connection = sqlite3.connect(
                database_uri + "?mode=ro", uri=True, timeout=5, check_same_thread=False
            )
            # Fixed-width IDs keep SQLite's key order identical to numeric order.
            sql = (
                "SELECT Key, Type, Value FROM DataStore WHERE PluginID = ? AND Type IN (3, 4) "
                "AND Key GLOB ? AND Key > ?"
            )
            params = [plugin_id, LOG_PREFIX + "[0-9]" * 19, f"{LOG_PREFIX}{after:019d}"]
            if log_id is not None:
                sql += " AND Key = ?"
                params.append(f"{LOG_PREFIX}{log_id:019d}")
            cursor = connection.execute(sql + " ORDER BY Key", params)
            return connection, cursor
        except sqlite3.Error as error:
            if connection is not None:
                connection.close()
            raise HTTPException(
                status_code=503, detail=f"Cannot read log database: {error}"
            ) from error

    @app.get("/", include_in_schema=False)
    def index():
        return FileResponse(Path(__file__).with_name("log_viewer.html"))

    @app.get("/status")
    def status():
        """Show the selected database and plugin IDs that have captured logs."""
        connection, _ = open_logs()
        with closing(connection):
            counts = connection.execute(
                "SELECT PluginID, COUNT(*) FROM DataStore WHERE Type IN (3, 4) AND Key GLOB ? "
                "GROUP BY PluginID ORDER BY PluginID",
                (LOG_PREFIX + "[0-9]" * 19,),
            ).fetchall()
        return {
            "database": str(db_path.expanduser().resolve()),
            "plugin_id": plugin_id,
            "stored_logs": dict(counts).get(plugin_id, 0),
            "plugins_with_logs": dict(counts),
        }

    @app.get("/filters")
    def filter_options():
        """Discover event types, field names, and sources in the selected plugin's history."""
        connection, cursor = open_logs()
        event_types, fields, sources = set(), set(), set()
        with closing(connection):
            for row in cursor:
                entry = decode(row)
                if entry.event_type is not None:
                    event_types.add(entry.event_type)
                fields.update(entry.fields)
                sources.add(entry.source)
        return {
            "event_types": sorted(event_types),
            "fields": sorted(fields),
            "sources": sorted(sources),
        }

    @app.get("/logs", response_model=LogPage)
    def logs(
        filters: Annotated[LogFilters, Depends()],
        after: Annotated[int, Query(ge=0, le=9223372036854775807)] = 0,
        limit: Annotated[int, Query(ge=1, le=1000)] = 100,
    ):
        """Read oldest first. Pass next_after as after to fetch the next page."""
        connection, cursor = open_logs(after, filters.log_id)
        entries = []
        with closing(connection):
            for row in cursor:
                entry = decode(row)
                if filters.matches(entry):
                    entries.append(entry)
                    if len(entries) > limit:
                        break
        return LogPage(
            entries=entries[:limit],
            next_after=entries[limit - 1].id if len(entries) > limit else None,
        )

    @app.delete("/logs")
    def clear_logs():
        """Delete all stored logs for this plugin, preserving settings and the ID counter."""
        try:
            with closing(
                sqlite3.connect(database_uri + "?mode=rw", uri=True, timeout=5)
            ) as connection:
                with connection:
                    cursor = connection.execute(
                        "DELETE FROM DataStore WHERE PluginID = ? AND Type IN (3, 4) AND Key GLOB ?",
                        (plugin_id, LOG_PREFIX + "[0-9]" * 19),
                    )
                    deleted = cursor.rowcount
            return {"deleted": deleted}
        except sqlite3.Error as error:
            raise HTTPException(
                status_code=503, detail=f"Cannot clear log database: {error}"
            ) from error

    @app.get("/logs/export", response_class=StreamingResponse)
    def export(filters: Annotated[LogFilters, Depends()]):
        """Download all messages matching the filters in chronological order."""
        connection, cursor = open_logs(log_id=filters.log_id)

        def lines():
            with closing(connection):
                for row in cursor:
                    entry = decode(row)
                    if filters.matches(entry):
                        yield entry.message + "\n"

        return StreamingResponse(
            lines(),
            media_type="text/plain; charset=utf-8",
            headers={
                "Content-Disposition": 'attachment; filename="debug-plugin-logs.txt"'
            },
        )

    return app


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--db", type=Path, default=DEFAULT_DB, help="Path to PluginData.db"
    )
    parser.add_argument(
        "--plugin-id", default=DEFAULT_PLUGIN_ID, help="PersistentDB plugin ID"
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    uvicorn.run(create_app(args.db, args.plugin_id), host=args.host, port=args.port)

import json
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from fastapi.testclient import TestClient

from tools.log_server import DEFAULT_DB, DEFAULT_PLUGIN_ID, LOG_PREFIX, create_app


def encode_table(value):
    if isinstance(value, list):
        value = dict(enumerate(value, start=1))
    if isinstance(value, dict):
        return [{"key": key, "value": encode_table(item)} for key, item in value.items()]
    return value


class LogServerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.database = Path(self.temp.name) / "PluginData.db"
        with closing(sqlite3.connect(self.database)) as connection:
            connection.execute(
                'CREATE TABLE DataStore (PluginID TEXT, Key TEXT, Type INTEGER, '
                'Value BLOB, PRIMARY KEY(PluginID, Key))'
            )
            for plugin, number, message in [
                (DEFAULT_PLUGIN_ID, 1, "Loading plugin..."),
                (DEFAULT_PLUGIN_ID, 2, 'event="HoveredNPC" | name(string)="Devout yak"'),
                (DEFAULT_PLUGIN_ID, 10, "Unicode: café\nsecond line"),
                ("another-plugin", 1, "Not a debug plugin log"),
            ]:
                connection.execute(
                    'INSERT INTO DataStore VALUES (?, ?, 3, ?)',
                    (plugin, f"{LOG_PREFIX}{number:019d}", message.encode() + b"\0"),
                )
            connection.execute(
                'INSERT INTO DataStore VALUES (?, ?, 1, ?)',
                (DEFAULT_PLUGIN_ID, "console:last_id", b"\x0a\0\0\0"),
            )
            for number, event_type, fields in [
                (11, "HoveredNPC", {"id": 122.0, "uid": 123.0, "name": "Devout yak", "enabled": False, "missing": None}),
                (12, "HoveredLoc", {"id": 122.0, "configName": "CAVE", "x": 12.0}),
                (13, "HoveredNPC", {"id": 1221.0, "name": "yak | id(number)=122"}),
                (14, "HoveredNPC", {"id": 122.0, "uid": 999.0, "name": "different"}),
                (15, None, {}),
            ]:
                stored_fields = []
                for name, value in fields.items():
                    kind = "nil" if value is None else "boolean" if isinstance(value, bool) else "number" if isinstance(value, float) else "string"
                    field = {"name": name, "type": kind}
                    if value is not None:
                        field["value"] = value
                    stored_fields.append(field)
                record = {
                    "schema_version": 1,
                    "source": "event" if event_type else "print",
                    "message": f"{event_type}: {fields.get('name', '')}" if event_type else "printed message",
                    "fields": stored_fields,
                }
                if event_type is not None:
                    record["event_type"] = event_type
                connection.execute(
                    'INSERT INTO DataStore VALUES (?, ?, 4, ?)',
                    (DEFAULT_PLUGIN_ID, f"{LOG_PREFIX}{number:019d}", json.dumps(encode_table(record)).encode() + b"\0"),
                )
            connection.commit()
        self.client = TestClient(create_app(self.database))
        self.addCleanup(self.client.close)

    def test_defaults_match_current_game_layout(self):
        self.assertEqual(DEFAULT_DB.name, "PluginData.db")
        self.assertEqual(DEFAULT_DB.parent.name, "plugins")
        self.assertEqual(DEFAULT_PLUGIN_ID, "Friendly's Debug Plugin")

    def test_pagination_and_decoding(self):
        response = self.client.get("/logs", params={"after": 0, "limit": 2})
        self.assertEqual(response.status_code, 200)
        first = response.json()
        self.assertEqual([entry["id"] for entry in first["entries"]], [1, 2])
        self.assertEqual(first["entries"][0]["message"], "Loading plugin...")
        self.assertEqual(first["next_after"], 2)
        second = self.client.get("/logs", params={"after": first["next_after"]}).json()
        self.assertEqual([entry["id"] for entry in second["entries"]], [10, 11, 12, 13, 14, 15])
        self.assertEqual(second["entries"][0]["message"], "Unicode: café\nsecond line")
        self.assertIsNone(second["next_after"])
        self.assertEqual(self.client.get("/logs?after=15").json()["entries"], [])

    def test_status_exposes_database_and_plugin_selection(self):
        result = self.client.get("/status").json()
        self.assertEqual(result["database"], str(self.database))
        self.assertEqual(result["plugin_id"], DEFAULT_PLUGIN_ID)
        self.assertEqual(result["stored_logs"], 8)
        self.assertEqual(result["plugins_with_logs"]["another-plugin"], 1)

    def test_export_is_ordered_and_scoped_to_plugin(self):
        response = self.client.get("/logs/export")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.text.startswith('Loading plugin...\nevent="HoveredNPC"'))
        self.assertIn("Unicode: café\nsecond line\n", response.text)
        self.assertNotIn("Not a debug plugin log", response.text)
        self.assertTrue(response.text.endswith("printed message\n"))

    def test_typed_structured_fields_and_legacy_entries(self):
        entry = self.client.get("/logs?log_id=11").json()["entries"][0]
        self.assertEqual(entry["event_type"], "HoveredNPC")
        self.assertEqual(entry["source"], "event")
        self.assertEqual(entry["fields"]["id"], 122)
        self.assertIs(entry["fields"]["enabled"], False)
        self.assertIsNone(entry["fields"]["missing"])
        self.assertEqual(entry["field_types"]["missing"], "nil")
        legacy = self.client.get("/logs?log_id=2").json()["entries"][0]
        self.assertEqual(legacy["source"], "legacy")
        self.assertIsNone(legacy["event_type"])
        self.assertEqual(legacy["fields"], {})

    def test_combined_filters_match_exact_structured_values(self):
        cases = [
            ({"entity_id": "122"}, [11, 12, 14]),
            ({"entity_id": "122", "event_type": "hoverednpc"}, [11, 14]),
            ({"entity_id": "122", "event_type": "HoveredNPC", "q": "DIFFERENT"}, [14]),
            ({"field": ["id=122", "uid=123"]}, [11]),
            ({"field": "enabled=false"}, [11]),
            ({"field": "missing=nil"}, [11]),
            ({"field": "configName=cave"}, [12]),
            ({"source": "print"}, [15]),
            ({"q": "café"}, [10]),
            ({"log_id": 12, "event_type": "HoveredNPC"}, []),
        ]
        for params, expected in cases:
            with self.subTest(params=params):
                response = self.client.get("/logs", params=params)
                self.assertEqual(response.status_code, 200)
                self.assertEqual([entry["id"] for entry in response.json()["entries"]], expected)

    def test_filtered_pagination_counts_matches_not_scanned_rows(self):
        first = self.client.get("/logs?entity_id=122&event_type=HoveredNPC&limit=1").json()
        self.assertEqual([entry["id"] for entry in first["entries"]], [11])
        self.assertEqual(first["next_after"], 11)
        second = self.client.get("/logs?entity_id=122&event_type=HoveredNPC&limit=1&after=11").json()
        self.assertEqual([entry["id"] for entry in second["entries"]], [14])
        self.assertIsNone(second["next_after"])

    def test_export_uses_the_same_filters(self):
        response = self.client.get("/logs/export?entity_id=122&event_type=HoveredNPC")
        self.assertEqual(response.text, "HoveredNPC: Devout yak\nHoveredNPC: different\n")

    def test_filter_options_and_browser_view(self):
        options = self.client.get("/filters").json()
        self.assertEqual(options["event_types"], ["HoveredLoc", "HoveredNPC"])
        self.assertIn("configName", options["fields"])
        self.assertEqual(options["sources"], ["event", "legacy", "print"])
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn('name="entity_id"', response.text)
        self.assertNotIn('id="clear"', response.text)
        self.assertIn("plugin's Live Logs window", response.text)

    def test_api_does_not_expose_deletion(self):
        before = self.client.get("/logs").json()
        response = self.client.delete("/logs")
        self.assertEqual(response.status_code, 405)
        self.assertEqual(self.client.get("/logs").json(), before)
        schema = self.client.get("/openapi.json").json()
        for path in schema["paths"].values():
            self.assertNotIn("delete", path)

    def test_missing_database_returns_503_without_creating_file(self):
        missing = self.database.with_name("missing.db")
        with TestClient(create_app(missing)) as client:
            self.assertEqual(client.get("/logs").status_code, 503)
            self.assertEqual(client.delete("/logs").status_code, 405)
        self.assertFalse(missing.exists())

    def test_invalid_pagination_is_rejected(self):
        for query in ["after=-1", "limit=0", "limit=1001", "after=9223372036854775808", "field=invalid", "log_id=0"]:
            with self.subTest(query=query):
                self.assertEqual(self.client.get("/logs?" + query).status_code, 422)


if __name__ == "__main__":
    unittest.main()

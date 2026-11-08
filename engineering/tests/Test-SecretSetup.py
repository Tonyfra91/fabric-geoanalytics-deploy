#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Offline tests for metadata-only Fabric diagnostics and persistence inspection.

Run with: python -B engineering\\tests\\Test-SecretSetup.py
"""

import argparse
import base64
import contextlib
import io
import json
from pathlib import Path
import types
import sys
import unittest
from unittest.mock import patch


NOTEBOOK_PATH = (
    Path(__file__).resolve().parents[1]
    / "fixtures"
    / "setup-esri-api-key.ipynb"
)
VAULT_URL = "https://kv-offline-test.vault.azure.net/"


def nonsecret_marker() -> str:
    return "-".join(("FASTPASS", "NONSECRET", "PROBE"))


def contains_marker(value: object) -> bool:
    if isinstance(value, str):
        if nonsecret_marker() in value:
            return True
        if value.lstrip().startswith(("{", "[", '"')):
            try:
                decoded = json.loads(value)
            except ValueError:
                return False
            return decoded != value and contains_marker(decoded)
        return False
    if isinstance(value, dict):
        return any(contains_marker(key) or contains_marker(item)
                   for key, item in value.items())
    if isinstance(value, list):
        return any(contains_marker(item) for item in value)
    return False


def inspect_definition(envelope: dict) -> dict:
    """Inspect saved API content without emitting any field values."""
    findings = {
        "notebookSource": False, "notebookOutputs": False,
        "notebookMetadata": False, "widgetState": False,
        "savedParameters": False, "fabricItemDefinition": contains_marker(envelope),
    }
    widget_state_present = False
    widget_views = 0
    notebook_count = 0
    parts = envelope.get("definition", {}).get("parts")
    if not isinstance(parts, list) or not parts:
        raise ValueError("Definition has no inspectable parts.")

    def inspect_fields(value: object) -> None:
        nonlocal widget_state_present, widget_views
        if isinstance(value, dict):
            for key, item in value.items():
                if key in ("widgets", "application/vnd.jupyter.widget-state+json"):
                    widget_state_present = True
                    findings["widgetState"] |= contains_marker(item)
                if key == "application/vnd.jupyter.widget-view+json":
                    widget_views += 1
                if key.lower() in ("parameters", "parametervalues", "savedparameters"):
                    findings["savedParameters"] |= contains_marker(item)
                inspect_fields(item)
        elif isinstance(value, list):
            for item in value:
                inspect_fields(item)

    inspect_fields(envelope)
    for part in parts:
        if part.get("payloadType") != "InlineBase64":
            raise ValueError("Definition contains an unsupported payload type.")
        text = base64.b64decode(part["payload"], validate=True).decode("utf-8")
        findings["fabricItemDefinition"] |= contains_marker(text)
        if part.get("path", "").endswith(".ipynb"):
            notebook = json.loads(text)
            if notebook.get("nbformat") != 4 or not isinstance(notebook.get("cells"), list):
                raise ValueError("Invalid notebook payload.")
            notebook_count += 1
            findings["notebookMetadata"] |= contains_marker(notebook.get("metadata", {}))
            for cell in notebook["cells"]:
                source = cell.get("source", "")
                findings["notebookSource"] |= contains_marker(
                    "".join(source) if isinstance(source, list) else source
                )
                findings["notebookOutputs"] |= contains_marker(cell.get("outputs", []))
                findings["notebookMetadata"] |= contains_marker(cell.get("metadata", {}))
                if "parameters" in cell.get("metadata", {}).get("tags", []):
                    findings["savedParameters"] |= contains_marker(source)
            inspect_fields(notebook)
        else:
            try:
                inspect_fields(json.loads(text))
            except ValueError:
                pass  # Non-JSON text parts were already scanned above.
    if not notebook_count:
        raise ValueError("No notebook payload was inspected.")
    return {
        "passed": not any(findings.values()) and not widget_state_present and not widget_views,
        "probeFound": findings,
        "widgetStatePresent": widget_state_present,
        "widgetViewReferences": widget_views,
        "notebookPayloadsInspected": notebook_count,
        "definitionPartsInspected": len(parts),
    }


class SecretSetupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.notebook = json.loads(NOTEBOOK_PATH.read_text(encoding="utf-8"))
        self.cells = [
            "".join(cell["source"])
            for cell in self.notebook["cells"]
            if cell["cell_type"] == "code"
        ]
        self.unconfigured_source = self.cells[0]
        self.cells[0] = self.cells[0].replace(
            "https://<vault-name>.vault.azure.net/", VAULT_URL
        )
        self.enabled = False
        self.attributes = {"enabled": True}
        self.status = 200
        self.next_link = None
        self.calls = []
        self.writes = []
        self.stdout = io.StringIO()
        self.namespace = {}
        self.credentials = types.SimpleNamespace(
            getToken=lambda audience: "offline-test-token",
            putSecret=lambda *args: self.writes.append(args),
        )
        self.module_patch = patch.dict(
            "sys.modules",
            {"notebookutils": types.SimpleNamespace(credentials=self.credentials)},
        )
        self.module_patch.start()
        self.addCleanup(self.module_patch.stop)
        self.connection_patch = patch(
            "http.client.HTTPSConnection", side_effect=lambda *a, **k: self.connection()
        )
        self.connection_patch.start()
        self.addCleanup(self.connection_patch.stop)

    def connection(self) -> types.SimpleNamespace:
        items = []
        if self.enabled:
            items.append(
                {"id": VAULT_URL + "secrets/geoanalytics-api-key",
                 "attributes": self.attributes}
            )
        response = types.SimpleNamespace(
            status=self.status,
            read=lambda: json.dumps(
                {"value": items, "nextLink": self.next_link}
            ).encode(),
        )
        return types.SimpleNamespace(
            request=lambda method, path, **kwargs: self.calls.append((method, path)),
            getresponse=lambda: response,
            close=lambda: None,
        )

    def run_cell(self, index: int) -> None:
        with contextlib.redirect_stdout(self.stdout):
            exec(compile(self.cells[index], f"setup-cell-{index}", "exec"),
                 self.namespace)

    def test_artifact_has_only_clean_python_cells(self) -> None:
        self.assertEqual(self.notebook["metadata"]["kernelspec"]["name"], "python3")
        self.assertEqual(len(self.cells), 1)
        for cell in self.notebook["cells"]:
            if cell["cell_type"] == "code":
                self.assertEqual(cell["outputs"], [])
                self.assertIsNone(cell["execution_count"])
                compile("".join(cell["source"]), "notebook-cell", "exec")
        serialized = json.dumps(self.notebook)
        for forbidden in ("getSecret(", "putSecret(", "getpass(", "ipywidgets",
                          "input(", "on_click(", "widget-state", "widget-view",
                          "10.0.0.4", nonsecret_marker()):
            self.assertNotIn(forbidden, serialized)

    def test_absence_is_explicitly_blocked_without_value_output(self) -> None:
        self.run_cell(0)
        self.assertIn("secret is absent. Secret creation requires", self.stdout.getvalue())
        self.assertNotIn("offline-test-token", self.stdout.getvalue())
        self.assertTrue(all(call == ("GET", "/secrets?api-version=7.4")
                            for call in self.calls))
        self.assertFalse(self.writes)

    def test_existing_enabled_secret_is_not_overwritten(self) -> None:
        self.enabled = True
        self.run_cell(0)
        self.assertIn("metadata verified", self.stdout.getvalue())
        self.assertFalse(self.writes)

    def test_invalid_existing_secret_is_not_replaced(self) -> None:
        self.enabled = True
        for attributes in ({"enabled": False}, {"enabled": True, "exp": 1},
                           {"enabled": True, "nbf": 99999999999}, {}):
            with self.subTest(attributes=attributes):
                self.attributes = attributes
                with self.assertRaisesRegex(RuntimeError, "disabled, expired"):
                    self.run_cell(0)
                self.assertFalse(self.writes)

    def test_private_network_or_rbac_denial_precedes_input(self) -> None:
        self.status = 403
        with patch("getpass.getpass", side_effect=AssertionError("No prompt")):
            with self.assertRaisesRegex(RuntimeError, "HTTP 403"):
                self.run_cell(0)
        self.assertFalse(self.writes)

    def test_all_remaining_cells_run_without_input_or_secret_writes(self) -> None:
        with patch("builtins.input", side_effect=AssertionError("No input")), \
                patch("getpass.getpass", side_effect=AssertionError("No prompt")):
            for index in range(len(self.cells)):
                self.run_cell(index)
        self.assertFalse(self.writes)
        self.assertNotIn("candidate", self.namespace)
        self.assertNotIn("show_nonsecret_probe", self.namespace)

    def test_invalid_vault_url_stops_before_network(self) -> None:
        self.cells[0] = self.unconfigured_source
        with self.assertRaisesRegex(ValueError, "Set VAULT_URL"):
            self.run_cell(0)
        self.assertFalse(self.calls)

    def test_metadata_transport_failure_is_explicit(self) -> None:
        with patch("http.client.HTTPSConnection", side_effect=OSError("offline")):
            with self.assertRaisesRegex(RuntimeError, "metadata check failed"):
                self.run_cell(0)

    def test_malformed_metadata_is_not_accepted(self) -> None:
        response = types.SimpleNamespace(status=200, read=lambda: b'{"value": {}}')
        connection = self.connection()
        connection.getresponse = lambda: response
        with patch("http.client.HTTPSConnection", return_value=connection):
            with self.assertRaisesRegex(RuntimeError, "Invalid Key Vault"):
                self.run_cell(0)

    def test_rerun_lists_metadata_without_mutations(self) -> None:
        self.run_cell(0)
        self.run_cell(0)
        self.assertEqual(len(self.calls), 2)
        self.assertFalse(self.writes)

    def test_unsafe_or_repeated_pagination_stops_before_another_request(self) -> None:
        for link in ("https://untrusted.invalid/secrets?api-version=7.4",
                     VAULT_URL + "secrets/geoanalytics-api-key?api-version=7.4",
                     VAULT_URL + "secrets?api-version=7.4"):
            self.calls.clear()
            self.next_link = link
            with self.assertRaisesRegex(RuntimeError, "continuation URL"):
                self.run_cell(0)
            self.assertEqual(len(self.calls), 1)


class PersistenceInspectionTests(unittest.TestCase):
    def envelope(self, notebook: dict) -> dict:
        return {"definition": {"parts": [{
            "path": "notebook-content.ipynb", "payloadType": "InlineBase64",
            "payload": base64.b64encode(json.dumps(notebook).encode()).decode(),
        }]}}

    def notebook(self) -> dict:
        return {"nbformat": 4, "metadata": {}, "cells": [{
            "cell_type": "code", "source": "print('PASS')",
            "outputs": [], "metadata": {},
        }]}

    def test_current_artifact_contains_no_probe_or_widget_state(self) -> None:
        notebook = json.loads(NOTEBOOK_PATH.read_text(encoding="utf-8"))
        self.assertTrue(inspect_definition(self.envelope(notebook))["passed"])

    def test_detects_probe_in_every_requested_notebook_surface(self) -> None:
        for surface in ("source", "outputs", "metadata", "widgets", "parameters"):
            with self.subTest(surface=surface):
                notebook = self.notebook()
                if surface == "source":
                    notebook["cells"][0]["source"] = nonsecret_marker()
                elif surface == "outputs":
                    notebook["cells"][0]["outputs"] = [
                        {"output_type": "stream", "text": nonsecret_marker()}
                    ]
                else:
                    notebook["metadata"][surface] = {"value": nonsecret_marker()}
                report = inspect_definition(self.envelope(notebook))
                self.assertFalse(report["passed"])
                self.assertTrue(report["probeFound"]["fabricItemDefinition"])

    def test_even_empty_persisted_widget_state_blocks_advancement(self) -> None:
        notebook = self.notebook()
        notebook["metadata"]["widgets"] = {}
        self.assertTrue(inspect_definition(self.envelope(notebook))["widgetStatePresent"])
        self.assertFalse(inspect_definition(self.envelope(notebook))["passed"])

    def test_observed_populated_password_state_fails_before_callback(self) -> None:
        notebook = self.notebook()
        notebook["metadata"]["widgets"] = {
            "application/vnd.jupyter.widget-state+json": {"state": {
                "offline-password-model": {"model_name": "PasswordModel", "state": {
                    "value": nonsecret_marker(),
                }}
            }}
        }
        notebook["cells"][0]["outputs"] = [
            {"data": {"application/vnd.jupyter.widget-view+json": {"model_id": model}}}
            for model in ("offline-password-model", "offline-button", "offline-result")
        ]
        report = inspect_definition(self.envelope(notebook))
        self.assertFalse(report["passed"])
        self.assertTrue(report["widgetStatePresent"])
        self.assertEqual(report["widgetViewReferences"], 3)
        self.assertEqual(report["probeFound"], {
            "notebookSource": False, "notebookOutputs": False,
            "notebookMetadata": True, "widgetState": True,
            "savedParameters": False, "fabricItemDefinition": True,
        })

    def test_widget_view_blocks_cleanup_without_being_mistaken_for_state(self) -> None:
        notebook = self.notebook()
        notebook["cells"][0]["outputs"] = [{"data": {
            "application/vnd.jupyter.widget-view+json": {"model_id": "offline-model"}
        }}]
        report = inspect_definition(self.envelope(notebook))
        self.assertEqual(report["widgetViewReferences"], 1)
        self.assertFalse(report["widgetStatePresent"])
        self.assertFalse(report["passed"])

    def test_checks_other_item_parts_and_unicode_escaped_values(self) -> None:
        envelope = self.envelope(self.notebook())
        escaped = "".join(f"\\u{ord(character):04x}" for character in nonsecret_marker())
        envelope["definition"]["parts"].append({
            "path": ".platform", "payloadType": "InlineBase64",
            "payload": base64.b64encode(
                ('{"parameters":{"value":"' + escaped + '"}}').encode()
            ).decode(),
        })
        report = inspect_definition(envelope)
        self.assertTrue(report["probeFound"]["fabricItemDefinition"])
        self.assertTrue(report["probeFound"]["savedParameters"])

    def test_uninspectable_or_missing_payload_fails_closed(self) -> None:
        for envelope in ({}, {"definition": {"parts": [{
            "path": "notebook-content.ipynb", "payloadType": "External", "payload": ""
        }]}}):
            with self.assertRaises(ValueError):
                inspect_definition(envelope)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inspect-definition", action="store_true",
                        help="Inspect saved-definition API JSON from stdin; print flags only.")
    arguments, remaining = parser.parse_known_args()
    if arguments.inspect_definition:
        try:
            report = inspect_definition(json.load(sys.stdin))
        except (ValueError, KeyError, TypeError, UnicodeError):
            print(json.dumps({"passed": False, "inspectionError": "Uninspectable definition"}))
            sys.exit(2)
        print(json.dumps(report))
        sys.exit(0 if report["passed"] else 1)
    unittest.main(argv=[sys.argv[0], *remaining])

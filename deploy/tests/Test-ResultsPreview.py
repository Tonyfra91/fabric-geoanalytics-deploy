#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Offline geometry and generated-notebook tests; no Spark or cloud required."""

import argparse
import json
from pathlib import Path
import runpy
import sys
import types
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET


MODULE = runpy.run_path(str(Path(__file__).resolve().parents[1] / "fabric" / "notebook" / "results-map.py"))
POLYGON = "POLYGON ((-84.4 33.7, -84.3 33.7, -84.3 33.8, -84.4 33.7))"
POINT = "POINT (-84.35 33.75)"
NOTEBOOK = None


class MapTests(unittest.TestCase):
    def test_point_and_polygon(self):
        self.assertEqual(MODULE["read_coordinates"](POINT, "POINT"), [(-84.35, 33.75)])
        self.assertEqual(len(MODULE["read_coordinates"](POLYGON, "POLYGON")), 4)
        self.assertEqual(MODULE["read_coordinates"]("point (1e1 -2e1)", "POINT"), [(10, -20)])

    def test_unsupported_or_invalid_geometry_fails(self):
        for wkt, geometry in (
            ("POINT EMPTY", "POINT"), ("POINT (1 2 3)", "POINT"),
            ("POINT (nan 2)", "POINT"), ("POINT (inf 2)", "POINT"),
            ("POINT (181 2)", "POINT"), ("POINT (1 -91)", "POINT"),
            ("POINT (1 2, 3 4)", "POINT"), ("MULTIPOLYGON (((1 2, 3 4, 1 2)))", "POLYGON"),
            ("POLYGON ((1 2, 3 4, 5 6))", "POLYGON"),
            ("POLYGON ((1 2, 3 4, 5 6, 1 2), (1 2, 3 4, 1 2))", "POLYGON"),
        ):
            with self.subTest(wkt=wkt), self.assertRaises(ValueError):
                MODULE["read_coordinates"](wkt, geometry)

    def test_svg_shape_and_escaping(self):
        svg = MODULE["render_map"]([POLYGON], [POLYGON], POINT, "<script>alert(1)</script>")
        root = ET.fromstring(svg)
        ns = {"s": "http://www.w3.org/2000/svg"}
        self.assertEqual(root.tag, "{http://www.w3.org/2000/svg}svg")
        self.assertEqual(len(root.findall(".//s:polygon", ns)), 2)
        self.assertEqual(len(root.findall(".//s:circle", ns)), 1)
        self.assertEqual(len(root.findall(".//s:script", ns)), 0)
        self.assertEqual(root.find("s:title", ns).text, "Zombie outbreak: <script>alert(1)</script>")
        self.assertNotIn("href", svg)
        for element in root.findall(".//s:polygon", ns):
            for pair in element.attrib["points"].split():
                x, y = map(float, pair.split(","))
                self.assertTrue(0 < x < 960 and 0 < y < 680)

    def test_empty_arrival_is_supported(self):
        self.assertIn("0 reached cells", MODULE["render_map"]([POLYGON], [], POINT, "run"))

    def test_bounds_and_degenerate_grid_fail(self):
        for grid in ([], [POLYGON] * 5001, ["POLYGON ((1 2, 1 2, 1 2, 1 2))"]):
            with self.subTest(size=len(grid)), self.assertRaises(ValueError):
                MODULE["render_map"](grid, [], POINT, "run")
        with self.assertRaises(ValueError):
            MODULE["render_map"]([POLYGON], [POLYGON] * 5001, POINT, "run")

    def test_exact_cell_limit_is_supported(self):
        root = ET.fromstring(MODULE["render_map"]([POLYGON] * 5000, [], POINT, "run"))
        self.assertEqual(len(root.findall(".//{http://www.w3.org/2000/svg}polygon")), 5000)

    def test_generated_notebook_reads_only_and_renders(self):
        if NOTEBOOK is None:
            self.skipTest("Generated notebook supplied by PowerShell test")
        self.execute_notebook()

    def test_generated_notebook_rejects_changed_counts_and_srid(self):
        if NOTEBOOK is None:
            self.skipTest("Generated notebook supplied by PowerShell test")
        for srid, changed_count in ((3857, False), (4326, True)):
            with self.subTest(srid=srid, changed_count=changed_count), self.assertRaises(RuntimeError):
                self.execute_notebook(srid=srid, changed_count=changed_count)

    def execute_notebook(self, srid=4326, changed_count=False):
        displayed = []
        requests = []
        receipts = []

        class ExitNotebook(Exception):
            pass

        class Frame:
            def __init__(self, table):
                self.table = table

            def select(self, geometry, projection):
                self.geometry = geometry
                self.assert_projection = projection
                return self

            def limit(self, limit):
                if limit != 5001:
                    raise AssertionError("Preview must bound collection.")
                return self

            def collect(self):
                if self.assert_projection != "geometry_srid":
                    raise AssertionError("Preview must check SRID.")
                value = POINT if self.geometry == "geometry_wkt" else POLYGON
                count = 2 if self.table == "grid" else 1
                if changed_count:
                    count += 1
                return [{self.geometry: value, "geometry_srid": srid} for _ in range(count)]

        def table(name):
            requests.append(name)
            return Frame(name)

        def exit_notebook(value):
            receipts.append(json.loads(value))
            raise ExitNotebook

        notebookutils = types.ModuleType("notebookutils")
        notebookutils.notebook = types.SimpleNamespace(exit=exit_notebook)
        display_module = types.ModuleType("IPython.display")
        display_module.SVG = lambda data: data
        display_module.display = displayed.append
        modules = {"notebookutils": notebookutils, "IPython": types.ModuleType("IPython"),
                   "IPython.display": display_module}
        source = "".join(NOTEBOOK["cells"][1]["source"])
        with patch.dict(sys.modules, modules), self.assertRaises(ExitNotebook):
            exec(compile(source, "<results-notebook>", "exec"), {"spark": types.SimpleNamespace(table=table)})
        self.assertEqual(requests, ["grid", "arrival", "origin"])
        self.assertEqual(len(displayed), 1)
        self.assertEqual(receipts[0]["preview"], "passed")
        self.assertEqual(receipts[0]["grid_rows"], 2)
        self.assertEqual(receipts[0]["arrival_rows"], 1)
        self.assertEqual(receipts[0]["svg"], displayed[0])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--notebook", type=Path)
    args, unittest_args = parser.parse_known_args()
    if args.notebook:
        NOTEBOOK = json.loads(args.notebook.read_text(encoding="utf-8-sig"))
    unittest.main(argv=[sys.argv[0], *unittest_args])

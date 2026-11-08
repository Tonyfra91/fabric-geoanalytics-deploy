#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Render bounded EPSG:4326 H3 output as a self-contained SVG, without services."""

import math
import re
import xml.etree.ElementTree as ET


def read_coordinates(wkt: str, geometry: str) -> list[tuple[float, float]]:
    """Read the demo's 2D POINT or single-ring POLYGON; reject other WKT."""
    wrapper = r"POINT\s*\(([^()]+)\)" if geometry == "POINT" else r"POLYGON\s*\(\(\s*([^()]+)\s*\)\)"
    match = re.fullmatch(wrapper, wkt.strip(), flags=re.IGNORECASE)
    if not match:
        raise ValueError(f"Preview requires a 2D {geometry} without holes.")
    coordinates = []
    for pair in match[1].split(","):
        values = pair.split()
        if len(values) != 2:
            raise ValueError("Preview coordinates must have two dimensions.")
        lon, lat = map(float, values)
        if not math.isfinite(lon) or not math.isfinite(lat) or abs(lon) > 180 or abs(lat) > 90:
            raise ValueError("Preview requires finite EPSG:4326 coordinates.")
        coordinates.append((lon, lat))
    if geometry == "POINT":
        if len(coordinates) != 1:
            raise ValueError("Preview origin must be one point.")
    else:
        if len(coordinates) < 4 or coordinates[0] != coordinates[-1]:
            raise ValueError("Preview polygon must be a closed ring.")
        x0, y0 = coordinates[0]
        area = math.fsum(
            (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
            for (x1, y1), (x2, y2) in zip(coordinates, coordinates[1:])
        )
        if area == 0:
            raise ValueError("Preview polygon must have nonzero area.")
    return coordinates


def render_map(
    grid: list[str], arrival: list[str], origin: str, run_id: str
) -> str:
    """Draw the study grid, reached cells and origin without external tiles."""
    if not grid or len(grid) > 5000 or len(arrival) > 5000:
        raise ValueError("Preview requires 1-5000 grid cells and at most 5000 reached cells.")
    rings = [read_coordinates(value, "POLYGON") for value in grid]
    reached = [read_coordinates(value, "POLYGON") for value in arrival]
    point = read_coordinates(origin, "POINT")[0]
    coordinates = [value for ring in rings + reached for value in ring] + [point]
    west = min(value[0] for value in coordinates)
    east = max(value[0] for value in coordinates)
    south = min(value[1] for value in coordinates)
    north = max(value[1] for value in coordinates)
    if east - west >= 180 or east == west or north == south:
        raise ValueError("Preview requires a nondegenerate grid without an antimeridian crossing.")
    longitude_scale = max(math.cos(math.radians((north + south) / 2)), 1e-6)
    scale = min(800 / ((east - west) * longitude_scale), 520 / (north - south))
    left = (960 - (east - west) * longitude_scale * scale) / 2
    top = 70 + (520 - (north - south) * scale) / 2

    def project(coordinate: tuple[float, float]) -> tuple[float, float]:
        lon, lat = coordinate
        return left + (lon - west) * longitude_scale * scale, top + (north - lat) * scale

    root = ET.Element("svg", {
        "xmlns": "http://www.w3.org/2000/svg", "viewBox": "0 0 960 680",
        "role": "img", "aria-labelledby": "map-title map-description",
    })
    ET.SubElement(root, "title", {"id": "map-title"}).text = f"Zombie outbreak: {run_id}"
    ET.SubElement(root, "desc", {"id": "map-description"}).text = (
        f"North-up EPSG:4326 spatial preview: {len(grid)} grid cells, "
        f"{len(arrival)} reached cells, one origin. Red means reached, not population."
    )
    ET.SubElement(root, "rect", {"width": "960", "height": "680", "fill": "white"})
    ET.SubElement(root, "text", {"x": "30", "y": "30", "font-size": "20"}).text = f"Run {run_id}"
    for layer, polygons, fill in (("grid", rings, "#e5e7eb"), ("arrival", reached, "#ef4444")):
        group = ET.SubElement(root, "g", {"id": layer})
        for ring in polygons:
            points = " ".join(f"{x:.3f},{y:.3f}" for x, y in map(project, ring))
            ET.SubElement(group, "polygon", {
                "points": points, "fill": fill, "stroke": "#374151", "stroke-width": "1",
            })
    x, y = project(point)
    ET.SubElement(root, "circle", {
        "id": "origin", "cx": f"{x:.3f}", "cy": f"{y:.3f}",
        "r": "6", "fill": "#2563eb", "stroke": "white", "stroke-width": "2",
    })
    for y, text in (
        (620, "Gray: study grid | Red: reached cells | Blue: outbreak origin | North is up"),
        (646, "Local equirectangular preview from EPSG:4326 WKT. No basemap or ArcGIS publication."),
    ):
        ET.SubElement(root, "text", {"x": "30", "y": str(y), "font-size": "15"}).text = text
    return ET.tostring(root, encoding="unicode")

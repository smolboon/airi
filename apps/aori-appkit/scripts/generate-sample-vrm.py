#!/usr/bin/env python3
"""Write the CC0 sample VRM used by the native companion."""

import json
import math
import struct
from pathlib import Path


def sphere(stacks, slices, radius, center):
    positions = []
    normals = []
    for stack in range(stacks + 1):
        phi = stack / stacks * math.pi
        for slice_index in range(slices):
            theta = slice_index / slices * (2 * math.pi)
            normal = (
                math.sin(phi) * math.cos(theta),
                math.cos(phi),
                math.sin(phi) * math.sin(theta),
            )
            normals.append(normal)
            positions.append(tuple(center[axis] + normal[axis] * radius for axis in range(3)))
    indices = []
    for stack in range(stacks):
        for slice_index in range(slices):
            a = stack * slices + slice_index
            b = stack * slices + (slice_index + 1) % slices
            c = (stack + 1) * slices + slice_index
            d = (stack + 1) * slices + (slice_index + 1) % slices
            indices.extend((a, c, b, b, c, d))
    return positions, normals, indices


def pad(data, byte):
    while len(data) % 4:
        data += bytes([byte])
    return data


def main():
    head_positions, head_normals, head_indices = sphere(8, 12, 0.28, (0.0, 0.2, 0.0))
    left_positions, left_normals, left_indices = sphere(4, 6, 0.035, (-0.09, 0.28, 0.22))
    right_positions, right_normals, right_indices = sphere(4, 6, 0.035, (0.09, 0.28, 0.22))
    eye_positions = left_positions + right_positions
    eye_normals = left_normals + right_normals
    eye_indices = list(left_indices)
    offset = len(left_positions)
    eye_indices.extend(index + offset for index in right_indices)

    def delta(kind, position):
        x, y, z = position
        if kind == "aa" and y < 0.12 and z > 0.12:
            return (0.0, -0.045, 0.02)
        if kind == "joy" and 0.18 < y < 0.36 and z > 0.08:
            return (0.0, 0.025, 0.01)
        if kind == "sorrow" and y < 0.16 and z > 0.1:
            return (0.0, -0.02, 0.0)
        if kind == "surprised" and 0.22 < y < 0.36 and z > 0.1:
            return (x * 0.08, 0.03, 0.0)
        if kind == "blink" and 0.24 < y < 0.34 and z > 0.12:
            return (0.0, -0.03, 0.0)
        return (0.0, 0.0, 0.0)

    morph_names = ["aa", "joy", "sorrow", "surprised", "blink"]
    morphs = [[delta(name, position) for position in head_positions] for name in morph_names]

    blobs = []

    def add_floats(vectors):
        start = sum(len(blob) for blob in blobs)
        blob = b"".join(struct.pack("<fff", *vector) for vector in vectors)
        blobs.append(blob)
        return start, len(blob), len(vectors)

    def add_indices(indices):
        start = sum(len(blob) for blob in blobs)
        blob = b"".join(struct.pack("<H", index) for index in indices)
        blobs.append(blob)
        return start, len(blob), len(indices)

    buffer_views = []
    accessors = []

    def view(start, length, stride=None):
        item = {"buffer": 0, "byteOffset": start, "byteLength": length}
        if stride:
            item["byteStride"] = stride
        buffer_views.append(item)
        return len(buffer_views) - 1

    def accessor(view_index, count, component_type, value_type):
        accessors.append({
            "bufferView": view_index,
            "componentType": component_type,
            "count": count,
            "type": value_type,
        })
        return len(accessors) - 1

    def vec3(vectors):
        start, length, count = add_floats(vectors)
        return accessor(view(start, length, 12), count, 5126, "VEC3")

    def scalar(indices):
        start, length, count = add_indices(indices)
        return accessor(view(start, length), count, 5123, "SCALAR")

    head_position = vec3(head_positions)
    head_normal = vec3(head_normals)
    head_index = scalar(head_indices)
    morph_accessors = [vec3(morph) for morph in morphs]
    eye_position = vec3(eye_positions)
    eye_normal = vec3(eye_normals)
    eye_index = scalar(eye_indices)

    binary = pad(b"".join(blobs), 0)
    document = {
        "asset": {"version": "2.0", "generator": "aori-sample-vrm"},
        "extensionsUsed": ["VRM"],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": buffer_views,
        "accessors": accessors,
        "materials": [
            {"name": "skin", "pbrMetallicRoughness": {"baseColorFactor": [0.96, 0.78, 0.74, 1], "metallicFactor": 0, "roughnessFactor": 0.7}},
            {"name": "eyes", "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.1, 0.16, 1], "metallicFactor": 0, "roughnessFactor": 0.4}},
        ],
        "meshes": [
            {
                "name": "head",
                "extras": {"targetNames": morph_names},
                "primitives": [{
                    "attributes": {"POSITION": head_position, "NORMAL": head_normal},
                    "indices": head_index,
                    "material": 0,
                    "targets": [{"POSITION": accessor} for accessor in morph_accessors],
                }],
            },
            {
                "name": "eyes",
                "primitives": [{
                    "attributes": {"POSITION": eye_position, "NORMAL": eye_normal},
                    "indices": eye_index,
                    "material": 1,
                }],
            },
        ],
        "nodes": [
            {"name": "head", "mesh": 0},
            {"name": "eyes", "mesh": 1},
        ],
        "scenes": [{"nodes": [0, 1]}],
        "scene": 0,
        "extensions": {
            "VRM": {
                "meta": {
                    "title": "Aori Sample",
                    "version": "1.0",
                    "author": "Aori",
                    "licenseName": "CC0",
                },
                "blendShapeMaster": {
                    "blendShapeGroups": [
                        {"name": "A", "presetName": "a", "binds": [{"mesh": 0, "index": 0, "weight": 100}]},
                        {"name": "Joy", "presetName": "joy", "binds": [{"mesh": 0, "index": 1, "weight": 100}]},
                        {"name": "Sorrow", "presetName": "sorrow", "binds": [{"mesh": 0, "index": 2, "weight": 100}]},
                        {"name": "Surprised", "presetName": "surprised", "binds": [{"mesh": 0, "index": 3, "weight": 100}]},
                        {"name": "Blink", "presetName": "blink", "binds": [{"mesh": 0, "index": 4, "weight": 100}]},
                    ]
                },
            }
        },
    }
    json_bytes = pad(json.dumps(document, separators=(",", ":")).encode("utf-8"), 0x20)
    length = 12 + 8 + len(json_bytes) + 8 + len(binary)
    header = struct.pack("<III", 0x46546C67, 2, length)
    json_chunk = struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
    bin_chunk = struct.pack("<II", len(binary), 0x004E4942) + binary
    destination = Path(__file__).resolve().parents[1] / "Sources" / "AoriApp" / "Resources" / "aori-sample.vrm"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(header + json_chunk + bin_chunk)
    print(destination, destination.stat().st_size)


if __name__ == "__main__":
    main()

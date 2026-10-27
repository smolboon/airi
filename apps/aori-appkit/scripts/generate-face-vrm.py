#!/usr/bin/env python3
"""Write the CC0 portrait VRM. This script does not replace Butter."""

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


def box(center, half):
    cx, cy, cz = center
    hx, hy, hz = half
    corners = []
    for x in (-hx, hx):
        for y in (-hy, hy):
            for z in (-hz, hz):
                corners.append((cx + x, cy + y, cz + z))
    quads = [
        (0, 1, 3, 2),
        (4, 6, 7, 5),
        (0, 4, 5, 1),
        (2, 3, 7, 6),
        (0, 2, 6, 4),
        (1, 5, 7, 3),
    ]
    indices = []
    for a, b, c, d in quads:
        indices.extend((a, b, c, a, c, d))
    normals = []
    for x, y, z in corners:
        dx, dy, dz = x - cx, y - cy, z - cz
        length = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
        normals.append((dx / length, dy / length, dz / length))
    return corners, normals, indices


def ribbon(columns, origin_y, origin_z, width, thick):
    positions = []
    for row in range(2):
        for column in range(columns):
            span = column / (columns - 1)
            positions.append((
                (span - 0.5) * width,
                origin_y + (row - 0.5) * thick,
                origin_z,
            ))
    indices = []
    for column in range(columns - 1):
        a = column
        b = column + 1
        c = columns + column
        d = columns + column + 1
        indices.extend((a, b, c, b, d, c))
    normals = [(0.0, 0.0, 1.0)] * len(positions)
    return positions, normals, indices


def zeros(count):
    return [(0.0, 0.0, 0.0)] * count


def smile(positions, columns, direction):
    deltas = []
    for index, position in enumerate(positions):
        column = index % columns
        edge = abs(column / (columns - 1) - 0.5) * 2
        lift = direction * (edge * 0.055 - (1 - edge) * 0.01)
        deltas.append((0.0, lift, 0.012 if direction > 0 else 0.0))
    return deltas


def gasp(positions, columns):
    deltas = []
    for index, position in enumerate(positions):
        row = 0 if index < columns else 1
        direction = -1 if row == 0 else 1
        deltas.append((position[0] * 0.35, direction * 0.04, 0.02))
    return deltas


def open_a(positions, columns):
    deltas = []
    for index, _position in enumerate(positions):
        row = 0 if index < columns else 1
        direction = -1 if row == 0 else 1
        deltas.append((0.0, direction * 0.012, 0.0))
    return deltas


def brow_delta(kind, positions):
    amount = {"joy": 0.025, "sorrow": -0.03, "surprised": 0.05}.get(kind, 0.0)
    return [(0.0, amount, 0.0)] * len(positions)


class Bin:
    def __init__(self):
        self.data = bytearray()
        self.views = []
        self.accessors = []

    def align(self):
        while len(self.data) % 4:
            self.data.append(0)

    def view(self, blob, stride=None):
        self.align()
        start = len(self.data)
        self.data.extend(blob)
        item = {"buffer": 0, "byteOffset": start, "byteLength": len(blob)}
        if stride:
            item["byteStride"] = stride
        self.views.append(item)
        return len(self.views) - 1

    def accessor(self, view_index, count, component_type, value_type):
        self.accessors.append({
            "bufferView": view_index,
            "componentType": component_type,
            "count": count,
            "type": value_type,
        })
        return len(self.accessors) - 1

    def vec3(self, vectors):
        blob = b"".join(struct.pack("<fff", *vector) for vector in vectors)
        return self.accessor(self.view(blob, 12), len(vectors), 5126, "VEC3")

    def scalar(self, indices):
        blob = b"".join(struct.pack("<H", index) for index in indices)
        return self.accessor(self.view(blob), len(indices), 5123, "SCALAR")


def material(name, color):
    return {
        "name": name,
        "pbrMetallicRoughness": {
            "baseColorFactor": [color[0], color[1], color[2], 1],
            "metallicFactor": 0,
            "roughnessFactor": 0.6,
        },
        "doubleSided": True,
    }


def mesh(name, positions, normals, indices, material_index, morphs, morph_names, binary):
    targets = []
    for morph in morphs:
        targets.append({"POSITION": binary.vec3(morph)})
    return {
        "name": name,
        "extras": {"targetNames": morph_names},
        "primitives": [{
            "attributes": {
                "POSITION": binary.vec3(positions),
                "NORMAL": binary.vec3(normals),
            },
            "indices": binary.scalar(indices),
            "material": material_index,
            "targets": targets,
        }],
    }


def pad(data, byte):
    data = bytearray(data)
    while len(data) % 4:
        data.append(byte)
    return bytes(data)


def main():
    head_positions, head_normals, head_indices = sphere(10, 14, 0.30, (0.0, 1.55, 0.0))
    left_eye, left_eye_normals, left_eye_indices = sphere(6, 8, 0.055, (-0.09, 1.66, 0.30))
    right_eye, right_eye_normals, right_eye_indices = sphere(6, 8, 0.055, (0.09, 1.66, 0.30))
    left_pupil, left_pupil_normals, left_pupil_indices = sphere(4, 6, 0.024, (-0.09, 1.66, 0.355))
    right_pupil, right_pupil_normals, right_pupil_indices = sphere(4, 6, 0.024, (0.09, 1.66, 0.355))
    nose_positions, nose_normals, nose_indices = box((0.0, 1.58, 0.34), (0.022, 0.038, 0.045))
    mouth_positions, mouth_normals, mouth_indices = ribbon(7, 1.52, 0.36, 0.16, 0.04)
    left_brow, left_brow_normals, left_brow_indices = box((-0.09, 1.74, 0.33), (0.05, 0.014, 0.015))
    right_brow, right_brow_normals, right_brow_indices = box((0.09, 1.74, 0.33), (0.05, 0.014, 0.015))
    shoulders, shoulder_normals, shoulder_indices = box((0.0, 1.34, -0.04), (0.50, 0.18, 0.10))

    columns = 7
    mouth_morphs = [
        open_a(mouth_positions, columns),
        smile(mouth_positions, columns, 1),
        smile(mouth_positions, columns, -1),
        gasp(mouth_positions, columns),
    ]
    brow_names = ["joy", "sorrow", "surprised"]

    binary = Bin()
    meshes = [
        mesh("head", head_positions, head_normals, head_indices, 0, [], [], binary),
        mesh("eyes", left_eye, left_eye_normals, left_eye_indices, 1, [], [], binary),
        mesh("eyes", right_eye, right_eye_normals, right_eye_indices, 1, [], [], binary),
        mesh("pupils", left_pupil, left_pupil_normals, left_pupil_indices, 2, [], [], binary),
        mesh("pupils", right_pupil, right_pupil_normals, right_pupil_indices, 2, [], [], binary),
        mesh("nose", nose_positions, nose_normals, nose_indices, 0, [], [], binary),
        mesh(
            "mouth",
            mouth_positions,
            mouth_normals,
            mouth_indices,
            3,
            mouth_morphs,
            ["a", "joy", "sorrow", "surprised"],
            binary,
        ),
        mesh(
            "brows",
            left_brow,
            left_brow_normals,
            left_brow_indices,
            2,
            [brow_delta(name, left_brow) for name in brow_names],
            brow_names,
            binary,
        ),
        mesh(
            "brows",
            right_brow,
            right_brow_normals,
            right_brow_indices,
            2,
            [brow_delta(name, right_brow) for name in brow_names],
            brow_names,
            binary,
        ),
        mesh("shoulders", shoulders, shoulder_normals, shoulder_indices, 4, [], [], binary),
    ]
    mouth_index = 6
    left_brow_index = 7
    right_brow_index = 8
    document = {
        "asset": {"version": "2.0", "generator": "aori-face-vrm"},
        "extensionsUsed": ["VRM"],
        "buffers": [{"byteLength": 0}],
        "bufferViews": binary.views,
        "accessors": binary.accessors,
        "materials": [
            material("skin", (0.96, 0.76, 0.68)),
            material("eye", (0.96, 0.97, 0.98)),
            material("dark", (0.08, 0.06, 0.07)),
            material("mouth", (0.78, 0.18, 0.24)),
            material("shirt", (0.25, 0.42, 0.72)),
        ],
        "meshes": meshes,
        "nodes": [{"name": item["name"], "mesh": index} for index, item in enumerate(meshes)],
        "scenes": [{"nodes": list(range(len(meshes)))}],
        "scene": 0,
        "extensions": {
            "VRM": {
                "meta": {
                    "title": "Aori Face",
                    "author": "Aori",
                    "licenseName": "CC0",
                    "otherLicenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/",
                },
                "humanoid": {
                    "humanBones": [
                        {"bone": "hips", "node": 9, "useDefaultValues": True},
                        {"bone": "head", "node": 0, "useDefaultValues": True},
                    ]
                },
                "blendShapeMaster": {
                    "blendShapeGroups": [
                        {
                            "name": "A",
                            "presetName": "a",
                            "binds": [{"mesh": mouth_index, "index": 0, "weight": 100}],
                        },
                        {
                            "name": "Joy",
                            "presetName": "joy",
                            "binds": [
                                {"mesh": mouth_index, "index": 1, "weight": 100},
                                {"mesh": left_brow_index, "index": 0, "weight": 100},
                                {"mesh": right_brow_index, "index": 0, "weight": 100},
                            ],
                        },
                        {
                            "name": "Sorrow",
                            "presetName": "sorrow",
                            "binds": [
                                {"mesh": mouth_index, "index": 2, "weight": 100},
                                {"mesh": left_brow_index, "index": 1, "weight": 100},
                                {"mesh": right_brow_index, "index": 1, "weight": 100},
                            ],
                        },
                        {
                            "name": "Surprised",
                            "presetName": "surprised",
                            "binds": [
                                {"mesh": mouth_index, "index": 3, "weight": 100},
                                {"mesh": left_brow_index, "index": 2, "weight": 100},
                                {"mesh": right_brow_index, "index": 2, "weight": 100},
                            ],
                        },
                    ]
                },
            }
        },
    }
    blob = pad(binary.data, 0)
    document["buffers"][0]["byteLength"] = len(blob)
    json_bytes = pad(json.dumps(document, separators=(",", ":")).encode("utf-8"), 0x20)
    length = 12 + 8 + len(json_bytes) + 8 + len(blob)
    header = struct.pack("<III", 0x46546C67, 2, length)
    json_chunk = struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
    bin_chunk = struct.pack("<II", len(blob), 0x004E4942) + blob
    destination = Path(__file__).resolve().parents[1] / "Sources/AoriApp/Resources/aori-face.vrm"
    destination.write_bytes(header + json_chunk + bin_chunk)
    print(destination, destination.stat().st_size)


if __name__ == "__main__":
    main()

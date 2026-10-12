#!/usr/bin/env python3
"""Write the CC0 sample VRM used by the native companion."""

import json
import math
import struct
import zlib
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


def uv_of(position, center):
    dx = position[0] - center[0]
    dy = position[1] - center[1]
    dz = position[2] - center[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
    u = math.atan2(dx / length, dz / length) / (2 * math.pi) + 0.5
    v = (dy / length) * 0.5 + 0.5
    return (u, v)


def png(width, height, pixels):
    def chunk(tag, data):
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride:(y + 1) * stride])
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def checker(width, height, cell):
    pixels = bytearray()
    for y in range(height):
        for x in range(width):
            if ((x // cell) + (y // cell)) % 2 == 0:
                pixels.extend((255, 214, 196, 255))
            else:
                pixels.extend((214, 64, 112, 255))
    return png(width, height, pixels)


def pad(data, byte):
    data = bytearray(data)
    while len(data) % 4:
        data.append(byte)
    return bytes(data)


def quat_z(angle):
    half = angle * 0.5
    return (0.0, 0.0, math.sin(half), math.cos(half))


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

    def vec2(self, vectors):
        blob = b"".join(struct.pack("<ff", *vector) for vector in vectors)
        return self.accessor(self.view(blob, 8), len(vectors), 5126, "VEC2")

    def joints(self, values):
        blob = b"".join(struct.pack("<HHHH", *value) for value in values)
        return self.accessor(self.view(blob), len(values), 5123, "VEC4")

    def weights(self, values):
        blob = b"".join(struct.pack("<ffff", *value) for value in values)
        return self.accessor(self.view(blob, 16), len(values), 5126, "VEC4")

    def scalar(self, indices):
        blob = b"".join(struct.pack("<H", index) for index in indices)
        return self.accessor(self.view(blob), len(indices), 5123, "SCALAR")

    def mat4(self, matrices):
        blob = b"".join(struct.pack("<16f", *matrix) for matrix in matrices)
        return self.accessor(self.view(blob), len(matrices), 5126, "MAT4")

    def floats(self, values, value_type):
        blob = b"".join(struct.pack("<f", value) for value in values)
        return self.accessor(self.view(blob), len(values), 5126, value_type)


def skin_weights(count):
    # Joint 1 is the neck. Every vertex of this sample follows that bone.
    return [(0, 1, 0, 0)] * count, [(0.0, 1.0, 0.0, 0.0)] * count


def main():
    head_center = (0.0, 0.2, 0.0)
    left_center = (-0.09, 0.26, 0.30)
    right_center = (0.09, 0.26, 0.30)
    head_positions, head_normals, head_indices = sphere(8, 12, 0.28, head_center)
    left_positions, left_normals, left_indices = sphere(4, 6, 0.045, left_center)
    right_positions, right_normals, right_indices = sphere(4, 6, 0.045, right_center)
    eye_positions = left_positions + right_positions
    eye_normals = left_normals + right_normals
    eye_indices = list(left_indices)
    offset = len(left_positions)
    eye_indices.extend(index + offset for index in right_indices)

    def head_delta(kind, position):
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

    def eye_delta(kind, position):
        if kind != "blink":
            return (0.0, 0.0, 0.0)
        center_y = left_center[1] if position[0] < 0 else right_center[1]
        return (0.0, (center_y - position[1]) * 0.85, 0.0)

    morph_names = ["aa", "joy", "sorrow", "surprised", "blink"]
    head_morphs = [[head_delta(name, position) for position in head_positions] for name in morph_names]
    eye_blink = [eye_delta("blink", position) for position in eye_positions]
    head_uvs = [uv_of(position, head_center) for position in head_positions]
    eye_uvs = [uv_of(position, left_center if position[0] < 0 else right_center) for position in eye_positions]
    head_joints, head_weights = skin_weights(len(head_positions))
    eye_joints, eye_weights = skin_weights(len(eye_positions))

    identity = (
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    )
    # Inverse of the neck translation (0, 0.05, 0). Bind pose stays put.
    neck_inverse = (
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, -0.05, 0.0, 1.0,
    )
    texture = checker(64, 64, 8)
    turn = quat_z(0.18)

    binary = Bin()
    head_position = binary.vec3(head_positions)
    head_normal = binary.vec3(head_normals)
    head_uv = binary.vec2(head_uvs)
    head_joint = binary.joints(head_joints)
    head_weight = binary.weights(head_weights)
    head_index = binary.scalar(head_indices)
    morph_accessors = [binary.vec3(morph) for morph in head_morphs]
    eye_position = binary.vec3(eye_positions)
    eye_normal = binary.vec3(eye_normals)
    eye_uv = binary.vec2(eye_uvs)
    eye_joint = binary.joints(eye_joints)
    eye_weight = binary.weights(eye_weights)
    eye_index = binary.scalar(eye_indices)
    eye_blink_accessor = binary.vec3(eye_blink)
    inverse_bind = binary.mat4([identity, neck_inverse])
    time_accessor = binary.floats([0.0, 1.6, 3.2], "SCALAR")
    rotation_blob = b"".join(
        struct.pack("<ffff", *quat) for quat in ((0.0, 0.0, 0.0, 1.0), turn, (0.0, 0.0, 0.0, 1.0))
    )
    rotation_accessor = binary.accessor(binary.view(rotation_blob, 16), 3, 5126, "VEC4")
    image_view = binary.view(texture)

    document = {
        "asset": {"version": "2.0", "generator": "aori-sample-vrm"},
        "extensionsUsed": ["VRM"],
        "buffers": [{"byteLength": len(binary.data)}],
        "bufferViews": binary.views,
        "accessors": binary.accessors,
        "images": [{"bufferView": image_view, "mimeType": "image/png"}],
        "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 10497, "wrapT": 10497}],
        "textures": [{"sampler": 0, "source": 0}],
        "materials": [
            {
                "name": "skin",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.96, 0.78, 0.74, 1],
                    "baseColorTexture": {"index": 0},
                    "metallicFactor": 0,
                    "roughnessFactor": 0.7,
                },
            },
            {
                "name": "eyes",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.12, 0.1, 0.16, 1],
                    "metallicFactor": 0,
                    "roughnessFactor": 0.4,
                },
            },
        ],
        "meshes": [
            {
                "name": "head",
                "extras": {"targetNames": morph_names},
                "primitives": [{
                    "attributes": {
                        "POSITION": head_position,
                        "NORMAL": head_normal,
                        "TEXCOORD_0": head_uv,
                        "JOINTS_0": head_joint,
                        "WEIGHTS_0": head_weight,
                    },
                    "indices": head_index,
                    "material": 0,
                    "targets": [{"POSITION": accessor} for accessor in morph_accessors],
                }],
            },
            {
                "name": "eyes",
                "extras": {"targetNames": ["blink"]},
                "primitives": [{
                    "attributes": {
                        "POSITION": eye_position,
                        "NORMAL": eye_normal,
                        "TEXCOORD_0": eye_uv,
                        "JOINTS_0": eye_joint,
                        "WEIGHTS_0": eye_weight,
                    },
                    "indices": eye_index,
                    "material": 1,
                    "targets": [{"POSITION": eye_blink_accessor}],
                }],
            },
        ],
        "nodes": [
            {"name": "root", "translation": [0, 0, 0], "children": [1]},
            {"name": "neck", "translation": [0, 0.05, 0]},
            {"name": "head", "mesh": 0, "skin": 0},
            {"name": "eyes", "mesh": 1, "skin": 0},
        ],
        "skins": [{
            "name": "armature",
            "joints": [0, 1],
            "inverseBindMatrices": inverse_bind,
        }],
        "animations": [{
            "name": "idle",
            "channels": [{"sampler": 0, "target": {"node": 1, "path": "rotation"}}],
            "samplers": [{
                "input": time_accessor,
                "output": rotation_accessor,
                "interpolation": "LINEAR",
            }],
        }],
        "scenes": [{"nodes": [0, 2, 3]}],
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
    blob = pad(binary.data, 0)
    document["buffers"][0]["byteLength"] = len(blob)
    json_bytes = pad(json.dumps(document, separators=(",", ":")).encode("utf-8"), 0x20)
    length = 12 + 8 + len(json_bytes) + 8 + len(blob)
    header = struct.pack("<III", 0x46546C67, 2, length)
    json_chunk = struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
    bin_chunk = struct.pack("<II", len(blob), 0x004E4942) + blob
    destination = Path(__file__).resolve().parents[1] / "Sources" / "AoriApp" / "Resources" / "aori-sample.vrm"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(header + json_chunk + bin_chunk)
    print(destination, destination.stat().st_size)


if __name__ == "__main__":
    main()

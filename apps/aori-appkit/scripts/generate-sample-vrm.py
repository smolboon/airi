#!/usr/bin/env python3
"""Write a small generated VRM. The shipped sample is Butter, not this file."""

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


def solid(width, height, color):
    pixels = bytearray()
    for _ in range(width * height):
        pixels.extend(color)
    return png(width, height, pixels)


def pad(data, byte):
    data = bytearray(data)
    while len(data) % 4:
        data.append(byte)
    return bytes(data)


def quat_axis(x, y, z, angle):
    half = angle * 0.5
    scale = math.sin(half)
    return (x * scale, y * scale, z * scale, math.cos(half))


def inverse_translation(x, y, z):
    return (
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        -x, -y, -z, 1.0,
    )


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
        # Real VRM files store JOINTS_0 as unsigned bytes.
        blob = b"".join(struct.pack("<BBBB", *value) for value in values)
        return self.accessor(self.view(blob), len(values), 5121, "VEC4")

    def rotations(self, quats):
        blob = b"".join(struct.pack("<ffff", *quat) for quat in quats)
        return self.accessor(self.view(blob, 16), len(quats), 5126, "VEC4")

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


def head_skin(count):
    # Joint 3 is the head. Neck and head clips move the head through that bone.
    return [(3, 0, 0, 0)] * count, [(1.0, 0.0, 0.0, 0.0)] * count


def eye_skin(positions, left_count):
    joints = []
    for index in range(len(positions)):
        joint = 4 if index < left_count else 5
        joints.append((joint, 0, 0, 0))
    return joints, [(1.0, 0.0, 0.0, 0.0)] * len(positions)


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
        if kind == "ih" and 0.08 < y < 0.2 and z > 0.1:
            return (0.012, -0.02, 0.03)
        if kind == "ou" and y < 0.16 and z > 0.08:
            return (0.0, -0.03, 0.05)
        if kind == "ee" and y < 0.18 and z > 0.1:
            return (0.03, -0.01, 0.0)
        if kind == "oh" and y < 0.16 and z > 0.1:
            return (0.0, -0.04, 0.012)
        if kind == "pp" and y < 0.14 and z > 0.12:
            return (0.0, 0.012, -0.01)
        return (0.0, 0.0, 0.0)

    def eye_delta(kind, position):
        if kind != "blink":
            return (0.0, 0.0, 0.0)
        center_y = left_center[1] if position[0] < 0 else right_center[1]
        return (0.0, (center_y - position[1]) * 0.85, 0.0)

    morph_names = ["aa", "joy", "sorrow", "surprised", "blink", "ih", "ou", "ee", "oh", "pp"]
    head_morphs = [[head_delta(name, position) for position in head_positions] for name in morph_names]
    eye_blink = [eye_delta("blink", position) for position in eye_positions]
    head_uvs = [uv_of(position, head_center) for position in head_positions]
    eye_uvs = [uv_of(position, left_center if position[0] < 0 else right_center) for position in eye_positions]
    head_joints, head_weights = head_skin(len(head_positions))
    eye_joints, eye_weights = eye_skin(eye_positions, len(left_positions))
    texture = solid(64, 64, (255, 214, 196, 255))
    rest = (0.0, 0.0, 0.0, 1.0)
    # World positions: hips 0, spine 0.02, neck 0.05, head 0.17, eyes at the eye centers.
    binds = [
        inverse_translation(0.0, 0.0, 0.0),
        inverse_translation(0.0, 0.02, 0.0),
        inverse_translation(0.0, 0.05, 0.0),
        inverse_translation(0.0, 0.17, 0.0),
        inverse_translation(-0.09, 0.26, 0.30),
        inverse_translation(0.09, 0.26, 0.30),
        inverse_translation(-0.16, 0.04, 0.0),
        inverse_translation(-0.16, -0.04, 0.0),
        inverse_translation(-0.16, -0.14, 0.0),
        inverse_translation(0.16, 0.04, 0.0),
        inverse_translation(0.16, -0.04, 0.0),
        inverse_translation(0.16, -0.14, 0.0),
    ]
    left_arm, left_arm_normals, left_arm_indices = box((-0.16, -0.14, 0.0), (0.02, 0.05, 0.02))
    right_arm, right_arm_normals, right_arm_indices = box((0.16, -0.14, 0.0), (0.02, 0.05, 0.02))
    arm_positions = left_arm + right_arm
    arm_normals = left_arm_normals + right_arm_normals
    arm_indices = list(left_arm_indices)
    arm_indices.extend(index + len(left_arm) for index in right_arm_indices)
    arm_joints = [(8, 0, 0, 0)] * len(left_arm) + [(11, 0, 0, 0)] * len(right_arm)
    arm_weights = [(1.0, 0.0, 0.0, 0.0)] * len(arm_positions)

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
    arm_position = binary.vec3(arm_positions)
    arm_normal = binary.vec3(arm_normals)
    arm_joint = binary.joints(arm_joints)
    arm_weight = binary.weights(arm_weights)
    arm_index = binary.scalar(arm_indices)
    inverse_bind = binary.mat4(binds)
    idle_time = binary.floats([0.0, 1.6, 3.2], "SCALAR")
    blink_time = binary.floats([0.0, 0.12, 0.24], "SCALAR")
    idle_keys = [
        (rest, quat_axis(0, 0, 1, 0.18), rest),
        (rest, quat_axis(0, 1, 0, 0.22), rest),
        (rest, quat_axis(0, 1, 0, 0.40), rest),
        (rest, quat_axis(0, 1, 0, -0.25), rest),
        (rest, quat_axis(0, 0, 1, 0.55), rest),
        (rest, quat_axis(0, 0, 1, -0.55), rest),
    ]
    blink_turn = quat_axis(1, 0, 0, 0.8)
    blink_keys = [
        (rest, blink_turn, rest),
        (rest, blink_turn, rest),
    ]
    idle_rotations = [binary.rotations(keys) for keys in idle_keys]
    blink_rotations = [binary.rotations(keys) for keys in blink_keys]
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
            {
                "name": "arms",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.96, 0.78, 0.74, 1],
                    "metallicFactor": 0,
                    "roughnessFactor": 0.7,
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
            {
                "name": "arms",
                "primitives": [{
                    "attributes": {
                        "POSITION": arm_position,
                        "NORMAL": arm_normal,
                        "JOINTS_0": arm_joint,
                        "WEIGHTS_0": arm_weight,
                    },
                    "indices": arm_index,
                    "material": 2,
                }],
            },
        ],
        "nodes": [
            {"name": "hips", "translation": [0, 0, 0], "children": [1]},
            {"name": "spine", "translation": [0, 0.02, 0], "children": [2, 6, 9]},
            {"name": "neck", "translation": [0, 0.03, 0], "children": [3]},
            {"name": "head", "translation": [0, 0.12, 0], "children": [4, 5]},
            {"name": "leftEye", "translation": [-0.09, 0.09, 0.30]},
            {"name": "rightEye", "translation": [0.09, 0.09, 0.30]},
            {"name": "leftShoulder", "translation": [-0.16, 0.02, 0], "children": [7]},
            {"name": "leftUpperArm", "translation": [0, -0.08, 0], "children": [8]},
            {"name": "leftLowerArm", "translation": [0, -0.10, 0]},
            {"name": "rightShoulder", "translation": [0.16, 0.02, 0], "children": [10]},
            {"name": "rightUpperArm", "translation": [0, -0.08, 0], "children": [11]},
            {"name": "rightLowerArm", "translation": [0, -0.10, 0]},
            {"name": "headMesh", "mesh": 0, "skin": 0},
            {"name": "eyesMesh", "mesh": 1, "skin": 0},
            {"name": "armsMesh", "mesh": 2, "skin": 0},
        ],
        "skins": [{
            "name": "armature",
            "joints": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
            "inverseBindMatrices": inverse_bind,
        }],
        "animations": [
            {
                "name": "idle",
                "channels": [
                    {"sampler": 0, "target": {"node": 2, "path": "rotation"}},
                    {"sampler": 1, "target": {"node": 3, "path": "rotation"}},
                    {"sampler": 2, "target": {"node": 4, "path": "rotation"}},
                    {"sampler": 3, "target": {"node": 5, "path": "rotation"}},
                    {"sampler": 4, "target": {"node": 8, "path": "rotation"}},
                    {"sampler": 5, "target": {"node": 11, "path": "rotation"}},
                ],
                "samplers": [
                    {"input": idle_time, "output": accessor, "interpolation": "LINEAR"}
                    for accessor in idle_rotations
                ],
            },
            {
                "name": "blink",
                "channels": [
                    {"sampler": 0, "target": {"node": 4, "path": "rotation"}},
                    {"sampler": 1, "target": {"node": 5, "path": "rotation"}},
                ],
                "samplers": [
                    {"input": blink_time, "output": accessor, "interpolation": "LINEAR"}
                    for accessor in blink_rotations
                ],
            },
        ],
        "scenes": [{"nodes": [0, 12, 13, 14]}],
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
                        {"name": "I", "presetName": "i", "binds": [{"mesh": 0, "index": 5, "weight": 100}]},
                        {"name": "U", "presetName": "u", "binds": [{"mesh": 0, "index": 6, "weight": 100}]},
                        {"name": "E", "presetName": "e", "binds": [{"mesh": 0, "index": 7, "weight": 100}]},
                        {"name": "O", "presetName": "o", "binds": [{"mesh": 0, "index": 8, "weight": 100}]},
                        {"name": "PP", "presetName": "pp", "binds": [{"mesh": 0, "index": 9, "weight": 100}]},
                    ]
                },
                "humanoid": {
                    "humanBones": [
                        {"bone": "hips", "node": 0, "useDefaultValues": True},
                        {"bone": "spine", "node": 1, "useDefaultValues": True},
                        {"bone": "neck", "node": 2, "useDefaultValues": True},
                        {"bone": "head", "node": 3, "useDefaultValues": True},
                        {"bone": "leftEye", "node": 4, "useDefaultValues": True},
                        {"bone": "rightEye", "node": 5, "useDefaultValues": True},
                        {"bone": "leftShoulder", "node": 6, "useDefaultValues": True},
                        {"bone": "leftUpperArm", "node": 7, "useDefaultValues": True},
                        {"bone": "leftLowerArm", "node": 8, "useDefaultValues": True},
                        {"bone": "rightShoulder", "node": 9, "useDefaultValues": True},
                        {"bone": "rightUpperArm", "node": 10, "useDefaultValues": True},
                        {"bone": "rightLowerArm", "node": 11, "useDefaultValues": True},
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
    destination = Path(__file__).resolve().parents[1] / "build" / "generated-sample.vrm"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(header + json_chunk + bin_chunk)
    print(destination, destination.stat().st_size)


if __name__ == "__main__":
    main()

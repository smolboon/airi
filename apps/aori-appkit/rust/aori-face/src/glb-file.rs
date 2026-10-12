use std::io::Cursor;

use serde_json::Value;

use crate::{FaceAnimation, FaceChannel, FaceJoint, FaceMesh, FaceMorph, FaceScene, RgbaImage, Vec3};

#[derive(Debug, PartialEq)]
pub enum FaceError {
  TooSmall,
  BadMagic,
  Truncated,
  MissingJson,
  InvalidJson,
  BadAccessor(String),
}

impl std::fmt::Display for FaceError {
  fn fmt(
    &self,
    formatter: &mut std::fmt::Formatter<'_>,
  ) -> std::fmt::Result {
    match self {
      FaceError::TooSmall => write!(formatter, "The file is too small to be a VRM model."),
      FaceError::BadMagic => write!(formatter, "The file is not a binary glTF VRM model."),
      FaceError::Truncated => write!(formatter, "The VRM file is truncated."),
      FaceError::MissingJson => write!(formatter, "The VRM file has no JSON chunk."),
      FaceError::InvalidJson => write!(formatter, "The VRM JSON chunk is not valid."),
      FaceError::BadAccessor(message) => write!(formatter, "{message}"),
    }
  }
}

pub fn read_glb(bytes: &[u8]) -> Result<FaceScene, FaceError> {
  let (json, bin) = read_chunks(bytes)?;
  let (joints, inverse_binds, node_to_joint) = read_skin(&json, &bin)?;
  let meshes = read_meshes(&json, &bin)?;
  let animations = read_animations(&json, &bin, &node_to_joint)?;
  Ok(FaceScene {
    meshes,
    joints,
    inverse_binds,
    animations,
  })
}

fn read_chunks(bytes: &[u8]) -> Result<(Value, Vec<u8>), FaceError> {
  if bytes.len() < 20 {
    return Err(FaceError::TooSmall);
  }
  let magic = read_u32(bytes, 0);
  if magic != 0x4654_6C67 {
    return Err(FaceError::BadMagic);
  }
  let length = read_u32(bytes, 8) as usize;
  if length > bytes.len() {
    return Err(FaceError::Truncated);
  }
  let mut offset = 12;
  let mut json = None;
  let mut bin = Vec::new();
  while offset + 8 <= length {
    let chunk_length = read_u32(bytes, offset) as usize;
    let chunk_type = read_u32(bytes, offset + 4);
    let start = offset + 8;
    let end = start + chunk_length;
    if end > length {
      return Err(FaceError::Truncated);
    }
    let chunk = &bytes[start..end];
    if chunk_type == 0x4E4F_534A {
      let trimmed = trim_padding(chunk);
      json = Some(serde_json::from_slice(trimmed).map_err(|_| FaceError::InvalidJson)?);
    } else if chunk_type == 0x004E_4942 {
      bin = chunk.to_vec();
    }
    offset = end;
  }
  json
    .map(|value| (value, bin))
    .ok_or(FaceError::MissingJson)
}

fn read_meshes(
  json: &Value,
  bin: &[u8],
) -> Result<Vec<FaceMesh>, FaceError> {
  let materials = json.get("materials").and_then(Value::as_array);
  let meshes = json.get("meshes").and_then(Value::as_array);
  let mut result = Vec::new();
  for (index, mesh) in meshes.into_iter().flatten().enumerate() {
    let primitive = mesh
      .get("primitives")
      .and_then(Value::as_array)
      .and_then(|items| items.first());
    let attributes = primitive.and_then(|item| item.get("attributes"));
    let position_index = attributes
      .and_then(|item| item.get("POSITION"))
      .and_then(json_usize)
      .ok_or_else(|| FaceError::BadAccessor(format!("Mesh {index} has no positions.")))?;
    let positions = read_vec3(json, bin, position_index)?;
    let indices = match primitive
      .and_then(|item| item.get("indices"))
      .and_then(json_usize)
    {
      Some(index_index) => read_indices(json, bin, index_index)?,
      None => (0..positions.len() as u32).collect(),
    };
    let material_index = primitive
      .and_then(|item| item.get("material"))
      .and_then(json_usize)
      .unwrap_or(0);
    let material = materials.and_then(|items| items.get(material_index));
    let color = color_of(material);
    let names = mesh
      .pointer("/extras/targetNames")
      .and_then(Value::as_array)
      .map(|items| {
        items
          .iter()
          .filter_map(|item| item.as_str().map(str::to_string))
          .collect::<Vec<_>>()
      })
      .unwrap_or_default();
    let targets = primitive
      .and_then(|item| item.get("targets"))
      .and_then(Value::as_array);
    let mut morphs = Vec::new();
    for (target_index, target) in targets.into_iter().flatten().enumerate() {
      let Some(accessor) = target.get("POSITION").and_then(json_usize) else {
        continue;
      };
      let deltas = read_vec3(json, bin, accessor)?;
      let name = names
        .get(target_index)
        .cloned()
        .unwrap_or_else(|| format!("morph{target_index}"));
      morphs.push(FaceMorph { name, deltas });
    }
    let name = mesh
      .get("name")
      .and_then(Value::as_str)
      .map(str::to_string)
      .unwrap_or_else(|| format!("mesh{index}"));
    let uvs = match attributes
      .and_then(|item| item.get("TEXCOORD_0"))
      .and_then(json_usize)
    {
      Some(accessor) => read_vec2(json, bin, accessor).unwrap_or_default(),
      None => Vec::new(),
    };
    let joints = match attributes
      .and_then(|item| item.get("JOINTS_0"))
      .and_then(json_usize)
    {
      Some(accessor) => read_joints(json, bin, accessor).unwrap_or_default(),
      None => Vec::new(),
    };
    let weights = match attributes
      .and_then(|item| item.get("WEIGHTS_0"))
      .and_then(json_usize)
    {
      Some(accessor) => read_weights(json, bin, accessor).unwrap_or_default(),
      None => Vec::new(),
    };
    let texture = texture_of(json, bin, material);
    result.push(FaceMesh {
      name,
      positions,
      indices,
      color,
      morphs,
      uvs,
      joints,
      weights,
      texture,
    });
  }
  Ok(result)
}

fn read_skin(
  json: &Value,
  bin: &[u8],
) -> Result<(Vec<FaceJoint>, Vec<[f32; 16]>, Vec<Option<usize>>), FaceError> {
  let nodes = json.get("nodes").and_then(Value::as_array);
  let Some(skin) = json
    .get("skins")
    .and_then(Value::as_array)
    .and_then(|items| items.first())
  else {
    return Ok((Vec::new(), Vec::new(), Vec::new()));
  };
  let joint_nodes = skin
    .get("joints")
    .and_then(Value::as_array)
    .map(|items| items.iter().filter_map(json_usize).collect::<Vec<_>>())
    .unwrap_or_default();
  let mut node_to_joint = vec![None; nodes.map(|items| items.len()).unwrap_or(0)];
  for (joint_index, node_index) in joint_nodes.iter().copied().enumerate() {
    if node_index < node_to_joint.len() {
      node_to_joint[node_index] = Some(joint_index);
    }
  }
  let parents = node_parents(nodes);
  let mut joints = Vec::new();
  for node_index in &joint_nodes {
    let node = nodes.and_then(|items| items.get(*node_index));
    let translation = node
      .and_then(|item| item.get("translation"))
      .and_then(Value::as_array);
    let component = |index: usize| {
      translation
        .and_then(|items| items.get(index))
        .and_then(Value::as_f64)
        .unwrap_or(0.0) as f32
    };
    let parent = parents
      .get(*node_index)
      .copied()
      .flatten()
      .and_then(|parent| node_to_joint.get(parent).copied().flatten());
    let name = node
      .and_then(|item| item.get("name"))
      .and_then(Value::as_str)
      .unwrap_or("joint")
      .to_string();
    joints.push(FaceJoint {
      name,
      parent,
      translation: Vec3 {
        x: component(0),
        y: component(1),
        z: component(2),
      },
    });
  }
  let inverse_binds = match skin.get("inverseBindMatrices").and_then(json_usize) {
    Some(accessor) => read_matrices(json, bin, accessor)?,
    None => Vec::new(),
  };
  Ok((joints, inverse_binds, node_to_joint))
}

fn read_animations(
  json: &Value,
  bin: &[u8],
  node_to_joint: &[Option<usize>],
) -> Result<Vec<FaceAnimation>, FaceError> {
  let Some(animations) = json.get("animations").and_then(Value::as_array) else {
    return Ok(Vec::new());
  };
  let mut clips = Vec::new();
  for animation in animations {
    let mut channels = Vec::new();
    let Some(items) = animation.get("channels").and_then(Value::as_array) else {
      continue;
    };
    for channel in items {
      let path = channel
        .pointer("/target/path")
        .and_then(Value::as_str)
        .unwrap_or("");
      if path != "rotation" {
        continue;
      }
      let node = channel
        .pointer("/target/node")
        .and_then(json_usize)
        .unwrap_or(usize::MAX);
      let Some(joint) = node_to_joint.get(node).copied().flatten() else {
        continue;
      };
      let sampler_index = channel.get("sampler").and_then(json_usize).unwrap_or(0);
      let sampler = animation
        .get("samplers")
        .and_then(Value::as_array)
        .and_then(|samplers| samplers.get(sampler_index));
      let Some(input) = sampler.and_then(|item| item.get("input")).and_then(json_usize) else {
        continue;
      };
      let Some(output) = sampler.and_then(|item| item.get("output")).and_then(json_usize) else {
        continue;
      };
      let times = read_floats(json, bin, input, 1)?;
      let values = read_floats(json, bin, output, 4)?;
      let mut rotations = Vec::new();
      let mut index = 0;
      while index + 3 < values.len() {
        rotations.push([
          values[index],
          values[index + 1],
          values[index + 2],
          values[index + 3],
        ]);
        index += 4;
      }
      channels.push(FaceChannel {
        joint,
        times,
        rotations,
      });
    }
    if channels.is_empty() {
      continue;
    }
    let name = animation
      .get("name")
      .and_then(Value::as_str)
      .unwrap_or("animation")
      .to_string();
    clips.push(FaceAnimation { name, channels });
  }
  Ok(clips)
}

fn node_parents(nodes: Option<&Vec<Value>>) -> Vec<Option<usize>> {
  let Some(nodes) = nodes else {
    return Vec::new();
  };
  let mut parents = vec![None; nodes.len()];
  for (index, node) in nodes.iter().enumerate() {
    let Some(children) = node.get("children").and_then(Value::as_array) else {
      continue;
    };
    for child in children {
      let Some(child_index) = json_usize(child) else {
        continue;
      };
      if child_index < parents.len() {
        parents[child_index] = Some(index);
      }
    }
  }
  parents
}

fn texture_of(
  json: &Value,
  bin: &[u8],
  material: Option<&Value>,
) -> Option<RgbaImage> {
  let texture_index = material
    .and_then(|item| item.pointer("/pbrMetallicRoughness/baseColorTexture/index"))
    .and_then(json_usize)?;
  let source = json
    .pointer(&format!("/textures/{texture_index}/source"))
    .and_then(json_usize)?;
  let view_index = json
    .pointer(&format!("/images/{source}/bufferView"))
    .and_then(json_usize)?;
  let view = json
    .pointer(&format!("/bufferViews/{view_index}"))?;
  let offset = view.get("byteOffset").and_then(json_usize).unwrap_or(0);
  let length = view.get("byteLength").and_then(json_usize).unwrap_or(0);
  if offset + length > bin.len() || length < 8 {
    return None;
  }
  decode_png(&bin[offset..offset + length])
}

fn decode_png(bytes: &[u8]) -> Option<RgbaImage> {
  let decoder = png::Decoder::new(Cursor::new(bytes));
  let mut reader = decoder.read_info().ok()?;
  let mut buffer = vec![0; reader.output_buffer_size()];
  let info = reader.next_frame(&mut buffer).ok()?;
  let filled = &buffer[..info.buffer_size()];
  let pixels = match info.color_type {
    png::ColorType::Rgba => filled.to_vec(),
    png::ColorType::Rgb => filled
      .chunks(3)
      .flat_map(|pixel| [pixel[0], pixel[1], pixel[2], 255])
      .collect(),
    _ => return None,
  };
  Some(RgbaImage {
    width: info.width,
    height: info.height,
    pixels,
  })
}

fn color_of(material: Option<&Value>) -> [f32; 4] {
  let factor = material
    .and_then(|item| item.pointer("/pbrMetallicRoughness/baseColorFactor"))
    .and_then(Value::as_array);
  let Some(factor) = factor else {
    return [0.96, 0.78, 0.74, 1.0];
  };
  if factor.len() < 3 {
    return [0.96, 0.78, 0.74, 1.0];
  }
  let channel = |index: usize, fallback: f32| {
    factor
      .get(index)
      .and_then(Value::as_f64)
      .map(|value| value as f32)
      .unwrap_or(fallback)
  };
  [
    channel(0, 1.0),
    channel(1, 1.0),
    channel(2, 1.0),
    channel(3, 1.0),
  ]
}

fn read_vec2(
  json: &Value,
  bin: &[u8],
  accessor: usize,
) -> Result<Vec<[f32; 2]>, FaceError> {
  let floats = read_floats(json, bin, accessor, 2)?;
  let mut vectors = Vec::with_capacity(floats.len() / 2);
  let mut index = 0;
  while index + 1 < floats.len() {
    vectors.push([floats[index], floats[index + 1]]);
    index += 2;
  }
  Ok(vectors)
}

fn read_weights(
  json: &Value,
  bin: &[u8],
  accessor: usize,
) -> Result<Vec<[f32; 4]>, FaceError> {
  let floats = read_floats(json, bin, accessor, 4)?;
  let mut vectors = Vec::with_capacity(floats.len() / 4);
  let mut index = 0;
  while index + 3 < floats.len() {
    vectors.push([
      floats[index],
      floats[index + 1],
      floats[index + 2],
      floats[index + 3],
    ]);
    index += 4;
  }
  Ok(vectors)
}

fn read_joints(
  json: &Value,
  bin: &[u8],
  accessor: usize,
) -> Result<Vec<[u16; 4]>, FaceError> {
  let info = accessor_info(json, accessor)?;
  let width = match info.component_type {
    5121 => 1,
    5123 => 2,
    _ => {
      return Err(FaceError::BadAccessor(format!(
        "Joint accessor {accessor} is not an unsigned byte or short buffer."
      )));
    },
  };
  let mut values = Vec::with_capacity(info.count);
  for item in 0..info.count {
    let start = info.offset + item * info.stride;
    let mut joint = [0_u16; 4];
    for component in 0..4 {
      let byte = start + component * width;
      if byte + width > bin.len() {
        return Err(FaceError::BadAccessor(format!(
          "Joint accessor {accessor} is past the binary chunk."
        )));
      }
      joint[component] = if width == 1 {
        u16::from(bin[byte])
      } else {
        u16::from(bin[byte]) | (u16::from(bin[byte + 1]) << 8)
      };
    }
    values.push(joint);
  }
  Ok(values)
}

fn read_matrices(
  json: &Value,
  bin: &[u8],
  accessor: usize,
) -> Result<Vec<[f32; 16]>, FaceError> {
  let floats = read_floats(json, bin, accessor, 16)?;
  let mut matrices = Vec::with_capacity(floats.len() / 16);
  let mut index = 0;
  while index + 15 < floats.len() {
    let mut matrix = [0.0; 16];
    matrix.copy_from_slice(&floats[index..index + 16]);
    matrices.push(matrix);
    index += 16;
  }
  Ok(matrices)
}

fn read_vec3(
  json: &Value,
  bin: &[u8],
  accessor: usize,
) -> Result<Vec<Vec3>, FaceError> {
  let floats = read_floats(json, bin, accessor, 3)?;
  let mut vectors = Vec::with_capacity(floats.len() / 3);
  let mut index = 0;
  while index + 2 < floats.len() {
    vectors.push(Vec3 {
      x: floats[index],
      y: floats[index + 1],
      z: floats[index + 2],
    });
    index += 3;
  }
  Ok(vectors)
}

fn read_floats(
  json: &Value,
  bin: &[u8],
  accessor: usize,
  components: usize,
) -> Result<Vec<f32>, FaceError> {
  let info = accessor_info(json, accessor)?;
  if info.component_type != 5126 {
    return Err(FaceError::BadAccessor(format!(
      "Accessor {accessor} is not a float buffer."
    )));
  }
  let mut values = Vec::with_capacity(info.count * components);
  for item in 0..info.count {
    let start = info.offset + item * info.stride;
    for component in 0..components {
      let byte = start + component * 4;
      if byte + 4 > bin.len() {
        return Err(FaceError::BadAccessor(format!(
          "Accessor {accessor} is past the binary chunk."
        )));
      }
      values.push(read_f32(bin, byte));
    }
  }
  Ok(values)
}

fn read_indices(
  json: &Value,
  bin: &[u8],
  accessor: usize,
) -> Result<Vec<u32>, FaceError> {
  let info = accessor_info(json, accessor)?;
  let mut values = Vec::with_capacity(info.count);
  for item in 0..info.count {
    let start = info.offset + item * info.stride;
    match info.component_type {
      5123 => {
        if start + 2 > bin.len() {
          return Err(FaceError::BadAccessor(format!(
            "Index accessor {accessor} is past the binary chunk."
          )));
        }
        values.push(u32::from(bin[start]) | (u32::from(bin[start + 1]) << 8));
      },
      5125 => {
        if start + 4 > bin.len() {
          return Err(FaceError::BadAccessor(format!(
            "Index accessor {accessor} is past the binary chunk."
          )));
        }
        values.push(read_u32(bin, start));
      },
      _ => {
        return Err(FaceError::BadAccessor(format!(
          "Index accessor {accessor} uses an unsupported type."
        )));
      },
    }
  }
  Ok(values)
}

struct AccessorInfo {
  offset: usize,
  count: usize,
  stride: usize,
  component_type: i64,
}

fn accessor_info(
  json: &Value,
  accessor: usize,
) -> Result<AccessorInfo, FaceError> {
  let accessors = json.get("accessors").and_then(Value::as_array);
  let views = json.get("bufferViews").and_then(Value::as_array);
  let item = accessors
    .and_then(|items| items.get(accessor))
    .ok_or_else(|| FaceError::BadAccessor(format!("Accessor {accessor} is missing.")))?;
  let view_index = item
    .get("bufferView")
    .and_then(json_usize)
    .unwrap_or(0);
  let view = views
    .and_then(|items| items.get(view_index))
    .ok_or_else(|| FaceError::BadAccessor(format!("Buffer view {view_index} is missing.")))?;
  let component_type = item
    .get("componentType")
    .and_then(Value::as_i64)
    .unwrap_or(0);
  let count = item
    .get("count")
    .and_then(json_usize)
    .unwrap_or(0);
  let component_size = match component_type {
    5120 | 5121 => 1,
    5122 | 5123 => 2,
    _ => 4,
  };
  let components = component_count(
    item
      .get("type")
      .and_then(Value::as_str)
      .unwrap_or("SCALAR"),
  );
  let default_stride = component_size * components;
  let stride = view
    .get("byteStride")
    .and_then(json_usize)
    .unwrap_or(default_stride);
  let offset = view
    .get("byteOffset")
    .and_then(json_usize)
    .unwrap_or(0)
    + item
      .get("byteOffset")
      .and_then(json_usize)
      .unwrap_or(0);
  Ok(AccessorInfo {
    offset,
    count,
    stride,
    component_type,
  })
}

fn component_count(value_type: &str) -> usize {
  match value_type {
    "VEC2" => 2,
    "VEC3" => 3,
    "VEC4" => 4,
    "MAT4" => 16,
    _ => 1,
  }
}

fn json_usize(value: &Value) -> Option<usize> {
  value
    .as_u64()
    .map(|number| number as usize)
    .or_else(|| {
      value
        .as_i64()
        .filter(|number| *number >= 0)
        .map(|number| number as usize)
    })
}

fn read_u32(
  bytes: &[u8],
  offset: usize,
) -> u32 {
  u32::from_le_bytes([
    bytes[offset],
    bytes[offset + 1],
    bytes[offset + 2],
    bytes[offset + 3],
  ])
}

fn read_f32(
  bytes: &[u8],
  offset: usize,
) -> f32 {
  f32::from_le_bytes([
    bytes[offset],
    bytes[offset + 1],
    bytes[offset + 2],
    bytes[offset + 3],
  ])
}

fn trim_padding(bytes: &[u8]) -> &[u8] {
  let mut end = bytes.len();
  while end > 0 {
    let byte = bytes[end - 1];
    if byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 || byte == 0x00 {
      end -= 1;
    } else {
      break;
    }
  }
  &bytes[..end]
}

use serde_json::Value;

use crate::{FaceMesh, FaceMorph, FaceScene, Vec3};

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
  let meshes = read_meshes(&json, &bin)?;
  Ok(FaceScene { meshes })
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
    result.push(FaceMesh {
      name,
      positions,
      indices,
      color,
      morphs,
    });
  }
  Ok(result)
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
  let component_size = if component_type == 5123 {
    2
  } else {
    4
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

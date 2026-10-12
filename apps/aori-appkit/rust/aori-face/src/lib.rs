#[path = "glb-file.rs"]
mod glb;

pub use glb::{read_glb, FaceError};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Vec3 {
  pub x: f32,
  pub y: f32,
  pub z: f32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceMorph {
  pub name: String,
  pub deltas: Vec<Vec3>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceMesh {
  pub name: String,
  pub positions: Vec<Vec3>,
  pub indices: Vec<u32>,
  pub color: [f32; 4],
  pub morphs: Vec<FaceMorph>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceScene {
  pub meshes: Vec<FaceMesh>,
}

/// Adds `weight * delta` onto each position. Extra deltas are ignored.
pub fn add_morph(
  positions: &mut [Vec3],
  deltas: &[Vec3],
  weight: f32,
) {
  let count = positions.len().min(deltas.len());
  for index in 0..count {
    positions[index].x += deltas[index].x * weight;
    positions[index].y += deltas[index].y * weight;
    positions[index].z += deltas[index].z * weight;
  }
}

/// Projects a point onto an AppKit-style plane. Y grows upward.
pub fn project(
  position: Vec3,
  sway: f32,
  origin_x: f32,
  origin_y: f32,
  scale: f32,
) -> (f32, f32) {
  (
    origin_x + (position.x + sway) * scale,
    origin_y + position.y * scale,
  )
}

/// # Safety
///
/// `positions` and `delta` must each point at `count` floats when `count` is not 0.
/// The floats are x, y, z groups.
#[no_mangle]
pub unsafe extern "C" fn aori_face_add_morph(
  positions: *mut f32,
  delta: *const f32,
  weight: f32,
  count: usize,
) -> i32 {
  if count == 0 {
    return 0;
  }
  if positions.is_null() || delta.is_null() {
    return -1;
  }
  let dest = unsafe { std::slice::from_raw_parts_mut(positions, count) };
  let source = unsafe { std::slice::from_raw_parts(delta, count) };
  let groups = count / 3;
  for index in 0..groups {
    let offset = index * 3;
    dest[offset] += source[offset] * weight;
    dest[offset + 1] += source[offset + 1] * weight;
    dest[offset + 2] += source[offset + 2] * weight;
  }
  0
}

/// # Safety
///
/// `positions` must point at `vertex_count * 3` floats.
/// `out_xy` must point at `vertex_count * 2` floats.
#[no_mangle]
pub unsafe extern "C" fn aori_face_project(
  positions: *const f32,
  vertex_count: usize,
  sway: f32,
  origin_x: f32,
  origin_y: f32,
  scale: f32,
  out_xy: *mut f32,
) -> i32 {
  if vertex_count == 0 {
    return 0;
  }
  if positions.is_null() || out_xy.is_null() {
    return -1;
  }
  let source = unsafe { std::slice::from_raw_parts(positions, vertex_count * 3) };
  let dest = unsafe { std::slice::from_raw_parts_mut(out_xy, vertex_count * 2) };
  for index in 0..vertex_count {
    let point = Vec3 {
      x: source[index * 3],
      y: source[index * 3 + 1],
      z: source[index * 3 + 2],
    };
    let (x, y) = project(point, sway, origin_x, origin_y, scale);
    dest[index * 2] = x;
    dest[index * 2 + 1] = y;
  }
  0
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn morph_moves_a_vertex() {
    let mut positions = vec![Vec3 {
      x: 0.0,
      y: 0.0,
      z: 0.0,
    }];
    add_morph(
      &mut positions,
      &[Vec3 {
        x: 0.0,
        y: -1.0,
        z: 0.0,
      }],
      0.5,
    );
    assert_eq!(positions[0].y, -0.5);
  }

  #[test]
  fn project_uses_sway_and_scale() {
    let point = project(
      Vec3 {
        x: 1.0,
        y: 2.0,
        z: 3.0,
      },
      0.5,
      10.0,
      20.0,
      2.0,
    );
    assert_eq!(point, (13.0, 24.0));
  }

  #[test]
  fn c_abi_adds_a_morph_and_rejects_null() {
    let mut positions = [0.0_f32, 0.0, 0.0];
    let delta = [0.0_f32, -1.0, 0.0];
    let code = unsafe { aori_face_add_morph(positions.as_mut_ptr(), delta.as_ptr(), 0.5, 3) };
    assert_eq!(code, 0);
    assert_eq!(positions[1], -0.5);
    let bad = unsafe { aori_face_add_morph(std::ptr::null_mut(), delta.as_ptr(), 1.0, 3) };
    assert_eq!(bad, -1);
  }

  #[test]
  fn sample_head_has_vertices_and_a_mouth_delta() {
    let bytes = include_bytes!("../../../Sources/AoriApp/Resources/aori-sample.vrm");
    let scene = read_glb(bytes).expect("sample vrm");
    let count: usize = scene
      .meshes
      .iter()
      .map(|mesh| mesh.positions.len())
      .sum();
    assert!(count > 20);
    let head = &scene.meshes[0];
    let mouth = head
      .morphs
      .iter()
      .find(|morph| morph.name == "aa")
      .expect("aa morph");
    let mut positions = head.positions.clone();
    add_morph(&mut positions, &mouth.deltas, 1.0);
    let moved = positions
      .iter()
      .zip(head.positions.iter())
      .any(|(next, base)| (next.y - base.y).abs() > 0.01);
    assert!(moved);
  }
}

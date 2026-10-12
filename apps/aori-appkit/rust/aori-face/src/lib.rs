#[path = "glb-file.rs"]
mod glb;
mod raster;
mod skin;

pub use glb::{read_glb, FaceError};
pub use raster::{render_frame, RenderPose};

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
pub struct RgbaImage {
  pub width: u32,
  pub height: u32,
  pub pixels: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceMesh {
  pub name: String,
  pub positions: Vec<Vec3>,
  pub indices: Vec<u32>,
  pub color: [f32; 4],
  pub morphs: Vec<FaceMorph>,
  pub uvs: Vec<[f32; 2]>,
  pub joints: Vec<[u16; 4]>,
  pub weights: Vec<[f32; 4]>,
  pub texture: Option<RgbaImage>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceJoint {
  pub name: String,
  pub parent: Option<usize>,
  pub translation: Vec3,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceAnimation {
  pub name: String,
  pub joint: usize,
  pub times: Vec<f32>,
  pub rotations: Vec<[f32; 4]>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceScene {
  pub meshes: Vec<FaceMesh>,
  pub joints: Vec<FaceJoint>,
  pub inverse_binds: Vec<[f32; 16]>,
  pub animation: Option<FaceAnimation>,
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

/// # Safety
///
/// `bytes` must point at `len` bytes. A null pointer returns null.
#[no_mangle]
pub unsafe extern "C" fn aori_face_load(
  bytes: *const u8,
  len: usize,
) -> *mut FaceScene {
  if bytes.is_null() || len == 0 {
    return std::ptr::null_mut();
  }
  let slice = unsafe { std::slice::from_raw_parts(bytes, len) };
  match read_glb(slice) {
    Ok(scene) => Box::into_raw(Box::new(scene)),
    Err(_) => std::ptr::null_mut(),
  }
}

/// # Safety
///
/// `scene` must be a pointer from `aori_face_load`, or null.
#[no_mangle]
pub unsafe extern "C" fn aori_face_free(scene: *mut FaceScene) {
  if !scene.is_null() {
    drop(unsafe { Box::from_raw(scene) });
  }
}

/// # Safety
///
/// `scene` must be a pointer from `aori_face_load`, or null.
/// `out_rgba` must point at `width * height * 4` bytes.
#[no_mangle]
pub unsafe extern "C" fn aori_face_render(
  scene: *const FaceScene,
  mouth: f32,
  blink: f32,
  happy: f32,
  sad: f32,
  surprised: f32,
  time: f32,
  width: u32,
  height: u32,
  out_rgba: *mut u8,
) -> i32 {
  if scene.is_null() || out_rgba.is_null() || width == 0 || height == 0 {
    return -1;
  }
  if width > 1280 || height > 1280 {
    return -1;
  }
  let scene = unsafe { &*scene };
  let image = render_frame(
    scene,
    &RenderPose {
      mouth,
      blink,
      happy,
      sad,
      surprised,
      time,
      reduce_motion: false,
    },
    width,
    height,
  );
  let dest = unsafe { std::slice::from_raw_parts_mut(out_rgba, image.len()) };
  dest.copy_from_slice(&image);
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

  #[test]
  fn bind_pose_keeps_vertices_and_the_idle_clip_moves_them() {
    let scene = sample();
    assert_eq!(scene.joints.len(), 2);
    assert_eq!(scene.animation.as_ref().map(|clip| clip.name.as_str()), Some("idle"));
    let rest = raster::deformed_meshes(&scene, &RenderPose::default());
    for (mesh, posed) in scene.meshes.iter().zip(rest.iter()) {
      for (base, next) in mesh.positions.iter().zip(posed.iter()) {
        assert!((base.x - next.x).abs() < 1.0e-3);
        assert!((base.y - next.y).abs() < 1.0e-3);
        assert!((base.z - next.z).abs() < 1.0e-3);
      }
    }
    let turned = raster::deformed_meshes(
      &scene,
      &RenderPose {
        time: 1.6,
        ..RenderPose::default()
      },
    );
    let moved = scene.meshes[0]
      .positions
      .iter()
      .zip(turned[0].iter())
      .any(|(base, next)| (base.x - next.x).abs() > 0.02);
    assert!(moved);
    let held = raster::deformed_meshes(
      &scene,
      &RenderPose {
        time: 1.6,
        reduce_motion: true,
        ..RenderPose::default()
      },
    );
    assert!((held[0][0].x - rest[0][0].x).abs() < 1.0e-3);
  }

  #[test]
  fn nearer_triangle_wins_the_depth_test() {
    let scene = overlapping_quads();
    let image = render_frame(&scene, &RenderPose::default(), 48, 48);
    let center = pixel(&image, 48, 24, 24);
    assert!(center[1] > 200, "near green fragment, got {center:?}");
    assert!(center[0] < 40);
  }

  #[test]
  fn texture_blink_and_mouth_change_pixels() {
    let scene = sample();
    assert!(scene.meshes[0].texture.is_some());
    assert!(!scene.meshes[0].uvs.is_empty());
    let open = render_frame(&scene, &RenderPose::default(), 160, 220);
    let blink = render_frame(
      &scene,
      &RenderPose {
        blink: 1.0,
        ..RenderPose::default()
      },
      160,
      220,
    );
    let mouth = render_frame(
      &scene,
      &RenderPose {
        mouth: 1.0,
        ..RenderPose::default()
      },
      160,
      220,
    );
    assert!(open.chunks(4).any(|pixel| pixel[3] == 0));
    assert!(open.chunks(4).any(|pixel| pixel[0] > 180 && pixel[1] < 90 && pixel[3] == 255));
    let eye_row = average_row(&open, 160, |pixel| pixel[0] < 50 && pixel[1] < 50 && pixel[3] == 255);
    assert!(eye_row < 110.0, "eyes sit above the center, row {eye_row}");
    assert!(count_diff(&open, &blink) > 10);
    let mouth_row = average_diff_row(&open, &mouth, 160);
    assert!(mouth_row > eye_row, "mouth diffs sit below the eyes");
  }

  #[test]
  fn render_stays_inside_the_frame_budget() {
    let scene = sample();
    let started = std::time::Instant::now();
    let image = render_frame(
      &scene,
      &RenderPose {
        mouth: 0.6,
        time: 1.6,
        ..RenderPose::default()
      },
      280,
      380,
    );
    let elapsed = started.elapsed();
    println!("aori_face_render_ms={:.2}", elapsed.as_secs_f64() * 1000.0);
    assert!(image.iter().any(|byte| *byte > 0));
    assert!(elapsed.as_millis() < 200, "render took {elapsed:?}");
  }

  #[test]
  fn c_abi_renders_the_sample_and_rejects_null() {
    let bytes = include_bytes!("../../../Sources/AoriApp/Resources/aori-sample.vrm");
    let scene = unsafe { aori_face_load(bytes.as_ptr(), bytes.len()) };
    assert!(!scene.is_null());
    let mut image = vec![0_u8; 32 * 32 * 4];
    let code = unsafe {
      aori_face_render(scene, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 32, 32, image.as_mut_ptr())
    };
    assert_eq!(code, 0);
    assert!(image.iter().any(|byte| *byte > 0));
    let bad = unsafe { aori_face_render(std::ptr::null(), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 32, 32, image.as_mut_ptr()) };
    assert_eq!(bad, -1);
    unsafe { aori_face_free(scene) };
    assert!(unsafe { aori_face_load(std::ptr::null(), 4) }.is_null());
  }

  fn sample() -> FaceScene {
    let bytes = include_bytes!("../../../Sources/AoriApp/Resources/aori-sample.vrm");
    read_glb(bytes).expect("sample vrm")
  }

  fn overlapping_quads() -> FaceScene {
    let triangle = |z: f32, color: [f32; 4]| FaceMesh {
      name: "quad".into(),
      positions: vec![
        Vec3 { x: -0.45, y: -0.15, z },
        Vec3 { x: 0.45, y: -0.15, z },
        Vec3 { x: 0.0, y: 0.75, z },
      ],
      indices: vec![0, 1, 2],
      color,
      morphs: Vec::new(),
      uvs: Vec::new(),
      joints: Vec::new(),
      weights: Vec::new(),
      texture: None,
    };
    FaceScene {
      meshes: vec![
        triangle(0.0, [1.0, 0.0, 0.0, 1.0]),
        triangle(0.7, [0.0, 1.0, 0.0, 1.0]),
      ],
      joints: Vec::new(),
      inverse_binds: Vec::new(),
      animation: None,
    }
  }

  fn pixel(image: &[u8], width: usize, x: usize, y: usize) -> [u8; 4] {
    let offset = (y * width + x) * 4;
    [image[offset], image[offset + 1], image[offset + 2], image[offset + 3]]
  }

  fn average_row(image: &[u8], width: usize, keep: impl Fn([u8; 4]) -> bool) -> f32 {
    let mut sum = 0.0;
    let mut count = 0.0;
    for (index, pixel) in image.chunks(4).enumerate() {
      let rgba = [pixel[0], pixel[1], pixel[2], pixel[3]];
      if keep(rgba) {
        sum += (index / width) as f32;
        count += 1.0;
      }
    }
    assert!(count > 0.0);
    sum / count
  }

  fn average_diff_row(left: &[u8], right: &[u8], width: usize) -> f32 {
    let mut sum = 0.0;
    let mut count = 0.0;
    for (index, (before, after)) in left.chunks(4).zip(right.chunks(4)).enumerate() {
      if before != after {
        sum += (index / width) as f32;
        count += 1.0;
      }
    }
    assert!(count > 0.0);
    sum / count
  }

  fn count_diff(left: &[u8], right: &[u8]) -> usize {
    left
      .chunks(4)
      .zip(right.chunks(4))
      .filter(|(before, after)| before != after)
      .count()
  }
}

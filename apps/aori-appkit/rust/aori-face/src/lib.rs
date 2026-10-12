#[path = "glb-file.rs"]
mod glb;
mod raster;
mod skin;

pub use glb::{read_glb, FaceError};
pub use raster::{encode_png, render_frame, RenderPose};

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
  pub normals: Vec<Vec3>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceJoint {
  pub name: String,
  pub parent: Option<usize>,
  pub translation: Vec3,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceChannel {
  pub joint: usize,
  pub times: Vec<f32>,
  pub rotations: Vec<[f32; 4]>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceAnimation {
  pub name: String,
  pub channels: Vec<FaceChannel>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FaceScene {
  pub meshes: Vec<FaceMesh>,
  pub joints: Vec<FaceJoint>,
  pub inverse_binds: Vec<[f32; 16]>,
  pub animations: Vec<FaceAnimation>,
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
  viseme: i32,
  time: f32,
  look_x: f32,
  look_y: f32,
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
      viseme,
      time,
      look_x,
      look_y,
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
    assert!(scene.joints.iter().any(|joint| joint.name == "leftEye"));
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
    assert_eq!(scene.joints.len(), 12);
    let names: Vec<&str> = scene.joints.iter().map(|joint| joint.name.as_str()).collect();
    assert!(names.contains(&"hips"));
    assert!(names.contains(&"head"));
    assert!(names.contains(&"leftEye"));
    assert!(names.contains(&"rightEye"));
    assert!(names.contains(&"leftLowerArm"));
    assert!(names.contains(&"rightLowerArm"));
    assert!(scene.animations.iter().any(|clip| clip.name == "idle"));
    assert!(scene.animations.iter().any(|clip| clip.name == "blink"));
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
    let arm_moved = scene.meshes[2]
      .positions
      .iter()
      .zip(turned[2].iter())
      .any(|(base, next)| (base.x - next.x).abs() > 0.01);
    assert!(arm_moved, "the idle clip rotates a lower arm");
    let held = raster::deformed_meshes(
      &scene,
      &RenderPose {
        time: 1.6,
        reduce_motion: true,
        ..RenderPose::default()
      },
    );
    assert!((held[0][0].x - rest[0][0].x).abs() < 1.0e-3);
    let idle = scene
      .animations
      .iter()
      .find(|clip| clip.name == "idle")
      .expect("idle");
    let eye = idle
      .channels
      .iter()
      .find(|channel| scene.joints[channel.joint].name == "leftEye")
      .expect("eye channel");
    let look = skin::sample_rotation(eye, 1.6);
    assert!((look[3] - 1.0).abs() > 1.0e-3 || look[1].abs() > 1.0e-3);
    let looked = raster::deformed_meshes(
      &scene,
      &RenderPose {
        time: 1.6,
        ..RenderPose::default()
      },
    );
    let eye_moved = scene.meshes[1]
      .positions
      .iter()
      .zip(looked[1].iter())
      .any(|(base, next)| (base.x - next.x).abs() > 0.01);
    assert!(eye_moved);
    let shut = raster::deformed_meshes(
      &scene,
      &RenderPose {
        blink: 1.0,
        ..RenderPose::default()
      },
    );
    let bone_blink = scene.meshes[1]
      .positions
      .iter()
      .zip(shut[1].iter())
      .any(|(base, next)| (base.z - next.z).abs() > 0.005);
    assert!(bone_blink, "an eye bone rotation moves z, the blink morph does not");
    let vowel_i = raster::deformed_meshes(
      &scene,
      &RenderPose {
        mouth: 1.0,
        viseme: 1,
        ..RenderPose::default()
      },
    );
    let vowel_a = raster::deformed_meshes(
      &scene,
      &RenderPose {
        mouth: 1.0,
        viseme: 0,
        ..RenderPose::default()
      },
    );
    let viseme_differs = vowel_a[0]
      .iter()
      .zip(vowel_i[0].iter())
      .any(|(left, right)| (left.y - right.y).abs() > 0.005 || (left.z - right.z).abs() > 0.005);
    assert!(viseme_differs);
    let gazed = raster::deformed_meshes(
      &scene,
      &RenderPose {
        look_x: 0.8,
        ..RenderPose::default()
      },
    );
    let gaze_moved = scene.meshes[1]
      .positions
      .iter()
      .zip(gazed[1].iter())
      .any(|(base, next)| (base.x - next.x).abs() > 0.005 || (base.z - next.z).abs() > 0.005);
    assert!(gaze_moved, "look-at turns an eye bone");
  }

  #[test]
  fn directional_light_darkens_a_back_normal() {
    let scene = sample();
    assert_eq!(scene.meshes[0].normals.len(), scene.meshes[0].positions.len());
    let rest = raster::deformed_surface(
      &scene,
      &RenderPose {
        reduce_motion: true,
        ..RenderPose::default()
      },
    );
    for (base, next) in scene.meshes[0].normals.iter().zip(rest[0].normals.iter()) {
      assert!((base.x - next.x).abs() < 1.0e-3);
      assert!((base.y - next.y).abs() < 1.0e-3);
      assert!((base.z - next.z).abs() < 1.0e-3);
      let length = (next.x * next.x + next.y * next.y + next.z * next.z).sqrt();
      assert!((length - 1.0).abs() < 1.0e-3);
    }
    let turned = raster::deformed_surface(
      &scene,
      &RenderPose {
        time: 1.6,
        ..RenderPose::default()
      },
    );
    let moved = rest[0]
      .normals
      .iter()
      .zip(turned[0].normals.iter())
      .any(|(base, next)| (base.x - next.x).abs() > 0.01);
    assert!(moved, "the idle clip rotates a skinned normal");

    let front = render_frame(&lit_triangle(Vec3 { x: 0.0, y: 1.0, z: 0.0 }), &RenderPose::default(), 64, 64);
    let back = render_frame(&lit_triangle(Vec3 { x: 0.0, y: -1.0, z: 0.0 }), &RenderPose::default(), 64, 64);
    let front_px = first_opaque(&front).expect("front pixel");
    let back_px = first_opaque(&back).expect("back pixel");
    let front_sum = front_px[0] as u16 + front_px[1] as u16 + front_px[2] as u16;
    let back_sum = back_px[0] as u16 + back_px[1] as u16 + back_px[2] as u16;
    assert!(front_sum > back_sum, "front {front_px:?} back {back_px:?}");
    assert!(front_px[0] != 200 || front_px[1] != 180 || front_px[2] != 160);
  }

  #[test]
  fn nearer_triangle_wins_the_depth_test() {
    let scene = overlapping_quads();
    let image = render_frame(&scene, &RenderPose::default(), 48, 48);
    let center = pixel(&image, 48, 24, 24);
    assert!(center[1] > center[0], "near green fragment, got {center:?}");
    assert!(center[1] > 80, "near green fragment, got {center:?}");
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
    assert!(open.chunks(4).any(|pixel| {
      pixel[0] > 80 && (pixel[1] as u16) * 2 < pixel[0] as u16 && pixel[3] == 255
    }));
    let eye_row = average_row(&open, 160, |pixel| pixel[0] < 50 && pixel[1] < 50 && pixel[3] == 255);
    assert!(eye_row < 110.0, "eyes sit above the center, row {eye_row}");
    assert!(count_diff(&open, &blink) > 10);
    let mouth_row = average_diff_row(&open, &mouth, 160);
    assert!(mouth_row > eye_row, "mouth diffs sit below the eyes");
  }

  #[test]
  fn render_stays_inside_the_frame_budget() {
    let started_load = std::time::Instant::now();
    let scene = sample();
    let load_ms = started_load.elapsed().as_secs_f64() * 1000.0;
    println!("aori_face_load_ms={load_ms:.2}");
    let mut times = Vec::new();
    for frame in 0..20 {
      let started = std::time::Instant::now();
      let image = render_frame(
        &scene,
        &RenderPose {
          mouth: 0.6,
          viseme: frame % 5,
          time: frame as f32 * 0.16,
          ..RenderPose::default()
        },
        280,
        380,
      );
      times.push(started.elapsed().as_secs_f64() * 1000.0);
      assert!(image.iter().any(|byte| *byte > 0));
    }
    times.sort_by(|left, right| left.partial_cmp(right).unwrap());
    let median = times[times.len() / 2];
    let max = times[times.len() - 1];
    println!("aori_face_render_median_ms={median:.2}");
    println!("aori_face_render_max_ms={max:.2}");
    assert!(median < 33.0, "median render took {median:.2} ms");
  }

  #[test]
  fn encode_png_keeps_a_clear_corner_and_a_lit_pixel() {
    let scene = sample();
    let pixels = render_frame(
      &scene,
      &RenderPose {
        mouth: 0.65,
        viseme: 0,
        time: 1.6,
        ..RenderPose::default()
      },
      280,
      380,
    );
    assert_eq!(pixels[3], 0, "the top-left pixel is clear");
    assert!(pixels.chunks(4).any(|pixel| pixel[3] == 255));
    assert!(pixels.chunks(4).any(|pixel| {
      pixel[0] > 80 && pixel[1] < pixel[0] && pixel[3] == 255
    }));
    let png = encode_png(&pixels, 280, 380).expect("png");
    assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n");
  }

  #[test]
  fn c_abi_renders_the_sample_and_rejects_null() {
    let bytes = include_bytes!("../../../Sources/AoriApp/Resources/aori-sample.vrm");
    let scene = unsafe { aori_face_load(bytes.as_ptr(), bytes.len()) };
    assert!(!scene.is_null());
    let mut image = vec![0_u8; 32 * 32 * 4];
    let code = unsafe {
      aori_face_render(scene, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 32, 32, image.as_mut_ptr())
    };
    assert_eq!(code, 0);
    assert!(image.iter().any(|byte| *byte > 0));
    let bad = unsafe { aori_face_render(std::ptr::null(), 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 32, 32, image.as_mut_ptr()) };
    assert_eq!(bad, -1);
    unsafe { aori_face_free(scene) };
    assert!(unsafe { aori_face_load(std::ptr::null(), 4) }.is_null());
  }

  fn sample() -> FaceScene {
    let bytes = include_bytes!("../../../Sources/AoriApp/Resources/aori-sample.vrm");
    read_glb(bytes).expect("sample vrm")
  }

  fn lit_triangle(normal: Vec3) -> FaceScene {
    FaceScene {
      meshes: vec![FaceMesh {
        name: "lit".into(),
        positions: vec![
          Vec3 { x: -0.45, y: -0.15, z: 0.2 },
          Vec3 { x: 0.45, y: -0.15, z: 0.2 },
          Vec3 { x: 0.0, y: 0.75, z: 0.2 },
        ],
        indices: vec![0, 1, 2],
        color: [1.0, 1.0, 1.0, 1.0],
        morphs: Vec::new(),
        uvs: vec![[0.0, 0.0], [1.0, 0.0], [0.5, 1.0]],
        joints: Vec::new(),
        weights: Vec::new(),
        texture: Some(RgbaImage {
          width: 1,
          height: 1,
          pixels: vec![200, 180, 160, 255],
        }),
        normals: vec![normal, normal, normal],
      }],
      joints: Vec::new(),
      inverse_binds: Vec::new(),
      animations: Vec::new(),
    }
  }

  fn first_opaque(image: &[u8]) -> Option<[u8; 4]> {
    image.chunks(4).find(|pixel| pixel[3] > 0).map(|pixel| [pixel[0], pixel[1], pixel[2], pixel[3]])
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
      normals: Vec::new(),
    };
    FaceScene {
      meshes: vec![
        triangle(0.0, [1.0, 0.0, 0.0, 1.0]),
        triangle(0.7, [0.0, 1.0, 0.0, 1.0]),
      ],
      joints: Vec::new(),
      inverse_binds: Vec::new(),
      animations: Vec::new(),
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

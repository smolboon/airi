use crate::{
  add_morph, skin::{
    joint_globals, sample_rotation, skin_normals, skin_positions, with_blink, with_look,
  }, FaceScene, RgbaImage, Vec3,
};

pub struct PosedSurface {
  pub positions: Vec<Vec3>,
  pub normals: Vec<Vec3>,
}

#[derive(Clone, Copy, Debug)]
pub struct RenderPose {
  pub mouth: f32,
  pub blink: f32,
  pub happy: f32,
  pub sad: f32,
  pub surprised: f32,
  pub viseme: i32,
  pub time: f32,
  pub look_x: f32,
  pub look_y: f32,
  pub reduce_motion: bool,
}

impl Default for RenderPose {
  fn default() -> Self {
    Self {
      mouth: 0.0,
      blink: 0.0,
      happy: 0.0,
      sad: 0.0,
      surprised: 0.0,
      viseme: 0,
      time: 0.0,
      look_x: 0.0,
      look_y: 0.0,
      reduce_motion: false,
    }
  }
}

/// Draws the scene into a top-left RGBA buffer. A smaller camera depth wins the z test.
pub fn render_frame(
  scene: &FaceScene,
  pose: &RenderPose,
  width: u32,
  height: u32,
) -> Vec<u8> {
  let width = width.min(1280);
  let height = height.min(1280);
  let mut image = vec![0_u8; (width as usize) * (height as usize) * 4];
  if width == 0 || height == 0 {
    return image;
  }
  let mut depth = vec![f32::INFINITY; (width as usize) * (height as usize)];
  let meshes = deformed_surface(scene, pose);
  for (mesh_index, posed) in meshes.iter().enumerate() {
    let Some(mesh) = scene.meshes.get(mesh_index) else {
      continue;
    };
    let mut index = 0;
    while index + 2 < mesh.indices.len() {
      let ids = [
        mesh.indices[index] as usize,
        mesh.indices[index + 1] as usize,
        mesh.indices[index + 2] as usize,
      ];
      index += 3;
      if ids.iter().any(|id| *id >= posed.positions.len()) {
        continue;
      }
      let uvs = ids.map(|id| mesh.uvs.get(id).copied().unwrap_or([0.0, 0.0]));
      let projected = ids.map(|id| project(posed.positions[id], width as f32, height as f32));
      let normals = ids.map(|id| {
        posed.normals.get(id).copied().unwrap_or(Vec3 {
          x: 0.0,
          y: 0.0,
          z: 1.0,
        })
      });
      paint_triangle(
        &mut image,
        &mut depth,
        width,
        height,
        projected,
        uvs,
        normals,
        mesh.color,
        mesh.texture.as_ref(),
      );
    }
  }
  image
}

#[cfg_attr(not(test), allow(dead_code))]
pub fn deformed_meshes(
  scene: &FaceScene,
  pose: &RenderPose,
) -> Vec<Vec<Vec3>> {
  deformed_surface(scene, pose)
    .into_iter()
    .map(|surface| surface.positions)
    .collect()
}

pub fn deformed_surface(
  scene: &FaceScene,
  pose: &RenderPose,
) -> Vec<PosedSurface> {
  let mut spins = vec![[0.0, 0.0, 0.0, 1.0]; scene.joints.len()];
  if !pose.reduce_motion {
    if let Some(idle) = scene
      .animations
      .iter()
      .find(|clip| clip.name == "idle")
      .or(scene.animations.first())
    {
      for channel in &idle.channels {
        if channel.joint < spins.len() {
          spins[channel.joint] = sample_rotation(channel, pose.time);
        }
      }
    }
    if pose.blink > 0.5 {
      for (index, joint) in scene.joints.iter().enumerate() {
        let name = joint.name.to_ascii_lowercase();
        if name == "lefteye" || name == "righteye" {
          spins[index] = with_blink(spins[index]);
        }
      }
    }
    if pose.look_x.abs() > 1.0e-4 || pose.look_y.abs() > 1.0e-4 {
      for (index, joint) in scene.joints.iter().enumerate() {
        let name = joint.name.to_ascii_lowercase();
        if name == "lefteye" || name == "righteye" {
          spins[index] = with_look(spins[index], pose.look_x, pose.look_y);
        }
      }
    }
  }
  let globals = joint_globals(scene, &spins);
  scene
    .meshes
    .iter()
    .enumerate()
    .map(|(mesh_index, mesh)| {
      let mut positions = mesh.positions.clone();
      for morph in &mesh.morphs {
        let weight = morph_weight(&morph.name, pose);
        if weight > 0.0 {
          add_morph(&mut positions, &morph.deltas, weight);
        }
      }
      skin_positions(scene, mesh_index, &mut positions, &globals);
      let mut normals = if mesh.normals.len() == positions.len() {
        mesh.normals.clone()
      } else {
        vec![
          Vec3 {
            x: 0.0,
            y: 0.0,
            z: 1.0,
          };
          positions.len()
        ]
      };
      skin_normals(scene, mesh_index, &mut normals, &globals);
      PosedSurface { positions, normals }
    })
    .collect()
}

fn morph_weight(
  name: &str,
  pose: &RenderPose,
) -> f32 {
  let lower = name.to_ascii_lowercase();
  let vowel = match lower.as_str() {
    "a" | "aa" | "ah" => Some(0),
    "i" | "ih" => Some(1),
    "u" | "ou" => Some(2),
    "e" | "ee" => Some(3),
    "o" | "oh" => Some(4),
    "pp" => Some(5),
    _ => None,
  };
  if let Some(code) = vowel {
    if code == 5 {
      return if pose.viseme == 5 { 1.0 } else { 0.0 };
    }
    return if pose.viseme == code { pose.mouth } else { 0.0 };
  }
  match lower.as_str() {
    "blink" | "blink_l" | "blink_r" => pose.blink,
    "joy" | "happy" | "fun" => pose.happy,
    "sorrow" | "sad" => pose.sad,
    "surprised" | "surprise" => pose.surprised,
    _ => 0.0,
  }
}

fn project(
  position: Vec3,
  width: f32,
  height: f32,
) -> [f32; 3] {
  let scale = width.min(height) * 0.9;
  let origin_x = width * 0.5;
  let origin_y = height * 0.5;
  let camera_depth = (2.2 - position.z).max(0.05);
  let factor = 1.6 / camera_depth * scale;
  let x = origin_x + position.x * factor;
  let y_up = origin_y + (position.y - 0.2) * factor;
  [x, (height - 1.0) - y_up, camera_depth]
}

pub fn shade_lambert(
  color: [f32; 4],
  normal: Vec3,
) -> [f32; 4] {
  let light = normalize_light(Vec3 {
    x: -0.3,
    y: 0.8,
    z: 0.6,
  });
  let shaded = normalize_light(normal);
  let diffuse = (shaded.x * light.x + shaded.y * light.y + shaded.z * light.z).max(0.0);
  let ambient = 0.28;
  let scale = ambient + (1.0 - ambient) * diffuse;
  [
    color[0] * scale,
    color[1] * scale,
    color[2] * scale,
    color[3],
  ]
}

fn normalize_light(value: Vec3) -> Vec3 {
  let length = (value.x * value.x + value.y * value.y + value.z * value.z).sqrt();
  if length <= 1.0e-8 {
    return Vec3 {
      x: 0.0,
      y: 0.0,
      z: 1.0,
    };
  }
  Vec3 {
    x: value.x / length,
    y: value.y / length,
    z: value.z / length,
  }
}

fn paint_triangle(
  image: &mut [u8],
  depth: &mut [f32],
  width: u32,
  height: u32,
  projected: [[f32; 3]; 3],
  uvs: [[f32; 2]; 3],
  normals: [Vec3; 3],
  color: [f32; 4],
  texture: Option<&RgbaImage>,
) {
  let width_i = width as i32;
  let height_i = height as i32;
  let points = projected.map(|point| [point[0], point[1]]);
  let area = edge(points[0], points[1], points[2]);
  if area.abs() < 1.0e-4 {
    return;
  }
  let min_x = points
    .iter()
    .map(|point| point[0].floor() as i32)
    .fold(width_i, i32::min)
    .clamp(0, width_i);
  let max_x = points
    .iter()
    .map(|point| point[0].ceil() as i32)
    .fold(0, i32::max)
    .clamp(0, width_i);
  let min_y = points
    .iter()
    .map(|point| point[1].floor() as i32)
    .fold(height_i, i32::min)
    .clamp(0, height_i);
  let max_y = points
    .iter()
    .map(|point| point[1].ceil() as i32)
    .fold(0, i32::max)
    .clamp(0, height_i);
  for y in min_y..max_y {
    for x in min_x..max_x {
      let sample = [x as f32 + 0.5, y as f32 + 0.5];
      let mut w0 = edge(points[1], points[2], sample);
      let mut w1 = edge(points[2], points[0], sample);
      let mut w2 = edge(points[0], points[1], sample);
      if area < 0.0 {
        w0 = -w0;
        w1 = -w1;
        w2 = -w2;
      }
      if w0 < 0.0 || w1 < 0.0 || w2 < 0.0 {
        continue;
      }
      let sum = w0 + w1 + w2;
      if sum.abs() < 1.0e-6 {
        continue;
      }
      let b0 = w0 / sum;
      let b1 = w1 / sum;
      let b2 = w2 / sum;
      let camera_depth = b0 * projected[0][2] + b1 * projected[1][2] + b2 * projected[2][2];
      let pixel = (y as usize) * (width as usize) + (x as usize);
      if camera_depth >= depth[pixel] {
        continue;
      }
      depth[pixel] = camera_depth;
      let inv0 = b0 / projected[0][2];
      let inv1 = b1 / projected[1][2];
      let inv2 = b2 / projected[2][2];
      let inv = inv0 + inv1 + inv2;
      let uv = if inv.abs() < 1.0e-6 {
        [0.0, 0.0]
      } else {
        [
          (uvs[0][0] * inv0 + uvs[1][0] * inv1 + uvs[2][0] * inv2) / inv,
          (uvs[0][1] * inv0 + uvs[1][1] * inv1 + uvs[2][1] * inv2) / inv,
        ]
      };
      let sampled = sample_color(texture, uv, color);
      let normal = if inv.abs() < 1.0e-6 {
        normals[0]
      } else {
        Vec3 {
          x: (normals[0].x * inv0 + normals[1].x * inv1 + normals[2].x * inv2) / inv,
          y: (normals[0].y * inv0 + normals[1].y * inv1 + normals[2].y * inv2) / inv,
          z: (normals[0].z * inv0 + normals[1].z * inv1 + normals[2].z * inv2) / inv,
        }
      };
      let sampled = shade_lambert(sampled, normal);
      let offset = pixel * 4;
      image[offset] = channel(sampled[0]);
      image[offset + 1] = channel(sampled[1]);
      image[offset + 2] = channel(sampled[2]);
      image[offset + 3] = channel(sampled[3]);
    }
  }
}

fn sample_color(
  texture: Option<&RgbaImage>,
  uv: [f32; 2],
  color: [f32; 4],
) -> [f32; 4] {
  let Some(texture) = texture else {
    return color;
  };
  if texture.width == 0 || texture.height == 0 || texture.pixels.len() < 4 {
    return color;
  }
  let u = uv[0].rem_euclid(1.0);
  let v = uv[1].rem_euclid(1.0);
  let x = ((u * texture.width as f32) as u32).min(texture.width - 1);
  let y = ((v * texture.height as f32) as u32).min(texture.height - 1);
  let offset = ((y * texture.width + x) * 4) as usize;
  if offset + 3 >= texture.pixels.len() {
    return color;
  }
  [
    texture.pixels[offset] as f32 / 255.0 * color[0],
    texture.pixels[offset + 1] as f32 / 255.0 * color[1],
    texture.pixels[offset + 2] as f32 / 255.0 * color[2],
    texture.pixels[offset + 3] as f32 / 255.0 * color[3],
  ]
}

fn edge(
  start: [f32; 2],
  end: [f32; 2],
  point: [f32; 2],
) -> f32 {
  (point[0] - start[0]) * (end[1] - start[1]) - (point[1] - start[1]) * (end[0] - start[0])
}

fn channel(value: f32) -> u8 {
  (value.clamp(0.0, 1.0) * 255.0).round() as u8
}

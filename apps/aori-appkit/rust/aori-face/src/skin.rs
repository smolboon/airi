use crate::{FaceChannel, FaceScene, Vec3};

pub const IDENTITY: [f32; 16] = [
  1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
];

pub fn sample_rotation(
  channel: &FaceChannel,
  time: f32,
) -> [f32; 4] {
  let times = &channel.times;
  let rotations = &channel.rotations;
  if times.is_empty() || rotations.is_empty() {
    return [0.0, 0.0, 0.0, 1.0];
  }
  let duration = times[times.len() - 1];
  let t = if duration > 0.0 {
    time.rem_euclid(duration)
  } else {
    0.0
  };
  if t <= times[0] {
    return rotations[0];
  }
  for index in 0..times.len().saturating_sub(1) {
    let end = times[index + 1];
    if t <= end {
      let start = times[index];
      let span = end - start;
      let mix = if span > 0.0 { (t - start) / span } else { 0.0 };
      let next = rotations.get(index + 1).copied().unwrap_or(rotations[index]);
      return nlerp(rotations[index], next, mix);
    }
  }
  *rotations.last().unwrap_or(&[0.0, 0.0, 0.0, 1.0])
}

pub fn joint_globals(
  scene: &FaceScene,
  spins: &[[f32; 4]],
) -> Vec<[f32; 16]> {
  let count = scene.joints.len();
  let mut globals = vec![IDENTITY; count];
  let mut done = vec![false; count];
  for _ in 0..count {
    for index in 0..count {
      if done[index] {
        continue;
      }
      let parent = scene.joints[index].parent;
      if let Some(parent) = parent {
        if parent >= count || !done[parent] {
          continue;
        }
      }
      let spin = spins.get(index).copied().unwrap_or([0.0, 0.0, 0.0, 1.0]);
      let local = mul(
        &translation(scene.joints[index].translation),
        &quat_to_matrix(spin),
      );
      globals[index] = match parent {
        Some(parent) => mul(&globals[parent], &local),
        None => local,
      };
      done[index] = true;
    }
  }
  globals
}

pub fn skin_positions(
  scene: &FaceScene,
  mesh_index: usize,
  positions: &mut [Vec3],
  globals: &[[f32; 16]],
) {
  let Some(mesh) = scene.meshes.get(mesh_index) else {
    return;
  };
  if mesh.joints.is_empty() || scene.inverse_binds.is_empty() {
    return;
  }
  for (index, position) in positions.iter_mut().enumerate() {
    let joints = mesh.joints.get(index).copied().unwrap_or([0, 0, 0, 0]);
    let weights = mesh
      .weights
      .get(index)
      .copied()
      .unwrap_or([1.0, 0.0, 0.0, 0.0]);
    let mut acc = Vec3 {
      x: 0.0,
      y: 0.0,
      z: 0.0,
    };
    let mut total = 0.0;
    for slot in 0..4 {
      let weight = weights[slot];
      if weight <= 0.0 {
        continue;
      }
      let joint = joints[slot] as usize;
      let (Some(global), Some(inverse)) = (globals.get(joint), scene.inverse_binds.get(joint)) else {
        continue;
      };
      let matrix = mul(global, inverse);
      let transformed = transform_point(&matrix, *position);
      acc.x += transformed.x * weight;
      acc.y += transformed.y * weight;
      acc.z += transformed.z * weight;
      total += weight;
    }
    if total > 0.0 {
      *position = acc;
    }
  }
}

pub fn with_blink(spin: [f32; 4]) -> [f32; 4] {
  mul_quat(spin, quat_x(0.8))
}

pub fn with_look(
  spin: [f32; 4],
  look_x: f32,
  look_y: f32,
) -> [f32; 4] {
  let yaw = mul_quat(spin, quat_y(look_x));
  mul_quat(yaw, quat_x(look_y))
}

fn quat_x(angle: f32) -> [f32; 4] {
  let half = angle * 0.5;
  [half.sin(), 0.0, 0.0, half.cos()]
}

fn quat_y(angle: f32) -> [f32; 4] {
  let half = angle * 0.5;
  [0.0, half.sin(), 0.0, half.cos()]
}

fn mul_quat(
  left: [f32; 4],
  right: [f32; 4],
) -> [f32; 4] {
  let (ax, ay, az, aw) = (left[0], left[1], left[2], left[3]);
  let (bx, by, bz, bw) = (right[0], right[1], right[2], right[3]);
  [
    aw * bx + ax * bw + ay * bz - az * by,
    aw * by - ax * bz + ay * bw + az * bx,
    aw * bz + ax * by - ay * bx + az * bw,
    aw * bw - ax * bx - ay * by - az * bz,
  ]
}

fn nlerp(
  start: [f32; 4],
  end: [f32; 4],
  mix: f32,
) -> [f32; 4] {
  let dot = start[0] * end[0] + start[1] * end[1] + start[2] * end[2] + start[3] * end[3];
  let end = if dot < 0.0 {
    [-end[0], -end[1], -end[2], -end[3]]
  } else {
    end
  };
  let mix = mix.clamp(0.0, 1.0);
  let value = [
    start[0] + (end[0] - start[0]) * mix,
    start[1] + (end[1] - start[1]) * mix,
    start[2] + (end[2] - start[2]) * mix,
    start[3] + (end[3] - start[3]) * mix,
  ];
  let length = (value[0] * value[0] + value[1] * value[1] + value[2] * value[2] + value[3] * value[3]).sqrt();
  if length <= f32::EPSILON {
    return [0.0, 0.0, 0.0, 1.0];
  }
  [
    value[0] / length,
    value[1] / length,
    value[2] / length,
    value[3] / length,
  ]
}

fn quat_to_matrix(q: [f32; 4]) -> [f32; 16] {
  let (x, y, z, w) = (q[0], q[1], q[2], q[3]);
  let x2 = x + x;
  let y2 = y + y;
  let z2 = z + z;
  let xx = x * x2;
  let xy = x * y2;
  let xz = x * z2;
  let yy = y * y2;
  let yz = y * z2;
  let zz = z * z2;
  let wx = w * x2;
  let wy = w * y2;
  let wz = w * z2;
  [
    1.0 - (yy + zz),
    xy + wz,
    xz - wy,
    0.0,
    xy - wz,
    1.0 - (xx + zz),
    yz + wx,
    0.0,
    xz + wy,
    yz - wx,
    1.0 - (xx + yy),
    0.0,
    0.0,
    0.0,
    0.0,
    1.0,
  ]
}

fn translation(position: Vec3) -> [f32; 16] {
  let mut matrix = IDENTITY;
  matrix[12] = position.x;
  matrix[13] = position.y;
  matrix[14] = position.z;
  matrix
}

fn mul(
  left: &[f32; 16],
  right: &[f32; 16],
) -> [f32; 16] {
  let mut out = [0.0; 16];
  for col in 0..4 {
    for row in 0..4 {
      let mut sum = 0.0;
      for k in 0..4 {
        sum += left[k * 4 + row] * right[col * 4 + k];
      }
      out[col * 4 + row] = sum;
    }
  }
  out
}

fn transform_point(
  matrix: &[f32; 16],
  position: Vec3,
) -> Vec3 {
  Vec3 {
    x: matrix[0] * position.x + matrix[4] * position.y + matrix[8] * position.z + matrix[12],
    y: matrix[1] * position.x + matrix[5] * position.y + matrix[9] * position.z + matrix[13],
    z: matrix[2] * position.x + matrix[6] * position.y + matrix[10] * position.z + matrix[14],
  }
}

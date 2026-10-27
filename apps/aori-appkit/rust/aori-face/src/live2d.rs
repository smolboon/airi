//! Flat layers that use Live2D parameter ids and motion3.json curves.
//! The pixels are original art. This module does not read moc3 or Cubism Core.

const SKIN: [u8; 4] = [255, 214, 186, 255];
const COAT: [u8; 4] = [52, 96, 176, 255];
const HAIR: [u8; 4] = [42, 28, 64, 255];
const EYE_WHITE: [u8; 4] = [248, 248, 252, 255];
const IRIS: [u8; 4] = [36, 64, 128, 255];
const PUPIL: [u8; 4] = [16, 16, 24, 255];
const MOUTH: [u8; 4] = [168, 48, 72, 255];
const LIP: [u8; 4] = [120, 48, 56, 255];
const RIBBON: [u8; 4] = [210, 64, 96, 255];
const EYELINE: [u8; 4] = [32, 24, 40, 255];

#[derive(Clone, Copy, Debug)]
pub struct LayeredPose {
  pub mouth_open_y: f32,
  pub eye_l_open: f32,
  pub eye_r_open: f32,
  pub angle_x: f32,
  pub angle_y: f32,
  pub time: f32,
}

/// Draws a top-left RGBA buffer. The top-left pixel stays clear.
pub fn render_layered(
  pose: LayeredPose,
  width: u32,
  height: u32,
) -> Vec<u8> {
  if width == 0 || height == 0 || width > 1280 || height > 1280 {
    return Vec::new();
  }
  let mut image = vec![0_u8; (width as usize) * (height as usize) * 4];
  let scale = (width as f32).min(height as f32);
  let shift_x = (pose.angle_x / 30.0).clamp(-1.0, 1.0) * scale * 0.06;
  let shift_y = (pose.angle_y / 30.0).clamp(-1.0, 1.0) * scale * 0.04;
  let bob = (pose.time * 2.0).sin() * scale * 0.012;
  let cx = width as f32 * 0.5 + shift_x;
  let cy = height as f32 * 0.36 + shift_y;
  let head_rx = scale * 0.26;
  let head_ry = scale * 0.30;
  fill_ellipse(
    &mut image,
    width,
    height,
    cx,
    cy + head_ry * 1.25,
    head_rx * 0.92,
    head_ry * 0.78,
    COAT,
  );
  fill_ellipse(
    &mut image,
    width,
    height,
    cx,
    cy - head_ry * 0.42 + bob,
    head_rx * 1.08,
    head_ry * 0.72,
    HAIR,
  );
  fill_ellipse(
    &mut image,
    width,
    height,
    cx + head_rx * 0.92,
    cy - head_ry * 0.55 + bob,
    head_rx * 0.16,
    head_ry * 0.16,
    RIBBON,
  );
  fill_ellipse(&mut image, width, height, cx, cy, head_rx, head_ry, SKIN);
  paint_eye(
    &mut image,
    width,
    height,
    cx - head_rx * 0.38,
    cy - head_ry * 0.08,
    head_rx * 0.20,
    head_ry * 0.18,
    pose.eye_l_open,
  );
  paint_eye(
    &mut image,
    width,
    height,
    cx + head_rx * 0.38,
    cy - head_ry * 0.08,
    head_rx * 0.20,
    head_ry * 0.18,
    pose.eye_r_open,
  );
  paint_mouth(
    &mut image,
    width,
    height,
    cx,
    cy + head_ry * 0.42,
    head_rx * 0.28,
    head_ry * 0.22,
    pose.mouth_open_y,
  );
  image
}

fn paint_eye(
  image: &mut [u8],
  width: u32,
  height: u32,
  cx: f32,
  cy: f32,
  rx: f32,
  ry: f32,
  open: f32,
) {
  let open = open.clamp(0.0, 1.0);
  if open <= 0.08 {
    fill_ellipse(image, width, height, cx, cy, rx, 1.6, EYELINE);
    return;
  }
  fill_ellipse(image, width, height, cx, cy, rx, ry * open, EYE_WHITE);
  fill_ellipse(
    image,
    width,
    height,
    cx,
    cy,
    rx * 0.46,
    ry * open * 0.72,
    IRIS,
  );
  fill_ellipse(
    image,
    width,
    height,
    cx,
    cy,
    rx * 0.18,
    ry * open * 0.28,
    PUPIL,
  );
}

fn paint_mouth(
  image: &mut [u8],
  width: u32,
  height: u32,
  cx: f32,
  cy: f32,
  rx: f32,
  ry: f32,
  open: f32,
) {
  let open = open.clamp(0.0, 1.0);
  if open <= 0.08 {
    fill_ellipse(image, width, height, cx, cy, rx * 0.7, 1.6, LIP);
    return;
  }
  fill_ellipse(image, width, height, cx, cy, rx, ry * open, MOUTH);
}

fn fill_ellipse(
  image: &mut [u8],
  width: u32,
  height: u32,
  cx: f32,
  cy: f32,
  rx: f32,
  ry: f32,
  color: [u8; 4],
) {
  if rx < 0.5 || ry < 0.5 {
    return;
  }
  let min_x = ((cx - rx).floor() as i32).max(0);
  let max_x = ((cx + rx).ceil() as i32).min(width as i32 - 1);
  let min_y = ((cy - ry).floor() as i32).max(0);
  let max_y = ((cy + ry).ceil() as i32).min(height as i32 - 1);
  let inv_rx = 1.0 / (rx * rx);
  let inv_ry = 1.0 / (ry * ry);
  for y in min_y..=max_y {
    for x in min_x..=max_x {
      let dx = x as f32 + 0.5 - cx;
      let dy = y as f32 + 0.5 - cy;
      if dx * dx * inv_rx + dy * dy * inv_ry <= 1.0 {
        put(image, width, x, y, color);
      }
    }
  }
}

fn put(
  image: &mut [u8],
  width: u32,
  x: i32,
  y: i32,
  color: [u8; 4],
) {
  if x < 0 || y < 0 {
    return;
  }
  let offset = (y as usize) * (width as usize) * 4 + (x as usize) * 4;
  if offset + 3 >= image.len() {
    return;
  }
  image[offset] = color[0];
  image[offset + 1] = color[1];
  image[offset + 2] = color[2];
  image[offset + 3] = color[3];
}

enum Span {
  Linear { start: f32, end: f32, from: f32, to: f32 },
  Bezier {
    start: f32,
    from: f32,
    c1_time: f32,
    c1_value: f32,
    c2_time: f32,
    c2_value: f32,
    end: f32,
    to: f32,
  },
  Stepped { end: f32, from: f32, to: f32 },
  Inverse { start: f32, end: f32, from: f32, to: f32 },
}

impl Span {
  fn end_time(&self) -> f32 {
    match self {
      Span::Linear { end, .. }
      | Span::Bezier { end, .. }
      | Span::Stepped { end, .. }
      | Span::Inverse { end, .. } => *end,
    }
  }

  fn end_value(&self) -> f32 {
    match self {
      Span::Linear { to, .. }
      | Span::Bezier { to, .. }
      | Span::Stepped { to, .. }
      | Span::Inverse { to, .. } => *to,
    }
  }

  fn value_at(&self, time: f32) -> f32 {
    match *self {
      Span::Linear { start, end, from, to } => lerp(start, end, from, to, time),
      Span::Stepped { end, from, to } => {
        if time < end {
          from
        } else {
          to
        }
      }
      Span::Inverse { start, from, to, .. } => {
        if time > start {
          to
        } else {
          from
        }
      }
      Span::Bezier {
        start,
        from,
        c1_time,
        c1_value,
        c2_time,
        c2_value,
        end,
        to,
      } => sample_bezier(start, from, c1_time, c1_value, c2_time, c2_value, end, to, time),
    }
  }
}

fn lerp(
  start: f32,
  end: f32,
  from: f32,
  to: f32,
  time: f32,
) -> f32 {
  let span = end - start;
  if span.abs() < 1.0e-6 {
    return to;
  }
  let weight = ((time - start) / span).clamp(0.0, 1.0);
  from + (to - from) * weight
}

fn cubic(
  p0: f32,
  p1: f32,
  p2: f32,
  p3: f32,
  t: f32,
) -> f32 {
  let u = 1.0 - t;
  u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
}

fn sample_bezier(
  start: f32,
  from: f32,
  c1_time: f32,
  c1_value: f32,
  c2_time: f32,
  c2_value: f32,
  end: f32,
  to: f32,
  time: f32,
) -> f32 {
  let mut low = 0.0_f32;
  let mut high = 1.0_f32;
  for _ in 0..24 {
    let mid = (low + high) * 0.5;
    if cubic(start, c1_time, c2_time, end, mid) < time {
      low = mid;
    } else {
      high = mid;
    }
  }
  cubic(from, c1_value, c2_value, to, (low + high) * 0.5)
}

/// Samples one motion3.json curve. The first two numbers are the first point.
/// Tag 0 is linear, 1 is bezier, 2 is stepped, and 3 is inverse stepped.
pub fn sample_segments(
  segments: &[f32],
  time: f32,
) -> Option<f32> {
  if segments.len() < 2 {
    return None;
  }
  let origin_time = segments[0];
  let origin_value = segments[1];
  let spans = parse_spans(segments)?;
  if time <= origin_time || spans.is_empty() {
    return Some(origin_value);
  }
  for span in &spans {
    if time <= span.end_time() {
      return Some(span.value_at(time));
    }
  }
  spans.last().map(Span::end_value)
}

fn parse_spans(segments: &[f32]) -> Option<Vec<Span>> {
  let mut index = 2;
  let mut time = segments[0];
  let mut value = segments[1];
  let mut spans = Vec::new();
  while index < segments.len() {
    let tag = segments[index] as i32;
    if (segments[index] - tag as f32).abs() > 1.0e-4 {
      return None;
    }
    match tag {
      0 | 2 | 3 => {
        let end = *segments.get(index + 1)?;
        let next = *segments.get(index + 2)?;
        let span = match tag {
          0 => Span::Linear { start: time, end, from: value, to: next },
          2 => Span::Stepped { end, from: value, to: next },
          _ => Span::Inverse { start: time, end, from: value, to: next },
        };
        spans.push(span);
        time = end;
        value = next;
        index += 3;
      }
      1 => {
        let c1_time = *segments.get(index + 1)?;
        let c1_value = *segments.get(index + 2)?;
        let c2_time = *segments.get(index + 3)?;
        let c2_value = *segments.get(index + 4)?;
        let end = *segments.get(index + 5)?;
        let next = *segments.get(index + 6)?;
        spans.push(Span::Bezier {
          start: time,
          from: value,
          c1_time,
          c1_value,
          c2_time,
          c2_value,
          end,
          to: next,
        });
        time = end;
        value = next;
        index += 7;
      }
      _ => return None,
    }
  }
  Some(spans)
}

/// Reads a public motion3.json curve by parameter id.
pub fn sample_motion(
  json: &str,
  id: &str,
  time: f32,
) -> Option<f32> {
  let root: serde_json::Value = serde_json::from_str(json).ok()?;
  let curves = root.get("Curves")?.as_array()?;
  for curve in curves {
    if curve.get("Id")?.as_str() != Some(id) {
      continue;
    }
    let raw = curve.get("Segments")?.as_array()?;
    let mut segments = Vec::with_capacity(raw.len());
    for item in raw {
      segments.push(item.as_f64()? as f32);
    }
    return sample_segments(&segments, time);
  }
  None
}

/// # Safety
///
/// `out_rgba` must point at `width * height * 4` bytes.
#[no_mangle]
pub unsafe extern "C" fn aori_face_render_live2d(
  mouth: f32,
  eye_l: f32,
  eye_r: f32,
  angle_x: f32,
  angle_y: f32,
  time: f32,
  width: u32,
  height: u32,
  out_rgba: *mut u8,
) -> i32 {
  if out_rgba.is_null() || width == 0 || height == 0 || width > 1280 || height > 1280 {
    return -1;
  }
  let image = render_layered(
    LayeredPose {
      mouth_open_y: mouth,
      eye_l_open: eye_l,
      eye_r_open: eye_r,
      angle_x,
      angle_y,
      time,
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

  fn pose(
    mouth: f32,
    eye: f32,
  ) -> LayeredPose {
    LayeredPose {
      mouth_open_y: mouth,
      eye_l_open: eye,
      eye_r_open: eye,
      angle_x: 0.0,
      angle_y: 0.0,
      time: 0.0,
    }
  }

  fn contains(
    pixels: &[u8],
    color: [u8; 4],
  ) -> bool {
    pixels.chunks(4).any(|pixel| pixel == color)
  }

  fn min_opaque_x(
    pixels: &[u8],
    width: u32,
  ) -> Option<u32> {
    for (index, pixel) in pixels.chunks(4).enumerate() {
      if pixel[3] == 255 {
        return Some((index as u32) % width);
      }
    }
    None
  }

  #[test]
  fn linear_motion_is_halfway_at_half_time() {
    let json = r#"{"Curves":[{"Id":"ParamMouthOpenY","Segments":[0,0,0,1,1]}]}"#;
    let value = sample_motion(json, "ParamMouthOpenY", 0.5).expect("curve");
    assert!((value - 0.5).abs() < 1.0e-5);
  }

  #[test]
  fn stepped_and_inverse_hold_opposite_values() {
    let stepped = sample_segments(&[0.0, 0.0, 2.0, 1.0, 1.0], 0.5).expect("stepped");
    let inverse = sample_segments(&[0.0, 0.0, 3.0, 1.0, 1.0], 0.5).expect("inverse");
    assert!((stepped - 0.0).abs() < 1.0e-5);
    assert!((inverse - 1.0).abs() < 1.0e-5);
  }

  #[test]
  fn bezier_line_matches_linear_and_bad_tags_fail() {
    let value = sample_segments(
      &[0.0, 0.0, 1.0, 1.0 / 3.0, 1.0 / 3.0, 2.0 / 3.0, 2.0 / 3.0, 1.0, 1.0],
      0.5,
    )
    .expect("bezier");
    assert!((value - 0.5).abs() < 0.02);
    assert!(sample_segments(&[0.0, 0.0, 9.0, 1.0, 1.0], 0.5).is_none());
    assert!(sample_segments(&[0.0, 0.0, 1.0, 0.2], 0.5).is_none());
    assert!(sample_motion("{}", "ParamMouthOpenY", 0.5).is_none());
  }

  #[test]
  fn layered_art_keeps_a_clear_corner_and_a_flat_head() {
    let pixels = render_layered(pose(1.0, 1.0), 280, 380);
    assert_eq!(pixels[3], 0);
    assert!(contains(&pixels, SKIN));
    assert!(contains(&pixels, COAT));
    assert!(contains(&pixels, HAIR));
    let flat = pixels.chunks(4).collect::<Vec<_>>();
    assert!(flat.windows(2).any(|pair| pair[0] == SKIN && pair[1] == SKIN));
  }

  #[test]
  fn mouth_and_eyes_change_pixels() {
    let open = render_layered(pose(1.0, 1.0), 160, 220);
    let shut = render_layered(pose(0.0, 0.0), 160, 220);
    assert!(contains(&open, MOUTH));
    assert!(!contains(&shut, MOUTH));
    assert!(contains(&shut, LIP));
    assert!(contains(&open, IRIS));
    assert!(contains(&open, EYE_WHITE));
    assert!(!contains(&shut, IRIS));
  }

  #[test]
  fn angle_shifts_the_body_and_the_corner_stays_clear() {
    let rest = render_layered(pose(0.2, 1.0), 160, 220);
    let turned = render_layered(
      LayeredPose {
        angle_x: 30.0,
        angle_y: 30.0,
        ..pose(0.2, 1.0)
      },
      160,
      220,
    );
    let rest_x = min_opaque_x(&rest, 160).expect("rest");
    let turned_x = min_opaque_x(&turned, 160).expect("turned");
    assert!(turned_x > rest_x);
    assert_eq!(turned[3], 0);
  }

  #[test]
  fn c_abi_renders_layers_and_rejects_a_bad_size() {
    let mut pixels = vec![7_u8; 32 * 32 * 4];
    let code = unsafe {
      aori_face_render_live2d(1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 32, 32, pixels.as_mut_ptr())
    };
    assert_eq!(code, 0);
    assert_eq!(pixels[3], 0);
    assert!(contains(&pixels, SKIN));
    let bad = unsafe {
      aori_face_render_live2d(
        1.0,
        1.0,
        1.0,
        0.0,
        0.0,
        0.0,
        0,
        32,
        pixels.as_mut_ptr(),
      )
    };
    assert_eq!(bad, -1);
    let huge = unsafe {
      aori_face_render_live2d(
        1.0,
        1.0,
        1.0,
        0.0,
        0.0,
        0.0,
        1281,
        32,
        pixels.as_mut_ptr(),
      )
    };
    assert_eq!(huge, -1);
    let null = unsafe {
      aori_face_render_live2d(1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 32, 32, std::ptr::null_mut())
    };
    assert_eq!(null, -1);
  }
}

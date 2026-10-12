use aori_face::{add_morph, project, read_glb, FaceMesh, Vec3};
use gpui::{
  canvas, div, point, prelude::*, px, rgb, size, App, Application, Bounds, Context, PathBuilder,
  Pixels, TitlebarOptions, Window, WindowBackgroundAppearance, WindowBounds, WindowKind,
  WindowOptions,
};

const SAMPLE: &[u8] = include_bytes!("../../../Sources/AoriApp/Resources/aori-sample.vrm");

struct FaceWindow {
  meshes: Vec<FaceMesh>,
}

impl Render for FaceWindow {
  fn render(
    &mut self,
    _window: &mut Window,
    _cx: &mut Context<Self>,
  ) -> impl IntoElement {
    let meshes = self.meshes.clone();
    div()
      .size_full()
      .bg(gpui::transparent_black())
      .child(
        canvas(
          |_, _, _| {},
          move |bounds, _, window, _| {
            paint_meshes(&meshes, bounds, window);
          },
        )
        .size_full(),
      )
  }
}

fn paint_meshes(
  meshes: &[FaceMesh],
  bounds: Bounds<Pixels>,
  window: &mut Window,
) {
  let width = f32::from(bounds.size.width);
  let height = f32::from(bounds.size.height);
  let scale = width.min(height) * 0.9;
  let origin_x = f32::from(bounds.origin.x) + width * 0.5;
  // GPUI y grows downward. AppKit y grows upward, so this window flips y.
  let center_y = f32::from(bounds.origin.y) + height * 0.5;
  for mesh in meshes {
    let mut positions = mesh.positions.clone();
    if let Some(mouth) = mesh
      .morphs
      .iter()
      .find(|morph| morph.name == "aa")
    {
      add_morph(&mut positions, &mouth.deltas, 0.65);
    }
    let mut triangles = Vec::new();
    let mut index = 0;
    while index + 2 < mesh.indices.len() {
      let first = mesh.indices[index] as usize;
      let second = mesh.indices[index + 1] as usize;
      let third = mesh.indices[index + 2] as usize;
      index += 3;
      if first >= positions.len() || second >= positions.len() || third >= positions.len() {
        continue;
      }
      let z = (positions[first].z + positions[second].z + positions[third].z) / 3.0;
      triangles.push((z, first, second, third));
    }
    triangles.sort_by(|left, right| {
      left
        .0
        .partial_cmp(&right.0)
        .unwrap_or(std::cmp::Ordering::Equal)
    });
    let mut color = rgb(pack(mesh.color));
    color.a = mesh.color[3];
    for (_, first, second, third) in triangles {
      let mut builder = PathBuilder::fill();
      let start = pixel(positions[first], origin_x, center_y, scale);
      builder.move_to(start);
      builder.line_to(pixel(positions[second], origin_x, center_y, scale));
      builder.line_to(pixel(positions[third], origin_x, center_y, scale));
      builder.close();
      if let Ok(path) = builder.build() {
        window.paint_path(path, color);
      }
    }
  }
}

fn pixel(
  position: Vec3,
  origin_x: f32,
  center_y: f32,
  scale: f32,
) -> gpui::Point<Pixels> {
  let (x, y_up) = project(position, 0.0, origin_x, 0.0, scale);
  let y = center_y - (y_up - 0.2 * scale);
  point(px(x), px(y))
}

fn pack(color: [f32; 4]) -> u32 {
  let channel = |value: f32| (value.clamp(0.0, 1.0) * 255.0) as u32;
  (channel(color[0]) << 16) | (channel(color[1]) << 8) | channel(color[2])
}

fn main() {
  let scene = read_glb(SAMPLE).expect("The bundled sample VRM parses.");
  Application::new().run(move |cx: &mut App| {
    let bounds = Bounds::centered(None, size(px(420.), px(640.)), cx);
    let meshes = scene.meshes.clone();
    cx.open_window(
      WindowOptions {
        window_bounds: Some(WindowBounds::Windowed(bounds)),
        titlebar: Some(TitlebarOptions {
          title: Some("Aori".into()),
          appears_transparent: true,
          traffic_light_position: None,
        }),
        kind: WindowKind::PopUp,
        is_movable: true,
        window_background: WindowBackgroundAppearance::Transparent,
        ..Default::default()
      },
      move |_window, cx| cx.new(move |_| FaceWindow { meshes }),
    )
    .expect("The GPUI window opens.");
    cx.activate(true);
  });
}

use std::{path::Path, sync::Arc};

use aori_face::{encode_png, read_glb, render_frame, FaceScene, RenderPose};
use gpui::{
  canvas, div, prelude::*, px, size, App, Application, Bounds, Context, Corners, Pixels,
  RenderImage, TitlebarOptions, Window, WindowBackgroundAppearance, WindowBounds, WindowKind,
  WindowOptions,
};
use image::{Frame, ImageBuffer, Rgba};

const SAMPLE: &[u8] = include_bytes!("../../../Sources/AoriApp/Resources/aori-sample.vrm");
const FRAME_WIDTH: u32 = 280;
const FRAME_HEIGHT: u32 = 380;

struct FaceWindow {
  image: Arc<RenderImage>,
}

impl Render for FaceWindow {
  fn render(
    &mut self,
    _window: &mut Window,
    _cx: &mut Context<Self>,
  ) -> impl IntoElement {
    let image = Arc::clone(&self.image);
    div()
      .size_full()
      .bg(gpui::transparent_black())
      .child(
        canvas(
          |_, _, _| {},
          move |bounds, _, window, _| {
            let corners: Corners<Pixels> = Corners::default();
            let _ = window.paint_image(bounds, corners, Arc::clone(&image), 0, false);
          },
        )
        .size_full(),
      )
  }
}

fn portrait_pose() -> RenderPose {
  RenderPose {
    mouth: 0.65,
    viseme: 0,
    time: 1.6,
    ..RenderPose::default()
  }
}

fn rgba_frame(scene: &FaceScene) -> Vec<u8> {
  render_frame(scene, &portrait_pose(), FRAME_WIDTH, FRAME_HEIGHT)
}

fn write_png(
  scene: &FaceScene,
  path: &Path,
) {
  let pixels = rgba_frame(scene);
  let png = encode_png(&pixels, FRAME_WIDTH, FRAME_HEIGHT).expect("The raster encodes as PNG.");
  std::fs::write(path, png).expect("The PNG file was written.");
}

fn lit_image(scene: &FaceScene) -> RenderImage {
  let mut pixels = rgba_frame(scene);
  let mut index = 0;
  while index + 3 < pixels.len() {
    pixels.swap(index, index + 2);
    index += 4;
  }
  let buffer = ImageBuffer::<Rgba<u8>, Vec<u8>>::from_raw(FRAME_WIDTH, FRAME_HEIGHT, pixels)
    .expect("The raster size matches the buffer.");
  RenderImage::new(vec![Frame::new(buffer)])
}

fn main() {
  let scene = read_glb(SAMPLE).expect("The bundled sample VRM parses.");
  if let Some(path) = std::env::var_os("AORI_GPUI_PNG") {
    write_png(&scene, Path::new(&path));
    return;
  }
  let image = Arc::new(lit_image(&scene));
  Application::new().run(move |cx: &mut App| {
    let bounds = Bounds::centered(None, size(px(420.), px(640.)), cx);
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
      move |_window, cx| cx.new(move |_| FaceWindow { image: Arc::clone(&image) }),
    )
    .expect("The GPUI window opens.");
    cx.activate(true);
  });
}

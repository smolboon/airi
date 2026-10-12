# Aori product

Aori is a desktop companion for macOS. It is a native port of Project AIRI. The Vue apps keep the upstream name. This app does not rename them.

The companion is a character on the desktop. The window is transparent. You can drag it. It can stay above other windows. Clear pixels pass clicks through the window. Opaque pixels and the caption keep the click.

Settings stores a name and a personality. The app stores facts that you mark with "remember that". Launch shows a greeting. The character blinks and sways while idle. Voice and text share one chat. The mouth follows speech, and a few words change the face.

## Sources

Project AIRI supplies the companion idea, the chat flow, and the VRM stage. The transparent window comes from the AIRI Stage Tamagotchi app.

Animates is a separate product from Animation Inc. The site at animates.ai says companions live on phones and desktops. The App Store page says the app uses real-time voice, emotion, and memory. That page does not describe a transparent desktop pet. Aori does not copy an Animates window. A fan site at companionsfan.cz is not the vendor.

## This milestone

The character is an original CC0 humanoid. Rust skins the mesh, lights it, and fills a depth buffer. AppKit shows that image. Chat can call an OpenAI-compatible provider. When the API key is empty, a local reply runs on the device. That reply is a template. It is not a neural model.

Speech output uses the macOS speech synthesizer. Speech input uses the Speech framework when permission is granted. When permission is missing, the app runs whisper.cpp on the recorded WAV. CI downloads `ggml-base.en.bin`. That file is not in git.

When `AORI_AVATAR` is `live2d`, the companion window draws a flat character. Rust draws the layers. The mouth, the eyes, and the head angle use Live2D parameter ids. Rust can sample a motion3.json curve. This path does not load Cubism Core or a moc3 file. Run 38295099387 showed that character in the companion window and in the chat sidebar.

Menu strings exist for en, es, fr, ja, ko, ru, vi, zh-Hans, and zh-Hant. The API key can live in the Keychain. A provider error retries once before any reply text. VoiceOver labels are on the chat controls, the character, and both windows. The screenshot path reads those live labels. It then tries to start VoiceOver.

The app reads an AIRI Manifest v2 file named `extension.airi.json`. The host grant is `aori.companion.*` with the snapshot action. A JSON command list asks for capabilities. The sample plugin `aori-greeting` receives the greeting text. A request for `aori.files.read` is denied. The host does not run JavaScript, and the process is not in the macOS App Sandbox.

Run 38298286037 logged `aori_plugin=loaded id=aori-greeting` and `aori_plugin_denied=aori.files.read`. The companion window still shows the flat character. The hair is above the blue body.

The screenshot path asks ScreenCaptureKit for one frame. When permission is denied, the app sends a PNG fixture through the OpenAI-compatible client. The workload is `screen:interpret`. The app does not run a vision ticker. A granted capture sends that frame to the configured provider.

Run 38301336719 logged `aori_vision_permission=granted` and `aori_vision_source=screen`. The PNG was 30500 bytes. The mock reply was `Mock vision from CI.`. The mock does not read the pixels. The chat reply stayed `Mock reply from CI.`.

## Not in this app

Cubism moc3, JavaScript plugins, a vision ticker, tool calls, and cloud memory are not in this app. The plan is in `docs/APPKIT_PORT.md`.

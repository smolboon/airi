# Aori

Aori is the native macOS companion. It is based on Project AIRI. The windows are AppKit. The chat core is plain Swift.

## What it does

The app opens a main window and a transparent companion window. The companion window stays above other apps. You can drag it. A status item lists the companion, the chat, and Settings.

Settings stores a name and a personality. Say "remember that" in chat to store a fact. Launch shows a greeting and speaks it. The character blinks while idle. The humanoid rig sways the neck and the head, and it turns the eyes. A few words change blend shapes.

Speak uses `AVSpeechSynthesizer`. A small word list picks phoneme visemes. Other words use letters. The audio level scales that shape. The app listens without a Speak press. A quiet tail ends the utterance. Listen uses the Speech framework when permission is granted. When it is not, the app runs `whisper-cli` on the recorded WAV. Set `AORI_WHISPER_BIN` and `AORI_WHISPER_MODEL` for that path. When the API key is empty, chat uses a local template. A key uses the OpenAI-compatible provider. The bundled character is an original CC0 VRM humanoid with a texture, arms, and eye look-at. A Rust library skins the mesh, lights it, and fills a depth buffer. AppKit shows that image.

When `AORI_AVATAR` is `live2d`, the companion window draws a flat character. The mouth, the eyes, and the head angle use Live2D parameter ids. The art is original. The app does not read a Cubism moc3 file. Chat history, provider settings, and the locale choice are saved next to the persona file. The chat panel can search messages and memory notes. Each locale under `packages/i18n` has Aori menu keys.

You can open another `.vrm` file. A separate GPUI window paints the lit sample raster. That window is not the AppKit app. Clear pixels on the companion window pass clicks through. Opaque pixels and the caption keep the click. The screenshot path posts one click onto a window titled Aori Behind.

## How to use it

On macOS:

1. Open a terminal in `apps/aori-appkit`.
2. Export `AORI_OPENAI_API_KEY`, or save the key in Settings after launch.
3. Run `./scripts/assemble-app.sh`. The script builds the Rust library, then the app.
4. Open `build/Aori.app`.

The GPUI window is separate. From `rust`, run `cargo run -p aori-gpui`. It paints the lit sample raster. Before that command, set `AORI_GPUI_PNG` to a PNG path. The command writes the raster and exits. Set `AORI_GPUI_EXIT_MS` to quit the interactive window after that many milliseconds. It does not join the AppKit chat.

In Xcode, open `Package.swift` and run the AoriApp scheme. You can also open `AoriAppKit.xcodeproj` and run the Aori scheme. The script bundle is `Aori.app`. Its executable is `AoriApp`. The Xcode product name is `Aori`.

Optional environment variables:

- `AORI_AVATAR` with the value `live2d` selects the flat character. The default is the VRM.
- `AORI_OPENAI_BASE_URL` or `OPENAI_BASE_URL`
- `AORI_OPENAI_MODEL` or `OPENAI_MODEL`
- `OPENAI_API_KEY` when `AORI_OPENAI_API_KEY` is absent

The default base URL is `https://api.openai.com/v1`. The default model is `gpt-4o-mini`.

## When to use it

Use it to work on the native macOS companion. Use it to run the milestone 1 shell on Apple Silicon. An Intel Mac on macOS 14 or later can run the same shell.

## When not to use it

Do not use it for Cubism moc3 models, plugins, vision, or games. Do not use it for vector memory. The saved facts are a short list. Use Stage Web or Stage Tamagotchi for the other features. Do not commit an API key.

## Layout

```text
apps/aori-appkit/
├── Package.swift
├── AoriAppKit.xcodeproj
├── Sources/AoriCore/         # Chat, secrets, VRM bytes, window policy
├── Sources/AoriProviders/    # OpenAI-compatible streaming client
├── Sources/AoriApp/          # AppKit, speech, raster blit (macOS only)
├── rust/aori-face/           # Skin, light, depth raster, layered avatar, sample glTF read
├── rust/aori-gpui/           # Separate GPUI window
└── Tests/
```

`AoriCore` and `AoriProviders` do not import AppKit. Linux can test them. `Package.swift` adds the AoriApp executable only on macOS.

## Tests

From `apps/aori-appkit`:

```sh
swift test
```

On macOS, build the face library before that test. `swift test` links the app.

```sh
(cd rust && cargo build -p aori-face)
```

From `rust`:

```sh
cargo test -p aori-face
cargo check -p aori-gpui
```

The macOS CI job also runs `xcodebuild`, `./scripts/fetch-whisper.sh`, `./scripts/assemble-app.sh`, `./scripts/screenshot-app.sh`, and `./scripts/capture-gpui-window.sh`. The screenshot script sets `AORI_SCREENSHOT=1` and starts `scripts/mock-chat-server.py`. The app writes `build/aori-framebuffer.png`, speaks a short line, and writes `build/aori-speech.wav`. The window stays open so `screencapture` can grab it.

## Limits

This tree does not run Live2D. The sample is an original CC0 humanoid, not a downloaded character. Persona and memory notes are stored in `companion.json`. Chat text is stored in `chat.json`. The base URL and the model are stored in `settings.json`. The locale id is stored in `locale.json`. The Linux URLSession path buffers the HTTP body. The macOS path reads the body in chunks. Speech permission strings are in `Info.plist`. Run the assembled app so macOS can read them. Known words use an ARPAbet list. That list is not a phoneme recognizer.

The GPUI binary paints the lit raster. It does not hear speech. The on-device model in CI is `ggml-base.en.bin`.

Every locale directory under `packages/i18n` has Aori menu keys. The local reply is a template. It is not a neural model. The whisper model file is not in git.

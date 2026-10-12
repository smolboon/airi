# Aori

Aori is the native macOS companion. It is based on Project AIRI. The windows are AppKit. The chat core is plain Swift.

## What it does

The app opens a main window and a transparent companion window. The companion window stays above other apps. You can drag it. Settings stores a name and a personality. Say "remember that" in chat to store a fact. Launch shows a greeting and speaks it. The character blinks while idle. A few words change blend shapes. Speak uses `AVSpeechSynthesizer`. The mouth blend shape uses the level of the spoken audio. Listen uses the Speech framework. The bundled character is a CC0 VRM head. AppKit fills its projected triangles. A Rust library moves the vertices. You can open another `.vrm` file. The mesh stays in the bind pose. A separate GPUI window can paint the same sample head. That window is not the AppKit app.

## How to use it

On macOS:

1. Open a terminal in `apps/aori-appkit`.
2. Export `AORI_OPENAI_API_KEY`, or save the key in Settings after launch.
3. Run `./scripts/assemble-app.sh`. The script builds the Rust library, then the app.
4. Open `build/Aori.app`.

The GPUI window is separate. From `rust`, run `cargo run -p aori-gpui`. It paints the sample head with a fixed mouth weight. It does not join the AppKit chat.

In Xcode, open `Package.swift` and run the AoriApp scheme. You can also open `AoriAppKit.xcodeproj` and run the Aori scheme. The script bundle is `Aori.app`. Its executable is `AoriApp`. The Xcode product name is `Aori`.

Optional environment variables:

- `AORI_OPENAI_BASE_URL` or `OPENAI_BASE_URL`
- `AORI_OPENAI_MODEL` or `OPENAI_MODEL`
- `OPENAI_API_KEY` when `AORI_OPENAI_API_KEY` is absent

The default base URL is `https://api.openai.com/v1`. The default model is `gpt-4o-mini`.

## When to use it

Use it to work on the native macOS companion. Use it to run the milestone 1 shell on Apple Silicon. An Intel Mac on macOS 14 or later can run the same shell.

## When not to use it

Do not use it for Live2D, plugins, vision, or games. Do not use it for vector memory. The saved facts are a short list. Use Stage Web or Stage Tamagotchi for the other features. Do not commit an API key.

## Layout

```text
apps/aori-appkit/
├── Package.swift
├── AoriAppKit.xcodeproj
├── Sources/AoriCore/         # Chat, secrets, VRM bytes, window policy
├── Sources/AoriProviders/    # OpenAI-compatible streaming client
├── Sources/AoriApp/          # AppKit, speech, triangle view (macOS only)
├── rust/aori-face/           # Deform, project, sample glTF read
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

The macOS CI job also runs `./scripts/assemble-app.sh`.

## Limits

This tree does not run Live2D. It does not play bone animation. The sample head uses a flat color. Chat text is lost when the app quits. Persona and memory notes are stored in `companion.json`. The Linux URLSession path buffers the HTTP body. The macOS path reads the body in chunks. Speech permission strings are in `Info.plist`. Run the assembled app so macOS can read them. Lip-sync uses audio level, not phoneme visemes.

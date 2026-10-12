# AIRI AppKit

Native macOS companion shell for Project AIRI. The windows are AppKit. The chat core is plain Swift.

## What it does

The app opens a main window and a transparent companion window. The companion window stays above other apps. You can chat with an OpenAI-compatible provider. Replies stream into the transcript. Speak uses `AVSpeechSynthesizer`. Listen uses the Speech framework. The character is a SceneKit placeholder. A binary VRM file can supply its name. The mesh is not imported.

## How to use it

On macOS:

1. Open a terminal in `apps/airi-appkit`.
2. Export `AIRI_OPENAI_API_KEY`, or save the key in Settings after launch.
3. Run `./scripts/assemble-app.sh`.
4. Open `build/Airi.app`.

In Xcode, open `Package.swift` and run the AiriApp scheme. You can also open `AiriAppKit.xcodeproj` and run the AIRI scheme.

Optional environment variables:

- `AIRI_OPENAI_BASE_URL` or `OPENAI_BASE_URL`
- `AIRI_OPENAI_MODEL` or `OPENAI_MODEL`
- `OPENAI_API_KEY` when `AIRI_OPENAI_API_KEY` is absent

The default base URL is `https://api.openai.com/v1`. The default model is `gpt-4o-mini`.

## When to use it

Use it to work on the native macOS port. Use it to run the milestone 1 chat shell on Apple Silicon or an Intel Mac on macOS 14 or later.

## When not to use it

Do not use it for Live2D, plugins, memory, vision, or games. Use Stage Web or Stage Tamagotchi for those features. Do not commit an API key.

## Layout

```text
apps/airi-appkit/
├── Package.swift
├── AiriAppKit.xcodeproj
├── Sources/AiriCore/         # Chat, secrets, VRM metadata, window policy
├── Sources/AiriProviders/    # OpenAI-compatible streaming client
├── Sources/AiriApp/          # AppKit, speech, SceneKit (macOS only)
└── Tests/
```

`AiriCore` and `AiriProviders` do not import AppKit. Linux can test them. `Package.swift` adds the AiriApp executable only on macOS.

## Tests

From `apps/airi-appkit`:

```sh
swift test
```

The macOS CI job also runs `./scripts/assemble-app.sh`.

## Limits

This tree does not render a VRM mesh. It does not run Live2D. Chat text stays in memory until the app quits. The Linux URLSession path buffers the HTTP body. The macOS path reads the body in chunks. Speech permission strings are in `Info.plist`. Run the assembled app so macOS can read them.

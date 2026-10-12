# Aori

Aori is the native macOS companion. It is based on Project AIRI. The windows are AppKit. The chat core is plain Swift.

## What it does

The app opens a main window and a transparent companion window. The companion window stays above other apps. You can drag it. Settings stores a name and a personality. Say "remember that" in chat to store a fact. Launch shows a greeting and speaks it. The character blinks while idle. A few words change the face. Speak uses `AVSpeechSynthesizer`. Listen uses the Speech framework. The mouth moves while speech is active. It does not follow audio samples. The character is a SceneKit placeholder. A binary VRM file can supply its name. The mesh is not imported.

## How to use it

On macOS:

1. Open a terminal in `apps/aori-appkit`.
2. Export `AORI_OPENAI_API_KEY`, or save the key in Settings after launch.
3. Run `./scripts/assemble-app.sh`.
4. Open `build/Aori.app`.

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
├── Sources/AoriCore/         # Chat, secrets, VRM metadata, window policy
├── Sources/AoriProviders/    # OpenAI-compatible streaming client
├── Sources/AoriApp/          # AppKit, speech, SceneKit (macOS only)
└── Tests/
```

`AoriCore` and `AoriProviders` do not import AppKit. Linux can test them. `Package.swift` adds the AoriApp executable only on macOS.

## Tests

From `apps/aori-appkit`:

```sh
swift test
```

The macOS CI job also runs `./scripts/assemble-app.sh`.

## Limits

This tree does not render a VRM mesh. It does not run Live2D. Chat text is lost when the app quits. Persona and memory notes are stored in `companion.json`. The Linux URLSession path buffers the HTTP body. The macOS path reads the body in chunks. Speech permission strings are in `Info.plist`. Run the assembled app so macOS can read them. The mouth timer is not audio lip-sync.

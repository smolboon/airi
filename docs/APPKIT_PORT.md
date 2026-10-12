# Aori AppKit port

Aori is a native macOS app based on Project AIRI. The app lives in `apps/aori-appkit`. It uses Swift and AppKit. Apple Silicon is the first machine target. Intel Macs on macOS 14 can build the same package.

This note maps the current AIRI apps onto Aori.

The verb for this note is "make sure". The noun for saved values is "configuration".

## Current AIRI

Stage Web, Stage Tamagotchi, and Stage Pocket share Vue, Pinia, and `packages/stage-ui`. Stage Tamagotchi is the Electron desktop app. Stage Pocket is the Capacitor mobile app.

Chat turns live in `packages/core-agent`. A turn can contain text, tool rounds, and a stream of deltas. `packages/stage-ui` stores the visible transcript and sends it through the active provider.

Chat providers live in `packages/provider-inference`. The OpenAI-compatible provider sends chat completions to a base URL with an API key. The default base URL is `https://api.openai.com/v1`. Other vendors can use that same protocol. The provider configuration is stored on the device and can replicate to the signed-in cloud account.

Speech output uses provider TTS from the speech store in `packages/stage-ui`. A browser speech path also exists. Speech input uses the hearing store. That store can call Apple Speech, Sherpa, Web Speech, or a transcription provider. The Electron app already bridges Apple Speech.

VRM rendering uses Three.js in `packages/stage-ui-three`. Live2D uses Pixi and Cubism in `packages/stage-ui-live2d`. MMD and Spine have their own stage packages. Lip sync maps audio weights onto VRM mouth expressions.

Long-term and short-term memory pages under `packages/stage-pages` show a work-in-progress marker. The Telegram integration stores vector memory in Postgres. `packages/memory-pgvector` is the package for that store.

Extensions use Manifest v2 from `packages/plugin-sdk`. The current host entry is Electron. Integrations in this repo include Discord, Telegram, Minecraft, Twitter, and Satori.

Stage Tamagotchi draws transparent Electron windows. Some of those windows stay above other apps.

## Feature map

| Feature | Current owner | Milestone 1 | Native plan |
| --- | --- | --- | --- |
| Chat text | `core-agent`, stage UI | Streaming text in AppKit | Keep the turn model in later milestones |
| Tool rounds | `core-agent` | Absent | Add after the chat shell is stable |
| OpenAI-compatible chat | `provider-inference` | One streaming client | Point other compatible vendors at the same client |
| Other chat protocols | `provider-inference` | Absent | Add Responses and vendor clients later |
| API key storage | local storage and cloud replica | Keychain and environment | Do not copy keys into git |
| Speech output | provider TTS and Web Speech | `AVSpeechSynthesizer` | Add provider TTS after the Apple voice works |
| Speech input | hearing store | Speech framework | Add Sherpa later for offline models |
| VRM mesh | `stage-ui-three` | Metadata plus a SceneKit placeholder | Load the mesh in milestone 2 |
| Live2D | `stage-ui-live2d` | Absent | Native Cubism first. `WKWebView` only as a bridge |
| MMD and Spine | stage UI packages | Absent | Decide after VRM |
| Memory | stage pages, Telegram, pgvector | Absent | Local store first. Server vectors stay on the server |
| Plugins | `plugin-sdk` | Absent | Native host for Manifest v2 |
| Integrations | `integrations/` | Absent | Port one host at a time |
| Companion window | Electron | Transparent and always on top | Click-through comes later |
| Vision and games | stage modules, integrations | Absent | After the companion can speak |

## Native mapping

Use these Apple APIs for the port:

- AppKit windows, menus, and views for the shell.
- Keychain Services for the API key.
- `URLSession` for provider HTTP.
- `AVSpeechSynthesizer` for speech output.
- Speech framework and `AVAudioEngine` for speech input.
- SceneKit for the milestone 1 character. SceneKit draws with Metal.
- A small glTF header reader for VRM names. The reader is pure Swift.

Do not use SwiftUI for the window shell. A later control can be SwiftUI only when AppKit cannot express it.

Do not use `WKWebView` in milestone 1. If a native Cubism renderer cannot ship, a later milestone can host Live2D in `WKWebView`. That bridge is the last option, not the default.

RealityKit loads USDZ and Reality files. It does not load VRM. Milestone 2 can skin the VRM mesh in SceneKit or Metal. A USDZ conversion is a separate decision.

## Package layout

```text
apps/aori-appkit/
├── Sources/AoriCore/        # Messages, session, SSE, secrets, VRM metadata
├── Sources/AoriProviders/   # OpenAI-compatible client
├── Sources/AoriApp/         # AppKit shell, speech, SceneKit
└── Tests/                   # XCTest for the core modules
```

`Package.swift` compiles `AoriApp` only on macOS. Linux `swift test` builds the core modules. The Xcode project `AoriAppKit.xcodeproj` links those modules into an Aori app target.

## Milestone plan

### Milestone 1, this change

The shell has a menu bar, a main window, and a companion window. The companion window is transparent and can stay above other apps. Chat streams from an OpenAI-compatible endpoint. The key comes from the environment or the Keychain. Speak and Listen call Apple speech APIs. The character view is a SceneKit placeholder. VRM files expose a title and a mesh count.

### Milestone 2, VRM mesh

Read glTF buffers from the VRM file. Skin the mesh with SceneKit or Metal. Move the mouth from speech audio, not from a timer.

### Milestone 3, Live2D

Use a native Cubism renderer if the license and the SDK allow it. If that renderer cannot ship, host the existing Live2D page in `WKWebView`.

### Milestone 4, memory

Store local memory in SQLite. Make sure that server-side pgvector stays behind the API. Do not embed Postgres in the app.

### Milestone 5, plugins

Host Manifest v2 in a native process. Keep the manifest checks. Do not embed Electron.

### Milestone 6, the rest of AIRI

Add vision, games, character cards, cloud provider sync, and the remaining chat protocols. Port integrations one at a time. These features exist in Project AIRI today.

## What this checkout did not run

The work ran on Linux. `swift test` passed for `AoriCore` and `AoriProviders` with Swift 6.0.3. The AppKit target was not compiled here. The windows were not opened. Speech, Keychain, and SceneKit were not executed. macOS CI is the compile and bundle step.

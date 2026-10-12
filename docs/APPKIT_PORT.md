# Aori AppKit port

Aori is a native macOS app based on Project AIRI. The app lives in `apps/aori-appkit`. It uses Swift and AppKit. Apple Silicon is the first machine target. Intel Macs on macOS 14 can build the same package.

This note maps the current AIRI apps onto Aori.

The verb for this note is "make sure". The noun for saved values is "configuration".

## Product direction

Aori is a desktop AI companion. It is based on Project AIRI. The same kind of product is Animates, from Animation Inc.

The character lives on the desktop. The first window is transparent, draggable, and able to stay above other apps. Later milestones add a real face, audio lip-sync, and richer memory. Chat tools, plugins, and games come after the companion can stay, speak, and remember.

### What Animates is

Animates is a product from Animation Inc. The site calls them AI companions that live on your phone and desktop. The apps are for iPhone, Android, Mac, and Windows. Source: [animates.ai](https://animates.ai/).

The Apple listing says the companions use real-time voice, show an emotional range, and keep memory of the user. It says you can shape the companion. It says the companion keeps learning when the app is closed. Voice and text share one conversation, including a messenger. The Mac build needs macOS 15 and Apple Silicon. Source: [App Store](https://apps.apple.com/us/app/animates-life-companions/id6758621319).

A fan site, not Animation Inc., describes desktop display modes. Those modes include Overlay, which stays above other windows, and Holographic, which hides the monitor background with a black field. The same site says each companion keeps its own memories. It also says custom personality controls are a plan, not a shipped feature. Source: [Companions Fan FAQ](https://companionsfan.cz/en/faq/) and [glossary](https://companionsfan.cz/en/glossary/). This checkout did not launch Animates. Treat the fan notes as secondary.

The official pages do not say that the Mac window is a transparent, click-through pet. Aori takes that desktop behavior from Project AIRI Stage Tamagotchi, not from a verified Animates window.

AniMate at getanimate.app is a different product. It is a VRM desktop pet. This note does not use it as the source for Animates.

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
| Persona | stage prompts | Name and personality in Settings | Richer character cards later |
| Long-term memory | stage pages, Telegram, pgvector | Local notes from "remember that" | Topic recall and companion-written notes later |
| Greeting | companion presence | A local line on launch, then Apple speech | A model-written greeting later |
| Idle motion | character modules | Blink, neck sway, head sway, and eye look | Richer clips later |
| Emotion | VRM expressions | glad, sorry, and wow change blend shapes | Richer expression maps later |
| Lip-sync | audio weights on VRM mouths | Letter visemes on real TTS PCM, scaled by RMS | A phoneme recognizer comes later |
| VRM mesh | `stage-ui-three` | Original CC0 VRM 0 humanoid, loaded from a file | Downloaded characters stay out |
| Live2D | `stage-ui-live2d` | Absent | Native Cubism first. `WKWebView` only as a bridge |
| MMD and Spine | stage UI packages | Absent | Decide after VRM |
| Plugins | `plugin-sdk` | Absent | Native host for Manifest v2 |
| Integrations | `integrations/` | Absent | Port one host at a time |
| Companion window | Electron | Transparent, draggable, always on top, and a status item | Click-through comes later |
| Vision and games | stage modules, integrations | Absent | After the companion can stay and speak |

## Native mapping

Use these Apple APIs for the port:

- AppKit windows, menus, a status item, and views for the shell.
- Keychain Services for the API key. A locked prompt fails the read.
- `URLSession` for provider HTTP.
- `AVSpeechSynthesizer` for speech output.
- Speech framework and `AVAudioEngine` for speech input.
- Rust `aori-face` for skinning, morphs, and a depth-buffer image.
- GPUI 0.2.2 for a separate character window. The crate is Apache-2.0.
- A small glTF header reader for VRM names. The reader is pure Swift. The Rust crate reads the same sample file.

Do not use SwiftUI for the window shell. A later control can be SwiftUI only when AppKit cannot express it.

Do not use SceneKit. AppKit blits the raster from `aori-face`.

Zig is not a dependency. The mesh routine is small, so it lives in Rust. Add Zig when a routine is smaller there than in Rust.

GPUI 0.2.2 owns its run loop. Zed pull request 63077 adds an embedded macOS loop. That pull request is not merged. This tree does not depend on it. The GPUI binary is a second window. The AppKit app does not host it.

`xattr` 0.2.3 does not build with libc 0.2.190 on Linux. A patched copy in `rust/patches/xattr` uses `ENODATA` for that name. Delete the copy when GPUI depends on a fixed release.

Do not use `WKWebView` in milestone 1. If a native Cubism renderer cannot ship, a later milestone can host Live2D in `WKWebView`. That bridge is the last option, not the default.

RealityKit loads USDZ and Reality files. It does not load VRM. A USDZ conversion is a separate decision.

## Package layout

```text
apps/aori-appkit/
├── Sources/AoriCore/        # Messages, session, SSE, secrets, VRM bytes
├── Sources/AoriProviders/   # OpenAI-compatible client
├── Sources/AoriApp/         # AppKit shell, speech, raster blit
├── rust/aori-face/          # Skin, depth raster, and the sample glTF read
├── rust/aori-gpui/          # Separate GPUI window for the same head
└── Tests/                   # XCTest for the core modules
```

`Package.swift` compiles `AoriApp` only on macOS. Linux `swift test` builds the core modules. The Xcode project `AoriAppKit.xcodeproj` links those modules into an Aori app target.

## Milestone plan

### Milestone 1, this change

The companion window is transparent, draggable, and able to stay above other apps. Settings stores a name and a personality. Those lines become the system prompt. A JSON file stores facts from "remember that". Launch shows a local greeting and speaks it. The greeting does not call the provider. The placeholder blinks and sways while idle. The words glad, sorry, and wow change the face. The mouth moves on a timer while speech is active. That timer is not lip-sync from audio samples. Chat still streams from an OpenAI-compatible endpoint. The key comes from the environment or the Keychain. VRM files expose a title and a mesh count. The mesh is still the placeholder.

### Milestone 2, this change

The sample file is an original CC0 VRM 0 humanoid. It is not a downloaded character. Bones are hips, spine, neck, head, leftEye, and rightEye. Skin weights use unsigned bytes. The idle clip sways the neck and the head, and it turns the eyes. A blink clip targets the eye bones. See `Resources/LICENSE.txt`.

`aori-face` applies morphs, skins those bones, and fills a depth buffer. AppKit blits that image. `AORI_VRM_PATH` loads that file with `VRMSceneReader`, the same reader as Open VRM.

Letters map to VRM presets a, i, u, e, and o. The letters m, b, and p close the mouth. Playback time advances the preset at about 12 characters per second. `willSpeakRangeOfSpeechString` wins when it fires. RMS still scales the open vowel. This is not a phoneme recognizer.

`AORI_SPEECH_WAV` stores the PCM that `AVSpeechSynthesizer.write` returned. The macOS job checks that the WAV is not silent and that the viseme log has more than one preset. This checkout did not play that audio.

Chat text is stored in `chat.json`. The base URL and the model are stored in `settings.json`. English menu strings come from `packages/i18n/src/locales/en/aori.yaml`. Other locales are not loaded.

A debug build rendered 20 frames at 280 by 380. The median was 2.70 ms. The max was 2.80 ms. The test fails when the median is 33 ms or more.

A status item lists the companion, the main window, Settings, and Quit. Those titles come from the English yaml when the file loads.

The GPUI binary still paints flat triangles. It uses a fixed mouth weight of 0.65. It does not hear TTS buffers. This checkout did not open that window.

`AORI_SCREENSHOT=1` still writes a framebuffer PNG, then speaks "Hello papa" and records that PCM. Run 38269452282 captured the earlier window. The new WAV check does not have a run id yet.

### Milestone 2 follow-up

Keep a voice turn going without a separate Speak press. Add click-through on the companion window.

### Milestone 3, memory that lasts

Keep the milestone 1 notes. Add recall by topic. Add notes the companion writes after a talk. Make sure that server-side pgvector stays behind the API. Do not embed Postgres in the app.

### Milestone 4, Live2D

Use a native Cubism renderer if the license and the SDK allow it. If that renderer cannot ship, host the existing Live2D page in `WKWebView`.

### Milestone 5, plugins

Host Manifest v2 in a native process. Keep the manifest checks. Do not embed Electron.

### Milestone 6, the rest of AIRI

Add vision, games, character cards, cloud provider sync, and the remaining chat protocols. Port integrations one at a time. These features exist in Project AIRI today.

## What this checkout did not run

The work ran on Linux. `swift test` passed 33 tests with 0 failures on Swift 6.0.3. `cargo test -p aori-face` passed 9 tests with Rust 1.99.0. A debug build rendered the 280 by 380 frame in 2.75 ms. `cargo check -p aori-gpui` passed. This checkout did not launch the app. Speech playback, Keychain, and the GPUI window were not executed. Run 38269452282 launched `AoriApp` on `macos-latest` and saved both PNGs.

The macOS job on 2026-10-12 failed before the mesh change. `Synchronization.Mutex` needs macOS 15. The deployment target is macOS 14. The name `SpeechTranscriber` also clashes with an Apple class. This change replaces both. Run 38262709300 then passed `swift test` and `swift build --product AoriApp` on `macos-latest`. The app was not launched.

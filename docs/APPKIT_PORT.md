# Aori AppKit port

Aori is a native macOS app based on Project AIRI. The app lives in `apps/aori-appkit`. It uses Swift and AppKit. Apple Silicon is the first machine target. Intel Macs on macOS 14 can build the same package.

This note maps the current AIRI apps onto Aori.

The verb for this note is "make sure". The noun for saved values is "configuration".

## Product direction

Aori is a desktop AI companion. It is based on Project AIRI. The same kind of product is Animates, from Animation Inc.

The character lives on the desktop. The first window is transparent, draggable, and able to stay above other apps. Later milestones add a real face, audio lip-sync, and richer memory. Chat tools and games come after the companion can stay, speak, and remember.

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
| Long-term memory | stage pages, Telegram, pgvector | SQLite cosine recall | pgvector stays out. The local file is converted MiniLM |
| Greeting | companion presence | A local line on launch, then Apple speech | A model-written greeting later |
| Idle motion | character modules | Blink, neck sway, head sway, and eye look | Richer clips later |
| Emotion | VRM expressions | glad, sorry, and wow change blend shapes | Richer expression maps later |
| Lip-sync | audio weights on VRM mouths | Letter visemes on real TTS PCM, scaled by RMS | A phoneme recognizer comes later |
| VRM mesh | `stage-ui-three` | Original CC0 VRM 0 humanoid, loaded from a file | Downloaded characters stay out |
| Live2D | `stage-ui-live2d` | Flat layers | Live2D parameter ids and motion3.json curves. Not Cubism moc3 |
| MMD and Spine | stage UI packages | Absent | Decide after VRM |
| Plugins | `plugin-sdk` | Manifest v2 host and one JavaScriptCore script | The grant is `aori.companion.*`. A `.mjs` file is rejected |
| Integrations | `integrations/` | Absent | Port one host at a time |
| Companion window | Electron | Transparent, draggable, always on top, and a status item | Click-through comes later |
| Vision and games | stage modules, integrations | Opt-in ticker with a rate limit | Games stay absent |

## Native mapping

Use these Apple APIs for the port:

- AppKit windows, menus, a status item, and views for the shell.
- Keychain Services for the API key. A locked prompt fails the read.
- `URLSession` for provider HTTP.
- `AVSpeechSynthesizer` for speech output.
- Speech framework and `AVAudioEngine` for speech input.
- ScreenCaptureKit for one display frame. The screenshot path does not present the permission dialog.
- Rust `aori-face` for skinning, morphs, a depth-buffer image, and flat layers.
- GPUI 0.2.2 for a separate character window. The crate is Apache-2.0.
- A small glTF header reader for VRM names. The reader is pure Swift. The Rust crate reads the same sample file.

Do not use SwiftUI for the window shell. A later control can be SwiftUI only when AppKit cannot express it.

`AoriSceneKit` is a macOS tool. It builds SceneKit meshes from `VRMSceneReader`. The camera frames the head and shoulders and sits on the front of the model. `VRMAvatarPose` sets the mouth morph. Reply text sets happy, sad, or surprised. Butter has no joy blend shape. The pose uses a vowel or blink shape as a stand-in. Materials sample the color texture. AppKit still blits the `aori-face` raster in the companion window.

Zig is not a dependency. The mesh routine is small, so it lives in Rust. Add Zig when a routine is smaller there than in Rust.

GPUI 0.2.2 owns its run loop. Zed pull request 63077 adds an embedded macOS loop. That pull request is not merged. This tree does not depend on it. The GPUI binary is a second window. The AppKit app does not host it.

`xattr` 0.2.3 does not build with libc 0.2.190 on Linux. A patched copy in `rust/patches/xattr` uses `ENODATA` for that name. Delete the copy when GPUI depends on a fixed release.

Do not use `WKWebView` in milestone 1. If a native Cubism renderer cannot ship, a later milestone can host Live2D in `WKWebView`. That bridge is the last option, not the default.

RealityKit loads USDZ and Reality files. It does not load VRM. The VRM portrait uses SceneKit.

## Package layout

```text
apps/aori-appkit/
├── Sources/AoriCore/        # Messages, session, SSE, secrets, VRM bytes
├── Sources/AoriProviders/   # OpenAI-compatible client
├── Sources/AoriApp/         # AppKit shell, speech, raster blit
├── rust/aori-face/          # Skin, depth raster, and the sample glTF read
├── Sources/AoriSceneKit/    # SceneKit VRM portrait (macOS only)
├── rust/aori-gpui/          # Separate GPUI window for the same head
├── plugins/aori-greeting/   # Sample Manifest v2 command list
└── Tests/                   # XCTest for the core modules
```

`Package.swift` compiles `AoriApp` only on macOS. Linux `swift test` builds the core modules. The Xcode project `AoriAppKit.xcodeproj` links those modules into an Aori app target.

## Milestone plan

### Milestone 1, this change

The companion window is transparent, draggable, and able to stay above other apps. Settings lists scene, providers, modules, the character card, memory, data, connection, models, and system. The editable fields are a name, a personality, one provider, a voice, a model, and saved facts. The name and the personality become the system prompt. The provider list has one entry. Saved facts live in `companion.sqlite`. Launch shows a local greeting and speaks it. The greeting does not call the provider. The placeholder blinks and sways while idle. The words glad, sorry, and wow change the face. The mouth moves on a timer while speech is active. That timer is not lip-sync from audio samples. Chat still streams from an OpenAI-compatible endpoint. The key comes from the environment or the Keychain. VRM files expose a title and a mesh count. The mesh is still the placeholder.

### Milestone 2, this change

The sample file is Butter, a VRM 0 humanoid by Polygonal Mind. The license is CC0. The source is the 100 Avatars repository. The file includes a color texture. The license text is in `Resources/LICENSE.txt`.

The file has blink and vowel blend shapes. It has no eye bones and no idle clip.

`aori-face` applies morphs, skins those bones, skins the normals, and fills a depth buffer. A directional light shades each pixel. AppKit blits that image. `AORI_VRM_PATH` loads that file with `VRMSceneReader`, the same reader as Open VRM.

Mouth presets come from the TTS buffer. Each 20 ms window uses RMS and the zero-crossing rate. A quiet window is silence. A soft flat window is a closure. A loud low rate is an open vowel.

`AORI_MIC_WAV` feeds one recorded WAV through the same speech mark as the microphone. A loud file marks speech. A quiet file marks silence.

`AORI_SPEECH_WAV` stores the PCM that `AVSpeechSynthesizer.write` returned. The macOS job checks that the WAV is not silent and that the viseme log has more than one preset. This checkout did not play that audio.

Chat, provider settings, the persona, and the locale id are stored in `companion.sqlite`. The first open copies `chat.json`, `settings.json`, `companion.json`, and `locale.json` when those tables are empty. SwiftData does not run in Linux `swift test`.

A search field matches chat lines and memory notes by words. All nine directories under `packages/i18n/src/locales` have Aori menu keys. The View menu lists the locale ids. A failed stream retries once before any text arrives. After a text delta, it does not retry. The status line says "Trying again." during that retry.

A debug build rendered 20 frames at 280 by 380. The median was 3.30 ms. The max was 3.56 ms. The test fails when the median is 33 ms or more. `AoriLog.frame` writes a JSON line with the event name and the frame time.

A status item lists the companion, the main window, Settings, and Quit. Those titles come from the English yaml when the file loads.

When `AORI_GPUI_PNG` is set, the GPUI binary writes one lit raster and exits. Set `AORI_GPUI_EXIT_MS` to open the window titled Aori GPUI and quit after that many milliseconds. The interactive window paints that same raster. It does not hear TTS buffers. SceneKit samples the color texture on that file. The camera now frames the head and shoulders. Run 38369523526 saved the older frame. That frame shows the upper body. It does not show a clear face.

`scripts/capture-gpui-window.sh` runs `AoriSceneKit` and writes `build/aori-gpui-window.png`. The portrait time is 1.6 seconds. The mouth morph is open. Blink is off at that time. This checkout did not run that tool.

`AORI_SCREENSHOT=1` writes a framebuffer PNG, then speaks "Hello papa" and records that PCM. The job runs voice activity on that WAV. When Speech permission is missing, it runs whisper.cpp on that WAV. An empty transcript does not invent text. A non-empty transcript goes to chat. An empty API key, or the model name local, uses a local template and logs `aori_llm=local`. A key with any other model calls the provider and logs `aori_llm=sent` and `aori_llm_reply`.

The screenshot script starts a mock server on 127.0.0.1 port 8765. It sets the key, the base URL, and the model name mock. The mock returns the text Mock reply from CI.

The screenshot path posts one click through the companion window. A window titled Aori Behind counts that click. The log says delivered only when that window receives the click. Clear pixels set `ignoresMouseEvents`. Opaque pixels and the caption keep the click. The job also probes the microphone and a Keychain probe account. A short capture logs `aori_mic_utterance` as no-device, silence, or speech.

The same path reads live accessibility labels and logs `aori_ax`. It presses the Send message control and logs `aori_ax_press`. After the captures, the script tries to start VoiceOver and logs running or unavailable.

Run 38282943123 was the earlier capture. It used the local reply Hello. I am here. It did not post a click, open the GPUI window, start VoiceOver, or call the mock server.

Run 38290795770 is the earlier capture for the posted click and the mock reply. Run 38293603474 drew the flat character, and the companion window in that run was upside down.

Run 38295099387 is the capture for the flat character. `AORI_AVATAR` is `live2d`. The framebuffer and the companion window both show the hair above the blue body. The framebuffer mouth is open. The window mouth is a line after the spoken turn. The log says `aori_avatar=live2d` and `aori_frame_ms=8.08`.

The log also says `aori_click_through=delivered`, `aori_llm_reply=Mock reply from CI.`, `aori_keychain=roundtrip`, `aori_locale_menu=loaded`, `aori_hit_corner=pass`, and `aori_hit_body=keep`. The microphone mark is `silence`. The VoiceOver process was running. The product notes are in `docs/AORI_PRODUCT.md`. The module map is in `docs/AORI_ARCHITECTURE.md`.

### Milestone 2 follow-up

A spoken microphone utterance is still open. Run 38359815442 logged `aori_caption=Mock reply from CI.`. VoiceOver starts after the app exits. Cubism moc3 stays in a later milestone.

The assembled app is sandboxed. The entitlements are the app sandbox, outgoing network, the microphone, user-selected files, and app-scoped bookmarks. Screen capture has no sandbox entitlement. ScreenCaptureKit uses the screen recording permission. The signed copy has no checkout path exception.

Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_bookmark=ok`. CI still stages files in the app container. The same run logged `aori_window_mouth=open`. The companion window mouth is open. A Developer ID profile is absent.

### Milestone 3, memory that lasts

Keep the milestone 1 notes. Add recall by topic. Add notes the companion writes after a talk. Make sure that server-side pgvector stays behind the API. Do not embed Postgres in the app.

### Milestone 4, Live2D

When `AORI_AVATAR` is `live2d`, the companion window draws flat layers. The parameters use Live2D ids. Rust samples motion3.json curves. The art is original. `WKWebView` stays out.

The Live2D Cubism Core library is proprietary. Live2D does not publish that library on GitHub (https://docs.live2d.com/en/cubism-sdk-manual/cubism-core/). This repository uses the MIT license. The proprietary terms block Core code under that license (https://www.live2d.com/eula/live2d-proprietary-software-license-agreement_en.html). This checkout does not add Cubism Core. The flat native rig stays.

### Milestone 5, plugins

The native host reads `extension.airi.json`. Unknown fields fail. The id, the version, and the AIRI range use the Manifest v2 checks. `AORI_PLUGINS` selects the directory. The host grant is `aori.companion.*` with action snapshot. The sample `plugins/aori-greeting` asks for that greeting and for `aori.files.read`.

The greeting returns `Plugin greeting.`. The file call is denied. The entrypoint must stay inside the plugin directory.

A `.js` file runs in JavaScriptCore. The script can call `aori.call`. A call outside the grant returns denied. A `.mjs` or `.cjs` file is rejected. The host does not embed Electron. This grant is not the macOS App Sandbox.

Run 38355635403 logged `aori_plugin_js=greeting=Plugin greeting. files=denied`.

### Milestone 6, screen vision ticker

The ticker is off until `AORI_VISION_TICKER` is `1`. The interval is at least 1000 ms. The maximum tick count is 8. The companion window shows an orange Vision badge while the ticker is on. A denied capture still uses `AORI_VISION_PNG`. The screenshot path does not call `CGRequestScreenCaptureAccess`.

Run 38355635403 logged `aori_vision_ticker=on`, two screen ticks, and `aori_vision_ticker=stopped`. The interval was 1000 ms. The maximum was 2. The mock reply was `Mock vision from CI.`. That mock does not read the pixels.

### Milestone 7, embeddings memory

`EmbeddingMemoryStore` keeps notes and vectors in SQLite. Recall uses cosine similarity. The closest notes enter the chat system prompt. The Memory window lists the notes and can delete one. When a key is set, the app calls the embeddings endpoint. A failed call uses `aori-minilm.mlmodel`.

That file is a Core ML conversion of all-MiniLM-L6-v2. The license is Apache-2.0. The word hash stays in the cosine test and in the CI mock. The app fallback does not call the hash.

Run 38359062380 logged `aori_embed_recall=tea`. `tea please` is closer to `I like tea` than to `The cat is orange`. The Memory window then showed `The cat is orange` after the delete.

### Milestone 8, the rest of AIRI

Add games, character cards, cloud provider sync, and the remaining chat protocols. Port integrations one at a time. These features exist in Project AIRI today.

## What this checkout did not run

Run 38355635403 passed 70 Linux tests and 71 macOS tests. `cargo test -p aori-face` passed 18 tests. The macOS job launched the sandboxed app. This Linux machine did not launch the Mac app.

`AORI_GPUI_PNG` wrote a lit PNG on this machine in an earlier session. This checkout did not launch the Mac app. Run 38290795770 launched `AoriApp` on `macos-latest`, posted the click, called the mock, and opened the GPUI window. The Linux job in that run passed 49 tests and saved the GPUI PNG.

The macOS job on 2026-10-12 failed before the mesh change. `Synchronization.Mutex` needs macOS 15. The deployment target is macOS 14. The name `SpeechTranscriber` also clashes with an Apple class. This change replaces both. Run 38262709300 then passed `swift test` and `swift build --product AoriApp` on `macos-latest`. The app was not launched.

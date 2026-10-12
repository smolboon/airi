# Aori AppKit audit

Audit date: 2026-10-12. Scope: `apps/aori-appkit` milestones 1 and 2, and `docs/APPKIT_PORT.md`. Aori is the native app. Project AIRI is the upstream product.

Scores use 0 to 5.

- 0 means absent.
- 1 means started.
- 2 means partial.
- 3 means usable, with known gaps.
- 4 means strong for this milestone.
- 5 means complete for the whole upstream AIRI product.

The scores judge the native port, not the Vue apps. The long-term aim is above 4.5 in every area. This file does not use a 10-point scale.

## Scores

| Area | Score | Evidence |
| --- | --- | --- |
| Product scope and feature parity | 3 | The app has a desktop companion, a persona, local memory notes, a greeting, chat, and a CC0 head with a neck bone, a texture, blink, and audio-level lip-sync. Tool rounds, plugins, Live2D, vision, and games are absent. |
| Architecture and module boundaries | 3 | `AoriCore` and `AoriProviders` do not import AppKit. `Package.swift` adds `AoriApp` only on macOS. `aori-face` is Rust and has no AppKit. `ChatViewModel` owns the send state. |
| Platform integration | 3 | AppKit, a status item, Keychain, Speech, and AVFoundation are in `Sources/AoriApp`. The raster is a Rust static library. GPUI is a second binary. Run 38269452282 launched `AoriApp` on `macos-latest`. This checkout did not open the microphone, the Keychain, or the GPUI window. |
| User interface and interaction | 3 | Run 38269452282 captured the companion window. The image is 280 by 380. Corner alpha is 0. The caption reads "Aori Sample". The status item and the chat window are not in that image. |
| Graphics and character rendering | 4 | `aori-face` skins the neck, samples the PNG, and keeps the nearer fragment. Tests cover bind pose, the idle clip, blink, mouth, and depth. The framebuffer center pixel is the blush color (205, 50, 83). Two dark eyes sit on the head. There is no Live2D view and no `WKWebView`. The GPUI binary still paints flat triangles. The rig is one neck bone. |
| Audio, speech input, and speech output | 2 | `AVSpeechSynthesizer.write` feeds PCM into `SpeechLevel`. The raster uses that mouth weight. Screenshot mode uses the same `SpeechLevel` helper on a synthetic buffer. No test on this machine can play audio or open a microphone. |
| Networking and model providers | 3 | `OpenAICompatibleClient` parses streamed chat completions. Tests use a scripted transport. There is no live network call. Linux `URLSession` buffers the body. See the NOTICE in `http-transport.swift`. |
| Security, secrets, and privacy | 3 | Key order is explicit, then `AORI_OPENAI_API_KEY`, then `OPENAI_API_KEY`, then Keychain. A Keychain read fails instead of showing a prompt. `SecretRedaction` strips the key from error text. No key is committed. The Keychain code was not executed here. The app is not sandboxed. |
| Data persistence | 2 | UserDefaults stores the base URL and the model. The Keychain stores the key. `companion.json` stores the persona and memory notes. Chat text is lost when the process ends. There is no topic search. |
| Error handling and recovery | 3 | `ChatProviderError` covers a missing key, HTTP status, and a bad event. A failed stream keeps partial text. The client does not retry. `core-agent` retries some HTTP statuses. This client does not. |
| Testing | 4 | XCTest covers SSE, UTF-8 splits, key order, the sample VRM, the rig markers, blend-shape weights, speech RMS, reduced motion, the copy table, the chat model, persona, memory, and the provider client. `swift test` on Linux Swift 6.0.3 ran 33 tests with 0 failures. `cargo test -p aori-face` ran 9 tests with 0 failures. Run 38269452282 captured the companion window. There is no speech playback test. |
| Continuous integration and build | 4 | `.github/workflows/aori-appkit.yml` runs `swift test`, `cargo test -p aori-face`, and `cargo check -p aori-gpui` on `ubuntu-latest`. On `macos-latest` it builds the app, launches it with `AORI_SCREENSHOT=1`, and uploads both PNGs. Run 38269452282 passed both jobs. The Xcode project is not the CI build. |
| Documentation | 4 | `docs/APPKIT_PORT.md`, this file, and `apps/aori-appkit/README.md` match the tree. They name the CC0 rig, the depth buffer, and the Linux limit. |
| Accessibility | 3 | Send, Speak, Listen, the draft field, and the transcript have accessibility labels. The status item has an accessibility description. Reduced motion holds the neck clip and the blink. There was no VoiceOver pass. |
| Internationalization | 1 | `AoriCopy` holds the English menu and status titles. `packages/i18n` is not wired in. No other locale is in the table. |
| Performance and operability | 2 | A debug build rendered the 280 by 380 frame in 2.75 ms. The test fails when that render takes 200 ms or more. The macOS transport yields 512-byte chunks. The Linux transport waits for the full body. There is no log pipeline. |

## What works in code

- A menu bar and a status item for chat, VRM open, Settings, and the companion.
- A main window with the character and the transcript.
- A borderless companion window. The standard policy is transparent, floating, draggable, and visible on all spaces.
- A name and a personality in Settings. They become the system prompt.
- Local memory notes from "remember that", stored in `companion.json`.
- A local launch greeting. The app then speaks that line. The greeting does not call the provider.
- Idle blink and a neck clip, plus keyword faces for glad, sorry, and wow.
- Streaming OpenAI-compatible chat, including split SSE events.
- API keys from the environment or `KeychainSecretStore`. Error text redacts the key.
- Speech buttons that call `AVSpeechSynthesizer` and `SFSpeechRecognizer`.
- A CC0 VRM head with a neck bone, UVs, and a PNG texture. Rust skins it and fills a depth buffer. AppKit blits that image.
- Mouth motion from the RMS of TTS PCM buffers, in the same process as the window. Playback was not run here.
- VRM 0 and VRM 1 name parsing, plus mesh bytes from the sample file.

## What is stubbed

- Bones beyond the single neck joint. The sample is still a low-poly head.
- Phoneme visemes. The mouth uses audio level, not a viseme map.
- Model-written greetings, topic recall, and notes the companion writes.
- Live2D, MMD, and Spine.
- Provider TTS, Sherpa, and every chat protocol except chat completions.
- Tool calls, plugins, and the integrations.
- Chat history on disk.
- Click-through on the companion window.
- Retries, cloud key sync, and a sandbox.

## What this session ran

Command: `swift test` in `apps/aori-appkit`.

Result: 33 tests passed, 0 failures, Swift 6.0.3 on `x86_64-unknown-linux-gnu`.

This session ran `cargo test -p aori-face` and `cargo check -p aori-gpui` with Rust 1.99.0. Both passed. The face crate ran 9 tests. A debug render of the 280 by 380 frame took 2.75 ms. `swift test` passed 33 tests. Run 38269452282 launched `AoriApp` on `macos-latest` and uploaded both PNGs. The framebuffer is 280 by 380. Its corners are clear. Its center pixel is (205, 50, 83, 255). The window PNG shows the same head and the caption. This session did not run `xcodebuild`. It did not launch the app on this machine.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. Milestone 2 follow-up is phoneme visemes and more bones. Milestone 3 is richer memory. Milestone 4 is Live2D. Milestone 5 is a native plugin host.

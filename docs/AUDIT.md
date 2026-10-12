# Aori AppKit audit

Audit date: 2026-10-12. Scope: `apps/aori-appkit` milestones 1 and 2, and `docs/APPKIT_PORT.md`. Aori is the native app. Project AIRI is the upstream product.

Scores use 0 to 5.

- 0 means absent.
- 1 means started.
- 2 means partial.
- 3 means usable, with known gaps.
- 4 means strong for this milestone.
- 5 means complete for the whole upstream AIRI product.

The scores judge the native port, not the Vue apps.

## Scores

| Area | Score | Evidence |
| --- | --- | --- |
| Product scope and feature parity | 2 | The app has a desktop companion, a persona, local memory notes, a greeting, a CC0 VRM head, audio-level lip-sync, and emotion blend shapes. The head has no bones and no texture. Tool rounds, plugins, Live2D, vision, and games are absent. |
| Architecture and module boundaries | 3 | `AoriCore` and `AoriProviders` do not import AppKit. `Package.swift` adds `AoriApp` only on macOS. `aori-face` is Rust and has no AppKit. `ChatViewModel` owns the send state. |
| Platform integration | 2 | AppKit, Keychain, Speech, and AVFoundation are in `Sources/AoriApp`. The mesh deformer is a Rust static library. GPUI is a second binary. This checkout did not launch the app, the microphone, the Keychain, or the GPUI window. |
| User interface and interaction | 2 | The menu, main window, companion window, and Settings window are coded. No window was opened here. There is no screenshot. |
| Graphics and character rendering | 2 | AppKit fills projected triangles. `aori-face` applies morph deltas. `aori-gpui` typechecks and paints the same CC0 head. There is no depth buffer, no bones, and no texture. No window was opened here. There is no Live2D view and no `WKWebView`. |
| Audio, speech input, and speech output | 2 | `AVSpeechSynthesizer.write` feeds PCM into `SpeechLevel`. The A blend shape uses that level. No test on this machine can play audio or open a microphone. |
| Networking and model providers | 3 | `OpenAICompatibleClient` parses streamed chat completions. Tests use a scripted transport. There is no live network call. Linux `URLSession` buffers the body. See the NOTICE in `http-transport.swift`. |
| Security, secrets, and privacy | 3 | Key order is explicit, then `AORI_OPENAI_API_KEY`, then `OPENAI_API_KEY`, then Keychain. `SecretRedaction` strips the key from error text. No key is committed. The Keychain code was not executed here. The app is not sandboxed. |
| Data persistence | 2 | UserDefaults stores the base URL and the model. The Keychain stores the key. `companion.json` stores the persona and memory notes. Chat text is lost when the process ends. There is no topic search. |
| Error handling and recovery | 3 | `ChatProviderError` covers a missing key, HTTP status, and a bad event. A failed stream keeps partial text. The client does not retry. `core-agent` retries some HTTP statuses. This client does not. |
| Testing | 3 | XCTest covers SSE, UTF-8 splits, key order, the sample VRM mesh, blend-shape weights, speech RMS, the chat model, persona, memory, and the provider client. `swift test` on Linux Swift 6.0.3 ran 33 tests with 0 failures. `cargo test -p aori-face` ran 4 tests with 0 failures. There is no UI test and no speech playback test. |
| Continuous integration and build | 2 | `.github/workflows/aori-appkit.yml` runs `swift test`, `cargo test -p aori-face`, and `cargo check -p aori-gpui` on `ubuntu-latest`. On `macos-latest` it also builds `AoriApp` after the Rust library. This session ran the Linux cargo commands. A macOS run of this link is not recorded yet. The Xcode project is not the CI build. |
| Documentation | 4 | `docs/APPKIT_PORT.md`, this file, and `apps/aori-appkit/README.md` match the tree. They name the CC0 head, the bind pose, and the Linux limit. |
| Accessibility | 2 | Send, Speak, Listen, the draft field, and the transcript have accessibility labels. System colors are used. There was no VoiceOver pass. The mouth timer ignores reduced motion. |
| Internationalization | 0 | The new strings are English only. `packages/i18n` is not wired in. |
| Performance and operability | 1 | There is no measurement. The macOS transport yields 512-byte chunks. The Linux transport waits for the full body. There is no log pipeline. |

## What works in code

- A menu bar with chat, VRM open, Settings, and companion commands.
- A main window with the character and the transcript.
- A borderless companion window. The standard policy is transparent, floating, draggable, and visible on all spaces.
- A name and a personality in Settings. They become the system prompt.
- Local memory notes from "remember that", stored in `companion.json`.
- A local launch greeting. The app then speaks that line. The greeting does not call the provider.
- Idle blink and sway, and keyword faces for glad, sorry, and wow.
- Streaming OpenAI-compatible chat, including split SSE events.
- API keys from the environment or `KeychainSecretStore`. Error text redacts the key.
- Speech buttons that call `AVSpeechSynthesizer` and `SFSpeechRecognizer`.
- A CC0 VRM head. AppKit fills projected triangles. Rust applies the morph deltas.
- Mouth motion from the RMS of TTS PCM buffers, in code. Playback was not run here.
- VRM 0 and VRM 1 name parsing, plus mesh bytes from the sample file.

## What is stubbed

- Bone animation and textures. The sample head is a flat-color bind pose.
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

This session ran `cargo test -p aori-face` and `cargo check -p aori-gpui` with Rust 1.99.0. Both passed. This session did not run `swift build --product AoriApp` on Linux. This session did not run `xcodebuild`, the GPUI window, or the app.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. Milestone 2 follow-up is bones, textures, and phoneme visemes. Milestone 3 is richer memory. Milestone 4 is Live2D. Milestone 5 is a native plugin host.

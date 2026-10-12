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
| Product scope and feature parity | 3 | The app has a desktop companion, a persona, local memory notes, a greeting, saved chat, and a CC0 humanoid with visemes. Tool rounds, plugins, Live2D, vision, and games are absent. |
| Architecture and module boundaries | 3 | `AoriCore` and `AoriProviders` do not import AppKit. `Package.swift` adds `AoriApp` only on macOS. `aori-face` is Rust and has no AppKit. `ChatViewModel` owns the send state. |
| Platform integration | 3 | AppKit, a status item, Keychain, Speech, and AVFoundation are in `Sources/AoriApp`. The raster is a Rust static library. GPUI is a second binary. Run 38269452282 launched `AoriApp` on `macos-latest`. This checkout did not open the microphone, the Keychain, or the GPUI window. |
| User interface and interaction | 3 | Run 38269452282 captured the companion window. The image is 280 by 380. Corner alpha is 0. The caption reads "Aori Sample". The status item and the chat window are not in that image. |
| Graphics and character rendering | 4 | `aori-face` skins hips, spine, neck, head, and both eyes. Tests keep the bind pose and move the head, the eyes, and the blink bone. The sample is an original CC0 VRM 0 file. There is no Live2D view. The GPUI binary still paints flat triangles. |
| Audio, speech input, and speech output | 2 | Letters map to presets a, i, u, e, o, and a closed mouth. The macOS job records PCM from `AVSpeechSynthesizer.write` and checks the WAV. This session did not play audio or open a microphone. The score stays here until that WAV is inspected. |
| Networking and model providers | 3 | `OpenAICompatibleClient` parses streamed chat completions. Tests use a scripted transport. There is no live network call. Linux `URLSession` buffers the body. See the NOTICE in `http-transport.swift`. |
| Security, secrets, and privacy | 3 | Key order is explicit, then `AORI_OPENAI_API_KEY`, then `OPENAI_API_KEY`, then Keychain. A Keychain read fails instead of showing a prompt. `SecretRedaction` strips the key from error text. No key is committed. The Keychain code was not executed here. The app is not sandboxed. |
| Data persistence | 3 | `chat.json` stores the transcript. `settings.json` stores the base URL and the model. `companion.json` stores the persona and memory notes. Linux tests round-trip the chat and the settings file. There is no topic search. |
| Error handling and recovery | 3 | `ChatProviderError` covers a missing key, HTTP status, and a bad event. A failed stream keeps partial text. The client does not retry. `core-agent` retries some HTTP statuses. This client does not. |
| Testing | 4 | XCTest covers the humanoid bones, visemes, the WAV header, chat files, settings files, and the English menu yaml. `swift test` on Linux Swift 6.0.3 ran 36 tests with 0 failures. `cargo test -p aori-face` ran 9 tests with 0 failures. There is no speech playback test on this machine. |
| Continuous integration and build | 4 | `.github/workflows/aori-appkit.yml` runs `swift test`, `cargo test -p aori-face`, and `cargo check -p aori-gpui` on `ubuntu-latest`. On `macos-latest` it builds the app, launches it with `AORI_SCREENSHOT=1`, and uploads both PNGs. Run 38269452282 passed both jobs. The Xcode project is not the CI build. |
| Documentation | 4 | `docs/APPKIT_PORT.md`, this file, and `apps/aori-appkit/README.md` match the tree. They name the CC0 rig, the depth buffer, and the Linux limit. |
| Accessibility | 3 | Send, Speak, Listen, the draft field, and the transcript have accessibility labels. The status item has an accessibility description. Reduced motion holds the neck clip and the blink. There was no VoiceOver pass. |
| Internationalization | 2 | English menu strings come from `packages/i18n/src/locales/en/aori.yaml`. A test checks `menu.showCompanion`. The app loads that file before it builds the menu. Other locales are not loaded. |
| Performance and operability | 3 | A debug build rendered 20 frames at 280 by 380. The median was 2.70 ms. The max was 2.80 ms. The test fails when the median is 33 ms or more. Sample load took 1.78 ms. There is no log pipeline. |

## What works in code

- A menu bar and a status item for chat, VRM open, Settings, and the companion.
- A main window with the character and the transcript.
- A borderless companion window. The standard policy is transparent, floating, draggable, and visible on all spaces.
- A name and a personality in Settings. They become the system prompt.
- Local memory notes from "remember that", stored in `companion.json`.
- A local launch greeting. The app then speaks that line. The greeting does not call the provider.
- Idle blink, neck sway, head sway, and an eye look. Keyword faces for glad, sorry, and wow.
- Streaming OpenAI-compatible chat, including split SSE events.
- API keys from the environment or `KeychainSecretStore`. Error text redacts the key.
- Speech buttons that call `AVSpeechSynthesizer` and `SFSpeechRecognizer`.
- An original CC0 VRM 0 humanoid. Bones are hips, spine, neck, head, leftEye, and rightEye. Rust skins it and fills a depth buffer. AppKit blits that image. `AORI_VRM_PATH` uses the same reader as Open VRM.
- Letter visemes on TTS PCM. RMS scales the open vowel. Playback was not run on this machine. The macOS job records a WAV.
- VRM 0 and VRM 1 name parsing, plus mesh bytes from the sample file.

## What is stubbed

- A phoneme recognizer. The viseme map reads letters, not recognized phonemes.
- Downloaded character files. The sample humanoid is original and CC0.
- Model-written greetings, topic recall, and notes the companion writes.
- Live2D, MMD, and Spine.
- Provider TTS, Sherpa, and every chat protocol except chat completions.
- Tool calls, plugins, and the integrations.
- Topic search over saved chat.
- Click-through on the companion window.
- Retries, cloud key sync, and a sandbox.

## What this session ran

Command: `swift test` in `apps/aori-appkit`.

Result: 33 tests passed, 0 failures, Swift 6.0.3 on `x86_64-unknown-linux-gnu`.

This session ran `cargo test -p aori-face` and `cargo check -p aori-gpui` with Rust 1.99.0. Both passed. The face crate ran 9 tests. Twenty debug frames at 280 by 380 had a median of 2.70 ms and a max of 2.80 ms. Sample load took 1.78 ms. `swift test` passed 36 tests. Run 38269452282 launched the earlier `AoriApp` build. The new WAV, viseme log, and `aori_frame_ms` line do not have a run id yet. This session did not run `xcodebuild`. It did not launch the app on this machine.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. Milestone 2 follow-up is a voice turn without a separate Speak press. Milestone 3 is richer memory. Milestone 4 is Live2D. Milestone 5 is a native plugin host.

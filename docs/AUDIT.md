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
| Platform integration | 3 | AppKit, a status item, Keychain, Speech, and AVFoundation are in `Sources/AoriApp`. The raster is a Rust static library. GPUI is a second binary. Run 38277207278 printed `aori_mic=started`. This checkout did not complete a Keychain read or open the GPUI window. |
| User interface and interaction | 3 | Run 38269452282 captured the companion window. The image is 280 by 380. Corner alpha is 0. The caption reads "Aori Sample". The status item and the chat window are not in that image. |
| Graphics and character rendering | 4 | `aori-face` skins hips, spine, neck, head, both eyes, and both arms. Tests keep the bind pose and move the head, an arm, the blink bone, and a look-at yaw. Run 38277207278 shows the checker head, two eyes, and two arm bars. The caption says 184 vertices. There is no Live2D view. The GPUI binary still paints flat triangles. |
| Audio, speech input, and speech output | 3 | Run 38277207278 started the microphone engine and the speech engine. The WAV RMS is 0.1532. Voice activity found speech. Phonemes are HH, EH, L, OW, P, AA, P, AH. Visemes include e, o, a, and pp. Speech authorization stayed unknown. The transcript was empty. The LLM call was skipped. A Linux test still sends the heard line with no Speak press. |
| Networking and model providers | 3 | `OpenAICompatibleClient` parses streamed chat completions. Tests use a scripted transport. There is no live network call. Linux `URLSession` buffers the body. See the NOTICE in `http-transport.swift`. |
| Security, secrets, and privacy | 3 | Key order is explicit, then `AORI_OPENAI_API_KEY`, then `OPENAI_API_KEY`, then Keychain. A Keychain read fails instead of showing a prompt. `SecretRedaction` strips the key from error text. No key is committed. The Keychain code was not executed here. The app is not sandboxed. |
| Data persistence | 4 | `chat.json` stores the transcript. `settings.json` stores the base URL and the model. `locale.json` stores the locale id. `companion.json` stores the persona and memory notes. `TranscriptSearch` matches every query word in a chat line and in a memory note. The chat panel has a search field. This is not embeddings or pgvector. |
| Error handling and recovery | 3 | `ChatProviderError` covers a missing key, HTTP status, and a bad event. A failed stream keeps partial text. The client does not retry. `core-agent` retries some HTTP statuses. This client does not. |
| Testing | 4 | XCTest covers the arm bones, phoneme units, WAV decode, chat search, the locale catalog, voice activity, and the hands-free send. `swift test` on Linux Swift 6.0.3 ran 41 tests with 0 failures. `cargo test -p aori-face` ran 9 tests with 0 failures. Run 38277207278 checked the WAV, the viseme set, the phoneme list, and the JSON frame line. |
| Continuous integration and build | 4 | `.github/workflows/aori-appkit.yml` runs `swift test`, `cargo test -p aori-face`, and `cargo check -p aori-gpui` on `ubuntu-latest`. On `macos-latest` it launches the app, checks the WAV, the viseme set, and the launch log. Run 38277207278 passed both jobs. The Xcode project is not the CI build. |
| Documentation | 4 | `docs/APPKIT_PORT.md`, this file, and `apps/aori-appkit/README.md` match the tree. They name the CC0 rig, the depth buffer, and the Linux limit. |
| Accessibility | 3 | Send, Speak, Listen, the draft field, and the transcript have accessibility labels. The status item has an accessibility description. Reduced motion holds the neck clip and the blink. There was no VoiceOver pass. |
| Internationalization | 4 | Run 38277207278 printed `aori_locale=ja`, `aori_locale_menu=fallback`, and `aori_locale_proof=設定…`. A Linux test loads en, es, fr, ja, ko, ru, vi, zh-Hans, and zh-Hant. Aori menu keys exist only in English. Missing keys use that English text. |
| Performance and operability | 4 | A debug build rendered 20 frames at 280 by 380. The median was 2.70 ms. The max was 2.80 ms. The test fails when the median is 33 ms or more. Run 38277207278 printed `{"event":"frame","ms":12.39}`. A test parses that line. There is no broader telemetry product. |

## What works in code

- A menu bar and a status item for chat, VRM open, Settings, and the companion.
- A main window with the character and the transcript.
- A borderless companion window. The standard policy is transparent, floating, draggable, and visible on all spaces.
- A name and a personality in Settings. They become the system prompt.
- Local memory notes from "remember that", stored in `companion.json`.
- A local launch greeting. The app then speaks that line. The greeting does not call the provider.
- Idle blink, neck sway, head sway, arm sway, and eye look-at. Keyword faces for glad, sorry, and wow.
- Streaming OpenAI-compatible chat, including split SSE events.
- API keys from the environment or `KeychainSecretStore`. Error text redacts the key.
- Speech buttons that call `AVSpeechSynthesizer` and `SFSpeechRecognizer`.
- An original CC0 VRM 0 humanoid. Bones include hips, spine, neck, head, both eyes, and both arms. Rust skins it and fills a depth buffer. AppKit blits that image. `AORI_VRM_PATH` uses the same reader as Open VRM.
- Phoneme visemes for hello and papa. Other words use letters. RMS scales the open vowel. Run 38273314570 recorded the PCM and started the audio engine.
- A hands-free turn. Voice activity ends an utterance. The next step sends that text. The reply is spoken. A Speak press is not part of that path.
- Word search over saved chat and memory notes.
- A JSON log line for frame time.
- VRM 0 and VRM 1 name parsing, plus mesh bytes from the sample file.

## What is stubbed

- A phoneme recognizer. The viseme path is a word list plus a letter fallback.
- Downloaded character files. The sample humanoid is original and CC0.
- Model-written greetings, topic recall, and notes the companion writes.
- Live2D, MMD, and Spine.
- Provider TTS, Sherpa, and every chat protocol except chat completions.
- Tool calls, plugins, and the integrations.
- Embedding search. Word search is in the chat panel. pgvector stays on the server.
- Click-through on the companion window.
- Retries, cloud key sync, and a sandbox.

## What this session ran

Command: `swift test` in `apps/aori-appkit`.

Result: 41 tests passed, 0 failures, Swift 6.0.3 on `x86_64-unknown-linux-gnu`.

This session ran `cargo test -p aori-face` and `cargo check -p aori-gpui` with Rust 1.99.0. Both passed. The face crate ran 9 tests. `swift test` passed 41 tests. `pnpm lint` exited 0. Run 38277207278 launched `AoriApp` on `macos-latest`. The log says `aori_mic=started`, `aori_locale=ja`, `aori_vad=speech`, `aori_stt=empty`, and `aori_llm=skipped`. The frame line is `{"event":"frame","ms":12.39}`. The phoneme line is `HH,EH,L,OW,P,AA,P,AH`. The WAV RMS is 0.1532. The bones include leftLowerArm and rightLowerArm. The caption says 184 vertices. This session did not run `xcodebuild`. It did not launch the app on this machine.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. Milestone 2 follow-up is click-through and a live microphone on a machine that has one. Milestone 3 is richer memory. Milestone 4 is Live2D. Milestone 5 is a native plugin host.

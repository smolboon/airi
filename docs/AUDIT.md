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
| Product scope and feature parity | 4 | Run 38282943123 finished a voice turn. The user line is Hello papa. The reply is Hello. I am here. The app still has a persona, memory notes, a greeting, and a CC0 humanoid. Tool rounds, plugins, Live2D, vision, and games are absent. |
| Architecture and module boundaries | 4 | `docs/AORI_ARCHITECTURE.md` names the modules. `AoriCore` and `AoriProviders` do not import AppKit. `RoutingChatClient` picks the local template or the remote client. GPUI is still a second binary. The Linux job wrote its lit raster. |
| Platform integration | 4 | Run 38282943123 built `AoriAppKit.xcodeproj` with `xcodebuild`. The log says `aori_keychain=roundtrip` and `aori_mic=started`. Speech authorization stayed unknown. The interactive GPUI window was not opened. |
| User interface and interaction | 4 | Run 38282943123 captured the chat window and the companion window. The chat shows the greeting, Hello papa, and Hello. I am here. Search, Listen, Speak, and Send are visible. The log says `aori_click_through=on`, `aori_hit_corner=pass`, `aori_hit_body=keep`, and `aori_ignores_mouse=true`. A click was not posted through the window. |
| Graphics and character rendering | 4 | The raster skins normals and applies a Lambert shade. A test keeps bind-pose normals and darkens a back face. The framebuffer and the GPUI PNG show a checker head, two eyes, and two arm bars. The left side is darker than the right. There is no Live2D view. The interactive GPUI window was not opened. |
| Audio, speech input, and speech output | 4 | Run 38282943123 started the microphone and the speech engine. The WAV RMS is 0.1532. whisper.cpp v1.7.6 with `ggml-base.en.bin` printed Hello papa. The spoken line was Hello papa. Speech authorization stayed unknown. Visemes still come from a word list. |
| Networking and model providers | 4 | The log says `aori_llm=local`. The reply is the on-device template. `OpenAICompatibleClient` remains the provider when a key is set. This run made no hosted call. Linux `URLSession` still buffers the body. |
| Security, secrets, and privacy | 4 | The log says `aori_keychain=roundtrip` for account `aori-keychain-probe`. That account is not the provider key. Key order is unchanged. `SecretRedaction` still strips a key from error text. The app is not sandboxed. |
| Data persistence | 4 | `chat.json` stores the transcript. `settings.json` stores the base URL and the model. `locale.json` stores the locale id. `companion.json` stores the persona and memory notes. `TranscriptSearch` matches every query word in a chat line and in a memory note. This is not embeddings or pgvector. |
| Error handling and recovery | 4 | A failed stream retries once before any text. The status says "Trying again." A delta blocks the retry. `testFailureKeepsPartialText` and `testRetryOnceBeforeAnyText` cover both paths. This run did not hit a provider error. |
| Testing | 4 | `swift test` on Linux Swift 6.0.3 passed 47 tests with 0 failures. `cargo test -p aori-face` passed 11 tests with 0 failures. Run 38282943123 recorded the WAV, the viseme set, the line Hello papa, the click-through log, and the chat window. The Linux job recorded the GPUI PNG. |
| Continuous integration and build | 4 | The macOS job runs `xcodebuild`, `scripts/fetch-whisper.sh`, and the screenshot script. The Linux job writes the GPUI raster. Run 38282943123 passed both jobs. The i18n locale check passed. This is not CI for the whole AIRI product. |
| Documentation | 4 | `docs/AORI_PRODUCT.md`, `docs/AORI_ARCHITECTURE.md`, `docs/APPKIT_PORT.md`, and this file match the tree. They name the base whisper model, the click-through flag, and the GPUI raster path. |
| Accessibility | 4 | The log line `aori_accessibility` lists the chat labels, the character, and both windows. Reduced motion holds the neck clip and the blink. VoiceOver was not run. |
| Internationalization | 4 | Run 38282943123 printed `aori_locale=ja`, `aori_locale_menu=loaded`, and `aori_locale_proof=設定…`. A Linux test reads `showCompanion` and `clickThrough` in en, es, fr, ja, ko, ru, vi, zh-Hans, and zh-Hant. The i18n locale check passed. The rest of the product is not translated. |
| Performance and operability | 4 | A debug build rendered 20 frames at 280 by 380. The median was 3.30 ms. The max was 3.56 ms. The test fails when the median is 33 ms or more. Run 38282943123 printed `{"event":"frame","ms":18.98}`. There is no broader telemetry product. |

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
- Phoneme visemes for hello and papa. Other words use letters. RMS scales the open vowel.
- A hands-free turn. Voice activity ends an utterance. The next step sends that text. The reply is spoken. A Speak press is not part of that path.
- An on-device transcript from whisper.cpp when Speech permission is missing. Run 38282943123 logged `aori_stt=Hello papa`.
- Click-through on clear pixels. The same run logged `aori_click_through=on`, `aori_hit_corner=pass`, `aori_hit_body=keep`, and `aori_ignores_mouse=true`. A click was not posted through the window.
- A local template reply when the API key is empty. The same run logged `aori_llm=local` and spoke the reply.
- One retry before the first text delta. The status line says "Trying again."
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
- A click posted through the companion window onto an app behind it.
- The interactive GPUI window. The Linux job wrote the lit PNG. That window did not open.
- Cloud key sync and a sandbox.

## What this session ran

Command: `swift test` in `apps/aori-appkit`.

Result: 47 tests passed, 0 failures, Swift 6.0.3 on `x86_64-unknown-linux-gnu`.

This session ran `cargo test -p aori-face` with Rust 1.99.0. The face crate ran 11 tests. The lit frame median was 3.30 ms. The max was 3.56 ms. `AORI_GPUI_PNG` wrote a 280 by 380 PNG on this machine. `pnpm lint` exited 0 with 656 warnings and 0 errors.

Run 38282943123 launched `AoriApp` on `macos-latest`. `xcodebuild` passed. The Linux job wrote the GPUI PNG. The log says `aori_mic=started`, `aori_keychain=roundtrip`, `aori_locale=ja`, `aori_locale_menu=loaded`, `aori_stt_engine=whisper`, `aori_stt=Hello papa`, and `aori_llm=local`. It also says `aori_click_through=on`, `aori_hit_corner=pass`, `aori_hit_body=keep`, and `aori_ignores_mouse=true`.

The frame line is `{"event":"frame","ms":18.98}`. The phoneme line is `HH,EH,L,OW,P,AA,P,AH`. The WAV RMS is 0.1532. The chat window shows the greeting, Hello papa, and Hello. I am here. This session did not launch the app on this Linux machine. VoiceOver was not run.

No hosted model call was made. A click was not posted through the window.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. Milestone 2 follow-up is a posted click through the window and a live microphone on a machine that has one. Milestone 3 is richer memory. Milestone 4 is Live2D. Milestone 5 is a native plugin host.

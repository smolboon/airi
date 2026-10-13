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
| Product scope and feature parity | 4 | Run 38348280149 shows a flat character and an orange Vision badge. The chat shows Hello papa and Mock reply from CI. The log recalls `I like tea`, then the Memory window shows `The cat is orange`. The ticker sent two screen frames and stopped. A neural embedder, Cubism moc3, JavaScript plugins, and games are absent. |
| Architecture and module boundaries | 4 | `docs/AORI_ARCHITECTURE.md` names the modules. `VisionRequest` lives in `AoriCore`. ScreenCaptureKit stays in the app target. `AoriCore` and `AoriProviders` do not import AppKit. GPUI is still a second binary. |
| Platform integration | 4 | Run 38348280149 built the Xcode project and opened the GPUI window. The log says `aori_vision_permission=granted`, `aori_vision_ticker=on`, and `aori_memory_window=open`. Speech authorization stayed unknown. |
| User interface and interaction | 4 | Run 38348280149 captured the chat, the companion, and the Memory window. The chat shows the greeting, Hello papa, and Mock reply from CI. The Memory window shows `The cat is orange` and a Delete button. The log says `aori_click_through=delivered`. |
| Graphics and character rendering | 4 | Run 38348280149 shows a flat character in the companion window. The hair is above the blue body. An orange Vision badge sits on that window. This is not a Cubism moc3 model. The GPUI window still shows the checker head. |
| Audio, speech input, and speech output | 4 | Run 38348280149 logged `aori_mic_utterance=silence`. whisper.cpp printed Hello papa. Speech authorization stayed unknown. Visemes still come from a word list. |
| Networking and model providers | 4 | Run 38348280149 logged `aori_memory_source=endpoint` and `aori_vision_reply=Mock vision from CI.`. The chat reply stayed `Mock reply from CI.`. The mock does not read the image. Other chat protocols are absent. |
| Security, secrets, and privacy | 4 | The log says `aori_keychain=roundtrip` for account `aori-keychain-probe`. That account is not the provider key. The plugin grant denies `aori.files.read`. Run 38348280149 sent two screen PNGs to the local mock. The log does not contain the images. The app is not sandboxed. |
| Data persistence | 4 | SQLite stores embedding notes. Run 38348280149 recalled `I like tea` and deleted that row. `chat.json`, `settings.json`, `locale.json`, and `companion.json` still store the other records. This is not pgvector. The local embedder is a hash. |
| Error handling and recovery | 4 | A failed stream retries once before any text. The status says "Trying again." A delta blocks the retry. `testFailureKeepsPartialText` and `testRetryOnceBeforeAnyText` cover both paths. This run did not hit a provider error. |
| Testing | 4 | The Linux job in run 38348280149 passed 67 tests with 0 failures. The macOS job passed 67 tests. `cargo test -p aori-face` passed 18 tests. The macOS log recorded the memory recall, the delete, two vision ticks, and the Vision badge. |
| Continuous integration and build | 4 | Run 38348280149 passed the Linux job and the macOS job. The macOS job saved the companion window, the Memory window, and the chat. The log says `aori_voiceover=running`. This is not CI for the whole AIRI product. |
| Documentation | 4 | `docs/AORI_PRODUCT.md`, `docs/AORI_ARCHITECTURE.md`, `docs/APPKIT_PORT.md`, and this file match run 38348280149. They do not cover the whole AIRI product. |
| Accessibility | 4 | Run 38348280149 logged the live labels and `aori_ax_press=Send message`. The log says `aori_voiceover=running`. The log has no spoken captions. |
| Internationalization | 4 | Run 38348280149 printed `aori_locale=ja`, `aori_locale_menu=loaded`, and `aori_locale_proof=設定…`. The menu dump includes クリックを透過. The Memory menu key is English only. The rest of the product is not translated. |
| Performance and operability | 4 | Run 38348280149 printed `{"event":"frame","ms":3.71}`. The vision ticker waited 1000 ms between two ticks and then stopped. There is no broader telemetry product. |

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
- When `AORI_AVATAR` is `live2d`, the companion draws a flat layered character. The mouth, the eyes, and the head angle use Live2D parameter ids. Rust samples motion3.json curves. The art is original. Run 38298286037 showed it in the companion window.
- A native Manifest v2 host. `AORI_PLUGINS` selects the directory. Run 38301336719 logged `aori_plugin=loaded id=aori-greeting`, `aori_plugin_result=Plugin greeting.`, and `aori_plugin_denied=aori.files.read`. The host does not run JavaScript.
- One opt-in vision ticker. Run 38348280149 logged `aori_vision_ticker=on`, two `aori_vision_source=screen` ticks, `aori_vision_interval_ms=1000`, and `aori_vision_ticker=stopped`. The companion window shows an orange Vision badge. The mock does not read the pixels.
- SQLite embedding memory. Run 38348280149 logged `aori_memory_source=endpoint`, `aori_memory_recall=I like tea`, and `aori_memory_delete=ok`. The Memory window then showed `The cat is orange`. The local embedder is a hash. No Core ML model is bundled.
- Phoneme visemes for hello and papa. Other words use letters. RMS scales the open vowel.
- A hands-free turn. Voice activity ends an utterance. The next step sends that text. The reply is spoken. A Speak press is not part of that path.
- An on-device transcript from whisper.cpp when Speech permission is missing. Run 38290795770 logged `aori_stt=Hello papa`.
- Click-through on clear pixels. The same run logged `aori_click_through=delivered` and `aori_click_hits=1`. The window behind the companion received the click.
- A mock provider reply when the key and model are set. The same run logged `aori_llm=sent` and `aori_llm_reply=Mock reply from CI.`.
- One retry before the first text delta. The status line says "Trying again."
- Word search over saved chat and memory notes.
- A JSON log line for frame time.
- VRM 0 and VRM 1 name parsing, plus mesh bytes from the sample file.

## What is stubbed

- A phoneme recognizer. The viseme path is a word list plus a letter fallback.
- Downloaded character files. The sample humanoid is original and CC0.
- Model-written greetings, topic recall, and notes the companion writes.
- Cubism moc3, MMD, and Spine. The flat character uses Live2D parameter ids. It does not load a moc3 file.
- Provider TTS, Sherpa, and every chat protocol except chat completions.
- Tool calls, JavaScript plugins, and the integrations. The native host reads a command list. It does not run JavaScript.
- A vision ticker that stays on after the rate limit. The screenshot path stops at the configured maximum.
- A neural sentence embedder and pgvector. The app stores endpoint vectors or hash vectors in SQLite. Word search remains in the chat panel.
- A spoken microphone utterance. Run 38295099387 logged `aori_mic_utterance=silence`.
- VoiceOver captions. The process was running. The log has no spoken line.
- Cloud key sync and a sandbox.

## What this session ran

The Linux job in run 38348280149 passed 67 tests with 0 failures on Swift 6.0.3. The macOS job passed 67 tests. `cargo test -p aori-face` passed 18 tests.

Run 38348280149 launched `AoriApp` on `macos-latest`. `xcodebuild` passed. The log says `aori_plugin_denied=aori.files.read`, `aori_click_through=delivered`, and `aori_llm_reply=Mock reply from CI.`. It also says `aori_memory_source=endpoint`, `aori_memory_recall=I like tea`, and `aori_memory_delete=ok`.

The same log says `aori_vision_ticker=on`, `aori_vision_tick=1`, `aori_vision_tick=2`, and `aori_vision_ticker=stopped`. Both ticks used `aori_vision_source=screen`. The mock reply was `Mock vision from CI.`. The mock does not read the pixels. The screen PNGs are not in the artifact.

The same log says `aori_mic_utterance=silence`, `aori_stt=Hello papa`, and `aori_voiceover=running`. The frame line is `{"event":"frame","ms":3.71}`.

The companion window shows a flat character with the hair above the blue body. The framebuffer mouth is open. The window mouth is a line. The chat window shows the greeting, Hello papa, and Mock reply from CI. The GPUI capture is a window with traffic lights and the checker head. This session did not launch the app on this Linux machine.

The microphone mark is silence. The log has no spoken caption. Speech authorization stayed unknown. The flat character is not a Cubism moc3 model.

The plugin host is a command list. JavaScript stays out. The macOS App Sandbox stays off.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. A spoken microphone utterance and VoiceOver captions remain open. Milestone 3 is richer memory. Milestone 4 still needs Cubism moc3.

Milestone 5 has a command-list host. JavaScript plugins stay out. Milestone 6 has an opt-in vision ticker. Milestone 7 has SQLite recall. A neural embedder and a Core ML model are not bundled. Games stay out.

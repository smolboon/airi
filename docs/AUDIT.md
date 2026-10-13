# Aori AppKit audit

Audit date: 2026-10-13. Scope: `apps/aori-appkit` and `docs/APPKIT_PORT.md`. Aori is the native app. Project AIRI is the upstream product.

Scores use 0 to 5.

- 0 means absent.
- 1 means started.
- 2 means partial.
- 3 means usable, with known gaps.
- 4 means strong for this milestone.
- 5 means complete for the whole upstream AIRI product.

The scores judge the native port, not the Vue apps. The long-term aim is above 4.5 in every area. This file does not use a 10-point scale.

A row is 4 only when the milestone behavior is strong. A central gap keeps the row at 3. No row is 5, because the Vue apps, games, and integrations are still outside this port.

## Scores

| Area | Score | Evidence |
| --- | --- | --- |
| Product scope and feature parity | 3 | The app chats, speaks, recalls notes, and reads the screen. Games, Cubism moc3, and most integrations are absent. JavaScriptCore is in the host. Run 38348280149 did not run it. |
| Architecture and module boundaries | 4 | `docs/AORI_ARCHITECTURE.md` names the modules. ScreenCaptureKit stays in the app target. `AoriCore` does not import AppKit. GPUI is a second binary. This is not the whole AIRI map. |
| Platform integration | 3 | Run 38348280149 built the app and granted screen recording. Keychain and the microphone probe ran. Speech authorization stayed unknown. The process is not sandboxed. |
| User interface and interaction | 4 | Run 38348280149 captured the chat, the companion, and the Memory window. Click-through logged `aori_click_through=delivered`. The Memory window has a Delete button. Settings are thinner than AIRI. |
| Graphics and character rendering | 3 | Run 38348280149 shows a flat character. The hair is above the blue body. The GPUI window shows the checker head. The flat character is not a Cubism moc3 mesh. The Cubism Core license blocks that loader in this MIT repo. |
| Audio, speech input, and speech output | 3 | whisper.cpp printed Hello papa. The log says `aori_speech_rms=0.1532`. The log says `aori_mic_utterance=silence`. Visemes come from a word list. |
| Networking and model providers | 3 | The same run used chat completions for text, vision, and embeddings. The mock does not read pixels. Other chat protocols are absent. |
| Security, secrets, and privacy | 3 | Keychain logged `aori_keychain=roundtrip`. The plugin grant denied `aori.files.read`. The signed app enables the sandbox, network client, and microphone. Run 38348280149 was not sandboxed. Screen capture uses permission, not an entitlement. |
| Data persistence | 3 | SQLite recalled `I like tea` and the delete left one row. JSON files still store chat, settings, locale, and the persona. The local embedder is a hash. |
| Error handling and recovery | 4 | `testFailureKeepsPartialText` and `testRetryOnceBeforeAnyText` cover the retry. A delta blocks the second try. This run did not hit a provider error. |
| Testing | 4 | Linux and macOS in run 38348280149 each passed 67 tests. `cargo test -p aori-face` passed 18 tests. The macOS log recorded recall, delete, and two vision ticks. |
| Continuous integration and build | 4 | Run 38348280149 passed the Linux job and the macOS job. The macOS job saved the companion, the Memory window, and the chat. This is not CI for the whole AIRI product. |
| Documentation | 4 | The product, architecture, port, and audit notes match run 38348280149. Each note names a gap. They do not cover the whole AIRI product. |
| Accessibility | 3 | The log has live labels and `aori_ax_press=Send message`. The log says `aori_voiceover=running`. The log has no spoken captions. |
| Internationalization | 3 | The log printed `aori_locale=ja` and `aori_locale_proof=設定…`. The menu dump includes クリックを透過. The Memory menu key is English only. |
| Performance and operability | 3 | The frame line is `{"event":"frame","ms":3.71}`. The ticker waited 1000 ms and then stopped. There is no broader telemetry product. |

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
- A native Manifest v2 host. `AORI_PLUGINS` selects the directory. Run 38301336719 logged `aori_plugin=loaded id=aori-greeting`, `aori_plugin_result=Plugin greeting.`, and `aori_plugin_denied=aori.files.read`. A `.js` file can run in JavaScriptCore. The script calls `aori.call`.
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
- Tool calls and the integrations. JavaScriptCore can run a `.js` plugin. Run 38348280149 did not run that plugin.
- A vision ticker that stays on after the rate limit. The screenshot path stops at the configured maximum.
- A neural sentence embedder and pgvector. The app stores endpoint vectors or hash vectors in SQLite. Word search remains in the chat panel.
- A spoken microphone utterance. Run 38295099387 logged `aori_mic_utterance=silence`.
- VoiceOver captions. The process was running. The log has no spoken line.
- Cloud key sync. The sandbox is signed, and run 38348280149 did not prove it.

## What this session ran

The Linux job in run 38348280149 passed 67 tests with 0 failures on Swift 6.0.3. The macOS job passed 67 tests. `cargo test -p aori-face` passed 18 tests.

Run 38348280149 launched `AoriApp` on `macos-latest`. `xcodebuild` passed. The log says `aori_plugin_denied=aori.files.read`, `aori_click_through=delivered`, and `aori_llm_reply=Mock reply from CI.`. It also says `aori_memory_source=endpoint`, `aori_memory_recall=I like tea`, and `aori_memory_delete=ok`.

The same log says `aori_vision_ticker=on`, `aori_vision_tick=1`, `aori_vision_tick=2`, and `aori_vision_ticker=stopped`. Both ticks used `aori_vision_source=screen`. The mock reply was `Mock vision from CI.`. The mock does not read the pixels. The screen PNGs are not in the artifact.

The same log says `aori_mic_utterance=silence`, `aori_stt=Hello papa`, and `aori_voiceover=running`. The frame line is `{"event":"frame","ms":3.71}`.

The companion window shows a flat character with the hair above the blue body. The framebuffer mouth is open. The window mouth is a line. The chat window shows the greeting, Hello papa, and Mock reply from CI. The GPUI capture is a window with traffic lights and the checker head. This session did not launch the app on this Linux machine.

The microphone mark is silence. The log has no spoken caption. Speech authorization stayed unknown. The flat character is not a Cubism moc3 model.

The plugin host is a command list. JavaScript stays out. The macOS App Sandbox stays off.

The score table above uses the same run. Ten rows are 3 because a central gap remains. Six rows are 4 because the milestone behavior is strong. No row is 5.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. A spoken microphone utterance and VoiceOver captions remain open. Milestone 3 is richer memory. Milestone 4 still needs Cubism moc3.

Milestone 5 has a command-list host. JavaScript plugins stay out. Milestone 6 has an opt-in vision ticker. Milestone 7 has SQLite recall. A neural embedder and a Core ML model are not bundled. Games stay out.

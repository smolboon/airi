# Aori AppKit audit

Audit date: 2026-10-13. Scope: `apps/aori-appkit` and `docs/APPKIT_PORT.md`. Aori is the native app. Project AIRI is the upstream product.

Scores use 0 to 5.

- 0 means absent.
- 1 means started.
- 2 means partial.
- 3 means usable, with known gaps.
- 4 means strong for this milestone.
- 5 means complete for the whole upstream AIRI product.

The scores judge the native port, not the Vue apps. The long-term aim is above 4.5 in every area. This file does not use a 10-point scale. This file does not use a score of 6.

A row is 4 only when the milestone behavior is strong. A central gap keeps the row at 3. No row is 5, because the Vue apps, games, and integrations are still outside this port.

## Scores

| Area | Score | Evidence |
| --- | --- | --- |
| Product scope and feature parity | 3 | The app chats, speaks, recalls notes, and reads the screen. Games, Cubism moc3, and most integrations are absent. Run 38355635403 ran one `.js` plugin in JavaScriptCore. |
| Architecture and module boundaries | 4 | `docs/AORI_ARCHITECTURE.md` names the modules. ScreenCaptureKit stays in the app target. `AoriCore` does not import AppKit. GPUI is a second binary. This is not the whole AIRI map. |
| Platform integration | 3 | Run 38357544156 launched the sandboxed app and granted screen recording. Keychain and the microphone probe ran. The log says `aori_stt_auth=unknown`. |
| User interface and interaction | 4 | Run 38357544156 captured the chat, the companion, and the Memory window. Click-through logged `aori_click_through=delivered`. The Memory window has a Delete button. Settings are thinner than AIRI. |
| Graphics and character rendering | 4 | Run 38357544156 shows a flat character. The hair is above the blue body. The mouth is open in the companion window and in the framebuffer. The GPUI window shows the checker head. Cubism Core stays out of this MIT repo. |
| Audio, speech input, and speech output | 3 | whisper.cpp printed Hello papa inside the sandbox. The log says `aori_speech_rms=0.1532`. The log says `aori_mic_utterance=silence`. Visemes come from a word list. |
| Networking and model providers | 3 | The same run used chat completions for text, vision, and embeddings. The mock does not read pixels. Other chat protocols are absent. |
| Security, secrets, and privacy | 4 | Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, `aori_bookmark=ok`, and `aori_keychain=roundtrip`. Screen capture uses permission. CI still stages files in the app container. |
| Data persistence | 3 | SQLite recalled `I like tea` and the delete left one row. JSON files still store chat, settings, locale, and the persona. The bundled file is a conversion of all-MiniLM-L6-v2. Linux ranked the reference vectors. A macOS launch has not logged `aori_embed_recall=tea`. This is not pgvector. |
| Error handling and recovery | 4 | `testFailureKeepsPartialText` and `testRetryOnceBeforeAnyText` cover the retry. A delta blocks the second try. This run did not hit a provider error. |
| Testing | 4 | Linux passed 71 tests. macOS passed 72 tests. `cargo test -p aori-face` passed 18 tests. The macOS log recorded recall, delete, and two vision ticks. |
| Continuous integration and build | 4 | Run 38357544156 passed the Linux job and the macOS job. The macOS job saved the companion, the Memory window, and the chat. This is not CI for the whole AIRI product. |
| Documentation | 4 | The product, architecture, port, and audit notes match run 38357544156. Each note names a gap. They do not cover the whole AIRI product. |
| Accessibility | 3 | The log has live labels and `aori_ax_press=Send message`. The log says `aori_voiceover=running`. The app posts the spoken line. A macOS launch has not logged `aori_caption`. |
| Internationalization | 3 | The log printed `aori_locale=ja` and `aori_locale_proof=設定…`. The menu dump includes クリックを透過. The Memory menu key is English only. |
| Performance and operability | 3 | The frame line is `{"event":"frame","ms":2.47}`. The ticker waited 1000 ms and then stopped. There is no broader telemetry product. |

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
- A native Manifest v2 host. `AORI_PLUGINS` selects the directory. Run 38355635403 logged `aori_plugin=loaded id=aori-greeting`, `aori_plugin_result=Plugin greeting.`, and `aori_plugin_denied=aori.files.read`. The same run logged `aori_plugin_js=greeting=Plugin greeting. files=denied`.
- One opt-in vision ticker. Run 38355635403 logged `aori_vision_ticker=on`, two `aori_vision_source=screen` ticks, `aori_vision_interval_ms=1000`, and `aori_vision_ticker=stopped`. The companion window shows an orange Vision badge. The mock does not read the pixels.
- SQLite embedding memory. Run 38355635403 logged `aori_memory_source=endpoint`, `aori_embed_coreml=ok`, `aori_memory_recall=I like tea`, and `aori_memory_delete=ok`. The Memory window then showed `The cat is orange`. The bundled file is now a conversion of all-MiniLM-L6-v2. Linux ranked the reference vectors. A macOS launch has not logged `aori_embed_recall=tea`.
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
- Tool calls and the integrations. Run 38355635403 ran one `.js` plugin. Tool calls stay out.
- A vision ticker that stays on after the rate limit. The screenshot path stops at the configured maximum.
- pgvector. The bundled Core ML file is a conversion of all-MiniLM-L6-v2. Linux ranked the reference vectors. A macOS launch has not logged `aori_embed_recall=tea`. Word search remains in the chat panel.
- A spoken microphone utterance. Run 38295099387 logged `aori_mic_utterance=silence`.
- A proven VoiceOver caption. The app posts the spoken line and logs `aori_caption`. A macOS launch has not logged that line.
- Cloud key sync. Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_bookmark=ok`. A Developer ID profile is absent.

## What this session ran

The Linux job in run 38357544156 passed 71 tests with 0 failures. The macOS job passed 72 tests. `cargo test -p aori-face` passed 18 tests.

Run 38357544156 launched the sandboxed app on `macos-latest`. The log says `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_bookmark=ok`. It also says `aori_window_mouth=open`, `aori_plugin_js=greeting=Plugin greeting. files=denied`, and `aori_stt=Hello papa`. Both vision ticks used `aori_vision_source=screen`. The mock does not read the pixels.

The companion window shows a flat character. The hair is above the blue body. The mouth is open in that window and in the framebuffer. The orange Vision badge is on. The Memory window shows `The cat is orange`.

Run 38354362753 logged `aori_sandbox=on` and then failed to read the checkout. The signed copy in that run named a checkout path exception. The ad-hoc sandbox ignored it. Run 38357544156 removed that exception. CI still stages plugins, locales, and the model in the app container.

This session did not launch the app on this Linux machine. Speech authorization stayed unknown. The microphone mark is silence. The flat character is not a Cubism moc3 model.

The score table above uses run 38357544156. Eight rows are 3 because a central gap remains. Eight rows are 4 because the milestone behavior is strong. No row is 5.

## Gap to the next score

This scale stops at 5. The lines below name the gap that blocks the next honest score.

Product scope is 3. Games, Cubism moc3, and most integrations are absent. One `.js` plugin does not close that gap.

Architecture is 4. The app modules are named. Games, the hosted API, and the integrations stay outside this port.

Platform integration is 3. Run 38357544156 logged `aori_stt_auth=unknown`. Speech permission is not granted on the runner.

User interface is 4. The chat, the companion, and the Memory window are captured. Settings are thinner than AIRI.

Graphics is 4. The companion window mouth is open. Cubism moc3, MMD, and Spine are absent. The GPUI window is a checker head.

Audio is 3. whisper.cpp printed Hello papa. The log says `aori_mic_utterance=silence`. Visemes come from a word list.

Networking is 3. The mock reply does not read pixels. Other chat protocols are absent.

Security is 4. The signature has no checkout path exception. The log says `aori_bookmark=ok`. A Developer ID profile is absent. CI still stages files in the app container.

Data persistence is 3. JSON files still store chat, settings, locale, and the persona. A macOS launch has not logged `aori_embed_recall=tea`. pgvector stays out.

Error handling is 4. Unit tests cover one retry. This launch did not hit a provider error.

Testing is 4. The suite covers this app. It does not cover the whole AIRI product.

Continuous integration is 4. Run 38357544156 passed. This is not CI for the whole AIRI product.

Documentation is 4. These notes match that run. They do not cover the whole AIRI product.

Accessibility is 3. The app posts the spoken line. A macOS launch has not logged `aori_caption`.

Internationalization is 3. The log printed `aori_locale=ja`. The Memory menu key is English only. Crowdin owns the other locales.

Performance is 3. One frame line is present. There is no broader telemetry product.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. A spoken microphone utterance and VoiceOver captions remain open. Milestone 4 keeps the flat rig because Cubism Core is proprietary.

Milestone 5 can run a `.js` file in JavaScriptCore. Milestone 6 has an opt-in vision ticker. Milestone 7 has SQLite recall and a converted MiniLM file. Games stay out.

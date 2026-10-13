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
| User interface and interaction | 4 | Run 38357544156 captured the chat, the companion, and the Memory window. Click-through logged `aori_click_through=delivered`. Settings lists provider, voice, model, persona, and saved facts. A macOS capture of that window is not in a launch log. The rest of the AIRI settings pages are absent. |
| Graphics and character rendering | 4 | Run 38357544156 shows a flat character. The hair is above the blue body. The mouth is open in the companion window and in the framebuffer. The GPUI window shows the checker head. The sample file is now Butter, a CC0 VRM with a color texture. A macOS SceneKit image is not saved yet. Cubism Core stays out of this MIT repo. |
| Audio, speech input, and speech output | 3 | whisper.cpp printed Hello papa inside the sandbox. The log says `aori_speech_rms=0.1532`. The log says `aori_mic_utterance=silence`. Visemes come from a word list. |
| Networking and model providers | 3 | The same run used chat completions for text, vision, and embeddings. The mock does not read pixels. Other chat protocols are absent. |
| Security, secrets, and privacy | 4 | Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, `aori_bookmark=ok`, and `aori_keychain=roundtrip`. Screen capture uses permission. CI still stages files in the app container. |
| Data persistence | 4 | Run 38359062380 logged `aori_embed_recall=tea` and `aori_memory_recall=I like tea`. Chat, settings, the persona, and the locale id are in SQLite. A macOS log has not shown `aori_store=sqlite` yet. pgvector stays out. |
| Error handling and recovery | 4 | `testFailureKeepsPartialText` and `testRetryOnceBeforeAnyText` cover the retry. A delta blocks the second try. This run did not hit a provider error. |
| Testing | 4 | Linux passed 72 tests. macOS passed 73 tests. `cargo test -p aori-face` passed 18 tests. The macOS log recorded MiniLM recall, delete, and two vision ticks. |
| Continuous integration and build | 4 | Run 38359062380 passed the Linux job and the macOS job. The macOS job saved the companion, the Memory window, and the chat. This is not CI for the whole AIRI product. |
| Documentation | 4 | The product, architecture, port, and audit notes match run 38359062380. Each note names a gap. They do not cover the whole AIRI product. |
| Accessibility | 4 | Run 38359815442 logged `aori_caption=Mock reply from CI.` and `aori_voiceover=running`. The app posts that line as an announcement. VoiceOver starts after the app exits. The log does not record that audio. |
| Internationalization | 3 | The log printed `aori_locale=ja` and `aori_locale_proof=設定…`. The menu dump includes クリックを透過. The shipped locales now have `menu.memory`. A macOS log has not shown `aori_menu_memory=記憶` yet. |
| Performance and operability | 3 | The frame line is `{"event":"frame","ms":2.47}`. The ticker waited 1000 ms and then stopped. There is no broader telemetry product. |

## What works in code

- A menu bar and a status item for chat, VRM open, Settings, and the companion.
- A main window with the character and the transcript.
- A borderless companion window. The standard policy is transparent, floating, draggable, and visible on all spaces.
- A name and a personality in Settings. They become the system prompt.
- Local memory notes from "remember that", stored with the persona in `companion.sqlite`.
- A local launch greeting. The app then speaks that line. The greeting does not call the provider.
- Idle blink, neck sway, head sway, arm sway, and eye look-at. Keyword faces for glad, sorry, and wow.
- Streaming OpenAI-compatible chat, including split SSE events.
- API keys from the environment or `KeychainSecretStore`. Error text redacts the key.
- Speech buttons that call `AVSpeechSynthesizer` and `SFSpeechRecognizer`.
- Butter, a CC0 VRM 0 humanoid by Polygonal Mind. The file has a color texture, blink, and vowel blend shapes. It has no eye bones. Rust skins it and fills a depth buffer. AppKit blits that image. `AORI_VRM_PATH` uses the same reader as Open VRM.
- When `AORI_AVATAR` is `live2d`, the companion draws a flat layered character. The mouth, the eyes, and the head angle use Live2D parameter ids. Rust samples motion3.json curves. The art is original. Run 38298286037 showed it in the companion window.
- A native Manifest v2 host. `AORI_PLUGINS` selects the directory. Run 38355635403 logged `aori_plugin=loaded id=aori-greeting`, `aori_plugin_result=Plugin greeting.`, and `aori_plugin_denied=aori.files.read`. The same run logged `aori_plugin_js=greeting=Plugin greeting. files=denied`.
- One opt-in vision ticker. Run 38355635403 logged `aori_vision_ticker=on`, two `aori_vision_source=screen` ticks, `aori_vision_interval_ms=1000`, and `aori_vision_ticker=stopped`. The companion window shows an orange Vision badge. The mock does not read the pixels.
- SQLite embedding memory. Run 38359062380 logged `aori_memory_source=endpoint`, `aori_embed_coreml=ok`, `aori_embed_recall=tea`, `aori_memory_recall=I like tea`, and `aori_memory_delete=ok`. The Memory window then showed `The cat is orange`. The bundled file is a conversion of all-MiniLM-L6-v2.
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

- A phoneme recognizer. Visemes come from RMS and zero crossings. That is not a recognizer.
- Other downloaded characters. The sample is Butter, a CC0 VRM by Polygonal Mind.
- Model-written greetings, topic recall, and notes the companion writes.
- Cubism moc3, MMD, and Spine. The flat character uses Live2D parameter ids. It does not load a moc3 file.
- Provider TTS, Sherpa, and every chat protocol except chat completions.
- Tool calls and the integrations. Run 38355635403 ran one `.js` plugin. Tool calls stay out.
- A vision ticker that stays on after the rate limit. The screenshot path stops at the configured maximum.
- pgvector. Run 38359062380 logged `aori_embed_recall=tea`. Word search remains in the chat panel.
- A spoken microphone utterance. The last log says `aori_mic_utterance=silence`. `AORI_MIC_WAV` feeds a recorded WAV through that mark. A macOS log has not shown speech yet.
- VoiceOver audio. Run 38359815442 logged `aori_caption=Mock reply from CI.`. VoiceOver starts after the app exits. The log does not record that audio.
- Cloud key sync. Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_bookmark=ok`. A Developer ID profile is absent.

## What this session ran

The Linux job in run 38359062380 passed 72 tests with 0 failures. The macOS job passed 73 tests. `cargo test -p aori-face` passed 18 tests.

Run 38359062380 launched the sandboxed app on `macos-latest`. The log says `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_bookmark=ok`. It also says `aori_embed_recall=tea`, `aori_window_mouth=open`, and `aori_stt=Hello papa`. Both vision ticks used `aori_vision_source=screen`. The mock does not read the pixels.

The companion window shows a flat character. The hair is above the blue body. The mouth is open in that window and in the framebuffer. The orange Vision badge is on. The Memory window shows `The cat is orange`.

Run 38354362753 logged `aori_sandbox=on` and then failed to read the checkout. The signed copy in that run named a checkout path exception. The ad-hoc sandbox ignored it. Run 38357544156 removed that exception. CI still stages plugins, locales, and the model in the app container.

This session did not launch the app on this Linux machine. Speech authorization stayed unknown. The microphone mark is silence. The flat character is not a Cubism moc3 model.

The score table above uses runs 38359062380 and 38359815442. Six rows are 3 because a central gap remains. Ten rows are 4 because the milestone behavior is strong. No row is 5.

## Gap to the next score

This scale stops at 5. The lines below name the gap that blocks the next honest score.

Product scope is 3. Games, Cubism moc3, and most integrations are absent. One `.js` plugin does not close that gap.

Architecture is 4. The app modules are named. Games, the hosted API, and the integrations stay outside this port.

Platform integration is 3. Run 38357544156 logged `aori_stt_auth=unknown`. Speech permission is not granted on the runner.

User interface is 4. The chat, the companion, and the Memory window are captured. Settings now lists provider, voice, model, persona, and saved facts. A macOS capture of that window is not in a launch log. The rest of the AIRI settings pages are absent.

Graphics is 4. The companion window mouth is open. Cubism moc3, MMD, and Spine are absent. `AoriSceneKit` draws Butter and samples its color texture. A macOS job has not saved that image yet. The last GPUI window is a checker head.

Audio is 3. whisper.cpp printed Hello papa. The last log says `aori_mic_utterance=silence`. Visemes now come from PCM frames. `AORI_MIC_WAV` feeds a recorded WAV through the mic mark. A macOS log has not shown `aori_mic_utterance=speech` yet.

Networking is 3. The mock reply does not read pixels. Other chat protocols are absent.

Security is 4. The signature has no checkout path exception. The log says `aori_bookmark=ok`. A Developer ID profile is absent. CI still stages files in the app container.

Data persistence is 4. macOS ranked `tea please` closer to `I like tea` than to `The cat is orange`. Chat, settings, the persona, and the locale id now use SQLite. pgvector stays out. A macOS log has not shown `aori_store=sqlite` yet.

Error handling is 4. Unit tests cover one retry. This launch did not hit a provider error.

Testing is 4. The suite covers this app. It does not cover the whole AIRI product.

Continuous integration is 4. Run 38357544156 passed. This is not CI for the whole AIRI product.

Documentation is 4. These notes match that run. They do not cover the whole AIRI product.

Accessibility is 4. Run 38359815442 logged `aori_caption=Mock reply from CI.`. VoiceOver starts after the app exits. The log does not record that audio.

Internationalization is 3. The log printed `aori_locale=ja`. The shipped locales now have `menu.memory`. A macOS log has not shown `aori_menu_memory=記憶` yet. Other AIRI pages stay on Crowdin.

Performance is 3. One frame line is present. There is no broader telemetry product.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. A spoken microphone utterance and VoiceOver captions remain open. Milestone 4 keeps the flat rig because Cubism Core is proprietary.

Milestone 5 can run a `.js` file in JavaScriptCore. Milestone 6 has an opt-in vision ticker. Milestone 7 has SQLite recall and a converted MiniLM file. Games stay out.

# Aori AppKit audit

Audit date: 2026-10-15. Scope: `apps/aori-appkit` and `docs/APPKIT_PORT.md`. Aori is the native app. The Vue apps are the rest of this product.

Scores use 0 to 5.

- 0 means absent.
- 1 means started.
- 2 means partial.
- 3 means usable, with known gaps.
- 4 means strong for this milestone.
- 5 means complete for the whole Aori product.

The scores judge the native port, not the Vue apps. The long-term aim is above 4.5 in every area. This file does not use a 10-point scale. This file does not use a score of 6.

A row is 4 only when the milestone behavior is strong. A central gap keeps the row at 3. No row is 5, because the Vue apps, games, and integrations are still outside this port.

## Scores

| Area | Score | Evidence |
| --- | --- | --- |
| Product scope and feature parity | 3 | The app chats, speaks, recalls notes, and reads the screen. Games, Cubism moc3, and most integrations are absent. Run 38355635403 ran one `.js` plugin in JavaScriptCore. |
| Architecture and module boundaries | 4 | `docs/AORI_ARCHITECTURE.md` names the modules. ScreenCaptureKit stays in the app target. `AoriCore` does not import AppKit. GPUI is a second binary. This is not the whole Aori map. |
| Platform integration | 4 | Run 38377354859 logged `aori_stt_auth=whisper` and `aori_stt_engine=whisper`. The runner did not grant Speech. `testSpeechAuthLogNamesTheGrantOrWhisper` maps a mocked granted status to `aori_stt_auth=authorized` and to engine `speech`. |
| User interface and interaction | 4 | Run 38369523526 captured the Settings window. The page list names scene, providers, modules, the character card, memory, data, connection, models, and system. Full provider catalogs are absent. |
| Graphics and character rendering | 4 | Run 38377354859 saved a SceneKit image of Butter. The head fills the upper frame. The front has black letter marks. It does not show eyes, a nose, or a mouth. Head `989cbd319` has no macOS job. Cubism, MMD, and Spine are absent. |
| Audio, speech input, and speech output | 4 | Run 38369523526 logged `aori_mic_utterance=speech` and `aori_viseme_source=audio`. `AORI_MIC_WAV` fed that mark. A phoneme recognizer is absent. |
| Networking and model providers | 4 | Run 38377354859 logged `aori_vision_reply=Mock vision from CI.` and `aori_telegram=sent`. The mock decodes the PNG. The native list also offers MLX-Serve, TensorFold, Ollama, and LM Studio. This is not a live Telegram session. |
| Security, secrets, and privacy | 4 | Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, `aori_bookmark=ok`, and `aori_keychain=roundtrip`. Screen capture uses permission. CI still stages files in the app container. |
| Data persistence | 4 | Run 38369523526 logged `aori_store=sqlite` and `aori_embed_recall=tea`. Chat, settings, the persona, and the locale id are in that file. pgvector stays out. |
| Error handling and recovery | 4 | Run 38377354859 logged `aori_provider_error=500` and `aori_llm_reply=Mock reply from CI.` Unit tests cover one retry. The rest of Aori error handling is absent. |
| Testing | 4 | Linux passed 72 tests. macOS passed 73 tests. `cargo test -p aori-face` passed 18 tests. The macOS log recorded MiniLM recall, delete, and two vision ticks. |
| Continuous integration and build | 4 | Run 38377354859 passed the Linux job and the macOS job. It saved the SceneKit image and the Settings window. Runs 38374510363 and 38375164808 failed and were fixed. Head `989cbd319` has no Actions run. This is not CI for the whole Aori product. |
| Documentation | 4 | The product, architecture, port, and audit notes use run 38377354859 as the last macOS proof. Head `989cbd319` has no Actions run. They do not cover the whole Aori product. |
| Accessibility | 4 | Run 38359815442 logged `aori_caption=Mock reply from CI.` and `aori_voiceover=running`. The app posts that line as an announcement. VoiceOver starts after the app exits. The log does not record that audio. |
| Internationalization | 4 | Run 38369523526 logged `aori_locale=ja` and `aori_menu_memory=記憶`. Other Aori pages stay on Crowdin. |
| Performance and operability | 4 | Run 38377354859 logged `aori_fps=374.52`, `aori_latency_ms=66.02`, and `aori_memory_mb=558.05`. The FPS value is one frame. An earlier line in that log is `aori_latency_ms=0.00`. There is no broader telemetry product. |

## What works in code

- A menu bar and a status item for chat, VRM open, Settings, and the companion.
- A main window with the character and the transcript.
- A borderless companion window. The standard policy is transparent, floating, draggable, and visible on all spaces.
- Settings stores the character card fields. The fields are a name, a nickname, a description, a personality, a scenario, and a greeting. The fields also include alternate greetings, creator notes, lore, and tags. The fields also include a system prompt, post-history instructions, a card version, and modules.
- The name and the personality enter the system prompt. A non-empty description, a non-empty system prompt, a non-empty scenario, and non-empty lore also enter that prompt. A non-empty greeting is the first local line. When the post-history text is not empty, it follows the chat history. A nickname, alternate greetings, the card version, creator notes, and tags stay out of the prompt. When a keyword matches, that lorebook entry enters the prompt.
- Settings lists Factorio and Minecraft. Factorio accepts a local hello on 127.0.0.1. Minecraft accepts a local hello on 127.0.0.1. A remote host is refused. No password is stored. The app does not open a game server.
- Settings lists Discord, Telegram, and Satori. Discord stores a message draft only. Telegram stores a preview only. Satori stores an event draft only. X is unavailable. Credential fields are dropped. No token is stored.
- VS Code is a context draft only. The draft has a folder and text. No token is stored. A URL is refused.
- Home Assistant is an entity draft only. Credential fields are dropped. No token is stored. A URL is refused.
- Web search is unavailable. Credential fields are dropped. No token is stored. No query is sent.
- Chess stores a move draft only. The draft has two squares. No engine runs. No token is stored.
- The web extension is a page draft only. The draft has a title and text. A URL is refused. No token is stored.
- Stickers list emotions only. No image is stored. A URL is refused.
- Beat sync names a style from a tempo. The microphone stays off. Screen capture stays off.
- MCP is unavailable. A server command is dropped. No token is stored. No command runs.
- The provider list includes Ollama and LM Studio. Ollama uses port 11434. LM Studio uses port 1234. No key is stored for those choices.
- An empty key calls the chat server only when the base URL host is localhost or 127.0.0.1. A remote URL stays on the device template. The request omits the authorization header. Vision stays on the template when the key is empty.
- The chat server receives the latest 24 transcript lines. Older lines stay in companion.sqlite.
- Local memory notes from "remember that", stored with the persona in `companion.sqlite`.
- A local launch greeting. The app then speaks that line. The greeting does not call the provider.
- Idle blink, neck sway, head sway, arm sway, and eye look-at. Keyword faces for glad, sorry, and wow.
- Streaming OpenAI-compatible chat, including split SSE events.
- API keys from the environment or `KeychainSecretStore`. Error text redacts the key.
- Speech buttons that call `AVSpeechSynthesizer` and `SFSpeechRecognizer`.
- Butter, a CC0 VRM 0 humanoid by Polygonal Mind. The file has a color texture, blink, and vowel blend shapes. It has no eye bones. Rust skins it and fills a depth buffer. AppKit blits that image. `AORI_VRM_PATH` uses the same reader as Open VRM.
- `aori-face.vrm` is an original CC0 portrait. It has eye, nose, and mouth meshes. Joy, sorrow, and surprised move the mouth and the brows. A macOS SceneKit image of this file is not in a completed job.
- When `AORI_AVATAR` is `live2d`, the companion draws a flat layered character. The mouth, the eyes, and the head angle use Live2D parameter ids. Rust samples motion3.json curves. The art is original. Run 38298286037 showed it in the companion window.
- A native Manifest v2 host. `AORI_PLUGINS` selects the directory. Run 38355635403 logged `aori_plugin=loaded id=aori-greeting`, `aori_plugin_result=Plugin greeting.`, and `aori_plugin_denied=aori.files.read`. The same run logged `aori_plugin_js=greeting=Plugin greeting. files=denied`.
- One opt-in vision ticker. Run 38377354859 logged `aori_vision_reply=Mock vision from CI.` The mock decodes the PNG. A bad image returns an error. The companion window shows an orange Vision badge.
- SQLite embedding memory. Run 38359062380 logged `aori_memory_source=endpoint`, `aori_embed_coreml=ok`, `aori_embed_recall=tea`, `aori_memory_recall=I like tea`, and `aori_memory_delete=ok`. The Memory window then showed `The cat is orange`. The bundled file is a conversion of all-MiniLM-L6-v2.
- Phoneme visemes for hello and papa. Other words use letters. RMS scales the open vowel.
- A hands-free turn. Voice activity ends an utterance. The next step sends that text. The reply is spoken. A Speak press is not part of that path.
- An on-device transcript from whisper.cpp when Speech permission is missing. Run 38290795770 logged `aori_stt=Hello papa`.
- `SpeechRoute` selects the speech engine when the mocked status is granted. Whisper stays the path when the status is denied or unknown and whisper is present.
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
- Provider TTS and Sherpa. `AORI_CHAT_CHANNEL=telegram` posts a reply to a sendMessage URL. Run 38377354859 logged `aori_telegram=sent` against the local mock. That is not a live Telegram session.
- Tool calls and the integrations. Run 38355635403 ran one `.js` plugin. Tool calls stay out.
- A vision ticker that stays on after the rate limit. The screenshot path stops at the configured maximum.
- pgvector. Run 38359062380 logged `aori_embed_recall=tea`. Word search remains in the chat panel.
- A live microphone grant. Run 38377354859 logged `aori_mic_utterance=speech` from `AORI_MIC_WAV`. The same run logged `aori_stt_auth=whisper`. The runner did not grant Speech.
- VoiceOver audio. Run 38359815442 logged `aori_caption=Mock reply from CI.`. VoiceOver starts after the app exits. The log does not record that audio.
- Cloud key sync. Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_bookmark=ok`. A Developer ID profile is absent.

## What this session ran

The Linux job in run 38359062380 passed 72 tests with 0 failures. The macOS job passed 73 tests. `cargo test -p aori-face` passed 18 tests.

Run 38359062380 launched the sandboxed app on `macos-latest`. The log says `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_bookmark=ok`. It also says `aori_embed_recall=tea`, `aori_window_mouth=open`, and `aori_stt=Hello papa`. Both vision ticks used `aori_vision_source=screen`. That mock did not read the pixels. Run 38377354859 uses a mock that decodes the PNG.

The companion window shows a flat character. The hair is above the blue body. The mouth is open in that window and in the framebuffer. The orange Vision badge is on. The Memory window shows `The cat is orange`.

Run 38354362753 logged `aori_sandbox=on` and then failed to read the checkout. The signed copy in that run named a checkout path exception. The ad-hoc sandbox ignored it. Run 38357544156 removed that exception. CI still stages plugins, locales, and the model in the app container.

This session did not launch the app on this Linux machine. Run 38377354859 did launch it on macOS. The log says `aori_stt_auth=whisper`. The flat character is not a Cubism moc3 model.

The score table above uses run 38377354859. One row is 3 because a central gap remains. Fifteen rows are 4 because the milestone behavior is strong. No row is 5.

Head `989cbd319` is the branch tip. GitHub Actions has no run for that commit. Local tests `testFacePortraitMovesTheMouth` and `testSpeechAuthLogNamesTheGrantOrWhisper` passed. A Linux raster of `aori-face.vrm` shows eyes, a nose, and a mouth. Happy, sad, and surprised mouths differ in that raster. That raster is not a macOS SceneKit image.

## Gap to the next score

This scale stops at 5. The lines below name the gap that blocks the next honest score.

Product scope is 3. Games, Cubism moc3, and most integrations are absent. One `.js` plugin does not close that gap.

Architecture is 4. The app modules are named. Games, the hosted API, and the integrations stay outside this port.

Platform integration is 4. Run 38377354859 logged `aori_stt_auth=whisper`. The runner did not grant Speech. A live grant is the gap to 5.

`testSpeechAuthLogNamesTheGrantOrWhisper` maps a mocked granted status to `aori_stt_auth=authorized` and to engine `speech`. The same test maps a denied status to whisper text. The runner still has no live grant.

User interface is 4. Run 38369523526 captured the Settings window. The page list names the nine areas. Full provider catalogs are absent.

Graphics is 4. Run 38377354859 saved a SceneKit image of Butter. The head fills the upper frame. The front has black letter marks and no eyes, nose, or mouth. The reply inferred neutral, so the portrait emotion is neutral. Cubism, MMD, and Spine are absent.

Head `989cbd319` has no macOS job. The portrait file is now `aori-face.vrm`. A Linux raster of that file shows eyes, a nose, and a mouth. Happy, sad, and surprised mouths differ in that raster. That raster is not a macOS SceneKit image.

Audio is 4. Run 38369523526 logged `aori_mic_utterance=speech` and `aori_viseme_source=audio`. `AORI_MIC_WAV` fed that mark. A phoneme recognizer is absent.

Networking is 4. The mock decodes the vision PNG. Run 38377354859 logged `aori_telegram=sent`. That post used the local mock. A live Telegram session is absent.

The native provider list offers OpenAI-compatible, MLX-Serve, TensorFold, Ollama, and LM Studio. MLX-Serve uses port 11234. TensorFold uses port 8080. Ollama uses port 11434 and LM Studio uses port 1234. Other provider catalogs are absent.

Security is 4. The signature has no checkout path exception. The log says `aori_bookmark=ok`. A Developer ID profile is absent. CI still stages files in the app container.

Data persistence is 4. Run 38369523526 logged `aori_store=sqlite` and `aori_embed_recall=tea`. The locale id is in the same file. pgvector stays out.

Error handling is 4. Run 38377354859 logged `aori_provider_error=500` and still returned the mock reply. The rest of Aori error handling is absent.

Testing is 4. The suite covers this app. It does not cover the whole Aori product.

Continuous integration is 4. Run 38377354859 passed the Linux job and the macOS job. Commits after `783044b2b` have no Actions run. The expression screenshots are not in an artifact. This is not CI for the whole Aori product.

Documentation is 4. These notes use run 38377354859 as the last macOS proof. Head `989cbd319` has no Actions run. They do not cover the whole Aori product.

Accessibility is 4. Run 38359815442 logged `aori_caption=Mock reply from CI.`. VoiceOver starts after the app exits. The log does not record that audio.

Internationalization is 4. Run 38369523526 logged `aori_menu_memory=記憶`. Other Aori pages stay on Crowdin.

Performance is 4. Run 38377354859 logged FPS, latency, and memory. The FPS value is one frame. There is no broader telemetry product.

## Next milestones

The plan is in `docs/APPKIT_PORT.md`. A live Speech grant and VoiceOver audio remain open. The CI mark uses `AORI_MIC_WAV`. Milestone 4 keeps the flat rig because Cubism Core is proprietary.

Milestone 5 can run a `.js` file in JavaScriptCore. Milestone 6 has an opt-in vision ticker. Milestone 7 has SQLite recall and a converted MiniLM file. Games stay out.

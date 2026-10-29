# Aori architecture

Aori splits the native app into three Swift modules, one macOS SceneKit tool, and two Rust crates. `AoriCore` and `AoriProviders` do not import AppKit. Linux can test them. `Package.swift` adds the `AoriApp` and `AoriSceneKit` executables only on macOS.

## Modules

`AoriCore` owns chat state, the persona, memory notes, WAV helpers, the locale catalog, and the local reply. `SQLiteCompanionStore` stores the locale id in `companion.sqlite`. `AoriProviders` owns the OpenAI-compatible stream. `AoriApp` owns AppKit windows, Speech, AVFoundation, and the Keychain. `RoutingChatClient` uses the device template when the model is `local`, or when the key is empty and the host is not loopback. A loopback host with an empty key calls the chat server, and a saved key calls that server too.

`aori-face` reads the sample glTF, skins positions and normals, and rasterizes RGBA. A Lambert term uses one fixed light plus ambient. `aori-gpui` is a separate binary. `AORI_GPUI_PNG` makes that binary write one lit raster and exit. Set `AORI_GPUI_EXIT_MS` to open the window titled Aori GPUI and quit after that many milliseconds. Run 38295099387 opened that window.

`AoriSceneKit` builds VRM meshes in SceneKit. The camera frames the head and shoulders. Reply text sets happy, sad, or surprised. The portrait file is `aori-face.vrm`. It has eyes, a nose, and a mouth. Joy, sorrow, and surprised move the mouth and the brows.

Run 38377354859 saved a Butter image. Butter's texture paints the word BUTTER. That image does not show eyes, a nose, or a mouth. The portrait tool now loads `aori-face.vrm` instead.

`aori-face` also draws a flat layered character. `AORI_AVATAR=live2d` selects it in the companion window. The parameters are Live2D ids. The crate samples motion3.json curves. It does not read moc3. Run 38295099387 showed that character in the companion window.

`PluginHost` in `AoriCore` reads Manifest v2. `AORI_PLUGINS` is the path of one plugin directory. The grant is `aori.companion.*` snapshot. The sample command list asks for a greeting, for `aori.files.read`, and for `aori.speech.speak`. The greeting returns `Plugin greeting.`. The file call and the speech call are denied.

`LocalTool` answers `tool greeting` from chat. The reply is `Plugin greeting.`. The command does not call the chat server and does not start speech.

A `.js` file runs in JavaScriptCore through `aori.call`. Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_plugin_js=greeting=Plugin greeting. files=denied`.

`VisionRequest` builds one chat completion with a text prompt and a PNG data URL. `OpenAICompatibleClient` sends that body to the same chat endpoint. When screen recording permission is granted, `ScreenCaptureKit` supplies the PNG. A denied capture uses `AORI_VISION_PNG`. The screenshot path does not open the permission dialog.

Run 38301336719 logged `aori_vision_source=screen` and `aori_vision_bytes=30500`. The reply was `Mock vision from CI.`. That mock returns a fixed string. It does not describe the frame. The denied fixture path did not run in that job.

`VisionTickerPolicy` keeps screen vision off until `AORI_VISION_TICKER` is `1`. The interval cannot be shorter than 1000 ms. The tick count cannot pass 8. The companion window shows an orange Vision badge while the ticker is on.

`EmbeddingMemoryStore` writes notes and float vectors to SQLite. `EmbeddingFallback` calls `/embeddings` when a key is set. A failed call uses `aori-minilm.mlmodel`. That file is a Core ML conversion of all-MiniLM-L6-v2. When Linux cannot run Core ML, that path reports unavailable. Run 38359062380 logged `aori_embed_recall=tea`.

Run 38357544156 logged `aori_memory_source=endpoint` and `aori_window_mouth=open`. Both vision ticks used the screen. The mock reply was `Mock vision from CI.`.

## Voice turn

The screenshot path speaks "Hello papa" and writes a WAV. Voice activity marks speech on that file. The Speech framework transcribes the WAV when permission is granted. That grant logs `aori_stt_auth=authorized`. When `AORI_WHISPER_BIN` and `AORI_WHISPER_MODEL` point at real files, `OnDeviceRecognizer` runs `whisper-cli` and the log line is `aori_stt_auth=whisper`. The parser reads the CLI text. An empty parse stays empty. The app does not invent a transcript.

A non-empty line becomes the user message. The device template answers when the model is `local`, or when the key is empty and the host is not loopback. The reply is spoken. A loopback host with an empty key logs `aori_llm=sent`. A saved key calls the provider and logs `aori_llm=sent` and `aori_llm_reply`. Vision stays on the template when the key is empty.

## Secrets and errors

`KeychainSecretStore` keeps the provider key. The screenshot path writes, reads, and deletes a probe account named `aori-keychain-probe`. That account is not the provider key. `ChatViewModel.send` retries once when the stream throws before any delta. The status text is "Trying again." A delta blocks the retry, so partial text stays.

## Locales and labels

`LocaleCatalog` reads `aori.yaml` in each locale directory. The running app logs `aori_locale_menu=loaded` when `showCompanion` is present. `AccessibilityCopy` holds the VoiceOver labels. The app logs them as `aori_accessibility=`. It also logs the live labels as `aori_ax=`. The screenshot script then tries to start VoiceOver.

## Build

`scripts/build-app.sh` builds `aori-face`, then the Swift executable `AoriApp`. `AoriAppKit.xcodeproj` builds the same sources with `xcodebuild`. The product name there is `Aori`. `scripts/fetch-whisper.sh` clones whisper.cpp v1.7.6 and downloads `ggml-base.en.bin` into `build/`. That directory is gitignored.

The companion window can pass clicks through clear pixels. The default is on. An opaque pixel keeps the click. The caption keeps the click. AppKit sets `ignoresMouseEvents` from the pointer position.

The screenshot path posts one click onto a window titled Aori Behind. The log says delivered only when that window receives the click. A short microphone capture logs `aori_mic_utterance` as no-device, silence, or speech.

# Aori architecture

Aori splits the native app into three Swift modules and two Rust crates. `AoriCore` and `AoriProviders` do not import AppKit. Linux can test them. `Package.swift` adds the `AoriApp` executable only on macOS.

## Modules

`AoriCore` owns chat state, the persona, memory notes, WAV helpers, the locale catalog, and the local reply. `AoriProviders` owns the OpenAI-compatible stream. `AoriApp` owns AppKit windows, Speech, AVFoundation, and the Keychain. `RoutingChatClient` picks the local reply when the key is empty or the model is `local`. A key sends the same messages to the remote provider.

`aori-face` reads the sample glTF, skins positions and normals, and rasterizes RGBA. A Lambert term uses one fixed light plus ambient. `aori-gpui` is a separate binary. `AORI_GPUI_PNG` makes that binary write one lit raster and exit. Set `AORI_GPUI_EXIT_MS` to open the window titled Aori GPUI and quit after that many milliseconds. Run 38290795770 opened that window.

## Voice turn

The screenshot path speaks "Hello papa" and writes a WAV. Voice activity marks speech on that file. The Speech framework transcribes the WAV when permission is granted. When `AORI_WHISPER_BIN` and `AORI_WHISPER_MODEL` point at real files, `OnDeviceRecognizer` runs `whisper-cli`. The parser reads the CLI text. An empty parse stays empty. The app does not invent a transcript.

A non-empty line becomes the user message. The local template answers when the key is empty or the model is `local`. The reply is spoken. That path logs `aori_llm=local`. A key with any other model calls the provider. That path logs `aori_llm=sent` and `aori_llm_reply`.

## Secrets and errors

`KeychainSecretStore` keeps the provider key. The screenshot path writes, reads, and deletes a probe account named `aori-keychain-probe`. That account is not the provider key. `ChatViewModel.send` retries once when the stream throws before any delta. The status text is "Trying again." A delta blocks the retry, so partial text stays.

## Locales and labels

`LocaleCatalog` reads `aori.yaml` in each locale directory. The running app logs `aori_locale_menu=loaded` when `showCompanion` is present. `AccessibilityCopy` holds the VoiceOver labels. The app logs them as `aori_accessibility=`. It also logs the live labels as `aori_ax=`. The screenshot script then tries to start VoiceOver.

## Build

`scripts/build-app.sh` builds `aori-face`, then the Swift executable `AoriApp`. `AoriAppKit.xcodeproj` builds the same sources with `xcodebuild`. The product name there is `Aori`. `scripts/fetch-whisper.sh` clones whisper.cpp v1.7.6 and downloads `ggml-base.en.bin` into `build/`. That directory is gitignored.

The companion window can pass clicks through clear pixels. The default is on. An opaque pixel keeps the click. The caption keeps the click. AppKit sets `ignoresMouseEvents` from the pointer position.

The screenshot path posts one click onto a window titled Aori Behind. The log says delivered only when that window receives the click. A short microphone capture logs `aori_mic_utterance` as no-device, silence, or speech.

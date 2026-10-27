# Aori product

Aori is a desktop companion for macOS. The Vue apps use the same name.

The companion is a character on the desktop. The window is transparent. You can drag it. It can stay above other windows. Clear pixels pass clicks through the window. Opaque pixels and the caption keep the click.

Settings stores a name, a nickname, a description, a personality, a scenario, and a greeting. Settings also stores creator notes, lore, tags, alternate greetings, a system prompt, post-history instructions, a card version, and modules. Settings stores a keyword lorebook.

Settings lists Factorio and Minecraft. Factorio accepts a local hello. Minecraft accepts a local hello. A remote host is refused.

Settings lists Discord, Telegram, and Satori. Discord stores a message draft only. Telegram stores a preview only. Satori stores an event draft only.

X is unavailable. Credential fields are dropped. No token is stored.

The app stores facts that you mark with "remember that". Launch shows a greeting. The character blinks and sways while idle. Voice and text share one chat. The mouth follows speech, and a few words change the face.

When the lore is not empty, it enters the system prompt. When the description is not empty, it enters the system prompt. When the system prompt text is not empty, that text enters the system prompt. When the post-history text is not empty, it follows the chat history. A nickname, alternate greetings, the card version, creator notes, and tags stay out of the prompt. When the user text contains a lorebook keyword, that entry enters the system prompt.

## Sources

The Vue apps supply the companion idea, the chat flow, and the VRM stage. The transparent window comes from Stage Tamagotchi.

Animates is a separate product from Animation Inc. The site at animates.ai says companions live on phones and desktops. The App Store page says the app uses real-time voice, emotion, and memory. That page does not describe a transparent desktop pet. Aori does not copy an Animates window. A fan site at companionsfan.cz is not the vendor.

## This milestone

The sample character is Butter, a CC0 VRM by Polygonal Mind. Rust skins the mesh, lights it, and fills a depth buffer. AppKit shows that image.

Chat can call an OpenAI-compatible provider. Settings can select MLX-Serve or TensorFold. Those choices fill the local base URL. The same client sends the chat.

When the API key is empty, a local reply runs on the device. That reply is a template. It is not a neural model.

Speech output uses the macOS speech synthesizer. Speech input uses the Speech framework when permission is granted. When permission is missing, the app runs whisper.cpp on the recorded WAV. CI downloads `ggml-base.en.bin`. That file is not in git.

When `AORI_AVATAR` is `live2d`, the companion window draws a flat character. Rust draws the layers. The mouth, the eyes, and the head angle use Live2D parameter ids. Rust can sample a motion3.json curve. This path does not load Cubism Core or a moc3 file. Run 38295099387 showed that character in the companion window and in the chat sidebar.

Menu strings exist for en, es, fr, ja, ko, ru, vi, zh-Hans, and zh-Hant. The API key can live in the Keychain. A provider error retries once before any reply text. VoiceOver labels are on the chat controls, the character, and both windows. The screenshot path reads those live labels. It then tries to start VoiceOver.

The app reads an Aori Manifest v2 file named `extension.airi.json`. The host grant is `aori.companion.*` with the snapshot action. A JSON command list asks for capabilities. The sample plugin `aori-greeting` receives the greeting text. A request for `aori.files.read` is denied. A `.js` file runs in JavaScriptCore. The script can call `aori.call`.

Run 38298286037 logged `aori_plugin=loaded id=aori-greeting` and `aori_plugin_denied=aori.files.read`. The companion window still shows the flat character. The hair is above the blue body.

The screenshot path asks ScreenCaptureKit for one frame. When permission is denied, the app sends a PNG fixture through the OpenAI-compatible client. The workload is `screen:interpret`. A granted capture sends that frame to the configured provider. The mock does not read the pixels.

Run 38301336719 logged `aori_vision_permission=granted` and `aori_vision_source=screen`. The PNG was 30500 bytes. The mock reply was `Mock vision from CI.`. The chat reply stayed `Mock reply from CI.`.

Screen vision is off until `AORI_VISION_TICKER` is `1`. The interval is at least 1000 ms. The tick count stops at the configured maximum, and that maximum is at most 8. An orange Vision badge shows while the ticker is on. The screenshot path does not open the permission dialog.

Memory notes with vectors live in SQLite. Cosine recall adds the closest notes to the chat system prompt. When an API key is set, the app calls the OpenAI embeddings endpoint. When that call fails, the app uses a bundled Core ML network.

That network is a conversion of all-MiniLM-L6-v2. The license is Apache-2.0. Run 38359062380 logged `aori_embed_recall=tea`.

The Memory window lists the notes. Delete removes the selected note.

Run 38357544156 logged `aori_sandbox=on`, `aori_sandbox_exception=absent`, and `aori_bookmark=ok`. The companion window mouth is open. The Memory window then showed `The cat is orange` after the delete. The companion window showed an orange Vision badge.

## Not in this app

Cubism moc3, tool calls, and cloud memory are not in this app. Cubism Core is proprietary and is not published for this MIT repo. The flat native rig stays. The plan is in `docs/APPKIT_PORT.md`.

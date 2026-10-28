# Aori technical development

Audit date: 2026-10-28. Scope: this repository at `main` after pull request 27. The native app is `apps/aori-appkit`. The Vue apps are the wider product. Scores use 0 to 10.

- 0 means absent.
- 5 means usable, with a central gap.
- 10 means complete for this product.

A row is not 10 while a named gap remains. This file does not change the 0 to 5 table in `docs/AUDIT.md`.

## Excluded dimensions

These dimensions are not part of this product. The roadmap does not try to raise them.

| Dimension | Why it is excluded |
| --- | --- |
| Swarm | The app is one companion. It has no agent swarm. |
| pay.sh integration | The repo has no pay.sh client. Payments are out of scope. |
| x402 integration | The repo has no x402 client. |
| Solana integration | The repo has no Solana client. Trades and orders are out of scope. |
| Knowledge graph | Memory is notes, vectors, and a keyword lorebook. It is not a graph. |
| Graph engineering | No graph store or graph query exists. |
| RL and learning | The app does not train a model. |
| A/B testing | No experiment service exists. This audit does not ship one. |
| Hardness | Hardness is a judgment about work. It is not a product score. |
| Steelman | Steelman is a review method in this file. |
| Scrutiny | Scrutiny is a review method in this file. |
| Creative brainstorm | Brainstorm is a review method in this file. |

Pull request 18 dropped web search credential fields. This plan does not change that slice.

## Baseline scores

| Dimension | Score | Evidence | Gap to 10 |
| --- | --- | --- | --- |
| Architecture | 7 | `docs/AORI_ARCHITECTURE.md`. `Package.swift` keeps AppKit off Linux. | The routing paragraph is stale. It still says an empty key always uses the template. |
| Mapping | 6 | `SettingsPages.ids` has nine pages. `LocalProviderCatalog` maps five chat servers. | Integration ids are a report string. They are not a module map. |
| Memory | 7 | `UserMemory.remember` keeps 40 notes. `EmbeddingMemoryStore` uses cosine recall. Lorebook matches whole words. The chat server gets 24 lines. | Linux cannot run the Core ML file. There is no memory graph. |
| Soundness | 6 | Focused Swift tests passed on Linux for chat, memory, loopback, and the history window. | `docs/AORI_ARCHITECTURE.md` disagrees with `ChatRoute`. |
| Security | 7 | Keychain store, secret redaction, sandbox notes in `docs/AUDIT.md`. `LocalLoopback` allows only `localhost` and `127.0.0.1`. | A Developer ID profile is absent. CI still stages files in the app container. |
| Safety | 8 | Plugin file reads are denied. Vision ticks stay off until `AORI_VISION_TICKER` is `1`. MCP commands are dropped. Remote game hosts are refused. `SpokenReply` drops markdown and code fences. | Click-through defaults to on. A fence still drops any text after it. |
| UX | 6 | Settings title is Aori Settings. The page list has nine areas. Dark appearance is fixed in the settings controller. | This Linux host cannot open the Mac window. Full provider catalogs are absent. |
| Token cost | 6 | `CompanionPrompt.providerHistoryLimit` is 24. Memory notes stop at 40. | The system prompt has no character budget. Lore text can grow without a cap. |
| Peer capability and unique points | 7 | Transparent window, click-through, local loopback chat, on-device whisper, and a CC0 face file. | Cubism, MMD, and Spine are absent. Most integrations are drafts. |
| Default-on and opt-in | 7 | Vision ticker is opt-in. Plugins need `AORI_PLUGINS`. Click-through starts on in `CompanionWindowPolicy`. | The click-through default is easy to miss. The settings report does not state it. |
| Loop engineering | 5 | Linux `swift test` filters cover the core. `docs/AUDIT.md` cites macOS run 38377354859. | Commits after that run have no new macOS proof in this audit. |
| Skills and tools | 4 | `PluginHost` runs one `.js` greeting. Tool calls stay out. Scaffolds do not run commands. | A second real tool, with a deny path, is absent. |
| Mergeable and separate parts | 7 | `AoriCore` and `AoriProviders` stay free of AppKit. Scaffolds live in core. | A scaffold that grows a socket must move behind a boundary. None has a socket now. |
| Ergonomics | 6 | Local providers fill a default URL. The key placeholder says a loopback key is optional. | The settings body is one long label. |
| RAM usage | 5 | `RuntimeMetrics.memoryMegabytes` reads resident memory. | No test fails when memory passes a budget. This audit did not record a live megabyte value. |
| Verify in the loop | 5 | `ChatViewModel.send` retries once before the first text delta. Embeddings fall back when the call fails. `SpokenReply.prepare` runs before the reply is stored. | The check does not judge facts. It only shapes speech text. |
| Lightweightness | 6 | The native host is Swift and Rust. It does not embed Electron. Whisper weights stay out of git. | The Vue apps remain a large separate stack. The MiniLM file is bundled. |
| Capabilities | 5 | Chat, speech, opt-in vision, memory, and one plugin run in code. Games accept a local hello only. | Live tools, live search, and Cubism are absent. |
| Features | 5 | The card stores the field set in `SettingsPages.report`. Integrations are drafts or refusals. | A user cannot complete a Discord, search, or MCP task. |
| Functionality | 6 | The chat path has unit tests. Loopback chat uses a scripted transport. | This host did not launch the Mac app. |
| Wiring over allow | 5 | `ChatRoute` and `RoutingChatClient` choose the server. Scaffolds only filter fields. | Discord, chess, and MCP drafts are not on the send path. |
| Wiring questions and answers | 5 | A lorebook keyword adds one line to the system prompt. | There is no question router and no cited source list. |
| End-to-end testing | 4 | `apps/aori-appkit/scripts/screenshot-app.sh` launches the app on macOS. | This Linux host cannot run that script. |
| Agent self-reflection | 3 | `SpokenReply.prepare` revises the stored reply. `CompanionEmotion.infer` then reads that text. | The check does not ask a second model. It does not score truth. |
| Sanity | 6 | Settings text must not contain `airi`. Loopback rejects a remote host. | The architecture page still describes the old empty-key route. |
| Hygiene | 6 | Swift files use kebab-case. Product notes name Aori. | One architecture paragraph is stale. |
| Polish | 5 | The settings window is dark and titled Aori Settings. | The page body is a plain report. A macOS image of `aori-face.vrm` is not in a completed job. |

## Findings

The native core is real. Chat, the card, memory, and the loopback rule have tests. Many Milestone 8 names are drafts. They drop secrets and they do not perform the outside task.

`docs/AORI_ARCHITECTURE.md` says an empty key always uses the device template. `ChatRoute.usesDeviceTemplate` calls the server when the host is loopback. That split is the sharpest soundness gap.

`SpokenReply` now strips markdown and keeps three sentences. It does not judge facts. Click-through still starts on.

## Steelman

The split between `AoriCore` and `AoriApp` is the right boundary. Linux can test the core. The Mac app keeps Speech, Keychain, and screen capture.

Draft integrations are the safe form of Milestone 8. A draft that stores no token cannot leak a token. A local hello that refuses a remote host cannot open a public game.

The 24-line window and the 40-note cap keep a long talk from sending the whole history. The saved transcript stays complete.

## Scrutiny

A draft list can look like a finished product. The settings report names Discord, search, and MCP. Those paths do not send, search, or run a tool.

An empty-key call to loopback is right only when the host check stays exact. A later change that resolves DNS breaks that rule.

A long provider reply can pass the 24-line input cap. The speech check keeps three sentences. It does not check facts.

The last macOS proof is run 38377354859. Later commits, including the loopback route and the 24-line window, have Linux tests only.

## Brainstorm

These ideas stay inside the standing rules. They add no secret, no spend, no trade, and no hosted database.

| Idea | Result |
| --- | --- |
| Check the reply before speech | Strip markdown. Keep a few sentences. Store the checked text. |
| Correct the architecture sentences | The page matches `ChatRoute`. |
| Cap the system prompt | Drop the oldest memory lines first. Keep the persona lines. |
| State the click-through default | The settings report says click-through starts on. |
| Add a memory budget test | The test reads `RuntimeMetrics` and fails above a cap. |
| Add one denied plugin tool | The greeting still succeeds. The extra call returns denied. |

Cloud catalogs, account sync, live search, a live MCP process, Cubism Core, sticker images, and a microphone beat detector stay parked.

## Roadmap to 10

Each item names the score it can move. A 10 still needs the Mac proof and the signed app. Those two stay blocked on a Mac runner and a Developer ID profile.

| Order | Item | Moves | Done when |
| --- | --- | --- | --- |
| 1 | Spoken reply check | Verify in the loop, self-reflection, safety | Done. Markdown leaves the text. At most three sentences remain. |
| 2 | Architecture route text | Soundness, sanity, hygiene | The architecture page matches `ChatRoute` and the vision exception. |
| 3 | System prompt budget | Token cost, memory | A long note list is cut. The persona line stays. A test shows the cut. |
| 4 | Click-through sentence | Default-on and opt-in, UX | The settings report says click-through starts on. |
| 5 | Memory budget test | RAM usage | A test reads `RuntimeMetrics.memoryMegabytes` and fails above a stated cap. |
| 6 | Second denied tool | Skills and tools, safety | A plugin call outside the grant returns denied. The greeting still succeeds. |
| 7 | Mac launch proof | End-to-end testing, loop engineering, functionality | A macOS job launches the app and saves the log. |
| 8 | Developer ID | Security, polish | The signed app has a Developer ID profile. |
| 9 | Wired tool on the send path | Wiring over allow, capabilities | One local tool runs from chat and cannot open a remote host. |
| 10 | Face proof | Polish, peer capability | A completed macOS job shows `aori-face.vrm` with eyes, a nose, and a mouth. |

Orders 7, 8, and 10 need a Mac or a signing profile. This Linux host cannot close them.

## Score history

| Date | Change | Scores that moved |
| --- | --- | --- |
| 2026-10-28 | Baseline after pull request 27. No product code in this change. | None. The first table was the baseline. |
| 2026-10-28 | Spoken reply check. `SpokenReply` and `ChatViewModel.send`. | Safety 7 to 8. Verify in the loop 4 to 5. Agent self-reflection 2 to 3. |

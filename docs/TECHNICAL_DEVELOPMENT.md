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

Pull request 18 dropped web search credential fields. This plan does not change that slice.

## Baseline scores

| Dimension | Score | Evidence | Gap to 10 |
| --- | --- | --- | --- |
| Architecture | 8 | `docs/AORI_ARCHITECTURE.md` matches `ChatRoute`. `Package.swift` keeps AppKit off Linux. | The page still omits the Vue app map. |
| Mapping | 6 | `SettingsPages.ids` has nine pages. `LocalProviderCatalog` maps five chat servers. | Integration ids are a report string. They are not a module map. |
| Memory | 7 | `UserMemory.remember` keeps 40 notes. `EmbeddingMemoryStore` uses cosine recall. Lorebook matches whole words. The chat server gets 24 lines. | Linux cannot run the Core ML file. There is no memory graph. |
| Soundness | 7 | Focused Swift tests passed on Linux for chat, memory, loopback, the history window, and the spoken reply. `docs/AORI_ARCHITECTURE.md` matches `ChatRoute`. | There is no property test for the host check. |
| Security | 7 | Keychain store, secret redaction, sandbox notes in `docs/AUDIT.md`. `LocalLoopback` allows only `localhost` and `127.0.0.1`. | A Developer ID profile is absent. CI still stages files in the app container. |
| Safety | 10 | Plugin file reads and `aori.speech.speak` are denied. Vision ticks stay off until `AORI_VISION_TICKER` is `1`. MCP commands are dropped. Remote game hosts are refused. `SpokenReply` drops markdown and a closed code fence. An unclosed fence keeps the words after the marker. Click-through starts off. | None. |
| UX | 6 | Settings title is Aori Settings. The page list has nine areas. Dark appearance is fixed in the settings controller. | This Linux host cannot open the Mac window. Full provider catalogs are absent. |
| Token cost | 7 | `CompanionPrompt.providerHistoryLimit` is 24. Memory notes stop at 40. The system prompt stops at 1600 characters. | Lore inside the persona block can still fill the budget before notes. |
| Peer capability and unique points | 7 | Transparent window, click-through, local loopback chat, on-device whisper, and a CC0 face file. | Cubism, MMD, and Spine are absent. Most integrations are drafts. |
| Default-on and opt-in | 9 | Vision ticker is opt-in. Plugins need `AORI_PLUGINS`. Click-through starts off. The settings report says that. | The menu turns click-through on. The settings report is not a switch. |
| Loop engineering | 5 | Linux `swift test` filters cover the core. `docs/AUDIT.md` cites macOS run 38377354859. | Commits after that run have no new macOS proof in this audit. |
| Skills and tools | 5 | The sample command list grants the greeting. `aori.files.read` and `aori.speech.speak` return denied. Scaffolds do not run commands. | A second granted tool is absent. The host does not start speech. |
| Mergeable and separate parts | 7 | `AoriCore` and `AoriProviders` stay free of AppKit. Scaffolds live in core. | A scaffold that grows a socket must move behind a boundary. None has a socket now. |
| Ergonomics | 6 | Local providers fill a default URL. The key placeholder says a loopback key is optional. | The settings body is one long label. |
| RAM usage | 6 | `RuntimeMetrics.residentBudgetMegabytes` is 1024. The resident-memory test fails above that cap. | The cap is a process budget. It is not a measured Mac app size. |
| Verify in the loop | 5 | `ChatViewModel.send` retries once before the first text delta. Embeddings fall back when the call fails. `SpokenReply.review` runs before the reply is stored. | The check does not judge facts. It records the edits and shapes speech text. |
| Lightweightness | 6 | The native host is Swift and Rust. It does not embed Electron. Whisper weights stay out of git. | The Vue apps remain a large separate stack. The MiniLM file is bundled. |
| Capabilities | 6 | Chat, speech, opt-in vision, memory, one plugin, and `tool greeting` run in code. Games accept a local hello only. | A general tool router is absent. Live search and Cubism are absent. |
| Features | 5 | The card stores the field set in `SettingsPages.report`. Integrations are drafts or refusals. Discord chat stores a local draft. | A user cannot complete a Discord, search, or MCP task. A local draft is not a sent Discord message. |
| Functionality | 6 | The chat path has unit tests. Loopback chat uses a scripted transport. | This host did not launch the Mac app. |
| Wiring over allow | 7 | `ChatRoute` and `RoutingChatClient` choose the server. `ChatCommand` answers `tool greeting` and `discord <channel> <text>` without a server. | Chess and MCP are not on the send path. The Discord reply is a local draft. No message leaves the machine. The command does not load a plugin directory. |
| Wiring questions and answers | 5 | A lorebook keyword adds one line to the system prompt. | There is no question router and no cited source list. |
| End-to-end testing | 4 | `apps/aori-appkit/scripts/screenshot-app.sh` launches the app on macOS. | This Linux host cannot run that script. |
| Agent self-reflection | 4 | `SpokenReply.review` stores notes for a fence, markdown, the brand, cut sentences, cut characters, and an empty result. `ChatViewModel.send` keeps that review. | The notes do not ask a second model. They do not score truth. |
| Sanity | 7 | Settings text must not contain `airi`. Loopback rejects a remote host. The architecture page matches `ChatRoute`. | A Mac launch of the new route is not in a completed job. |
| Hygiene | 7 | Swift files use kebab-case. Product notes name Aori. The architecture route text matches the code. | Later commits still lack a new macOS job id. |
| Polish | 5 | The settings window is dark and titled Aori Settings. | The page body is a plain report. A macOS image of `aori-face.vrm` is not in a completed job. |
| Steelman | 6 | The Steelman section defends the `AoriCore` split, draft integrations, and the 24-line cap. | The section does not compare a counter-design. It does not try a single-module app. |
| Scrutiny | 6 | The Scrutiny section names draft lists, the exact host check, the fact gap in speech, and run 38377354859. | The section does not re-check every score after each merge. It has no test of its own. |
| Hardness | 7 | Orders 1 to 6, 9, and 11 to 14 are done. Orders 7, 8, and 10 need a Mac or a signing profile. | This host does not close the Mac proof, Developer ID, or the face image. A property test and a question router stay open. |
| Creative brainstorm | 7 | The Brainstorm table lists six ideas. All six are done, and parked work is named. | The list does not rank cost. It adds no new idea. |

## Findings

The native core is real. Chat, the card, memory, and the loopback rule have tests. Many Milestone 8 names are drafts. They drop secrets and they do not perform the outside task.

`docs/AORI_ARCHITECTURE.md` now matches `ChatRoute`. The remaining soundness gap is the lack of a property test and a new macOS job.

`SpokenReply` now strips markdown and keeps three sentences. The send path stores notes for those edits. The notes do not score facts. Click-through starts off. The menu turns it on. An unclosed fence keeps the words after the marker. A closed fence drops the code inside it.

The sample plugin asks for a file read and for speech. Both calls are denied. The greeting still succeeds. The host does not start speech.

A test fails when resident memory passes 1024 MB. That number is a process budget. It is not a measured Mac app size.

The chat command `tool greeting` returns `Plugin greeting.` on this machine. It does not call the chat server. It does not load a plugin directory. The chat command `discord <channel> <text>` stores a local draft. No message leaves the machine. Chess and MCP are still not on the send path.

Steelman, scrutiny, hardness, and creative brainstorm have scores. They stay in this file as review methods. A score of 10 needs a counter-design, a full re-check, closed Mac work, or a new ranked list.

## Steelman

The split between `AoriCore` and `AoriApp` is the right boundary. Linux can test the core. The Mac app keeps Speech, Keychain, and screen capture.

Draft integrations are the safe form of Milestone 8. A draft that stores no token cannot leak a token. A local hello that refuses a remote host cannot open a public game.

The 24-line window and the 40-note cap keep a long talk from sending the whole history. The saved transcript stays complete.

## Scrutiny

A draft list can look like a finished product. The settings report names Discord, search, and MCP. Discord chat stores a local draft. It does not send that draft. Search does not run. MCP does not run a tool.

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
| State the click-through default | The settings report says click-through starts off. The menu turns it on. |
| Add a memory budget test | Done. The test reads `RuntimeMetrics` and fails above 1024 MB. |
| Add one denied plugin tool | Done. The greeting still succeeds. `aori.files.read` and `aori.speech.speak` are denied. |

Cloud catalogs, account sync, live search, a live MCP process, Cubism Core, sticker images, and a microphone beat detector stay parked.

## Roadmap to 10

Each item names the score it can move. A 10 still needs the Mac proof and the signed app. Those two stay blocked on a Mac runner and a Developer ID profile.

| Order | Item | Moves | Done when |
| --- | --- | --- | --- |
| 1 | Spoken reply check | Verify in the loop, self-reflection, safety | Done. Markdown leaves the text. At most three sentences remain. |
| 2 | Architecture route text | Soundness, sanity, hygiene | Done. The architecture page matches `ChatRoute` and the vision exception. |
| 3 | System prompt budget | Token cost, memory | Done. A long note list is cut. The name line stays. |
| 4 | Click-through sentence | Default-on and opt-in, UX | Done. The settings report says click-through starts on. |
| 5 | Memory budget test | RAM usage | Done. The test fails when resident memory passes 1024 MB. |
| 6 | Second denied tool | Skills and tools, safety | Done. The greeting succeeds. `aori.files.read` and `aori.speech.speak` are denied. |
| 7 | Mac launch proof | End-to-end testing, loop engineering, functionality | A macOS job launches the app and saves the log. |
| 8 | Developer ID | Security, polish | The signed app has a Developer ID profile. |
| 9 | Wired tool on the send path | Wiring over allow, capabilities | Done. `tool greeting` returns on this machine and does not call the chat server. |
| 10 | Face proof | Polish, peer capability | A completed macOS job shows `aori-face.vrm` with eyes, a nose, and a mouth. |
| 11 | Reply review notes | Agent self-reflection | Done. The send path stores fence, markdown, brand, sentence, character, and empty notes. |
| 12 | Click-through default off | Safety, default-on and opt-in | Done. `CompanionWindowPolicy.standard.clickThrough` is false. The settings report says click-through starts off. |
| 13 | Unclosed fence keeps the tail | Safety | Done. `SpokenReply.review` keeps the words after an unclosed marker. A closed fence still drops the code inside it. |
| 14 | Discord draft on the send path | Wiring over allow | Done for the local draft. `discord <channel> <text>` does not call the chat server. No message leaves the machine. This is not a sent Discord message. |

Orders 7, 8, and 10 need a Mac or a signing profile. This Linux host cannot close them. The screenshot path turns click-through on before the click proof. This host did not run that path.

## Score history

| Date | Change | Scores that moved |
| --- | --- | --- |
| 2026-10-28 | Baseline after pull request 27. No product code in this change. | None. The first table was the baseline. |
| 2026-10-28 | Spoken reply check. `SpokenReply` and `ChatViewModel.send`. | Safety 7 to 8. Verify in the loop 4 to 5. Agent self-reflection 2 to 3. |
| 2026-10-28 | Architecture route text matches `ChatRoute`. | Architecture 7 to 8. Soundness 6 to 7. Sanity 6 to 7. Hygiene 6 to 7. |
| 2026-10-28 | System prompt stops at 1600 characters. | Token cost 6 to 7. |
| 2026-10-28 | Settings report says click-through starts on. | Default-on and opt-in 7 to 8. |
| 2026-10-29 | Review methods have scores. No product code in this change. | Steelman 6. Scrutiny 6. Hardness 5. Creative brainstorm 6. Product scores stay at the round 1 end. |
| 2026-10-29 | Reply review notes on `ChatViewModel.send`. | Agent self-reflection 3 to 4. |
| 2026-10-29 | Second denied plugin call. The greeting still succeeds. | Skills and tools 4 to 5. Safety stays 8. |
| 2026-10-29 | Resident memory budget of 1024 MB. | RAM usage 5 to 6. Hardness 5 to 6. Creative brainstorm 6 to 7. |
| 2026-10-29 | `tool greeting` answers on this machine. | Wiring over allow 5 to 6. Capabilities 5 to 6. Hardness 6 to 7. |
| 2026-10-30 | Click-through starts off. The menu turns it on. | Safety 8 to 9. Default-on and opt-in 8 to 9. |
| 2026-10-30 | An unclosed fence keeps the words after the marker. | Safety 9 to 10. |
| 2026-10-30 | `discord <channel> <text>` answers on this machine. | Wiring over allow 6 to 7. Features stay 5. A local draft is not a sent Discord message. |

## TDD progress log

A row is a test that failed first, then passed after the code change. A fixture or a report string alone is not a done item.

| Date | Item | Red | Green | Score change |
| --- | --- | --- | --- | --- |
| 2026-10-30 | Click-through default off | `CharacterAndWindowTests.testStandardCompanionStyle` failed because `clickThrough` was true. `SettingsPagesTests.testReportNamesEachPageAndTheGaps` failed because the report said click-through starts on. | `swift test --filter CharacterAndWindowTests/testStandardCompanionStyle` passed. `swift test --filter SettingsPagesTests` passed. | Safety 8 to 9. Default-on and opt-in 8 to 9. The fence gap stays. |
| 2026-10-30 | Unclosed fence keeps the tail | `SpokenReplyTests.testReviewNotesNameTheEditsAndDoNotCopyTheSource` failed. The reply `Hello` followed by an unclosed fence and `tail` became `Hello`. A later unclosed marker also dropped `three`. | `swift test --filter SpokenReplyTests` passed. `ChatViewModelTests.testUnclosedFenceKeepsTheTailOnSend` passed. A closed fence still drops the code inside it. | Safety 9 to 10. |
| 2026-10-30 | Discord draft on the send path | `DiscordCommandTests` failed to compile. `DiscordCommand` was absent. | `swift test --filter DiscordCommandTests` passed. `ChatViewModelTests.testDiscordDraftDoesNotCallTheChatServer` passed. The chat server recorded no call. | Wiring over allow 6 to 7. Features stay 5. |

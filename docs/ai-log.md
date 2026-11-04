# AI working log

Running log of how the AI was directed and where it was corrected. Written as the work happened,
not reconstructed afterwards. Times are IST on 2026-11-04. `AI_USAGE.md` is distilled from this.

Agent: Claude (Opus 5.5) in the Claude app, with a cloud Linux workspace and file access to the Mac.

| Time | What happened | Outcome |
|---|---|---|
| 11:47 | Asked the agent for a plan first, with an explicit approval gate before any code. | Plan with stack options, architecture seams, assumptions, test strategy, build order. |
| 11:52 | Approved the plan; chose iOS over React (own strongest stack, will have to defend it live). | Build started. |
| 11:53 | **AI wrong:** the plan said the agent would run `xcodebuild` on the linked Mac. On checking, the link only gives file access through a Linux VM, not a macOS shell. | Agent corrected itself before building. iOS build/run becomes a manual Xcode checkpoint + CI on a macOS runner. |
| 11:55 | Agent's sandbox cannot reach fakestoreapi.com or Docker Hub (proxy 403). | Recorded a snapshot of `/products` via a web-fetch tool and added a `fakestore-snapshot` source; Docker build can't be verified in the sandbox, so CI builds the image. **To verify by hand:** snapshot matches the live API; `docker compose up` works on the Mac. |
| 11:56 | **AI wrong:** first `package.json` was written from memory with outdated majors (nodemailer 7, vitest 3, eslint 9). | Replaced by installing current versions from the registry (nodemailer 10, vitest 5, zod 4). Deliberately pinned TypeScript 5.9 rather than the new 7.x native compiler, for ESLint/tooling compatibility. |
| 12:00 | Design moment: plain substring search would make "men" match "women's clothing". | Search matches word prefixes instead; regression test added. |
| 12:02 | **AI wrong (self-caught):** a ranking test's expected order was wrong. Tracing the scoring by hand showed the code was right and the expectation was not. | Fixed the test, added a comment explaining the order. |
| 12:03 | **AI wrong:** a validation test compared `"  Jane  "` against a fixture named `"Jane Doe"`. Test failed; the test was wrong, not the code. | Fixed the test and made it assert the optional fields explicitly. |
| 12:05 | Ran the built API end to end against a local SMTP sink: featured, categories, category split, search, 404, 400, enquiry → email with Reply-To. | All behaved as specified. |
| 12:08 | **AI wrong (self-caught):** the first email-adapter test monkey-patched nodemailer internals. | Replaced with a small fake transporter that records the mail options we pass. |
| 12:12 | Decided to drop XcodeGen: the agent can't run it, and Xcode 16 synchronized folders give the same "no project-file merge conflicts" benefit with no extra tool. | Project file hand-generated; checked with a pbxproj parser that every object reference resolves. |
| 12:14 | **AI wrong (self-caught):** Swift `catch where error.isCancellation` (needs `catch let error where …`) and `let name = trimmed(name)` shadowing a property. | Fixed on review before any build. |
| 12:15 | Repo handling: I commit and push myself; the agent delivers files only. | — |
| 12:16 | **AI wrong (self-caught):** a test named `keepsShowingContentIfARefreshFails` asserted that the error screen replaces the content. | Renamed to match the intended behaviour. |
| 12:16 | Swift syntax-checked with tree-sitter (no compiler in the sandbox). One false positive (`if await …` is valid Swift) was rewritten anyway for clarity. | **Still to do by hand:** build and test in Xcode, then record any compile errors here. |
| 12:25 | First SwiftUI build ran in the Simulator with **no source changes** (verified: no Swift file modified after delivery). First launch showed the "can't reach the catalogue" state because no backend was running, which is the error state working as designed. | — |
| 12:27 | Docker is not installed on my Mac, so the backend ran with `npm run dev`. | The `docker compose up` path in the README is verified only by the CI Docker job. |
| 12:36 | Prompt: "Read this doc again and check for any missing gaps in the project before I push." | Gaps found: `ci.yml` not in the repo (the agent can't write `.github/` on my Mac), "time spent" blank, Docker path unverified, iOS tests not run, and images loaded straight from fakestoreapi.com. |
| 12:36 | **AI wrong:** DECISIONS.md had rationalised the direct image loading as a latency trade-off, despite constraint 2 of the brief. | Fixed: `GET /api/v1/products/:id/image` proxy (ImageFetcher port + HTTP adapter, size/content-type/timeout limits, only source URLs looked up by id, so no SSRF), plus a test that no product response contains a Fake Store URL. |
| 12:43 | Prompt: "Use swift or obj-c for the ios project not the swiftui." The agent asked first, pointing out SwiftUI already satisfies "Swift" and costing the rewrite. I chose UIKit in Swift. | View layer rewritten in UIKit (code-only, coordinator, compositional layout + diffable data sources, content-unavailable states). View models, networking and tests unchanged apart from removing one SwiftUI-only binding property. |
| 12:58 | UIKit code syntax-checked only; no compiler in the agent's sandbox. | **Still to do by hand:** build + ⌘U in Xcode; record any compile errors here. |
| 20:17 | Prompt: "Check the iOS project again. Make sure everything aligns with MVVM, SOLID and Clean Architecture." | Review found: no domain layer (models were JSON shapes), view models depending on a fat networking protocol (ISP), `APIError` leaking into a view model, validation rules in a view model and search rules in a view, formatting on the model, navigation decided in view controllers, `ImageLoader.shared` singleton. |
| 20:45 | **AI wrong (earlier call reversed):** the AI had justified skipping a mapping layer because "the backend is a BFF". The review showed that coupled screens to the wire format. | Refactored into Domain / Data / Presentation with use cases, repository protocols, DTO mapping, domain errors, navigator protocols, `AppContainer` and an injected image loader. Added `ios/scripts/check-architecture.sh` (tested against deliberate violations) and a CI job. Tests reorganised by layer. Still unverified by a compiler. |

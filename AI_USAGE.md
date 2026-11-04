# AI usage

<!-- TODO before submitting: read this through and make it yours. Add the things YOU caught in review
     (section 5) and anything that went wrong when you built and ran it in Xcode. -->

## 1. Tools and models

- **Claude (Opus 5.5) in the Claude desktop app**, working as an agent: it had a cloud Linux workspace (Node,
  Docker CLI, no Swift toolchain) and file access to my Mac. It wrote the plan, the backend, the iOS app (first
  in SwiftUI, then in UIKit), tests, CI and the first drafts of these docs.
- **Xcode 16** on my Mac to build, run and test the iOS app, which the agent could not compile itself.
- I made all commits myself.

## 2. Agent instruction files

- [`AGENTS.md`](AGENTS.md): the rules any agent must follow in this repo (the client never calls Fake Store,
  ports and adapters, no Fake Store types outside the adapter, a versioned API contract, no secrets, theme tokens
  only, view models depend on the `CatalogueAPI` protocol), plus commands and conventions.
- [`CLAUDE.md`](CLAUDE.md): imports `AGENTS.md`, so Claude Code, Cursor and others all read the same rules.
- [`docs/ai-log.md`](docs/ai-log.md): the running log of prompts, decisions and corrections this file is drawn from.

## 3. Plan / spec

[`docs/PLAN.md`](docs/PLAN.md). I asked for a plan first, with an explicit approval gate before any code. The plan
covered stack options with a recommendation, the three seams the brief says will change (data source, email,
look and feel), the API shape, security basics, the test strategy, assumptions and the build order. I approved
it with one decision (iOS over React). Where the build deviated, the plan says so inline.

## 4. Key prompts and moments that shaped the solution

1. **"Plan out this assignment for me. Once I approve the plan then start with the implementation."**
   Planning first made the agent commit to seams and assumptions before writing code. It also gave me the
   chance to pick the client stack deliberately: React was easier for reviewers, iOS was easier for me to defend.
2. **Putting the non-negotiables in `AGENTS.md` before the code.** Writing the rules down (the client never calls
   Fake Store, Fake Store types stay in the adapter, theme tokens only) meant every later piece of generated
   code could be checked against a written standard instead of my memory.
3. **Search semantics.** Plain substring matching makes "men" return women's clothing in this exact catalogue.
   We switched to word-prefix matching with AND semantics and pinned it with a regression test. This is the kind
   of gap the brief says the criteria leave open.
4. **"Read this doc again and check for any missing gaps in the project before I push."** A second pass of the
   brief against the finished work found that the app loaded product images straight from fakestoreapi.com,
   which breaks "do not call the Fake Store API directly from the client". The AI had written that up in
   DECISIONS.md as an acceptable trade-off. It also found the CI file missing, the Docker path never run and
   "time spent" still blank. The images now go through `GET /api/v1/products/:id/image`.
5. **"Use Swift or Obj-C for the iOS project, not SwiftUI."** The AI pointed out that SwiftUI already met the
   brief ("iOS app in Swift") and costed the rewrite; I chose UIKit anyway, as the framework I'd most
   confidently change live. Only the view layer was replaced: view models, networking, models and their tests
   were untouched, because the view models were plain `@Observable` classes with no UI framework in them.

## 5. Where the AI got things wrong, and how it was caught

| What went wrong | How it was caught | Fix |
|---|---|---|
| DECISIONS.md defended loading product images directly from fakestoreapi.com as a latency trade-off, even though the brief forbids the client calling Fake Store. | My gap review against the brief. | Images now proxied through the backend, with tests that no product response contains a Fake Store URL. |
| The plan said the agent would run `xcodebuild` on my Mac. The link only gives file access through a Linux VM. | The agent checked its tools before building and corrected the plan. | iOS verified in Xcode by me, plus a macOS CI job. |
| The first `package.json` used outdated major versions from memory (nodemailer 7, vitest 3, eslint 9). | Checked against the npm registry. | Installed current versions. Deliberately pinned TypeScript 5.9 rather than the new 7.x native compiler, for tooling compatibility. |
| A search-ranking test asserted the wrong order. | Tracing the scoring by hand before running the suite. The code was right, the test was wrong. | Fixed the expectation and added a comment explaining the order. |
| A validation test compared `"  Jane  "` against a fixture named `"Jane Doe"`. | The test failed on the first run. | Fixed the test. Also made it assert the optional fields explicitly. |
| The first email-adapter test monkey-patched nodemailer internals. | Review: too clever, and it tested nodemailer rather than our mapping. | Replaced with a tiny fake transporter that records what we send. |
| Swift: `catch where error.isCancellation` (needs a pattern: `catch let error where …`), and `let name = trimmed(name)` shadowing a property inside its own initialiser. | Self-review of the Swift written without a compiler. | Fixed both before the first build. |
| A Swift test named `keepsShowingContentIfARefreshFails` asserted the opposite: the error screen replaces content. | Review: the name and the assertion disagreed. | Renamed the test to match the intended behaviour. Keeping stale content on refresh failure is listed as a possible improvement. |

<!-- Add here: anything Xcode flagged when you first built, and anything you changed after reading the code. -->

## 6. How I reviewed the output

- Read every file the agent produced against `AGENTS.md` and the plan, not just the diff summary.
- Ran the backend end to end against a local SMTP sink, checking each acceptance criterion through the API before
  the iOS app existed.
- Built and ran the iOS app in the Simulator against the local backend, walking through all five acceptance
  criteria and checking the email arrived in Mailpit. (The first, SwiftUI, version built in Xcode with no source
  changes; the UIKit version: see section 5.)
- Treated tests as specifications: where a test and the code disagreed, decided which was right instead of
  editing whichever made the suite pass.

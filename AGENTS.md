# Agent instructions

Instructions for AI coding agents (Claude Code, Cursor, Copilot, etc.) working in this repo.
Humans: this is also the fastest way to learn the conventions.

## What this is

A proof of concept for a product catalogue that is meant to **grow, not be thrown away**.
The product data source, the look and feel, and the email provider are all expected to change.
Every change should keep those three things swappable.

- `backend/` — Node.js + TypeScript API (Express 5). The only thing that talks to Fake Store.
- `ios/` — Swift + UIKit app (iOS 17+, built in code, no storyboards). Talks only to our backend, images included.
- `docs/PLAN.md` — the approved plan. `DECISIONS.md` — assumptions and trade-offs.

## Non-negotiable rules

1. **The client never calls Fake Store** (or any product source) directly. All product data goes through `backend/`.
2. **Ports and adapters in the backend.** Business logic lives in `src/domain` (pure functions) and `src/services`
   (use cases). They depend only on interfaces in `src/ports`. Anything that does I/O lives in `src/adapters`.
   `src/container.ts` is the only file that chooses adapters.
3. **Fake Store types never leave `src/adapters/fakestore`.** Map to the domain `Product` at the boundary.
4. **The HTTP contract is versioned** (`/api/v1`) and mapped from the domain in `src/http/presenters.ts`.
   Shipped mobile apps can't be force-updated, so never change a v1 response shape in a breaking way.
5. **No secrets in the repo.** Configuration is env vars validated in `src/config/env.ts`; document every new one
   in `backend/.env.example`.
6. **iOS views never hard-code colours, fonts or spacing.** Use `Theme` (design tokens) so the brand can be swapped.
7. **iOS follows Clean Architecture.** `Domain/` (entities, use cases, repository protocols, validation, errors)
   imports Foundation only. `Data/` (DTOs, mapping, HTTP repositories) implements Domain protocols.
   `Presentation/` depends on Domain only. `App/AppContainer.swift` is the only place that picks implementations.
   Run `ios/scripts/check-architecture.sh` before committing; CI runs it too.
8. **MVVM with coordinators.** View models are `@MainActor @Observable`, have no UIKit imports, depend on use
   case protocols, expose display-ready values, and navigate through `*Navigating` protocols (held weakly)
   that coordinators implement. View controllers render with `renderOnChange { [weak self] in self?.render() }`
   and forward actions; they hold no business logic, formatting or navigation decisions.
9. **Errors:** Data translates `APIError` to `CatalogueError`; user-facing wording lives in `ErrorMessages`.

## Commands

```bash
# backend
cd backend
npm install
npm run dev          # API on :8080 (tsx watch)
npm run check        # typecheck + lint + tests — run before every commit
npm test

# whole stack (API + Mailpit inbox on :8025)
docker compose up --build

# iOS (needs Xcode 16+)
open ios/Catalogue.xcodeproj         # then Run on an iOS 17+ simulator
xcodebuild test -project ios/Catalogue.xcodeproj -scheme Catalogue \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

The Xcode project uses synchronized folders: any file added under `ios/Catalogue/` or `ios/CatalogueTests/`
is picked up automatically, so don't edit `project.pbxproj` just to add files.

```bash
ios/scripts/check-architecture.sh   # layer dependency rules
```

## Conventions

- TypeScript: strict mode, ESM, `.js` extensions in imports, `type` imports, no `console` (use the pino logger).
- Validation with zod at every trust boundary (env, HTTP input, upstream responses).
- Errors: throw `AppError` subclasses from `src/domain/errors.ts`; the HTTP error handler maps them to status codes
  and a single error shape `{ error: { code, message, requestId, details? } }`. Never leak upstream error text to clients.
- Never log customer PII. Use `maskEmail()` if you need to correlate.
- Swift: Swift 6 language mode, strict concurrency. View models are `@MainActor @Observable`. UIKit in code, no
  storyboards or XIBs. No third-party packages without a recorded reason in `DECISIONS.md`.
- Tests: domain logic and services get unit tests; every endpoint gets a supertest test for its happy path and
  its main failure. Tests never touch the network: fake the ports.

## When you are unsure

The acceptance criteria deliberately leave gaps. Make the smallest reasonable assumption, record it in
`DECISIONS.md` under "Assumptions", and move on. If you (the agent) got something wrong and a human caught it,
add a line to `docs/ai-log.md` — that log feeds `AI_USAGE.md`.

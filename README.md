# Product catalogue PoC

A product catalogue where customers browse featured products and categories, search, view product details and
send an enquiry that lands in the sales inbox. It is built as a foundation to grow from, not a throwaway prototype:
the product data source, the email provider and the look and feel can each be replaced without rewriting the rest.

- **Client:** iOS app in Swift with UIKit (iOS 17+, no storyboards). Chosen because it is my strongest stack, so I can
  defend and change every line. The brief allows mobile, and the Simulator runs against the local backend.
- **Backend:** Node.js + TypeScript (Express 5). The client never calls Fake Store: all product data, including
  product images, goes through this API.

More detail: [DECISIONS.md](DECISIONS.md) (assumptions, trade-offs, cuts, next steps) ·
[AI_USAGE.md](AI_USAGE.md) · [docs/PLAN.md](docs/PLAN.md) (the plan agreed before building).

## Run it locally (about 5 minutes)

**You need:** Docker Desktop (Compose 2.24 or later) and Xcode 16 or later. No accounts, API keys or paid services.

```bash
# 1. Start the API and a local mail inbox
docker compose up --build
```

- API: <http://localhost:8080/health> → `{"status":"ok"}`
- Sales inbox (Mailpit): <http://localhost:8025>

```bash
# 2. Run the app
open ios/Catalogue.xcodeproj
```

In Xcode, pick any iPhone simulator (iOS 17+) and press **Run** (⌘R). The app talks to `http://localhost:8080`;
the Simulator shares your Mac's network, so nothing needs configuring.

**3. Try the acceptance criteria**

| Criterion | Where |
|---|---|
| Home shows the 5 chosen products | "Top rated" on the home screen (picks in `backend/data/merchandising.json`) |
| Category page: top rated + more | Tap a category under "Shop by category" |
| Search | Type e.g. `jacket` and tap **Search** |
| Product page | Tap any product tile |
| Enquiry → email + thank you | Product page → **Enquire** → fill the form → **Send enquiry**, then open <http://localhost:8025> |

### No internet, or Fake Store is down?

Use the recorded catalogue: create `backend/.env` containing `PRODUCT_SOURCE=fakestore-snapshot` and re-run
`docker compose up`.

### Without Docker

```bash
cd backend
cp .env.example .env        # optional; defaults work
npm install
EMAIL_TRANSPORT=log npm run dev   # emails are written to the console instead of Mailpit
```

(Or run Mailpit yourself with `brew install mailpit && mailpit` and leave `EMAIL_TRANSPORT=smtp`.)

## Configuration

All configuration is environment variables, validated at startup (`backend/src/config/env.ts`) and documented in
[`backend/.env.example`](backend/.env.example). Everything has a safe local default, so no `.env` is needed to run.
Never commit `backend/.env`.

| Variable | Default | Purpose |
|---|---|---|
| `PRODUCT_SOURCE` | `fakestore-api` | `fakestore-api` (live) or `fakestore-snapshot` (offline copy) |
| `SALES_INBOX` | `sales@catalogue.local` | Where enquiries are emailed |
| `EMAIL_TRANSPORT` | `smtp` | `smtp` or `log` |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` | Mailpit | Any SMTP server, e.g. the AWS SES SMTP endpoint |
| `CATALOGUE_CACHE_TTL_SECONDS` | `300` | How long the catalogue is cached |
| `ENQUIRY_RATE_LIMIT_MAX` | `10` per 15 min | Abuse protection on the enquiry endpoint |
| `PUBLIC_BASE_URL` | request origin | Origin used for image links in responses; set it in production |

iOS: the backend URL is set in [`ios/Config/Catalogue.xcconfig`](ios/Config/Catalogue.xcconfig). For a physical
device, create `ios/Config/Local.xcconfig` (git-ignored) with your Mac's LAN IP.

## Tests

```bash
cd backend && npm run check     # typecheck + lint + 103 tests
```

iOS: in Xcode press ⌘U, or

```bash
cd ios && xcodebuild test -project Catalogue.xcodeproj -scheme Catalogue \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

CI (`.github/workflows/ci.yml`) runs the backend checks, builds the Docker image and smoke-tests the whole stack
(including that an enquiry email reaches Mailpit), and runs the iOS tests on a macOS runner.

**What is covered:** search matching and ranking, featured selection (including a removed pick), the category
split, Fake Store mapping and failure modes (timeouts, 500s, empty 200 bodies, bad JSON), caching (TTL,
single-flight, stale-on-error), enquiry validation (including header injection), email composition, every
endpoint's happy path and main failures, rate limiting, and config. On iOS, by layer: **Domain** (search-query
rules, enquiry normalisation and validation, use cases validating before sending); **Data** (contract → entity
mapping, query encoding, every transport error → domain error); **Presentation** (every view model's states,
navigation decisions, enquiry field errors, retries and double-tap protection, formatting, and the home screen
rendering the 5 featured products and forwarding a tap). Plus `ios/scripts/check-architecture.sh` for layer rules.

## API

| Method | Path | Response |
|---|---|---|
| GET | `/api/v1/featured` | `{ products }`: the 5 curated products |
| GET | `/api/v1/categories` | `{ categories: [{ slug, name }] }` |
| GET | `/api/v1/categories/:slug/products` | `{ category, topRated, more }` |
| GET | `/api/v1/products?search=term` | `{ query, products }` |
| GET | `/api/v1/products/:id` | product |
| GET | `/api/v1/products/:id/image` | the product image, proxied from the data source |
| POST | `/api/v1/enquiries` | `202 { reference }`; body `{ productId, name, email, phone?, message? }` |
| GET | `/health` | `{ status: "ok" }` |

Errors always look like `{ "error": { "code", "message", "requestId", "details?" } }`. `details` lists field
errors for 400s. Every response has an `X-Request-Id` header for tracing.

## iOS architecture

```
 Presentation (MVVM)                Domain                        Data
 ───────────────────               ───────────────────           ──────────────────────
 ViewController ──▶ ViewModel ──▶  UseCase (protocol) ──▶ Repository (protocol) ◀── RemoteRepository ──▶ HTTPClient
   (renders)      (state, actions)   Default*UseCase        entities, validator,         DTOs + mapping
                       │                                    CatalogueError
                       └──▶ *Navigating (protocol) ◀── Coordinator (App)
```

- **Dependency rule:** Presentation and Data both depend on Domain; Domain depends on nothing (Foundation only).
  `AppContainer` is the only place that knows the concrete types. `scripts/check-architecture.sh` enforces this in CI.
- **MVVM:** view controllers are passive. They render a view model's state (via `renderOnChange`, built on
  `withObservationTracking`) and forward user actions to it. View models hold no UIKit, expose display-ready
  values (`ProductCardModel`, `ProductDetailModel`), decide navigation through small navigator protocols, and
  are unit tested without a screen.
- **SOLID:** one use case per user action, and separate catalogue/enquiry repositories (interface segregation).
  View models and use cases depend on protocols, injected by `AppContainer` (dependency inversion). Business
  rules (validation, search-term rules) live in Domain, formatting and copy in Presentation, and transport
  details in Data (single responsibility). Adding a data source or screen means adding a type, not editing the
  existing ones (open/closed).

## Project structure

```
backend/
  src/domain/        pure business rules: search, merchandising, enquiry validation, errors
  src/ports/         interfaces: ProductRepository, MerchandisingSource, ImageFetcher, EmailSender
  src/adapters/      Fake Store (API + snapshot), in-memory repository + cache, image fetcher, JSON merchandising, SMTP/log email
  src/services/      use cases: CatalogueService, EnquiryService
  src/http/          Express routes, validation, presenters (API contract), error handling
  src/container.ts   the one place that picks adapters
  data/              curated picks + recorded Fake Store catalogue
ios/                              Clean Architecture + MVVM-C (see "iOS architecture" below)
  Catalogue/Domain/               entities, use cases, repository protocols, EnquiryValidator, CatalogueError
  Catalogue/Data/                 DTOs + mapping, HTTPClient, Remote*Repository (implements Domain protocols)
  Catalogue/Presentation/         view models, view controllers, display models, navigation protocols, design system
  Catalogue/App/                  AppDelegate/SceneDelegate, AppContainer (composition root), coordinators
  CatalogueTests/{Domain,Data,Presentation}/   Swift Testing, one folder per layer
  scripts/check-architecture.sh   fails CI if a layer imports what it shouldn't
AGENTS.md / CLAUDE.md      instructions for AI coding agents
```

## Time spent

| Phase | Time |
|---|---|
| Planning: reading the brief, agreeing the plan with the AI | 20 min |
| Building: backend, iOS app, CI (AI-driven, directed and reviewed) | 1 h 30 min |
| Testing: tests written alongside the code, end-to-end runs, Simulator checks | 30 min |
| Reviewing: reading the code, fixing what the AI got wrong, docs, PR | 1 h |
| **Total** | **3 h 20 min** |


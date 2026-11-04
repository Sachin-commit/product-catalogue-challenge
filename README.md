# Product catalogue PoC

A product catalogue built as a foundation to grow from: an **iOS app (Swift, UIKit)** and a
**Node.js + TypeScript backend**, with featured products, categories, search, product pages and
enquiries emailed to a sales inbox.

**The work is in the open pull request:** `feature/catalogue-poc` → `main`
([pull requests](https://github.com/Sachin-commit/product-catalogue-challenge/pulls)).
It is left open on purpose, as the challenge asks.

- Setup and run instructions: [README](https://github.com/Sachin-commit/product-catalogue-challenge/blob/feature/catalogue-poc/README.md)
- Assumptions, trade-offs and next steps: [DECISIONS.md](https://github.com/Sachin-commit/product-catalogue-challenge/blob/feature/catalogue-poc/DECISIONS.md)
- How AI was used: [AI_USAGE.md](https://github.com/Sachin-commit/product-catalogue-challenge/blob/feature/catalogue-poc/AI_USAGE.md)

~~~bash
git clone https://github.com/Sachin-commit/product-catalogue-challenge.git
cd product-catalogue-challenge && git checkout feature/catalogue-poc
docker compose up --build          # API on :8080, sales inbox on :8025
open ios/Catalogue.xcodeproj       # Run on any iOS 17+ simulator
~~~

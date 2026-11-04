# Product catalogue PoC

An iOS app (Swift, UIKit) and a Node.js + TypeScript backend for a product catalogue: featured products,
categories, search, product pages, and enquiries emailed to a sales inbox. Built as a foundation to grow
from, not a throwaway prototype.

**The work is in [pull request #1](https://github.com/Sachin-commit/product-catalogue-challenge/pull/1)**
(`feature/catalogue-poc` → `main`). It is left open on purpose, as the challenge asks.

## Run it (about 5 minutes)

You need Docker Desktop and Xcode 16 or later. No accounts or API keys.

~~~bash
git clone -b feature/catalogue-poc https://github.com/Sachin-commit/product-catalogue-challenge.git
cd product-catalogue-challenge
docker compose up --build        # API on http://localhost:8080
open ios/Catalogue.xcodeproj     # press Run on any iOS 17+ simulator
~~~

Enquiry emails arrive in the local sales inbox at http://localhost:8025.

## Read more

- [Full README](https://github.com/Sachin-commit/product-catalogue-challenge/blob/feature/catalogue-poc/README.md): setup, configuration, architecture
- [DECISIONS.md](https://github.com/Sachin-commit/product-catalogue-challenge/blob/feature/catalogue-poc/DECISIONS.md): assumptions, trade-offs, next steps
- [AI_USAGE.md](https://github.com/Sachin-commit/product-catalogue-challenge/blob/feature/catalogue-poc/AI_USAGE.md): how AI was used

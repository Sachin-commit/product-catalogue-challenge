#!/usr/bin/env bash
# Enforces the Clean Architecture dependency rule in the iOS app:
#   Presentation -> Domain <- Data, with App (composition root) wiring them together.
# The app is one Swift module, so the compiler can't enforce layer boundaries;
# this check does, in CI and before commits. (Next step: split layers into Swift packages.)
set -euo pipefail
cd "$(dirname "$0")/../Catalogue"

failures=0
forbid() {
  local layer="$1" pattern="$2" reason="$3"
  local hits
  hits=$(grep -rnE --include='*.swift' "$pattern" "$layer" | grep -vE '^[^:]+:[0-9]+:\s*//' || true)
  if [[ -n "$hits" ]]; then
    echo "✗ $layer: $reason"
    echo "$hits" | sed 's/^/    /'
    failures=$((failures + 1))
  fi
}

# Domain: pure business rules. No UI, no networking, no knowledge of other layers.
forbid Domain 'import (UIKit|SwiftUI)' 'Domain must not import UI frameworks'
forbid Domain '\b(URLSession|URLRequest|HTTPClient|APIError|[A-Za-z]+DTO)\b' 'Domain must not know about networking or DTOs'
forbid Domain '\b[A-Za-z]+(ViewModel|ViewController|Coordinator)\b' 'Domain must not reference Presentation'

# Data: implements Domain repositories. No UI.
forbid Data 'import (UIKit|SwiftUI)' 'Data must not import UI frameworks'
forbid Data '\b[A-Za-z]+(ViewModel|ViewController|Coordinator)\b' 'Data must not reference Presentation'

# Presentation: depends on Domain only, never on Data or the composition root.
forbid Presentation '\b(HTTPClient|APIError|Remote[A-Za-z]+Repository|AppContainer|[A-Za-z]+DTO)\b' 'Presentation must not depend on Data or App'

# View models stay UI-framework-free so they are testable and reusable with any UI.
vm_hits=$(grep -lE 'import (UIKit|SwiftUI)' Presentation/Features/*/*ViewModel.swift || true)
if [[ -n "$vm_hits" ]]; then
  echo "✗ View models must not import UI frameworks:"
  echo "$vm_hits" | sed 's/^/    /'
  failures=$((failures + 1))
fi

if [[ $failures -gt 0 ]]; then
  echo "Architecture check failed ($failures rule(s))."
  exit 1
fi
echo "✓ Architecture check passed: Domain ← Data, Domain ← Presentation, wired in App."

# Architecture overview

<!-- Fill in as the architecture takes shape. Record decisions in Docs/adr/. -->

## Layers

- **App target (`APPNAME/`)** — SwiftUI screens, app-specific stores and
  orchestration, dependency wiring in `APPNAMEApp.swift`.
- **`Packages/Modules` → `DesignSystem`** — shared SwiftUI primitives (colors,
  typography, components). No business logic.
- **`Packages/Modules` → `Sources/Integrations/<Name>`** — one target per
  external system (HealthKit, network APIs, …). Only I/O and `Sendable`
  mirrors; app-specific rules stay in the app target.

## State management

Model-View with native SwiftUI state (`@State`, `@Observable`, `@Environment`,
`@Binding`). No ViewModels. App-wide services are injected via `.environment(_:)`
from the app entry point.

## Where things run

<!-- Concurrency story: what is @MainActor, what runs on actors, background
     execution constraints. -->

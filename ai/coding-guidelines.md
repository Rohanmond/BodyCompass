# Coding Guidelines

## General

- Keep changes phase-aligned with `docs/phases.md`.
- Prefer small, verifiable increments.
- Update `/ai` and `/docs` when architecture, commands, or phase status changes.
- Do not remove beginner explanations unless replacing them with clearer ones.

## Swift/iOS

- Keep pure business logic in `Sources/BodyCompassCore`.
- Keep SwiftUI screens in `App/Features`.
- Keep Apple/system integrations in `App/Services`.
- Avoid putting network/provider logic directly in SwiftUI views.
- HealthKit must handle denied, partial, and missing data states.
- Use manual fallback inputs for missing health data.

## Backend

- API keys stay server-side.
- Provider calls should be wrapped in provider services.
- Meal analysis should return ranges and confidence, not fake precision.
- Keep mock provider mode working without API keys.
- Do not add a database until Phase 8 unless a phase explicitly changes.

## AI Behavior

- MVP calls both OpenAI and Gemini for meal analysis and coach chat.
- Show combined answer first.
- Preserve raw provider outputs for comparison.
- Use safety checks for medical, injury, extreme deficit, and eating-disorder content.

## Git

- Keep commits phase-scoped.
- Run verification commands before committing.
- Update `docs/phases.md` after completing a phase.

## Xcode Project Membership

- Creating a Swift file does not automatically add it to the manually maintained Xcode project.
- Add new app/core files to the appropriate PBX group and Sources build phase in `ios/BodyCompass/BodyCompass.xcodeproj/project.pbxproj`.
- Keep pure logic in `BodyCompassCore`; do not import SwiftUI, HealthKit, UserNotifications, or networking there.
- Run both the Swift package check and Xcode build because either one can pass while the other is missing a file.

## Status Claims

- Distinguish implemented, build-verified, simulator-tested, and real-device-verified.
- Do not mark HealthKit, notifications, camera, or signing verified from a build alone.
- Update `ai/HANDOFF.md`, `ai/implementation-status.md`, and `docs/implementation-status.md` when phase state changes materially.

# Swift Beginner Guide for BodyCompass

This app is split so you can learn one piece at a time.

## What to Open First

1. `ios/BodyCompass/App/BodyCompassApp.swift`
   - This is the app entrypoint. Think of it like `main.jsx` in React.
2. `ios/BodyCompass/App/RootView.swift`
   - This creates the bottom tab bar.
3. `ios/BodyCompass/App/Features/TodayView.swift`
   - This is one screen. Start here to understand SwiftUI layout.
4. `ios/BodyCompass/App/AppStore.swift`
   - This holds temporary app state and mock data.
5. `ios/BodyCompass/Sources/BodyCompassCore/GoalProjection.swift`
   - This is the real 12% body-fat calculation logic.

## SwiftUI Mental Model

- `struct SomethingView: View` means a screen or reusable UI component.
- `var body: some View` describes what appears on screen.
- `VStack` is vertical layout.
- `HStack` is horizontal layout.
- `Text`, `Button`, `Image`, `TextField` are built-in UI components.
- `@State` is local screen state.
- `@StateObject` owns shared state.
- `@EnvironmentObject` reads shared state from the app.

## How BodyCompass Is Organized

- `App/Features` contains screens.
- `App/Design` contains shared UI styling.
- `App/Services` contains Apple/system integrations like HealthKit.
- `Sources/BodyCompassCore` contains pure logic that can be tested without opening Xcode.
- `Tests/BodyCompassCoreTests` contains unit tests.

## Your First Safe Changes

Try these first:

1. Change the text in `TodayView`.
2. Add a new schedule item in `AppStore`.
3. Adjust mock body fat or weight in `AppStore`.
4. Run `swift test` and see goal numbers update.

## Important Xcode Notes

HealthKit works best on a real iPhone. Simulators can run UI, but real Health data access is limited.

When we create the full Xcode project target, enable:

- Signing & Capabilities -> HealthKit
- Info -> Health Share Usage Description

The backend keeps OpenAI and Gemini keys private. Never put API keys in Swift files.

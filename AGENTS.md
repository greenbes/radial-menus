# Repository Guidelines

## Project Structure & Module Organization
`radial-menu/radial-menu.xcodeproj` exists only for metadata—drive every task via CLI. Sources in `radial-menu/radial-menu/` follow Clean Architecture: `Domain/` (pure models + geometry utilities), `Infrastructure/` (system managers such as OverlayWindow, Hotkey, ControllerInput), and `Presentation/` (SwiftUI views + view models). Unit tests live in `radial-menu/radial-menuTests/` (`Domain/`, `Mocks/`), and UI tests in `radial-menu/radial-menuUITests/`.

## Command-Line Workflow Expectations
Develop, deploy, test, and manage packages only via shell commands—never open the Xcode GUI. Resolve Swift Package Manager dependencies with `xcodebuild -resolvePackageDependencies`, inspect them using `swift package show-dependencies`, and create releases with scripted `xcodebuild archive` calls. Keep automation (CI or manual) as shell scripts so the workflow remains reproducible.

## Build, Test, and Development Commands
- `xcodebuild -scheme radial-menu -configuration Debug build`: primary build command; avoid Xcode UI entirely.
- `xcodebuild test -scheme radial-menu -destination 'platform=macOS'`: executes all XCTest bundles from the command line.
- `xcodebuild -scheme radial-menu -configuration Release archive`: produce signed archives when you need a distributable binary.
- `./run-with-logs.sh`: launches the latest Debug build and tails `/tmp/radial-menu-debug.log`.
- `./test-hotkey.sh`: streams live logs so you can confirm Ctrl+Space hotkey events.

## Coding Style & Naming Conventions
Use Swift 5 defaults: four-space indentation, `final` where possible, and `// MARK:` sections. Domain stays framework-free and pure; Infrastructure hides macOS APIs behind protocols; Presentation uses MVVM with `@Observable` view models. Stick to PascalCase types, camelCase members, and align file names with the primary type. Protocol-first design keeps mocking straightforward.

## Testing Guidelines
Use XCTest with descriptive names (`testCalculateSlices_WithFourItems_CreatesCorrectAngles`). New pure functions in `Domain/` need deterministic tests under `radial-menuTests/Domain/`. Infrastructure or Presentation changes should extend `radial-menuTests/Mocks/` to avoid macOS APIs. Guard UI flows with `radial-menuUITests` plus manual verification alongside `./run-with-logs.sh`.

## Commit & Pull Request Guidelines
History currently shows one imperative summary (“Initial Commit”); continue with concise, present-tense subjects (e.g., `Add controller navigation tests`). Pull requests should describe the change, list affected layers/modules, show `xcodebuild test` output, and attach screenshots or GIFs when UI shifts. Call out needed permissions, configuration migrations, and linked issues so reviewers can reproduce quickly.

## Security & Configuration Tips
Global hotkeys need Accessibility access; add the built app under System Settings → Privacy & Security → Accessibility whenever `test-hotkey.sh` reports a failure. User configuration lives at `~/Library/Application Support/com.radial-menu/radial-menu-config.json`; keep it out of source control and document schema migrations. Prefer the provided logging scripts over ad-hoc `print` dumps so sensitive paths stay confined to `/tmp/radial-menu-debug.log`.

# GEMINI.md

## Project Overview

**Radial Menu Overlay** is a lightweight, frameless macOS application designed to provide quick access to actions via a radial menu interface. It is built using **Swift** and **SwiftUI**, following **Clean Architecture** principles (Domain, Infrastructure, Presentation) and the **Functional Core / Imperative Shell** pattern.

### Architecture Highlights
*   **Domain**: Pure Swift logic (Models, Geometry) with no dependencies.
*   **Infrastructure**: System integration (Hotkeys, Window management, Action execution) via protocols.
*   **Presentation**: SwiftUI Views and MVVM ViewModels.
*   **App**: Composition root (`AppCoordinator`) handling dependency injection.

## Development Workflow

**CRITICAL**: This project emphasizes a CLI-first workflow. Avoid using the Xcode GUI for building or running tests.

### Key Commands

*   **Build (Debug)**:
    ```bash
    xcodebuild -scheme radial-menu -configuration Debug build
    ```
*   **Run Tests**:
    ```bash
    xcodebuild test -scheme radial-menu -destination 'platform=macOS'
    ```
*   **Build & Run (with Logs)**:
    ```bash
    ./run-with-logs.sh
    ```
    *   Logs are streamed to `/tmp/radial-menu-debug.log`.
    *   Use `tail -f /tmp/radial-menu-debug.log` to monitor.
*   **Archive (Release)**:
    ```bash
    xcodebuild -scheme radial-menu -configuration Release archive
    ```
*   **Test Hotkeys**:
    ```bash
    ./test-hotkey.sh
    ```

### Logs & Debugging
*   **Log File**: `/tmp/radial-menu-debug.log`
*   **Observation**: Use the provided scripts (`run-with-logs.sh`, `test-hotkey.sh`) to observe application behavior and debug issues, as `print` statements are directed to these logs.

## Project Structure

```text
radial-menu/
├── Domain/           # Pure business logic & geometry (No frameworks)
├── Infrastructure/   # System APIs (Carbon, AppKit) behind protocols
├── Presentation/     # SwiftUI Views & ViewModels
├── App/              # AppCoordinator & Lifecycle
├── radial-menu.xcodeproj # Xcode project metadata
└── radial-menuTests/ # Unit tests (Domain & Mocks)
```

## Coding Conventions

*   **Language**: Swift 5
*   **Style**:
    *   4-space indentation.
    *   PascalCase for types, camelCase for members.
    *   `final` classes where possible.
    *   Protocol-first design for Infrastructure.
*   **Architecture**:
    *   **Domain**: Must remain framework-free.
    *   **Infrastructure**: Must implement protocols to allow mocking.
    *   **Presentation**: MVVM with `@Observable`.
*   **Testing**:
    *   Domain logic must have deterministic unit tests.
    *   Use mocks in `Mocks/` for Infrastructure dependencies.

## Important Notes for Agents

1.  **Xcode Project Sync**: When creating new Swift files, be aware they must be added to `radial-menu.xcodeproj` to be recognized by the build system. Since direct `pbxproj` manipulation is risky, prefer modifying existing files or clearly instructing the user if a file addition is critical and cannot be automated safely.
2.  **Permissions**: The app requires **Accessibility** permissions for global hotkeys (`Ctrl+Space`). If hotkeys fail, check System Settings.
3.  **Config**: User configuration is stored in `~/Library/Application Support/com.radial-menu/radial-menu-config.json`.

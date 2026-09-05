# Windows desktop app

The desktop uses native Win32 controls with the existing shared Swift state.
Manual launch opens the main window; `--background` starts in the tray. Newly
enabled startup entries include that argument.

## Screens

- Home: available provider count, refresh status, usage table, companion summary.
- Usage: provider availability, remaining quota, reset, tokens, cost, and detailed quota windows.
- Companions: owned companions, persisted growth target selection, egg opening, desktop overlay.
- Settings: enabled providers, startup, test notifications, overlay visibility, and Quit.

Close and Escape hide to the tray. Use Quit to stop the app. Relaunching activates
the existing instance. Normal window bounds are saved per user and clamped to an
available monitor on restoration. Native controls support keyboard navigation;
tables can scroll horizontally and vertically.

Unavailable and stale data never appear as current numeric values. Companion
changes use the existing game engine and only become visible after saving succeeds.
The UI does not calculate growth or read provider credentials directly.

## Boundaries and validation

`TokeniApplication` supplies provider-neutral state. `WindowsDashboardPresentation`
formats table values. `WindowsTrayShell` publishes snapshots and collects requests.
`WindowsTrayNative.c` owns the message thread, tray, window, and controls. The overlay
also creates, updates, and releases its native and COM resources on that thread.
`WindowsCompanionGrowthCoordinator` applies and persists game actions.

Run `swift test` and `swift build` on configured Windows/macOS environments. The
Windows desktop controls workflow also exercises real Win32 controls in a separate
namespace, without reading or modifying user settings or provider data. It covers
navigation, service and companion requests, overlay lifecycle, hide/reopen, and Quit.

The first desktop version uses English UI text. It does not yet include every macOS
history chart, pet shop, or display setting. A dedicated dark theme, complete Korean
UI localization, and an installer remain follow-up work. Distribution uses a portable ZIP.

# Changelog

All notable changes to WindowSmartMover will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned (v1.3.0)
- **Manual Window Snapshot & Restore**: User-controlled window layout save/restore
  - Configurable hotkeys for save and restore operations (default: Ctrl+Cmd+↑ for save, Ctrl+Cmd+↓ for restore)
  - Independent snapshot storage separate from automatic restoration
  - Visual notification feedback (success count, failure alerts)
  - Menu bar commands for manual snapshot operations
  - Clear saved snapshot option
  - Fallback solution when automatic restoration fails
- **Internationalization (i18n)**
  - English as default UI language
  - Japanese localization
  - Localized debug logs for international users

### Future Considerations (Post v1.3.0)
- Multiple snapshot slots (save/restore multiple layouts)
- Persistent snapshot storage (UserDefaults)
- Snapshot management interface (list, delete, rename)
- Per-app window restoration rules
- Window size restoration (currently position only)
- Support for more than 2 displays
- Configurable snapshot interval

## [1.2.0] - 2025-11-13

### Added
- Display change detection stabilization timer to handle rapid display configuration events
  - New setting: "Display Change Detection Stabilization Time" (0.1-3.0s, default 0.5s)
  - Prevents premature window restoration during system wake/sleep cycles
- Two-stage timing mechanism for reliable window restoration
  - Stage 1: Wait for display configuration to stabilize
  - Stage 2: Wait for macOS to complete window coordinate updates
- Enhanced Settings dialog with detailed timing configuration explanations
  - Separate sections for each timing setting with dividers
  - Expanded window height to 715px to prevent content clipping

### Changed
- Window restore delay default increased from 1.5s to 2.5s
  - Provides more time for macOS to update window coordinates after display reconnection
- Window position detection logic improved from frame intersection to X-coordinate based
  - More reliable detection of which display a window is currently on
  - Reduces false positives during coordinate system transitions
- Settings dialog "Default" button now resets both timing values

### Fixed
- **Critical**: Windows not restoring to external displays after system wake/sleep
  - Root cause: Rapid display configuration events caused timer overwrites
  - Solution: Stabilization timer cancels and reschedules until display changes settle
- Window restoration logic incorrectly identifying window locations during coordinate updates
  - Changed from `frame.intersects()` to X-coordinate range checking
  - More accurate determination of main vs. external display placement
- Settings window content clipping when displaying both timing configurations
  - Adjusted window height from 650px to 715px to ensure all content is visible

### Technical Details
- Implemented `displayStabilizationTimer` with automatic invalidation on new events
- Modified `displayConfigurationChanged()` to use two-stage delay mechanism
- Enhanced `restoreWindowsIfNeeded()` with improved screen position detection
- All timing values now user-configurable via WindowTimingSettings

## [1.1.0] - 2025-11-08

### Added
- Display memory feature: Auto-restore windows on display reconnect
  - Periodic window position snapshots every 5 seconds
  - Automatic window restoration when external displays reconnect
  - Per-display window position memory using CGWindowID
  - Support for multiple windows per application
- Debug log viewer with clear and copy functionality (in-memory only, no file storage)
- Window restore timing configuration (0.1-10.0 seconds, default 1.5s)
- `debugPrint()` function for centralized logging
- `DebugLogger` class for managing log entries (max 1000 entries)
- `WindowTimingSettings` class for managing restore delay configuration

### Changed
- Unified settings dialog and renamed menu item from "Shortcut Settings..." to "Settings..."
- Settings window now includes both hotkey and timing configurations
- Settings window size increased from 400x400 to 500x600
- "Cancel" button changed to "Reset to Defaults" with full functionality

### Fixed
- Window position calculation bug - restored relative positioning logic instead of center alignment
- Removed all compiler warnings:
  - Deleted unused `found` variable
  - Changed `nextScreenIndex` from `var` to `let`
  - Changed `gMyHotKeyID1` from `var` to `let`
  - Changed `gMyHotKeyID2` from `var` to `let`

### Security
- Debug logs are stored in memory only and cleared on app termination
- No sensitive information is written to disk

### Technical Details
- Implemented CGWindowListCopyWindowInfo for window enumeration
- Display identification using NSScreen device description
- Window matching based on app name + CGWindowID
- NSApplication.didChangeScreenParametersNotification for display change detection

## [1.0.0] - 2025-10-18

### Added
- Initial release
- Multi-display window management with keyboard shortcuts
  - Default hotkeys: Ctrl+Option+Command+Arrow keys
  - Move windows between displays instantly
- Customizable hotkey modifiers (Control, Option, Shift, Command)
- Menu bar integration with system tray icon
- About window with version information

### Technical Details
- Built as macOS menu bar application
- Used Accessibility API for window manipulation
- Implemented in Swift 5.x with SwiftUI for settings interface
- Utilized Carbon API for global hotkey registration

## [Planned Features]

### Internationalization (i18n)
Multi-language support to make the app accessible to international users.

**Scope:**
- **User-facing UI and messages** - Menu items, dialogs, buttons, settings, and all user-visible text
- **Debug logs** - Translate to English for global accessibility

**Current state:**
- All UI text is in Japanese
- Debug logs are currently in Japanese, which prevents non-Japanese speakers from independently troubleshooting issues

**Implementation approach:**

**Phase 1: English default (Priority)**
1. Translate all UI strings to English
   - Menu items
   - Settings dialog
   - Debug log viewer
   - About window
   - Alert messages
2. Translate all debug logs to English
   - This enables international users to troubleshoot issues independently
   - Facilitates collaboration on bug reports
   - Enables effective Stack Overflow/GitHub issue searches
3. Translate code comments to English
   - Improves code readability for international contributors
   - Facilitates open-source collaboration
   - Makes the codebase more maintainable globally
4. Implement NSLocalizedString framework for all user-facing text
   - Prepares infrastructure for future localizations

**Phase 2: Japanese localization**
1. Create Japanese .strings files
2. Add language auto-detection based on system preferences
3. Test both English and Japanese interfaces thoroughly

**Phase 3: Additional languages (Future)**
- Community contributions welcome
- Consider: Chinese, Korean, Spanish, French, German

**Rationale:**
- English debug logs are essential for international troubleshooting
- English as the default UI maximizes the global user base
- Phased approach enables stable implementation without major refactoring
- Separating UI localization from debug logging optimizes both developer and user experience

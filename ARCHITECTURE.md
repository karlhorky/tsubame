# Tsubame Architecture

This document describes the internal architecture of Tsubame, a macOS menu bar app for window position management.

## Overview

Tsubame automatically saves and restores window positions when external displays are connected/disconnected.

## Core Components

### AppDelegate.swift

Main application logic, including:

- **Display monitoring**: Detects display configuration changes
- **Window snapshot**: Captures window positions periodically  
- **Window restoration**: Restores windows to saved positions
- **Sleep/wake handling**: Manages monitoring during sleep cycles

### SettingsView.swift

SwiftUI-based settings interface, including:

- **WindowTimingSettings**: Timing-related settings (delays, intervals)
- **SnapshotSettings**: Snapshot behavior settings (sound, notifications)
- **DebugSettings**: Debug mode toggles

### TimerManager.swift

Centralized timer management:

- **Snapshot timers**: Display memory, initial capture, periodic capture
- **Display change timers**: Stabilization check, restore, fallback

## Data Flow

### Snapshot Data (Single Source of Truth)

```
takeWindowSnapshot() (30s) → manualSnapshots[0] (memory)
                                    ↓
performAutoSnapshot() (30min) → UserDefaults (persist)
                                    ↓
restoreWindowsIfNeeded() ← manualSnapshots[0] (read)
```

**Slot 0** (`manualSnapshots[0]`) is reserved for auto-snapshot data.
Slots 1-5 are for manual snapshots triggered by user.

### Display Change Flow

```
NSWorkspace.screensDidWakeNotification
         ↓
displayConfigurationChanged()
         ↓
    [guard: isUserLoggedIn()]
         ↓
checkStabilization() (polling every 0.5s)
         ↓
    [3.5s elapsed since last event]
         ↓
scheduleRestore() (2.0s delay)
         ↓
restoreWindowsIfNeeded()
         ↓
    [guard: isUserLoggedIn()]
         ↓
    [read from manualSnapshots[0]]
         ↓
Move windows via AXUIElement API
```

### Sleep/Wake Flow

```
willSleepNotification / screensDidSleepNotification
         ↓
pauseMonitoring() ← idempotent, safe to call multiple times
         ↓
isMonitoringEnabled = false
         ↓
    [No snapshots taken during sleep]
         ↓
screensDidWakeNotification
         ↓
isMonitoringEnabled = true
         ↓
    [Wait for display stabilization]
         ↓
restoreWindowsIfNeeded()
```

## Key Design Decisions

### 1. Single Source of Truth (v1.2.13+)

Previously, there were two data stores:
- `windowPositions` (memory-only, lost on app restart)
- `manualSnapshots[0]` (persisted to UserDefaults)

Now unified to `manualSnapshots[0]` only:
- Memory updates every 30 seconds
- Persisted every 30 minutes
- Survives app restart

### 2. Login Screen Guard (v1.2.13+)

At login screen, macOS may report phantom display IDs.
`isUserLoggedIn()` check prevents:
- Corrupting snapshot data with invalid display IDs
- Attempting restoration with incorrect mappings

### 3. Idempotent pauseMonitoring()

Both system sleep and display sleep notifications may fire.
`pauseMonitoring()` is safe to call multiple times:
```swift
guard isMonitoringEnabled else { return }  // Already paused
```

### 4. Display Stabilization

macOS sends multiple rapid display change events.
We wait for stabilization before restoration:
- Poll every 0.5s for display changes
- Trigger restoration when no change for 3.5s
- Fallback after 3s if no further events

## Constants and Timing

| Constant | Value | Purpose |
|----------|-------|---------|
| Display memory interval | 30s | How often to update snapshot in memory |
| Auto-snapshot interval | 30min | How often to persist to UserDefaults |
| Display stabilization delay | 3.5s | Wait for display to stabilize |
| Window restore delay | 2.0s | Wait before moving windows |
| Fallback wait delay | 3.0s | Wait for display event after stabilization |
| Restore cooldown | 5.0s | Prevent duplicate restorations |
| Restore retry delay | 3.0s | Wait between retry attempts |
| Max restore retries | 2 | Maximum retry attempts |

## File Structure

```
Tsubame/
├── AppDelegate.swift       # Main app logic
├── SettingsView.swift      # Settings UI and data models
├── TimerManager.swift      # Centralized timer management
├── ManualSnapshotStorage.swift  # Snapshot persistence
└── Localizable.strings     # Localization (ja, en)
```

## Privacy Considerations

- Window titles and app names are hashed before storage
- `DebugLogger.maskAppName()` masks sensitive data in logs
- No data sent externally

import Cocoa
import Combine

// MARK: - Focus Follows Mouse Delay Presets

enum FocusDelayPreset: String, CaseIterable {
    case instant = "instant"      // 0ms
    case fast = "fast"            // 150ms
    case standard = "standard"    // 250ms
    case slow = "slow"            // 500ms
    
    var delayMs: Int {
        switch self {
        case .instant: return 0
        case .fast: return 150
        case .standard: return 250
        case .slow: return 500
        }
    }
    
    var displayName: String {
        switch self {
        case .instant: return NSLocalizedString("Instant (0ms)", comment: "Focus delay preset")
        case .fast: return NSLocalizedString("Fast (150ms)", comment: "Focus delay preset")
        case .standard: return NSLocalizedString("Standard (250ms)", comment: "Focus delay preset")
        case .slow: return NSLocalizedString("Slow (500ms)", comment: "Focus delay preset")
        }
    }
}

// MARK: - Focus Follows Mouse Manager

class FocusFollowsMouseManager: ObservableObject {
    static let shared = FocusFollowsMouseManager()
    
    // MARK: - Published Properties
    
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "focusFollowsMouseEnabled")
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published var selectedPreset: FocusDelayPreset {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: "focusFollowsMousePreset")
            if !useCustomDelay {
                delayMs = selectedPreset.delayMs
            }
        }
    }
    
    @Published var useCustomDelay: Bool {
        didSet {
            UserDefaults.standard.set(useCustomDelay, forKey: "focusFollowsMouseUseCustom")
            if !useCustomDelay {
                delayMs = selectedPreset.delayMs
            }
        }
    }
    
    @Published var customDelayMs: Int {
        didSet {
            let clamped = max(0, min(1000, customDelayMs))
            if customDelayMs != clamped {
                customDelayMs = clamped
            }
            UserDefaults.standard.set(clamped, forKey: "focusFollowsMouseCustomDelay")
            if useCustomDelay {
                delayMs = clamped
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var delayMs: Int = 250
    private var eventMonitor: Any?
    private var hoverTimer: Timer?
    private var lastHoveredWindow: AXUIElement?
    private var lastMouseLocation: NSPoint = .zero
    
    /// Suspended during display configuration changes
    private var isSuspendedForDisplayChange = false
    
    // MARK: - Initialization
    
    private init() {
        // Load saved settings
        self.isEnabled = UserDefaults.standard.bool(forKey: "focusFollowsMouseEnabled")
        
        if let presetRaw = UserDefaults.standard.string(forKey: "focusFollowsMousePreset"),
           let preset = FocusDelayPreset(rawValue: presetRaw) {
            self.selectedPreset = preset
        } else {
            self.selectedPreset = .standard
        }
        
        self.useCustomDelay = UserDefaults.standard.bool(forKey: "focusFollowsMouseUseCustom")
        
        let savedCustom = UserDefaults.standard.integer(forKey: "focusFollowsMouseCustomDelay")
        self.customDelayMs = savedCustom > 0 ? savedCustom : 250
        
        // Set initial delay
        if useCustomDelay {
            self.delayMs = customDelayMs
        } else {
            self.delayMs = selectedPreset.delayMs
        }
        
        // Note: Don't start monitoring here - wait for AppDelegate to call startIfEnabled()
        // This ensures proper startup sequence after display stabilization
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring if enabled (called by AppDelegate after startup completes)
    func startIfEnabled() {
        if isEnabled {
            startMonitoring()
        }
    }
    
    /// Suspend during display configuration changes
    func suspendForDisplayChange() {
        isSuspendedForDisplayChange = true
        hoverTimer?.invalidate()
        hoverTimer = nil
    }
    
    /// Resume after display stabilization
    func resumeAfterDisplayChange() {
        isSuspendedForDisplayChange = false
    }
    
    /// Get current effective delay in milliseconds
    var effectiveDelayMs: Int {
        return useCustomDelay ? customDelayMs : selectedPreset.delayMs
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        guard eventMonitor == nil else { return }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
        }
    }
    
    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        hoverTimer?.invalidate()
        hoverTimer = nil
        lastHoveredWindow = nil
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        // Skip if paused
        if PauseManager.shared.isPaused {
            return
        }
        
        // Skip during display configuration changes
        if isSuspendedForDisplayChange {
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Skip if mouse hasn't moved significantly (reduces unnecessary processing)
        let distance = hypot(mouseLocation.x - lastMouseLocation.x, mouseLocation.y - lastMouseLocation.y)
        if distance < 5 {
            return
        }
        lastMouseLocation = mouseLocation
        
        // Cancel existing timer
        hoverTimer?.invalidate()
        
        // Skip areas: menu bar, dock
        if isInExcludedArea(mouseLocation) {
            return
        }
        
        // Get window under cursor
        guard let windowElement = getWindowAtPosition(mouseLocation) else {
            return
        }
        
        // Skip if same window
        if let lastWindow = lastHoveredWindow, CFEqual(windowElement, lastWindow) {
            return
        }
        
        // Schedule focus change with delay
        let delaySeconds = Double(delayMs) / 1000.0
        
        if delaySeconds <= 0 {
            // Instant mode
            focusWindow(windowElement)
            lastHoveredWindow = windowElement
        } else {
            // Delayed mode
            hoverTimer = Timer.scheduledTimer(withTimeInterval: delaySeconds, repeats: false) { [weak self] _ in
                self?.focusWindow(windowElement)
                self?.lastHoveredWindow = windowElement
            }
        }
    }
    
    private func isInExcludedArea(_ point: NSPoint) -> Bool {
        // Exclude menu bar area (top 24 pixels of main screen)
        if let mainScreen = NSScreen.main {
            let menuBarHeight: CGFloat = 24
            let menuBarY = mainScreen.frame.maxY - menuBarHeight
            if point.y > menuBarY {
                return true
            }
        }
        
        // Exclude Dock area
        // Note: Dock position can vary (bottom, left, right)
        // For simplicity, we check if the point is over any screen edge
        // A more robust implementation would query the Dock's actual position
        
        return false
    }
    
    private func getWindowAtPosition(_ point: NSPoint) -> AXUIElement? {
        // NSEvent.mouseLocation: origin at bottom-left of primary screen
        // AXUIElementCopyElementAtPosition: origin at top-left of primary screen
        
        // Get primary screen height for coordinate conversion
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height
        
        // Convert: flip Y coordinate relative to primary screen
        let cgPoint = CGPoint(x: point.x, y: primaryHeight - point.y)
        
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(cgPoint.x), Float(cgPoint.y), &element)
        
        guard result == .success, let element = element else {
            return nil
        }
        
        // Traverse up to find window element
        return findWindowElement(from: element)
    }
    
    private func findWindowElement(from element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        
        while let el = current {
            var role: CFTypeRef?
            let roleResult = AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
            
            if roleResult == .success,
               let roleString = role as? String,
               roleString == kAXWindowRole as String {
                return el
            }
            
            // Get parent
            var parent: CFTypeRef?
            let parentResult = AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent)
            
            if parentResult == .success, let parentElement = parent {
                current = (parentElement as! AXUIElement)
            } else {
                break
            }
        }
        
        return nil
    }
    
    private func focusWindow(_ window: AXUIElement) {
        // Get the application that owns this window
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        
        guard pid != 0 else {
            return  // Silent fail for system elements
        }
        
        // Skip system/background apps (prevents errors with WindowServer, Dock, etc.)
        guard let runningApp = NSRunningApplication(processIdentifier: pid),
              runningApp.activationPolicy == .regular else {
            return
        }
        
        // Skip if it's the current app (avoid unnecessary focus changes)
        if runningApp == NSRunningApplication.current {
            return
        }
        
        let app = AXUIElementCreateApplication(pid)
        
        // Activate the app (brings to foreground and accepts key input)
        runningApp.activate()
        
        // Set this window as the focused window of the application
        AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, window)
        
        // Set as main window and raise
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopMonitoring()
    }
}

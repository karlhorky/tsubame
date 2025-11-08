import Cocoa
import Carbon
import SwiftUI

// グローバル変数としてAppDelegateの参照を保持
private var globalAppDelegate: AppDelegate?

// Cイベントハンドラー
private func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    
    guard status == noErr else {
        return status
    }
    
    guard let appDelegate = globalAppDelegate else {
        return OSStatus(eventNotHandledErr)
    }
    
    print("🔥 ホットキーが押されました: ID = \(hotKeyID.id)")
    
    DispatchQueue.main.async {
        switch hotKeyID.id {
        case 1: // 右矢印（次の画面）
            appDelegate.moveWindowToNextScreen()
        case 2: // 左矢印（前の画面）
            appDelegate.moveWindowToPrevScreen()
        default:
            break
        }
    }
    
    return noErr
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hotKeyRef: EventHotKeyRef?
    var hotKeyRef2: EventHotKeyRef?
    var eventHandler: EventHandlerRef?
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?
    
    // ディスプレイ記憶機能
    private var windowPositions: [String: [String: CGRect]] = [:]
    private var snapshotTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // グローバル参照を設定
        globalAppDelegate = self
        
        // システムバーにアイコンを追加
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.2.swap", accessibilityDescription: "Window Mover")
            button.image?.isTemplate = true
        }
        
        // メニューを設定
        setupMenu()
        
        // グローバルホットキーを登録
        registerHotKeys()
        
        // アクセシビリティ権限をチェック
        checkAccessibilityPermissions()
        
        // ディスプレイ変更の監視を開始
        setupDisplayChangeObserver()
        
        // 定期スナップショットを開始（5秒ごと）
        startPeriodicSnapshot()
        
        debugPrint("アプリが起動しました")
        debugPrint("接続されている画面数: \(NSScreen.screens.count)")
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        let modifierString = HotKeySettings.shared.getModifierString()
        menu.addItem(NSMenuItem(title: "ウィンドウを次の画面へ (\(modifierString)→)", action: #selector(moveWindowToNextScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "ウィンドウを前の画面へ (\(modifierString)←)", action: #selector(moveWindowToPrevScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "ショートカット設定...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "デバッグ情報を表示", action: #selector(showDebugInfo), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About WindowSmartMover", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "設定"
            window.styleMask = [.titled, .closable]
            window.center()
            window.level = .floating
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openAbout() {
        if aboutWindow == nil {
            let aboutView = AboutView()
            let hostingController = NSHostingController(rootView: aboutView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "About"
            window.styleMask = [.titled, .closable]
            window.center()
            window.level = .floating
            
            aboutWindow = window
        }
        
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func registerHotKeys() {
        // 既存のホットキーを解除
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
            hotKeyRef = nil
        }
        if let hotKey = hotKeyRef2 {
            UnregisterEventHotKey(hotKey)
            hotKeyRef2 = nil
        }
        
        // イベントタイプの指定
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // イベントハンドラをインストール（初回のみ）
        if eventHandler == nil {
            let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, &eventHandler)
            
            if status == noErr {
                debugPrint("✅ イベントハンドラのインストール成功")
            } else {
                debugPrint("❌ イベントハンドラのインストール失敗: \(status)")
            }
        }
        
        // 設定から修飾キーを取得
        let modifiers = HotKeySettings.shared.getModifiers()
        let modifierString = HotKeySettings.shared.getModifierString()
        
        // Ctrl + Option + Command + 右矢印
        var gMyHotKeyID1 = EventHotKeyID(signature: OSType(0x4D4F5652), id: 1) // 'MOVR'
        var hotKey1: EventHotKeyRef?
        let registerStatus1 = RegisterEventHotKey(UInt32(kVK_RightArrow), modifiers, gMyHotKeyID1, GetApplicationEventTarget(), 0, &hotKey1)
        
        if registerStatus1 == noErr {
            hotKeyRef = hotKey1
            debugPrint("✅ ホットキー1 (\(modifierString)→) の登録成功")
        } else {
            debugPrint("❌ ホットキー1 の登録失敗: \(registerStatus1)")
        }
        
        // Ctrl + Option + Command + 左矢印
        var gMyHotKeyID2 = EventHotKeyID(signature: OSType(0x4D4F564C), id: 2) // 'MOVL'
        var hotKey2: EventHotKeyRef?
        let registerStatus2 = RegisterEventHotKey(UInt32(kVK_LeftArrow), modifiers, gMyHotKeyID2, GetApplicationEventTarget(), 0, &hotKey2)
        
        if registerStatus2 == noErr {
            hotKeyRef2 = hotKey2
            debugPrint("✅ ホットキー2 (\(modifierString)←) の登録成功")
        } else {
            debugPrint("❌ ホットキー2 の登録失敗: \(registerStatus2)")
        }
    }
    
    @objc func moveWindowToNextScreen() {
        debugPrint("=== 次の画面への移動を開始 ===")
        moveWindow(direction: 1)
    }
    
    @objc func moveWindowToPrevScreen() {
        debugPrint("=== 前の画面への移動を開始 ===")
        moveWindow(direction: -1)
    }
    
    func moveWindow(direction: Int) {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            debugPrint("❌ フロントアプリを取得できませんでした")
            return
        }
        
        debugPrint("フロントアプリ: \(frontmostApp.localizedName ?? "不明")")
        
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        
        // フロントアプリのメインウィンドウを探す
        guard let windows = windowList,
              let targetWindow = windows.first(where: { window in
                  guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                        ownerPID == frontmostApp.processIdentifier,
                        let layer = window[kCGWindowLayer as String] as? Int,
                        layer == 0 else { return false }
                  return true
              }),
              let boundsDict = targetWindow[kCGWindowBounds as String] as? [String: CGFloat]
        else {
            debugPrint("❌ ターゲットウィンドウが見つかりませんでした")
            return
        }
        
        let currentFrame = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
        
        debugPrint("現在のウィンドウ位置: \(currentFrame)")
        
        // 現在のウィンドウがある画面を特定
        let screens = NSScreen.screens
        guard let currentScreenIndex = screens.firstIndex(where: { screen in
            screen.frame.intersects(currentFrame)
        }) else {
            debugPrint("❌ 現在の画面を特定できませんでした")
            return
        }
        
        debugPrint("現在の画面インデックス: \(currentScreenIndex)")
        
        // 次の画面を計算
        let nextScreenIndex = (currentScreenIndex + direction + screens.count) % screens.count
        let targetScreen = screens[nextScreenIndex]
        
        debugPrint("移動先画面インデックス: \(nextScreenIndex)")
        debugPrint("移動先画面のフレーム: \(targetScreen.frame)")
        
        // ウィンドウの相対位置を維持して移動
        let currentScreen = screens[currentScreenIndex]
        let relativeX = currentFrame.origin.x - currentScreen.frame.origin.x
        let relativeY = currentFrame.origin.y - currentScreen.frame.origin.y
        
        let newX = targetScreen.frame.origin.x + relativeX
        let newY = targetScreen.frame.origin.y + relativeY
        
        debugPrint("新しい位置: x=\(newX), y=\(newY)")
        
        // Accessibility APIを使用してウィンドウを移動
        let appRef = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // まずフォーカスウィンドウを試す
        var value: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &value)
        
        // フォーカスウィンドウが取得できない場合は、全ウィンドウリストから取得
        if result != .success {
            var windowList: CFTypeRef?
            result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowList)
            
            if result == .success, let windows = windowList as? [AXUIElement], !windows.isEmpty {
                value = windows[0]
                result = .success
            }
        }
        
        if result == .success, let windowElement = value {
            // 現在の位置を確認
            var currentPos: CFTypeRef?
            if AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXPositionAttribute as CFString, &currentPos) == .success {
                var point = CGPoint.zero
                if AXValueGetValue(currentPos as! AXValue, .cgPoint, &point) {
                    debugPrint("現在のAX位置: \(point)")
                }
            }
            
            // 新しい位置を設定
            var position = CGPoint(x: newX, y: newY)
            
            if let positionValue = AXValueCreate(.cgPoint, &position) {
                let setResult = AXUIElementSetAttributeValue(windowElement as! AXUIElement, kAXPositionAttribute as CFString, positionValue)
                
                if setResult == .success {
                    debugPrint("✅ ウィンドウの移動に成功しました")
                } else {
                    debugPrint("❌ ウィンドウの移動に失敗: \(setResult.rawValue)")
                }
            }
        }
    }
    
    @objc func showDebugInfo() {
        debugPrint("\n=== デバッグ情報 ===")
        debugPrint("接続されている画面数: \(NSScreen.screens.count)")
        
        for (index, screen) in NSScreen.screens.enumerated() {
            debugPrint("画面 \(index): \(screen.frame)")
            let name = screen.localizedName
            debugPrint("  名前: \(name)")
        }
        
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            debugPrint("現在のフロントアプリ: \(frontmostApp.localizedName ?? "不明")")
        }
        
        debugPrint("アクセシビリティ権限: \(AXIsProcessTrusted())")
        debugPrint("現在のショートカット: \(HotKeySettings.shared.getModifierString())← / →")
        debugPrint("===================\n")
    }
    
    func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            debugPrint("⚠️ アクセシビリティ権限が必要です")
            
            let alert = NSAlert()
            alert.messageText = "アクセシビリティ権限が必要です"
            alert.informativeText = "このアプリはウィンドウを移動するためにアクセシビリティ権限が必要です。\n\nシステム設定 > プライバシーとセキュリティ > アクセシビリティ\nでこのアプリを許可してください。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "システム設定を開く")
            alert.addButton(withTitle: "あとで")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            debugPrint("✅ アクセシビリティ権限が付与されています")
        }
    }
    
    func debugPrint(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(message)")
    }
    
    // MARK: - ディスプレイ記憶機能（定期スナップショット方式）
    
    /// 定期スナップショットを開始
    private func startPeriodicSnapshot() {
        // 初回は即座に実行
        saveAllWindowPositions()
        
        // 5秒ごとに保存
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.saveAllWindowPositions()
        }
        
        debugPrint("✅ 定期スナップショット（5秒間隔）を開始しました")
    }
    
    /// ディスプレイ変更の監視を開始
    private func setupDisplayChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        debugPrint("✅ ディスプレイ変更の監視を開始しました")
    }
    
    /// ディスプレイ構成が変更された時の処理
    @objc private func screenParametersDidChange(_ notification: Notification) {
        debugPrint("\n=== ディスプレイ構成が変更されました ===")
        
        let currentScreens = NSScreen.screens
        debugPrint("現在の画面数: \(currentScreens.count)")
        
        for (index, screen) in currentScreens.enumerated() {
            let id = getDisplayIdentifier(for: screen)
            debugPrint("  画面\(index): \(id)")
        }
        
        // 少し待ってから復元処理を実行（画面が安定するまで）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.restoreWindowsIfNeeded()
        }
    }
    
    /// ディスプレイの識別子を生成（名前+解像度）
    private func getDisplayIdentifier(for screen: NSScreen) -> String {
        var name = screen.localizedName
        
        // localizedNameが空の場合の対処
        if name.isEmpty {
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                name = "Display\(screenNumber)"
            } else {
                name = "UnknownDisplay"
            }
        }
        
        let width = Int(screen.frame.width)
        let height = Int(screen.frame.height)
        return "\(name)_\(width)x\(height)"
    }
    
    /// ウィンドウの識別子を生成（アプリ名+CGWindowID）
    private func getWindowIdentifier(appName: String, windowID: CGWindowID) -> String {
        return "\(appName)_\(windowID)"
    }
    
    /// 全ウィンドウの位置を保存（定期実行）
    private func saveAllWindowPositions() {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        
        let screens = NSScreen.screens
        
        // 画面ごとに初期化
        for screen in screens {
            let displayID = getDisplayIdentifier(for: screen)
            if windowPositions[displayID] == nil {
                windowPositions[displayID] = [:]
            }
        }
        
        // 全ウィンドウを記録
        for window in windowList {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let cgWindowID = window[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            let windowID = getWindowIdentifier(appName: ownerName, windowID: cgWindowID)
            
            // このウィンドウがどの画面にあるか判定
            for screen in screens {
                if screen.frame.intersects(frame) {
                    let displayID = getDisplayIdentifier(for: screen)
                    windowPositions[displayID]?[windowID] = frame
                    break
                }
            }
        }
    }
    
    /// 必要に応じてウィンドウを復元
    private func restoreWindowsIfNeeded() {
        debugPrint("🔄 ウィンドウ復元処理を開始...")
        
        let currentScreens = NSScreen.screens
        guard currentScreens.count >= 2 else {
            debugPrint("  画面が1つしかないため、復元をスキップします")
            return
        }
        
        let currentScreenIDs = Set(currentScreens.map { getDisplayIdentifier(for: $0) })
        let mainScreen = currentScreens[0]
        let mainScreenID = getDisplayIdentifier(for: mainScreen)
        
        // 保存されている画面IDのうち、現在接続されているものを確認
        let savedScreenIDs = Set(windowPositions.keys)
        let externalScreenIDs = savedScreenIDs.intersection(currentScreenIDs).subtracting([mainScreenID])
        
        if externalScreenIDs.isEmpty {
            debugPrint("  復元対象の外部ディスプレイがありません")
            return
        }
        
        debugPrint("  復元対象ディスプレイ: \(externalScreenIDs.joined(separator: ", "))")
        
        // 現在の全ウィンドウを取得
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            debugPrint("  ❌ ウィンドウリストの取得に失敗")
            return
        }
        
        // デバッグ: 現在のウィンドウリストを表示
        debugPrint("  現在のウィンドウ:")
        for window in windowList {
            if let ownerName = window[kCGWindowOwnerName as String] as? String,
               let cgWindowID = window[kCGWindowNumber as String] as? CGWindowID,
               let layer = window[kCGWindowLayer as String] as? Int, layer == 0 {
                debugPrint("    現在ID: \(ownerName)_\(cgWindowID)")
            }
        }
        
        var restoredCount = 0
        
        // 各外部ディスプレイについて処理
        for externalScreenID in externalScreenIDs {
            guard let savedWindows = windowPositions[externalScreenID], !savedWindows.isEmpty else {
                continue
            }
            
            debugPrint("  画面 \(externalScreenID) に \(savedWindows.count)個の保存情報")
            
            // デバッグ: 保存されているウィンドウIDを表示
            for (savedWindowID, _) in savedWindows {
                debugPrint("    保存ID: \(savedWindowID)")
            }
            
            // 保存されたウィンドウを復元
            for (savedWindowID, savedFrame) in savedWindows {
                debugPrint("    復元試行: \(savedWindowID)")
                
                // windowIDからアプリ名とCGWindowIDを抽出
                let components = savedWindowID.split(separator: "_")
                guard components.count >= 2,
                      let cgWindowID = UInt32(components[1]) else {
                    debugPrint("      ❌ ID解析失敗")
                    continue
                }
                let appName = String(components[0])
                
                // 現在のウィンドウリストから該当するものを探す
                var found = false
                for window in windowList {
                    guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                          ownerName == appName,
                          let currentCGWindowID = window[kCGWindowNumber as String] as? CGWindowID,
                          currentCGWindowID == cgWindowID,
                          let layer = window[kCGWindowLayer as String] as? Int,
                          layer == 0,
                          let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                          let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 else {
                        continue
                    }
                    
                    found = true
                    debugPrint("      ✓ ウィンドウ発見: \(ownerName)")
                    
                    let currentFrame = CGRect(
                        x: boundsDict["X"] ?? 0,
                        y: boundsDict["Y"] ?? 0,
                        width: boundsDict["Width"] ?? 0,
                        height: boundsDict["Height"] ?? 0
                    )
                    
                    debugPrint("      現在位置: \(currentFrame)")
                    debugPrint("      メイン画面: \(mainScreen.frame)")
                    
                    // メイン画面にあるウィンドウのみを復元対象とする
                    if !mainScreen.frame.intersects(currentFrame) {
                        debugPrint("      ❌ メイン画面にない（スキップ）")
                        continue
                    }
                    
                    debugPrint("      ✓ メイン画面にある")
                    
                    // Accessibility APIでウィンドウを移動
                    let appRef = AXUIElementCreateApplication(ownerPID)
                    var windowListRef: CFTypeRef?
                    let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowListRef)
                    
                    if result == .success, let windows = windowListRef as? [AXUIElement] {
                        // 全ウィンドウから該当するものを探す
                        for axWindow in windows {
                            var currentPosRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &currentPosRef) == .success,
                               let currentPosValue = currentPosRef {
                                var currentPoint = CGPoint.zero
                                if AXValueGetValue(currentPosValue as! AXValue, .cgPoint, &currentPoint) {
                                    // 現在の位置が現在のウィンドウ位置と一致するか確認
                                    if abs(currentPoint.x - currentFrame.origin.x) < 10 &&
                                       abs(currentPoint.y - currentFrame.origin.y) < 10 {
                                        // 保存された座標に移動
                                        var position = CGPoint(x: savedFrame.origin.x, y: savedFrame.origin.y)
                                        if let positionValue = AXValueCreate(.cgPoint, &position) {
                                            let setResult = AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, positionValue)
                                            if setResult == .success {
                                                restoredCount += 1
                                                debugPrint("    ✅ \(appName) を (\(savedFrame.origin.x), \(savedFrame.origin.y)) に復元")
                                            } else {
                                                debugPrint("    ❌ \(appName) の移動失敗: \(setResult.rawValue)")
                                            }
                                        }
                                        break
                                    }
                                }
                            }
                        }
                    }
                    break
                }
            }
        }
        
        debugPrint("✅ 合計 \(restoredCount)個のウィンドウを復元しました\n")
    }
    
    deinit {
        // ホットキーの登録解除
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
        }
        if let hotKey = hotKeyRef2 {
            UnregisterEventHotKey(hotKey)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        // タイマーの停止
        snapshotTimer?.invalidate()
    }
}

//
//  TsubameTests.swift
//  TsubameTests
//
//  Created by Masahito Zembutsu on 2025/11/29.
//

import XCTest
@testable import WindowSmartMover

/// 最小限のテスト - まずこれが通ることを確認
final class TsubameTests: XCTestCase {
    
    /// 1. テストが実行できることを確認
    func test_canRunTest() {
        XCTAssertTrue(true)
    }
    
    /// 2. 本体コードにアクセスできることを確認
    func test_canAccessMainCode() {
        // WindowMatchInfoが見えるか
        let info = WindowMatchInfo(
            appName: "Test",
            title: nil,
            size: CGSize(width: 100, height: 100),
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertNotNil(info)
    }
}

// MARK: - WindowMatcher Tests

/// Firefox複数ウィンドウのテスト
final class WindowMatcherTests: XCTestCase {
    
    var matcher: WindowMatcher!
    
    override func setUp() {
        super.setUp()
        matcher = WindowMatcher()
    }
    
    override func tearDown() {
        matcher = nil
        super.tearDown()
    }
    
    // ヘルパー: 保存情報を作成
    private func makeSavedInfo(
        appName: String,
        title: String? = nil,
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    ) -> WindowMatchInfo {
        WindowMatchInfo(
            appName: appName,
            title: title,
            size: frame.size,
            frame: frame
        )
    }
    
    // ヘルパー: ウィンドウ候補を作成
    private func makeCandidate(
        id: CGWindowID,
        appName: String,
        title: String? = nil,
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    ) -> WindowCandidate {
        WindowCandidate(
            cgWindowID: id,
            appName: appName,
            title: title,
            frame: frame,
            pid: 1234
        )
    }
    
    /// Firefox: タイトルで正しいウィンドウを区別できるか
    func test_firefox_distinguishesByTitle() {
        // 保存時: GitHubを見ていた
        let saved = makeSavedInfo(appName: "Firefox", title: "GitHub - Mozilla Firefox")
        
        // 現在: 3つのウィンドウが開いている
        let candidates = [
            makeCandidate(id: 1, appName: "Firefox", title: "YouTube - Mozilla Firefox"),
            makeCandidate(id: 2, appName: "Firefox", title: "GitHub - Mozilla Firefox"),
            makeCandidate(id: 3, appName: "Firefox", title: "Twitter - Mozilla Firefox"),
        ]
        
        // 実行
        let result = matcher.findMatch(for: saved, in: candidates)
        
        // 検証: GitHubのウィンドウ（id: 2）が返される
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.candidate.cgWindowID, 2)
        XCTAssertEqual(result?.method, .titleHash)
    }
    
    /// Terminal: 同一タイトル・サイズでも位置で区別できるか
    func test_terminal_distinguishesByPosition() {
        // 保存時: 左側のターミナル (100, 100)
        let saved = makeSavedInfo(
            appName: "Terminal",
            title: "zsh",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600)
        )
        
        // 現在: 2つの同一ウィンドウ（タイトル・サイズ同じ、位置が違う）
        let candidates = [
            makeCandidate(id: 1, appName: "Terminal", title: "zsh",
                         frame: CGRect(x: 900, y: 100, width: 800, height: 600)),  // 右側
            makeCandidate(id: 2, appName: "Terminal", title: "zsh",
                         frame: CGRect(x: 100, y: 100, width: 800, height: 600)),  // 左側
        ]
        
        // 実行
        let result = matcher.findMatch(for: saved, in: candidates)
        
        // 検証: 位置が近い左側（id: 2）が返される
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.candidate.cgWindowID, 2)
    }
}

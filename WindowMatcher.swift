import Foundation
import CoreGraphics

// MARK: - Window Candidate（テスト可能な入力データ構造）

/// 現在のウィンドウ情報（CGWindowListから変換）
/// テスト時はこの構造体を直接作成できる
struct WindowCandidate: Equatable {
    let cgWindowID: CGWindowID
    let appName: String
    let title: String?
    let frame: CGRect
    let pid: Int32
    
    /// appNameのSHA256ハッシュ（キャッシュ用）
    var appNameHash: String {
        WindowMatchInfo.hash(appName)
    }
    
    /// titleのSHA256ハッシュ（キャッシュ用）
    var titleHash: String? {
        title.map { WindowMatchInfo.hash($0) }
    }
}

// MARK: - Window Matcher（テスト可能なマッチングロジック）

/// ウィンドウマッチングロジック
/// AppDelegateから分離することでユニットテストが可能
class WindowMatcher {
    
    // MARK: - Match Result
    
    /// マッチ結果とその方法を返す（デバッグ・テスト用）
    enum MatchMethod: Equatable {
        case cgWindowID          // CGWindowID完全一致（最優先）
        case titleHash           // appNameHash + titleHash
        case sizeApproximate     // appNameHash + サイズ近似
        case appNameOnly         // appNameHash単体（最終フォールバック）
    }
    
    struct MatchResult: Equatable {
        let candidate: WindowCandidate
        let method: MatchMethod
    }
    
    // MARK: - Configuration
    
    /// サイズマッチの許容誤差（ピクセル）
    var sizeTolerance: CGFloat = 20
    
    // MARK: - Main Matching Logic
    
    /// 保存されたウィンドウ情報に最もマッチする現在のウィンドウを探す
    ///
    /// 優先順位:
    /// 1. CGWindowID完全一致（セッション中は確実）
    /// 2. appNameHash + titleHash（タイトルで識別）
    /// 3. appNameHash + サイズ近似（同一サイズのウィンドウ）
    /// 4. appNameHash単体（最終フォールバック）
    ///
    /// 同一優先度で複数候補がある場合、保存時の位置に最も近いものを選択
    ///
    /// - Parameters:
    ///   - savedInfo: 保存されたウィンドウ情報
    ///   - candidates: 現在のウィンドウ候補一覧
    ///   - usedIDs: 既にマッチ済みで除外するCGWindowID
    ///   - preferredCGWindowID: 優先的にマッチさせるCGWindowID（保存時のID）
    /// - Returns: マッチ結果（候補とマッチ方法）、見つからない場合はnil
    func findMatch(
        for savedInfo: WindowMatchInfo,
        in candidates: [WindowCandidate],
        excluding usedIDs: Set<CGWindowID> = [],
        preferredCGWindowID: CGWindowID? = nil
    ) -> MatchResult? {
        
        var titleMatches: [WindowCandidate] = []
        var sizeMatches: [WindowCandidate] = []
        var appOnlyMatches: [WindowCandidate] = []
        
        for candidate in candidates {
            // 既に使用済みのウィンドウはスキップ
            if usedIDs.contains(candidate.cgWindowID) {
                continue
            }
            
            // CGWindowID完全一致（最優先）
            // appNameHashも確認して異なるアプリのウィンドウを誤マッチしないようにする
            if let preferredID = preferredCGWindowID,
               candidate.cgWindowID == preferredID,
               candidate.appNameHash == savedInfo.appNameHash {
                return MatchResult(candidate: candidate, method: .cgWindowID)
            }
            
            // appNameHashが一致しなければスキップ
            guard candidate.appNameHash == savedInfo.appNameHash else {
                continue
            }
            
            // titleHashでマッチ
            if let savedTitleHash = savedInfo.titleHash,
               let candidateTitleHash = candidate.titleHash,
               candidateTitleHash == savedTitleHash {
                titleMatches.append(candidate)
                continue
            }
            
            // サイズでマッチ
            if savedInfo.sizeMatches(candidate.frame.size, tolerance: sizeTolerance) {
                sizeMatches.append(candidate)
                continue
            }
            
            // appName単体マッチ（最後のフォールバック）
            appOnlyMatches.append(candidate)
        }
        
        // 位置近接でソート（保存時の位置に最も近いウィンドウを優先）
        let savedOrigin = savedInfo.frame.origin
        
        let sortByDistance: ([WindowCandidate]) -> [WindowCandidate] = { candidates in
            candidates.sorted { a, b in
                self.distance(from: a.frame.origin, to: savedOrigin) <
                self.distance(from: b.frame.origin, to: savedOrigin)
            }
        }
        
        // 優先順位順に返す
        if let match = sortByDistance(titleMatches).first {
            return MatchResult(candidate: match, method: .titleHash)
        }
        if let match = sortByDistance(sizeMatches).first {
            return MatchResult(candidate: match, method: .sizeApproximate)
        }
        if let match = sortByDistance(appOnlyMatches).first {
            return MatchResult(candidate: match, method: .appNameOnly)
        }
        
        return nil
    }
    
    // MARK: - Helper
    
    /// 2点間の距離を計算
    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - CGWindowList Conversion Helper

extension WindowMatcher {
    
    /// CGWindowListCopyWindowInfoの結果をWindowCandidate配列に変換
    /// - Parameter windowList: CGWindowListCopyWindowInfoの結果
    /// - Returns: WindowCandidate配列（layer 0のウィンドウのみ）
    static func convertFromCGWindowList(_ windowList: [[String: Any]]) -> [WindowCandidate] {
        var candidates: [WindowCandidate] = []
        
        for window in windowList {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let cgWindowID = window[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            let title = window[kCGWindowName as String] as? String
            
            candidates.append(WindowCandidate(
                cgWindowID: cgWindowID,
                appName: ownerName,
                title: title,
                frame: frame,
                pid: ownerPID
            ))
        }
        
        return candidates
    }
}

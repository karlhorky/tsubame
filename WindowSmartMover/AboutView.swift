//
//  AboutView.swift
//  WindowSmartMover
//
//  Created by Masahito Zembutsu on 2025/10/18.
//

import SwiftUI

struct AboutView: View {
    // Info.plistから情報を取得
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "WindowSmartMover"
    }
    
    private let githubURL = "https://github.com/zembutsu/WindowSmartMover"
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // アイコン
            Image(systemName: "rectangle.2.swap")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding(.top, 20)
            
            // アプリ名
            VStack(spacing: 4) {
                Text("Tsubame")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Window Smart Mover")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // バージョン情報
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Version")
                        .foregroundColor(.secondary)
                    Text(appVersion)
                        .fontWeight(.semibold)
                }
                
                HStack(spacing: 4) {
                    Text("Build")
                        .foregroundColor(.secondary)
                    Text(buildNumber)
                        .fontWeight(.semibold)
                }
            }
            .font(.subheadline)
            
            Divider()
            
            // ショートカット一覧
            GroupBox(label: Text("ショートカット").font(.headline)) {
                VStack(alignment: .leading, spacing: 6) {
                    let mod = HotKeySettings.shared.getModifierString()
                    
                    HStack {
                        Text("画面間移動")
                            .frame(width: 90, alignment: .leading)
                            .font(.subheadline)
                        Text("\(mod)→ / \(mod)←")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("スナップショット")
                            .frame(width: 90, alignment: .leading)
                            .font(.subheadline)
                        Text("\(mod)↑ / \(mod)↓")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("位置微調整")
                            .frame(width: 90, alignment: .leading)
                            .font(.subheadline)
                        Text("\(mod)W/A/S/D")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // 情報
            GroupBox(label: Text("情報").font(.headline)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("開発者")
                            .frame(width: 70, alignment: .leading)
                            .font(.subheadline)
                        Text("Masahito Zembutsu")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("ライセンス")
                            .frame(width: 70, alignment: .leading)
                            .font(.subheadline)
                        Text("MIT License")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("GitHub")
                            .frame(width: 70, alignment: .leading)
                            .font(.subheadline)
                        Link("zembutsu/WindowSmartMover", destination: URL(string: githubURL)!)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
            
            // 著作権情報
            Text("© 2025 @zembutsu")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 閉じるボタン
            Button("OK") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .padding(.horizontal)
        .frame(width: 360, height: 520)
    }
}

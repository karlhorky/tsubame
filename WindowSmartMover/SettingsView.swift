import SwiftUI
import Carbon
import Combine

class HotKeySettings: ObservableObject {
    static let shared = HotKeySettings()
    
    @Published var useControl: Bool {
        didSet { UserDefaults.standard.set(useControl, forKey: "useControl") }
    }
    @Published var useOption: Bool {
        didSet { UserDefaults.standard.set(useOption, forKey: "useOption") }
    }
    @Published var useShift: Bool {
        didSet { UserDefaults.standard.set(useShift, forKey: "useShift") }
    }
    @Published var useCommand: Bool {
        didSet { UserDefaults.standard.set(useCommand, forKey: "useCommand") }
    }
    
    private init() {
        // デフォルト値: Ctrl + Option + Command
        self.useControl = UserDefaults.standard.object(forKey: "useControl") as? Bool ?? true
        self.useOption = UserDefaults.standard.object(forKey: "useOption") as? Bool ?? true
        self.useShift = UserDefaults.standard.object(forKey: "useShift") as? Bool ?? false
        self.useCommand = UserDefaults.standard.object(forKey: "useCommand") as? Bool ?? true
    }
    
    func getModifiers() -> UInt32 {
        var modifiers: UInt32 = 0
        if useControl { modifiers |= UInt32(controlKey) }
        if useOption { modifiers |= UInt32(optionKey) }
        if useShift { modifiers |= UInt32(shiftKey) }
        if useCommand { modifiers |= UInt32(cmdKey) }
        return modifiers
    }
    
    func getModifierString() -> String {
        var parts: [String] = []
        if useControl { parts.append("⌃") }
        if useOption { parts.append("⌥") }
        if useShift { parts.append("⇧") }
        if useCommand { parts.append("⌘") }
        return parts.joined()
    }
}

struct SettingsView: View {
    @ObservedObject var settings = HotKeySettings.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("キーボードショートカット設定")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("修飾キーを選択してください：")
                    .font(.subheadline)
                
                Toggle("⌃ Control", isOn: $settings.useControl)
                Toggle("⌥ Option", isOn: $settings.useOption)
                Toggle("⇧ Shift", isOn: $settings.useShift)
                Toggle("⌘ Command", isOn: $settings.useCommand)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("現在のショートカット：")
                    .font(.subheadline)
                HStack {
                    Text("\(settings.getModifierString())→")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("次の画面へ")
                        .font(.body)
                }
                HStack {
                    Text("\(settings.getModifierString())←")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("前の画面へ")
                        .font(.body)
                }
            }
            .padding()
            
            Text("⚠️ 設定を変更したらアプリを再起動してください")
                .font(.caption)
                .foregroundColor(.orange)
            
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("OK") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

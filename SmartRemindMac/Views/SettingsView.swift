import SwiftUI

// Settings is now integrated into MainWindowView
// This file kept for compilation compatibility
struct SettingsView: View {
    @EnvironmentObject var llmService: LLMService
    @EnvironmentObject var config: AppearanceConfig
    var body: some View {
        Text("请使用主界面中的设置面板")
            .frame(width: 300, height: 200)
    }
}

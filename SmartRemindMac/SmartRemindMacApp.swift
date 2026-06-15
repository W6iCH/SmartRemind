import SwiftUI

@main
struct SmartRemindMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 纯状态栏应用 — 无主窗口，全由 AppDelegate 管理
        WindowGroup(id: "settings") {
            EmptyView()
        }
    }
}

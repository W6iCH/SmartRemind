import SwiftUI

/// Placeholder — 实际 UI 通过状态栏/悬浮窗呈现
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist").font(.system(size: 40)).foregroundColor(.accentColor)
            Text("SmartRemind").font(.title2)
            Text("应用已在状态栏运行 · 按 ⌥⇧R 唤出悬浮窗").font(.caption).foregroundColor(.secondary)
        }
        .frame(width: 260, height: 150)
    }
}

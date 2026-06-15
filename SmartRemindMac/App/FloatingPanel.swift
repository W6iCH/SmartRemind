import AppKit
import SwiftUI

/// 无边框悬浮窗 — Esc 不关闭，悬停不暂停（由 SwiftUI 控制）
final class FloatingPanel: NSPanel {

    private var hostingView: NSHostingView<AnyView>!

    init() {
        let config = AppearanceConfig.shared
        let size = NSSize(width: config.floatWidth, height: config.floatHeight)

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true

        if !config.floatResizable {
            self.styleMask.remove(.resizable)
        }

        hostingView = NSHostingView(
            rootView: AnyView(
                FloatingWindowView()
                    .environmentObject(ReminderManager.shared)
                    .environmentObject(AppearanceConfig.shared)
            )
        )
        self.contentView = hostingView
        positionAtTopRight()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // ✅ 禁止 Esc 关闭悬浮窗
    override func cancelOperation(_ sender: Any?) {
        // 不执行任何操作 — 悬浮窗保持显示
    }

    func refreshContentView() {
        hostingView.rootView = AnyView(
            FloatingWindowView()
                .environmentObject(ReminderManager.shared)
                .environmentObject(AppearanceConfig.shared)
        )
    }

    func positionAtTopRight() {
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 20
        let x = screen.visibleFrame.maxX - frame.width - padding
        let y = screen.visibleFrame.maxY - frame.height - padding
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updateSize() {
        let config = AppearanceConfig.shared
        var newSize = NSSize(width: config.floatWidth, height: config.floatHeight)
        // 如果显示 AI 输入框，自动加高度
        if config.floatShowInput {
            newSize.height += 28
        }
        let newFrame = NSRect(origin: frame.origin, size: newSize)
        setFrame(newFrame, display: true, animate: true)
    }

    // 手动拖拽大小 → 同步回 config
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        let config = AppearanceConfig.shared
        if config.floatResizable && frameRect.width > 100 && frameRect.height > 30 {
            config.floatWidth = Double(frameRect.width)
            config.floatHeight = Double(frameRect.height)
        }
    }
}

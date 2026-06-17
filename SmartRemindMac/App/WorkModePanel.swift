import AppKit
import SwiftUI

/// 工作模式悬浮窗 — 无边框 always-on-top
final class WorkModePanel: NSPanel {

    private var hostingView: NSHostingView<AnyView>!

    init() {
        let config = AppearanceConfig.shared
        let size = NSSize(width: config.workWidth, height: config.workHeight)

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

        if !config.workResizable {
            self.styleMask.remove(.resizable)
        }

        hostingView = NSHostingView(
            rootView: AnyView(
                WorkModeView()
                    .environmentObject(ReminderManager.shared)
                    .environmentObject(AppearanceConfig.shared)
            )
        )
        self.contentView = hostingView
        positionAtLeft()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        // Esc 不关闭
    }

    func refreshContentView() {
        hostingView.rootView = AnyView(
            WorkModeView()
                .environmentObject(ReminderManager.shared)
                .environmentObject(AppearanceConfig.shared)
        )
    }

    func positionAtLeft() {
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 20
        let x = screen.visibleFrame.minX + padding
        let y = screen.visibleFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        let config = AppearanceConfig.shared
        if config.workResizable && frameRect.width > 100 && frameRect.height > 100 {
            config.workWidth = Double(frameRect.width)
            config.workHeight = Double(frameRect.height)
        }
    }
}

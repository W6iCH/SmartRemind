import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var menuPanel: NSPanel?
    private var floatingPanel: FloatingPanel?
    private var mainWindow: NSWindow?
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        setupGlobalHotkey()
        setupNotificationObserver()
        Task {
            await ReminderManager.shared.requestAccess()
            await ReminderManager.shared.fetchReminders()
        }
    }

    // MARK: - Status Bar (Icon Only)

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.action = #selector(statusBarClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateStatusBarIcon()
        }
    }

    func updateStatusBarDisplay() {
        updateStatusBarIcon()
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        let config = AppearanceConfig.shared
        let symbolName = config.statusBarIconName.isEmpty ? "checklist" : config.statusBarIconName
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SmartRemind") {
            img.isTemplate = true // follows system appearance
            button.image = img
        }
        button.title = ""
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleMenuPanel()
        }
    }

    // MARK: - Menu Panel

    private func toggleMenuPanel() {
        if let panel = menuPanel, panel.isVisible { closeMenuPanel() }
        else { showMenuPanel() }
    }

    private func showMenuPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let pw: CGFloat = 380, ph: CGFloat = 520
        let x = buttonFrame.midX - pw / 2
        let y = buttonFrame.minY - ph - 4

        if menuPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: x, y: y, width: pw, height: ph),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            panel.titlebarAppearsTransparent = true; panel.titleVisibility = .hidden
            panel.isMovable = false; panel.level = .popUpMenu
            panel.backgroundColor = .windowBackgroundColor
            panel.hasShadow = true; panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.fullScreenAuxiliary]
            panel.contentView = NSHostingView(
                rootView: MenuBarPopoverView().environmentObject(ReminderManager.shared)
            )
            menuPanel = panel
        }
        menuPanel?.setFrame(NSRect(x: x, y: y, width: pw, height: ph), display: true)
        menuPanel?.makeKeyAndOrderFront(nil)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.menuPanel, panel.isVisible else { return }
            let loc = event.locationInWindow
            if let ew = event.window {
                let sp = ew.convertToScreen(NSRect(origin: loc, size: .zero)).origin
                if panel.frame.contains(sp) { return }
            }
            if let cw = event.window, cw.level.rawValue >= NSWindow.Level.popUpMenu.rawValue { return }
            if event.window == self.statusItem.button?.window { return }
            DispatchQueue.main.async { self.closeMenuPanel() }
        }
    }

    private func closeMenuPanel() {
        menuPanel?.orderOut(nil)
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "主界面", action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "悬浮窗", action: #selector(handleToggleFloatingPanel), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.statusItem.menu = nil }
    }

    // MARK: - Main Window

    @objc func openMainWindow() {
        closeMenuPanel()
        if let win = mainWindow, win.isVisible { win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false
        )
        win.title = "SmartRemind"
        win.contentView = NSHostingView(
            rootView: MainWindowView()
                .environmentObject(ReminderManager.shared)
                .environmentObject(AppearanceConfig.shared)
                .environmentObject(LLMService.shared)
        )
        win.center(); win.isReleasedWhenClosed = false
        mainWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Floating Panel

    @objc func handleToggleFloatingPanel() {
        if let panel = floatingPanel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            if floatingPanel == nil { floatingPanel = FloatingPanel() }
            floatingPanel?.refreshContentView()
            floatingPanel?.makeKeyAndOrderFront(nil)
        }
    }

    func relaunchFloatingPanel() {
        floatingPanel?.orderOut(nil)
        floatingPanel = FloatingPanel()
        floatingPanel?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Hotkey ⌥⇧R

    private func setupGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.option, .shift]) && event.keyCode == 15 {
                DispatchQueue.main.async { self?.handleToggleFloatingPanel() }
            }
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.option, .shift]) && event.keyCode == 15 {
                DispatchQueue.main.async { self?.handleToggleFloatingPanel() }
                return nil
            }
            return event
        }
    }

    // MARK: - Notifications

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleFloatingPanel), name: .toggleFloatingPanel, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRemindersChanged), name: .remindersChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openMainWindow), name: .openMainWindow, object: nil)
    }

    @objc private func handleRemindersChanged() {
        Task {
            await ReminderManager.shared.fetchReminders()
            updateStatusBarDisplay()
        }
    }
}

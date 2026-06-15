import SwiftUI
import AppKit

/// 专用于 Popover 的输入区域 — 解决输入法空格退出问题
/// 核心：使用 NSTextField 的 NSViewRepresentable 包装，阻止事件冒泡
struct PopoverInputArea: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @StateObject private var coordinator = SmartReminderCoordinator.shared
    @State private var inputText: String = ""
    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                // 使用自定义 NSTextField 包装，阻止空格键事件冒泡到 Popover
                StableTextField(
                    text: $inputText,
                    placeholder: "自然语言输入，回车添加...",
                    onSubmit: submit
                )
                .frame(height: 24)

                if coordinator.isProcessing {
                    ProgressView().scaleEffect(0.6).frame(width: 16, height: 16)
                } else {
                    Button(action: submit) {
                        Image(systemName: "paperplane.fill").font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            // 状态提示
            if let err = errorMsg {
                Text(err).font(.system(size: 9)).foregroundColor(.red).lineLimit(1)
            } else if coordinator.currentStage != .idle && coordinator.currentStage != .done {
                HStack(spacing: 3) {
                    ProgressView().scaleEffect(0.4).frame(width: 8, height: 8)
                    Text(stageText).font(.system(size: 9)).foregroundColor(.blue)
                }
            } else if coordinator.currentStage == .done, let r = coordinator.lastResult {
                Text("✓ 已添加「\(r.items.first?.title ?? "")」")
                    .font(.system(size: 9)).foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var stageText: String {
        switch coordinator.currentStage {
        case .parsingWithAI: return "AI 解析中..."
        case .geocoding: return "位置解析..."
        case .savingToReminders: return "写入中..."
        default: return ""
        }
    }

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        errorMsg = nil
        Task {
            do {
                _ = try await coordinator.processInput(text)
                inputText = ""
                NotificationCenter.default.post(name: .remindersChanged, object: nil)
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }
}

// MARK: - StableTextField (解决 Popover 空格退出问题)

/// 自定义 NSTextField 包装，拦截 key events 防止 Popover 关闭
struct StableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.5)
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 12)
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.wantsLayer = true
        field.layer?.cornerRadius = 4

        // 关键：阻止 key event 冒泡到 popover
        field.refusesFirstResponder = false
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: StableTextField

        init(_ parent: StableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            // 返回 false 让其他 key events 正常处理（包括空格）
            return false
        }
    }
}

import SwiftUI
import AppKit

struct MenuBarPopoverView: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @State private var editingItem: ReminderItem?
    @State private var showNewReminder = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            header
            Divider()

            // 提醒列表（完整 CRUD）
            if reminderManager.reminders.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.system(size: 28)).foregroundColor(.secondary)
                    Text("暂无待办").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(reminderManager.reminders) { item in
                            reminderRow(item)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // 输入区 — 用自定义 InputField 避免空格退出问题
            PopoverInputArea()
                .environmentObject(reminderManager)

            Divider()

            // 底部操作栏
            bottomBar
        }
        .frame(width: 380, height: 500)
        .sheet(item: $editingItem) { item in
            EditReminderSheet(item: item)
                .environmentObject(reminderManager)
        }
        .sheet(isPresented: $showNewReminder) {
            NewReminderSheet()
                .environmentObject(reminderManager)
        }
        .task {
            await reminderManager.requestAccess()
            await reminderManager.fetchReminders()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "checklist").foregroundColor(.accentColor)
            Text("SmartRemind").font(.headline)
            if reminderManager.reminders.count > 0 {
                Text("\(reminderManager.reminders.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
            }
            Spacer()
            Button(action: { showNewReminder = true }) {
                Image(systemName: "plus").font(.caption)
            }
            .buttonStyle(.plain)
            Button(action: { Task { await reminderManager.fetchReminders() } }) {
                Image(systemName: "arrow.clockwise").font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Reminder Row (with CRUD)

    private func reminderRow(_ item: ReminderItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // 完成切换
                Button(action: {
                    Task { try? await reminderManager.toggleCompletion(for: item) }
                }) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundColor(item.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .strikethrough(item.isCompleted)

                Spacer()

                if let listName = item.listName {
                    Text(listName)
                        .font(.system(size: 9))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(3)
                }

                // 编辑按钮
                Button(action: { editingItem = item }) {
                    Image(systemName: "pencil").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                // 删除按钮
                Button(action: {
                    Task { try? await reminderManager.deleteReminder(id: item.id) }
                }) {
                    Image(systemName: "trash").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red.opacity(0.6))
            }

            // 详细信息
            if item.dueDate != nil || item.location != nil || (item.notes != nil && !item.notes!.isEmpty) {
                HStack(spacing: 8) {
                    if let dueDate = item.dueDate {
                        Label(formatRelative(dueDate), systemImage: "clock")
                            .font(.system(size: 10)).foregroundColor(.orange)
                    }
                    if let location = item.location {
                        Label(location, systemImage: "mappin")
                            .font(.system(size: 10)).foregroundColor(.blue).lineLimit(1)
                    }
                    if let notes = item.notes, !notes.isEmpty {
                        Label(notes, systemImage: "text.alignleft")
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                .padding(.leading, 18)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(4)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                NotificationCenter.default.post(name: .toggleFloatingPanel, object: nil)
            }) {
                Label("悬浮窗", systemImage: "rectangle.on.rectangle").font(.caption)
            }
            .buttonStyle(.plain).foregroundColor(.accentColor)

            Button(action: {
                NotificationCenter.default.post(name: .toggleWorkMode, object: nil)
            }) {
                Label("工作模式", systemImage: "target").font(.caption)
            }
            .buttonStyle(.plain).foregroundColor(.orange)

            Spacer()

            Button(action: {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }) {
                Label("设置", systemImage: "gear").font(.caption)
            }
            .buttonStyle(.plain).foregroundColor(.secondary)

            Button("退出") { NSApplication.shared.terminate(nil) }
                .font(.caption).buttonStyle(.plain).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func formatRelative(_ date: Date) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) {
            fmt.dateFormat = "HH:mm"; return "今天 \(fmt.string(from: date))"
        } else if cal.isDateInTomorrow(date) {
            fmt.dateFormat = "HH:mm"; return "明天 \(fmt.string(from: date))"
        } else {
            fmt.dateFormat = "M/d HH:mm"; return fmt.string(from: date)
        }
    }
}

// MARK: - 通知名
extension Notification.Name {
    static let toggleFloatingPanel = Notification.Name("toggleFloatingPanel")
    static let openSettings = Notification.Name("openSettings")
    static let remindersChanged = Notification.Name("remindersChanged")
    static let openMainWindow = Notification.Name("openMainWindow")
    static let toggleWorkMode = Notification.Name("toggleWorkMode")
}

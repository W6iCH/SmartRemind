import SwiftUI

/// 编辑提醒事项 Sheet — 支持旗标/优先级/分组编辑
struct EditReminderSheet: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @Environment(\.dismiss) var dismiss

    let item: ReminderItem
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var isFlagged: Bool = false
    @State private var priority: Int = 0
    @State private var selectedList: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("编辑提醒事项").font(.headline)

            TextField("标题", text: $title)
                .textFieldStyle(.roundedBorder)

            // 分组
            Picker("分组", selection: $selectedList) {
                Text("默认").tag("")
                ForEach(reminderManager.lists, id: \.calendarIdentifier) { list in
                    Text(list.title).tag(list.title)
                }
            }

            HStack {
                Toggle("截止日期", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("", selection: $dueDate).labelsHidden()
                }
            }

            // 旗标 & 优先级
            HStack(spacing: 16) {
                Toggle(isOn: $isFlagged) {
                    Label("旗标", systemImage: isFlagged ? "flag.fill" : "flag")
                        .foregroundColor(isFlagged ? .orange : .secondary)
                }
                .toggleStyle(.button)

                Picker("优先级", selection: $priority) {
                    Text("无").tag(0)
                    Text("高").tag(1)
                    Text("中").tag(5)
                    Text("低").tag(9)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            TextField("地点（可选）", text: $location)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("备注").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(height: 50)
                    .font(.system(size: 12))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            }

            if let err = errorMsg {
                Text(err).font(.caption).foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .padding(20)
        .frame(width: 420, height: 380)
        .onAppear {
            title = item.title
            notes = item.notes ?? ""
            location = item.location ?? ""
            isFlagged = item.flagged
            priority = item.priority
            selectedList = item.listName ?? ""
            if let d = item.dueDate { hasDueDate = true; dueDate = d }
            reminderManager.fetchLists()
        }
    }

    private func save() {
        isSaving = true; errorMsg = nil
        Task {
            do {
                try await reminderManager.updateReminder(
                    id: item.id,
                    title: title.trimmingCharacters(in: .whitespaces),
                    dueDate: hasDueDate ? dueDate : nil,
                    listName: selectedList.isEmpty ? nil : selectedList,
                    notes: notes,
                    location: location.isEmpty ? nil : location
                )
                // Apply flag/priority changes
                if isFlagged != item.flagged {
                    try await reminderManager.setFlagged(id: item.id, flagged: isFlagged)
                }
                if priority != item.priority && !isFlagged {
                    try await reminderManager.setPriority(id: item.id, priority: priority)
                }
                // Move list if changed
                if !selectedList.isEmpty && selectedList != item.listName {
                    try await reminderManager.moveToList(id: item.id, listName: selectedList)
                }
                NotificationCenter.default.post(name: .remindersChanged, object: nil)
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
            isSaving = false
        }
    }
}

/// 新建提醒事项 Sheet — 支持旗标/优先级
struct NewReminderSheet: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var isFlagged: Bool = false
    @State private var priority: Int = 0
    @State private var selectedList: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("新建提醒事项").font(.headline)

            TextField("标题", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("分组", selection: $selectedList) {
                Text("默认").tag("")
                ForEach(reminderManager.lists, id: \.calendarIdentifier) { list in
                    Text(list.title).tag(list.title)
                }
            }

            HStack {
                Toggle("截止日期", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("", selection: $dueDate).labelsHidden()
                }
            }

            HStack(spacing: 16) {
                Toggle(isOn: $isFlagged) {
                    Label("旗标", systemImage: isFlagged ? "flag.fill" : "flag")
                        .foregroundColor(isFlagged ? .orange : .secondary)
                }
                .toggleStyle(.button)

                Picker("优先级", selection: $priority) {
                    Text("无").tag(0)
                    Text("高").tag(1)
                    Text("中").tag(5)
                    Text("低").tag(9)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            TextField("地点（可选）", text: $location)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("备注").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(height: 50)
                    .font(.system(size: 12))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            }

            if let err = errorMsg {
                Text(err).font(.caption).foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("创建") { create() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .padding(20)
        .frame(width: 420, height: 400)
        .task { reminderManager.fetchLists() }
    }

    private func create() {
        isSaving = true; errorMsg = nil
        Task {
            do {
                try await reminderManager.createReminder(.init(
                    title: title.trimmingCharacters(in: .whitespaces),
                    listName: selectedList.isEmpty ? nil : selectedList,
                    dueDate: hasDueDate ? dueDate : nil,
                    location: location.isEmpty ? nil : location,
                    notes: notes.isEmpty ? nil : notes,
                    priority: priority > 0 ? priority : nil,
                    flagged: isFlagged ? true : nil
                ))
                NotificationCenter.default.post(name: .remindersChanged, object: nil)
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
            isSaving = false
        }
    }
}

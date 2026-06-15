import SwiftUI

/// 编辑提醒事项 Sheet
struct EditReminderSheet: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @Environment(\.dismiss) var dismiss

    let item: ReminderItem
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var isSaving = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("编辑提醒事项").font(.headline)

            TextField("标题", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack {
                Toggle("截止日期", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("", selection: $dueDate)
                        .labelsHidden()
                }
            }

            TextField("地点（可选）", text: $location)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("备注").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(height: 60)
                    .font(.system(size: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3))
                    )
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
        .frame(width: 380, height: 300)
        .onAppear {
            title = item.title
            notes = item.notes ?? ""
            location = item.location ?? ""
            if let d = item.dueDate {
                hasDueDate = true; dueDate = d
            }
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
                    listName: nil,
                    notes: notes,
                    location: location.isEmpty ? nil : location
                )
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
            isSaving = false
        }
    }
}

/// 新建提醒事项 Sheet
struct NewReminderSheet: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var selectedList: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新建提醒事项").font(.headline)

            TextField("标题", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("分类", selection: $selectedList) {
                Text("默认").tag("")
                ForEach(reminderManager.lists, id: \.calendarIdentifier) { list in
                    Text(list.title).tag(list.title)
                }
            }

            HStack {
                Toggle("截止日期", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("", selection: $dueDate)
                        .labelsHidden()
                }
            }

            TextField("地点（可选）", text: $location)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("备注").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(height: 60)
                    .font(.system(size: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3))
                    )
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
        .frame(width: 380, height: 360)
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
                    notes: notes.isEmpty ? nil : notes
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

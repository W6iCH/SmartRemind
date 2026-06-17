import SwiftUI

// MARK: - 工作模式悬浮窗 v2 — 简洁 + 计时器 + List onMove 排序

struct WorkModeView: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @EnvironmentObject var config: AppearanceConfig

    @State private var phase: WorkPhase = .picking
    @State private var selectedIds: Set<String> = []
    @State private var orderedTasks: [WorkTask] = []
    @State private var searchText: String = ""

    // Timer
    @State private var sessionStartDate: Date = Date()
    @State private var elapsedSeconds: Int = 0
    @State private var isPaused: Bool = false
    @State private var pausedAccumulated: Int = 0  // seconds before current pause
    @State private var lastResumeDate: Date = Date()
    @State private var timerObj: Timer?

    enum WorkPhase { case picking, working }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: config.workCornerRadius)
                .fill(config.workBgColor.opacity(config.workBgOpacity))

            VStack(spacing: 0) {
                switch phase {
                case .picking: pickingView
                case .working: workingView
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: config.workCornerRadius))
        .task { await reminderManager.fetchReminders() }
    }

    // MARK: ─── Phase 1: Pick Tasks ───

    private var pickingView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "target").foregroundColor(config.workAccentColor)
                Text("选择任务").font(.system(size: config.workHeaderFontSize, weight: .bold))
                    .foregroundColor(config.workTextColor)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10)).foregroundColor(config.workTextColor.opacity(0.3))
                TextField("搜索...", text: $searchText)
                    .textFieldStyle(.plain).font(.system(size: 11))
                    .foregroundColor(config.workTextColor)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                            .foregroundColor(config.workTextColor.opacity(0.3))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(config.workTextColor.opacity(0.05))

            Divider().background(config.workTextColor.opacity(0.1))

            // Task list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(pickableReminders) { item in
                        pickRow(item)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider().background(config.workTextColor.opacity(0.1))

            // Bottom
            HStack {
                Text("\(selectedIds.count) 项已选")
                    .font(.system(size: 11)).foregroundColor(config.workTextColor.opacity(0.5))
                Spacer()
                Button("开始") { startWorking() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(selectedIds.isEmpty)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    private var pickableReminders: [ReminderItem] {
        let items = reminderManager.reminders.filter { !$0.isCompleted }
        if searchText.isEmpty { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.listName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private func pickRow(_ item: ReminderItem) -> some View {
        let sel = selectedIds.contains(item.id)
        return Button(action: {
            if sel { selectedIds.remove(item.id) } else { selectedIds.insert(item.id) }
        }) {
            HStack(spacing: 8) {
                Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundColor(sel ? config.workAccentColor : config.workTextColor.opacity(0.25))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        if item.flagged {
                            Image(systemName: "flag.fill").font(.system(size: 8))
                                .foregroundColor(config.color(from: config.floatFlagColorHex))
                        }
                        Text(item.title)
                            .font(.system(size: config.workFontSize))
                            .foregroundColor(config.workTextColor).lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        if let ln = item.listName {
                            HStack(spacing: 2) {
                                Circle().fill(item.listColor).frame(width: 5, height: 5)
                                Text(ln)
                            }
                            .font(.system(size: config.workSubFontSize))
                            .foregroundColor(config.workTextColor.opacity(0.45))
                        }
                        if let d = item.dueDate {
                            Text(shortDate(d))
                                .font(.system(size: config.workSubFontSize))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                        if let loc = item.location {
                            Label(loc, systemImage: "mappin")
                                .font(.system(size: config.workSubFontSize))
                                .foregroundColor(.blue.opacity(0.6)).lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(sel ? config.workAccentColor.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: ─── Phase 2: Working ───

    private var workingView: some View {
        VStack(spacing: 0) {
            // Header with timer
            HStack(spacing: 8) {
                Text(config.workHeaderText)
                    .font(.system(size: config.workHeaderFontSize, weight: .bold))
                    .foregroundColor(config.workAccentColor)

                Spacer()

                // Timer display
                HStack(spacing: 4) {
                    Image(systemName: isPaused ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(isPaused ? .orange : .green)
                    Text(formatTime(elapsedSeconds))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(config.workTextColor)
                }

                // Pause/Resume
                Button(action: togglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10))
                        .foregroundColor(config.workTextColor.opacity(0.6))
                }
                .buttonStyle(.plain).help(isPaused ? "继续" : "暂停")

                // Reset
                Button(action: endSession) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain).help("结束工作")
            }
            .padding(.horizontal, 14).padding(.vertical, 8)

            // Start time
            HStack {
                Text("开始于 \(formatStartTime(sessionStartDate))")
                    .font(.system(size: 9)).foregroundColor(config.workTextColor.opacity(0.35))
                Spacer()
                let done = orderedTasks.filter { $0.isDone }.count
                Text("\(done)/\(orderedTasks.count) 已完成")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(config.workTextColor.opacity(0.4))
            }
            .padding(.horizontal, 14).padding(.bottom, 6)

            Divider().background(config.workTextColor.opacity(0.1))

            // Task list with onMove
            List {
                ForEach(Array(orderedTasks.enumerated()), id: \.element.id) { index, task in
                    taskRow(task, index: index)
                        .listRowBackground(rowBackground(for: task))
                        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                        .listRowSeparator(.hidden)
                }
                .onMove(perform: moveTask)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func rowBackground(for task: WorkTask) -> some View {
        let isCurrent = !task.isDone && currentTask?.id == task.id
        let bgColor = task.isDone ? config.workDoneBgColor :
                      isCurrent ? config.workCurrentBgColor :
                      config.workPendingBgColor
        return RoundedRectangle(cornerRadius: 8).fill(bgColor)
    }

    private var currentTask: WorkTask? {
        orderedTasks.first { !$0.isDone }
    }

    private func taskRow(_ task: WorkTask, index: Int) -> some View {
        let isCurrent = !task.isDone && currentTask?.id == task.id

        return HStack(spacing: 8) {
            // Index
            if config.workShowIndex {
                Text("\(index + 1)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(task.isDone ? config.workDoneTextColor :
                                    isCurrent ? config.workCurrentTextColor :
                                    config.workTextColor.opacity(0.35))
                    .frame(width: 16)
            }

            // Completion
            Button(action: { toggleTask(task) }) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(task.isDone ? .green :
                                    isCurrent ? config.workAccentColor :
                                    config.workTextColor.opacity(0.3))
            }
            .buttonStyle(.plain)

            // Text
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: config.workFontSize, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(task.isDone ? config.workDoneTextColor :
                                    isCurrent ? config.workCurrentTextColor :
                                    config.workTextColor)
                    .strikethrough(task.isDone)
                    .lineLimit(1)

                if config.workShowSubtitle, let sub = task.subtitle {
                    HStack(spacing: 4) {
                        if let lc = task.listColor as Color? {
                            Circle().fill(lc).frame(width: 4, height: 4)
                        }
                        Text(sub).lineLimit(1)
                    }
                    .font(.system(size: config.workSubFontSize))
                    .foregroundColor((task.isDone ? config.workDoneTextColor : config.workTextColor).opacity(0.45))
                }
            }

            Spacer()

            if task.flagged {
                Image(systemName: "flag.fill").font(.system(size: 8))
                    .foregroundColor(config.color(from: config.floatFlagColorHex))
            }
        }
        .padding(.vertical, max((config.workRowHeight - 34) / 2, 2))
    }

    // MARK: ─── Actions ───

    private func startWorking() {
        let allItems = reminderManager.reminders
        orderedTasks = allItems
            .filter { selectedIds.contains($0.id) }
            .map { WorkTask(from: $0) }
        sessionStartDate = Date()
        lastResumeDate = Date()
        elapsedSeconds = 0
        pausedAccumulated = 0
        isPaused = false
        phase = .working
        startTimer()
    }

    private func endSession() {
        stopTimer()
        // Save session record
        let record = WorkSessionRecord(
            id: UUID(),
            startDate: sessionStartDate,
            endDate: Date(),
            totalSeconds: elapsedSeconds,
            tasksSelected: orderedTasks.count,
            tasksCompleted: orderedTasks.filter { $0.isDone }.count,
            taskDetails: orderedTasks.map {
                WorkSessionRecord.TaskDetail(title: $0.title, completed: $0.isDone, listName: $0.subtitle)
            }
        )
        WorkSessionStore.shared.saveSession(record)

        // Reset
        phase = .picking
        selectedIds = []
        orderedTasks = []
        searchText = ""
    }

    private func togglePause() {
        if isPaused {
            // Resume
            lastResumeDate = Date()
            isPaused = false
            startTimer()
        } else {
            // Pause
            stopTimer()
            pausedAccumulated = elapsedSeconds
            isPaused = true
        }
    }

    private func toggleTask(_ task: WorkTask) {
        if let idx = orderedTasks.firstIndex(where: { $0.id == task.id }) {
            orderedTasks[idx].isDone.toggle()
            if let item = reminderManager.reminders.first(where: { $0.id == task.id }) {
                Task { try? await reminderManager.toggleCompletion(for: item) }
            }
        }
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        orderedTasks.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: ─── Timer ───

    private func startTimer() {
        stopTimer()
        timerObj = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard !isPaused else { return }
            DispatchQueue.main.async {
                let running = Int(Date().timeIntervalSince(lastResumeDate))
                elapsedSeconds = pausedAccumulated + running
            }
        }
    }

    private func stopTimer() {
        timerObj?.invalidate(); timerObj = nil
    }

    // MARK: ─── Formatting ───

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) { f.dateFormat = "HH:mm"; return "今天 \(f.string(from: date))" }
        if cal.isDateInTomorrow(date) { f.dateFormat = "HH:mm"; return "明天 \(f.string(from: date))" }
        f.dateFormat = "M/d HH:mm"; return f.string(from: date)
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func formatStartTime(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - WorkTask Model

struct WorkTask: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let flagged: Bool
    let listColor: Color
    var isDone: Bool

    init(from item: ReminderItem) {
        self.id = item.id
        self.title = item.title
        self.flagged = item.flagged
        self.listColor = item.listColor
        self.isDone = false
        var parts: [String] = []
        if let ln = item.listName { parts.append(ln) }
        if let d = item.dueDate {
            let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M/d HH:mm"
            parts.append(f.string(from: d))
        }
        self.subtitle = parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// WorkSessionRecord is defined in WorkSessionStore.swift

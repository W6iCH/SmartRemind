import SwiftUI

/// 数据统计面板 — 3 个子页面: 概览 / 所有数据 / Log
struct StatisticsView: View {
    @StateObject private var store = WorkSessionStore.shared
    @EnvironmentObject var reminderManager: ReminderManager

    @Binding var selectedPage: MainWindowView.StatPage

    // Time range for overview chart
    @State private var timeRange: TimeRange = .day

    enum TimeRange: String, CaseIterable {
        case day = "日", week = "周", month = "月"
    }

    var body: some View {
        Group {
            switch selectedPage {
            case .overview: overviewPage
            case .allData: allDataPage
            case .log: logPage
            }
        }
    }

    // MARK: - Overview Page

    private var overviewPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary cards - row 1
                HStack(spacing: 12) {
                    statCard("总工时", value: formatDuration(store.totalWorkSeconds), icon: "clock.fill", color: .blue)
                    statCard("完成任务", value: "\(store.totalTasksCompleted)", icon: "checkmark.circle.fill", color: .green)
                    statCard("工作次数", value: "\(store.sessions.count)", icon: "target", color: .orange)
                }

                // Summary cards - row 2
                HStack(spacing: 12) {
                    let weekSessions = store.sessionsThisWeek
                    let weekSeconds = weekSessions.reduce(0) { $0 + $1.totalSeconds }
                    let weekTasks = weekSessions.reduce(0) { $0 + $1.tasksCompleted }
                    statCard("本周工时", value: formatDuration(weekSeconds), icon: "calendar", color: .purple)
                    statCard("本周完成", value: "\(weekTasks)", icon: "star.fill", color: .yellow)
                    statCard("当前待办", value: "\(reminderManager.reminders.filter { !$0.isCompleted }.count)", icon: "tray.full.fill", color: .red)
                }

                Divider()

                // Time range picker
                HStack {
                    Text("工作时长趋势").font(.headline)
                    Spacer()
                    Picker("", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                // Bar chart
                barChart
                    .frame(height: 180)
                    .padding(.top, 4)
            }
            .padding(16)
        }
    }

    // MARK: Bar Chart (SwiftUI shapes, no Charts framework)

    private var barChart: some View {
        let data = chartData
        let maxVal = max(data.map(\.seconds).max() ?? 1, 1)

        return VStack(spacing: 0) {
            // Bars
            GeometryReader { geo in
                let barCount = data.count
                let totalSpacing = CGFloat(max(barCount - 1, 0)) * 4
                let barWidth = max((geo.size.width - totalSpacing) / CGFloat(max(barCount, 1)), 8)
                let availableHeight = geo.size.height - 24 // reserve for labels

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 2) {
                            // Value label on top
                            if item.seconds > 0 {
                                Text(shortDuration(item.seconds))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            // Bar
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.7), Color.blue],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(
                                    width: barWidth,
                                    height: max(CGFloat(item.seconds) / CGFloat(maxVal) * availableHeight, item.seconds > 0 ? 4 : 1)
                                )

                            // Date label
                            Text(item.label)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .padding(.horizontal, 4)
    }

    private struct ChartItem {
        let label: String
        let seconds: Int
    }

    private var chartData: [ChartItem] {
        let calendar = Calendar.current
        let now = Date()

        switch timeRange {
        case .day:
            // Past 7 days
            return (0..<7).reversed().map { daysAgo in
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let seconds = store.sessions
                    .filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                    .reduce(0) { $0 + $1.totalSeconds }
                let f = DateFormatter()
                f.locale = Locale(identifier: "zh_CN")
                f.dateFormat = calendar.isDateInToday(date) ? "'今'" : "E"
                return ChartItem(label: f.string(from: date), seconds: seconds)
            }

        case .week:
            // Past 4 weeks
            return (0..<4).reversed().map { weeksAgo in
                let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now)!
                let weekStartDay = calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!)
                let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartDay)!
                let seconds = store.sessions
                    .filter { $0.startDate >= weekStartDay && $0.startDate < weekEnd }
                    .reduce(0) { $0 + $1.totalSeconds }
                let f = DateFormatter()
                f.locale = Locale(identifier: "zh_CN")
                f.dateFormat = "M/d"
                return ChartItem(label: f.string(from: weekStartDay), seconds: seconds)
            }

        case .month:
            // Past 6 months
            return (0..<6).reversed().map { monthsAgo in
                let monthDate = calendar.date(byAdding: .month, value: -monthsAgo, to: now)!
                let comps = calendar.dateComponents([.year, .month], from: monthDate)
                let monthStart = calendar.date(from: comps)!
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
                let seconds = store.sessions
                    .filter { $0.startDate >= monthStart && $0.startDate < monthEnd }
                    .reduce(0) { $0 + $1.totalSeconds }
                let f = DateFormatter()
                f.locale = Locale(identifier: "zh_CN")
                f.dateFormat = "M月"
                return ChartItem(label: f.string(from: monthStart), seconds: seconds)
            }
        }
    }

    // MARK: - All Data Page

    private var allDataPage: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("所有工作记录").font(.headline)
                Spacer()
                Text("\(store.sessions.count) 条记录").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()

            if store.sessions.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "tray").font(.system(size: 38)).foregroundColor(.secondary)
                    Text("暂无工作记录").foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(store.sessions.reversed()) { session in
                        SessionRowView(session: session)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Log Page

    private var logPage: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("事件日志").font(.headline)
                Spacer()
                Button(role: .destructive) {
                    // Will be handled by confirmation
                } label: {
                    Text("清除所有数据")
                        .font(.caption).foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .confirmationDialog("确认清除所有数据？此操作不可恢复。", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                    Button("清除", role: .destructive) { store.clearAll() }
                    Button("取消", role: .cancel) {}
                }
                .onTapGesture { showClearConfirmation = true }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()

            if logEntries.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "doc.text").font(.system(size: 38)).foregroundColor(.secondary)
                    Text("暂无日志").foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(logEntries) { entry in
                            Text(entry.text)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(entry.color)
                                .textSelection(.enabled)
                                .padding(.horizontal, 12).padding(.vertical, 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(entry.isAlt ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @State private var showClearConfirmation = false

    // MARK: - Log Entries

    private struct LogEntry: Identifiable {
        let id = UUID()
        let text: String
        let color: Color
        let date: Date
        let isAlt: Bool
    }

    private var logEntries: [LogEntry] {
        var entries: [LogEntry] = []

        // Work session events
        for session in store.sessions {
            let dateStr = logDateFormat(session.startDate)
            let endStr = logTimeFormat(session.endDate)
            let dur = formatDuration(session.totalSeconds)

            entries.append(LogEntry(
                text: "[\(dateStr)] 🎯 工作会话开始 | 选择 \(session.tasksSelected) 项任务",
                color: .primary,
                date: session.startDate,
                isAlt: false
            ))

            for detail in session.taskDetails {
                let status = detail.completed ? "✅ 完成" : "⬜ 未完成"
                let listStr = detail.listName.map { " [\($0)]" } ?? ""
                entries.append(LogEntry(
                    text: "[\(dateStr)]   \(status) \(detail.title)\(listStr)",
                    color: detail.completed ? .green : .secondary,
                    date: session.startDate,
                    isAlt: false
                ))
            }

            entries.append(LogEntry(
                text: "[\(dateStr)–\(endStr)] 🏁 工作会话结束 | 时长 \(dur) | 完成 \(session.tasksCompleted)/\(session.tasksSelected)",
                color: .blue,
                date: session.endDate,
                isAlt: false
            ))
        }

        // Reminder snapshots
        for snap in store.dailySnapshots {
            let dateStr = logDateFormat(snap.date)
            entries.append(LogEntry(
                text: "[\(dateStr)] 📊 提醒快照 | 总计 \(snap.totalCount) | 完成 \(snap.completedCount) | 新增 \(snap.addedCount)",
                color: .purple,
                date: snap.date,
                isAlt: false
            ))
        }

        // Sort chronologically, mark alternating
        let sorted = entries.sorted { $0.date < $1.date }
        return sorted.enumerated().map { idx, entry in
            LogEntry(text: entry.text, color: entry.color, date: entry.date, isAlt: idx % 2 == 1)
        }
    }

    // MARK: - Helpers

    private func statCard(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h\(m)m" }
        return "\(m)m"
    }

    private func shortDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func logDateFormat(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    private func logTimeFormat(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatSessionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Session Row (Expandable)

struct SessionRowView: View {
    let session: WorkSessionRecord
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(width: 12)

                Image(systemName: "target")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)

                Text(formatDate(session.startDate))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(formatDur(session.totalSeconds))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.blue)

                Text("\(session.tasksCompleted)/\(session.tasksSelected) 完成")
                    .font(.system(size: 11))
                    .foregroundColor(.green)

                Spacer()

                // Task names preview
                if !isExpanded {
                    Text(session.taskDetails.prefix(2).map(\.title).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }

            // Expanded task details
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(session.taskDetails.enumerated()), id: \.offset) { idx, detail in
                        HStack(spacing: 6) {
                            Image(systemName: detail.completed ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 10))
                                .foregroundColor(detail.completed ? .green : .secondary)
                            Text(detail.title)
                                .font(.system(size: 11))
                                .strikethrough(detail.completed)
                                .foregroundColor(detail.completed ? .secondary : .primary)
                            if let listName = detail.listName {
                                Text(listName)
                                    .font(.system(size: 9))
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(3)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding(.leading, 32)
                    }

                    // Session time range
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                        Text("\(formatDate(session.startDate)) → \(formatTime(session.endDate))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 32)
                    .padding(.top, 2)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func formatDur(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h\(m)m" }
        return "\(m)m"
    }
}

import SwiftUI
import AppKit

// MARK: - 悬浮窗视图 v5.1 — 完整对齐 / 多样化动画 / 旗标颜色 / 连续滚动

struct FloatingWindowView: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @EnvironmentObject var config: AppearanceConfig

    // 翻页模式用
    @State private var currentPage: Int = 0
    // 连续滚动模式用
    @State private var scrollOffset: CGFloat = 0
    @State private var timer: Timer?
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: config.floatCornerRadius)
                .fill(config.floatBgColor.opacity(config.floatBgOpacity))

            if filteredReminders.isEmpty {
                emptyState
            } else {
                carouselBody
            }

            // AI 输入区
            if config.floatShowInput {
                VStack { Spacer()
                    VStack(spacing: 0) {
                        Divider().background(config.floatTextColor.opacity(0.2))
                        FloatInputBar()
                    }
                }
            }

            // Widget overlay
            if config.floatWidgetEnabled { widgetOverlay }
        }
        .clipShape(RoundedRectangle(cornerRadius: config.floatCornerRadius))
        .onHover { h in
            isHovering = h
            if config.floatPauseOnHover {
                if h { stopTimer() } else { startTimer() }
            }
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .task { await reminderManager.fetchReminders() }
    }

    // MARK: - Widget

    private var widgetOverlay: some View {
        let a: Alignment = {
            switch config.floatWidgetPosition {
            case "topLeft": return .topLeading
            case "topRight": return .topTrailing
            case "bottomLeft": return .bottomLeading
            case "bottomRight": return .bottomTrailing
            default: return .topTrailing
            }
        }()
        return ZStack(alignment: a) {
            Color.clear
            widgetText
                .font(.system(size: config.floatWidgetFontSize))
                .foregroundColor(config.floatWidgetColor.opacity(config.floatWidgetOpacity))
                .padding(6)
        }
    }

    private var widgetText: Text {
        switch config.floatWidgetContent {
        case "remaining":
            return Text("\(filteredReminders.count)项待办")
        case "time":
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return Text(f.string(from: Date()))
        case "date":
            let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "M月d日 E"
            return Text(f.string(from: Date()))
        default:
            return Text("\(filteredReminders.count)项")
        }
    }

    // MARK: - Filtered

    private var filteredReminders: [ReminderItem] {
        var items = reminderManager.reminders.filter { !$0.isCompleted }
        switch config.floatFilterMode {
        case "flagged": items = items.filter { $0.flagged }
        case "lists":
            let lists = config.floatFilterLists
            if !lists.isEmpty { items = items.filter { lists.contains($0.listName ?? "") } }
        default: break
        }
        return items
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        if config.floatScrollMode == "continuousScroll" {
            startContinuousTimer()
        } else {
            startPageTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate(); timer = nil
    }

    // Page mode timer
    private func startPageTimer() {
        let interval = max(0.5, config.floatScrollInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard !(config.floatPauseOnHover && isHovering), !filteredReminders.isEmpty else { return }
            DispatchQueue.main.async {
                let total = totalPages
                if total > 1 {
                    withAnimation(animAnimation) {
                        currentPage = (currentPage + 1) % total
                    }
                }
            }
        }
    }

    // Continuous scroll timer
    private func startContinuousTimer() {
        let fps: TimeInterval = 1.0 / 60.0
        timer = Timer.scheduledTimer(withTimeInterval: fps, repeats: true) { _ in
            guard !(config.floatPauseOnHover && isHovering), !filteredReminders.isEmpty else { return }
            DispatchQueue.main.async {
                let step = config.floatAnimSpeed / 60.0
                let itemHeight = config.floatFontSize + max(config.floatSubFontSize, 0) + 8
                let totalContentHeight = CGFloat(filteredReminders.count) * itemHeight
                if totalContentHeight > 0 {
                    scrollOffset += step
                    if scrollOffset >= totalContentHeight { scrollOffset = 0 }
                }
            }
        }
    }

    private var totalPages: Int {
        let count = filteredReminders.count
        let pp = max(1, config.floatItemsPerPage)
        return max(1, Int(ceil(Double(count) / Double(pp))))
    }

    // MARK: - Animation

    private var animAnimation: Animation {
        .easeInOut(duration: config.floatAnimDuration)
    }

    @ViewBuilder
    private var carouselBody: some View {
        if config.floatScrollMode == "continuousScroll" {
            continuousScrollView
        } else {
            pageView
        }
    }

    // MARK: - Page View (翻页模式)

    private var pageView: some View {
        let items = filteredReminders
        let pp = max(1, config.floatItemsPerPage)
        let safePage = min(currentPage, max(0, totalPages - 1))
        let start = safePage * pp
        let end = min(start + pp, items.count)
        let pageItems = start < items.count ? Array(items[start..<end]) : []

        return VStack(spacing: 0) {
            if config.floatAlignV == "bottom" || config.floatAlignV == "center" { Spacer(minLength: 0) }

            VStack(spacing: 4) {
                ForEach(pageItems) { item in
                    floatRow(item)
                        .id("p-\(item.id)-\(safePage)")
                        .transition(pageTransition)
                }
            }
            .padding(.horizontal, config.floatAlignPaddingH + 10)
            .padding(.top, config.floatAlignV == "top" ? 8 + config.floatAlignPaddingV : 0)

            if config.floatAlignV == "center" || config.floatAlignV == "top" { Spacer(minLength: 0) }

            // 页码指示
            if totalPages > 1 {
                HStack(spacing: 3) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Circle()
                            .fill(i == safePage ? config.floatAccentColor : config.floatTextColor.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.bottom, config.floatShowInput ? 32 : 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pageTransition: AnyTransition {
        switch config.floatAnimMode {
        case "horizontalSlide":
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        case "verticalSlide":
            return .asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top))
        case "flip":
            return .asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity),
                               removal: .scale(scale: 0.8).combined(with: .opacity))
        case "rotate3D":
            return .asymmetric(insertion: .scale(scale: 0.1).combined(with: .opacity),
                               removal: .scale(scale: 0.1).combined(with: .opacity))
        default: // fade
            return .opacity
        }
    }

    // MARK: - Continuous Scroll View

    private var continuousScrollView: some View {
        let items = filteredReminders
        return GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        floatRow(item)
                    }
                }
                .padding(.horizontal, config.floatAlignPaddingH + 10)
                .padding(.top, 8)
                .offset(y: -scrollOffset)
            }
            .disabled(true) // 禁止用户手动滚动
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(gradient: Gradient(colors: [.clear, .black]),
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 10)
                    Rectangle().fill(.black)
                    LinearGradient(gradient: Gradient(colors: [.black, .clear]),
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 10)
                }
            )
        }
    }

    // MARK: - Single Row

    @ViewBuilder
    private func floatRow(_ item: ReminderItem) -> some View {
        let hAl = config.contentHAlignment
        let vPadding = config.floatAlignV == "top" ? config.floatAlignPaddingV :
                       config.floatAlignV == "bottom" ? config.floatAlignPaddingV : 0

        VStack(alignment: hAl, spacing: 2) {
            // 标题行
            HStack(spacing: 5) {
                if config.floatAlignH == "center" || config.floatAlignH == "right" { Spacer(minLength: 0) }

                if config.floatAllowComplete {
                    Button(action: {
                        Task { try? await reminderManager.toggleCompletion(for: item) }
                    }) {
                        Image(systemName: "circle")
                            .font(.system(size: 10))
                            .foregroundColor(config.floatTextColor.opacity(0.5))
                    }.buttonStyle(.plain)
                }

                ForEach(titleFields, id: \.self) { field in
                    titleFieldView(field, item: item)
                }

                if config.floatAlignH == "center" || config.floatAlignH == "left" { Spacer(minLength: 0) }
            }

            // 副标题行
            if !subtitleFields.isEmpty {
                HStack(spacing: 5) {
                    if config.floatAlignH == "center" || config.floatAlignH == "right" { Spacer(minLength: 0) }
                    ForEach(subtitleFields, id: \.self) { field in
                        subtitleFieldView(field, item: item)
                    }
                    if config.floatAlignH == "center" || config.floatAlignH == "left" { Spacer(minLength: 0) }
                }
            }
        }
        .padding(.top, vPadding)
    }

    private var titleFields: [String] {
        config.floatLayoutTitleFields.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var subtitleFields: [String] {
        config.floatLayoutSubtitleFields.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    @ViewBuilder
    private func titleFieldView(_ field: String, item: ReminderItem) -> some View {
        switch field {
        case "flag":
            if item.flagged {
                Image(systemName: "flag.fill")
                    .font(.system(size: config.floatFontSize * 0.7))
                    .foregroundColor(config.floatFlagColor)
            }
        case "priority":
            if item.priority > 0 {
                Circle().fill(priorityColor(item.priority))
                    .frame(width: config.floatFontSize * 0.42, height: config.floatFontSize * 0.42)
            }
        case "title":
            Text(item.title)
                .font(.system(size: config.floatFontSize, weight: .medium))
                .foregroundColor(item.flagged ? config.floatFlagColor : config.floatTextColor)
                .lineLimit(1)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func subtitleFieldView(_ field: String, item: ReminderItem) -> some View {
        let fs = config.floatSubFontSize
        switch field {
        case "listName":
            if let ln = item.listName {
                HStack(spacing: 2) {
                    Circle().fill(item.listColor).frame(width: fs * 0.7, height: fs * 0.7)
                    Text(ln)
                }
                .font(.system(size: fs))
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(item.listColor.opacity(0.2)).cornerRadius(2)
                .foregroundColor(config.floatTextColor.opacity(0.8))
            }
        case "dueDate":
            if let d = item.dueDate {
                Text(shortDate(d))
                    .font(.system(size: fs))
                    .foregroundColor(config.floatDueDateColor)
            }
        case "location":
            if let loc = item.location {
                Label(loc, systemImage: "mappin")
                    .font(.system(size: fs)).foregroundColor(.blue).lineLimit(1)
            }
        case "notes":
            if let notes = item.notes, !notes.isEmpty {
                Text(notes).font(.system(size: fs))
                    .foregroundColor(config.floatTextColor.opacity(0.4)).lineLimit(1)
            }
        case "tags":
            ForEach(item.tags.prefix(2), id: \.self) { tag in
                Text("#\(tag)").font(.system(size: max(fs - 2, 7))).foregroundColor(.teal)
            }
        default: EmptyView()
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: config.floatFontSize))
                .foregroundColor(config.floatAccentColor)
            Text("暂无待办事项")
                .font(.system(size: config.floatFontSize))
                .foregroundColor(config.floatTextColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func priorityColor(_ p: Int) -> Color {
        switch p { case 1: return .red; case 5: return .yellow; case 9: return .gray; default: return .clear }
    }
    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) { fmt.dateFormat = "HH:mm"; return "今天\(fmt.string(from: date))" }
        if cal.isDateInTomorrow(date) { fmt.dateFormat = "HH:mm"; return "明天\(fmt.string(from: date))" }
        fmt.dateFormat = "M/d HH:mm"; return fmt.string(from: date)
    }
}

// MARK: - FloatInputBar

struct FloatInputBar: View {
    @EnvironmentObject var config: AppearanceConfig
    @State private var inputText: String = ""
    @State private var isProcessing = false
    @State private var statusText: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 9)).foregroundColor(config.floatAccentColor)
            TextField("添加提醒...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(config.floatTextColor)
                .onSubmit { submit() }
            if isProcessing {
                ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
            } else if let s = statusText {
                Text(s).font(.system(size: 8)).foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isProcessing = true; statusText = nil
        Task {
            do {
                let result = try await SmartReminderCoordinator.shared.processInput(text, multiMode: config.aiMultiMode)
                statusText = "✓ \(result.createdCount)条"
                inputText = ""
                NotificationCenter.default.post(name: .remindersChanged, object: nil)
            } catch { statusText = "✗" }
            isProcessing = false
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusText = nil
        }
    }
}

import SwiftUI
import AppKit

// MARK: - Main Window (3-Tab: 提醒 / 统计 / 设置)

struct MainWindowView: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @EnvironmentObject var config: AppearanceConfig
    @EnvironmentObject var llmService: LLMService

    // Top-level tab
    @State private var selectedTab: TopTab = .reminders

    // Reminder tab state
    @State private var selectedList: ListFilter = .all
    @State private var searchText: String = ""
    @State private var editingItem: ReminderItem?
    @State private var showNewReminder = false
    @State private var showCompleted = false
    @State private var aiInputText: String = ""

    // Statistics tab state
    @State private var selectedStatPage: StatPage = .overview

    // Settings tab state
    @State private var selectedSettingsCategory: SettingsCategory = .floatAppearance

    enum TopTab: String, CaseIterable { case reminders = "提醒", statistics = "统计", settings = "设置" }
    enum ListFilter: Hashable { case all, flagged, list(String) }
    enum StatPage: String, CaseIterable, Hashable { case overview = "概览", allData = "所有数据", log = "Log" }
    enum SettingsCategory: String, CaseIterable, Hashable {
        case floatAppearance = "悬浮窗外观"
        case floatColor = "悬浮窗颜色"
        case floatLayout = "悬浮窗布局"
        case floatAnimation = "悬浮窗动画"
        case floatWidget = "悬浮窗插件"
        case floatBehavior = "悬浮窗行为"
        case workSize = "工作模式尺寸"
        case workColor = "工作模式颜色"
        case mainList = "主列表"
        case statusBar = "状态栏"
        case aiModel = "AI 模型"
        case about = "关于"

        var icon: String {
            switch self {
            case .floatAppearance: return "rectangle.inset.filled"
            case .floatColor: return "paintpalette"
            case .floatLayout: return "rectangle.split.3x1"
            case .floatAnimation: return "wand.and.stars"
            case .floatWidget: return "widget.small"
            case .floatBehavior: return "gearshape"
            case .workSize: return "arrow.up.left.and.arrow.down.right"
            case .workColor: return "paintpalette.fill"
            case .mainList: return "list.bullet"
            case .statusBar: return "menubar.rectangle"
            case .aiModel: return "brain"
            case .about: return "info.circle"
            }
        }

        var isFloatCategory: Bool {
            switch self {
            case .floatAppearance, .floatColor, .floatLayout, .floatAnimation, .floatWidget, .floatBehavior: return true
            default: return false
            }
        }

        var isWorkCategory: Bool {
            switch self {
            case .workSize, .workColor: return true
            default: return false
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            detailContent
        }
        .frame(minWidth: 860, minHeight: 600)
        .sheet(isPresented: $showNewReminder) { NewReminderSheet().environmentObject(reminderManager) }
        .sheet(item: $editingItem) { item in EditReminderSheet(item: item).environmentObject(reminderManager) }
        .task {
            await reminderManager.requestAccess()
            await reminderManager.fetchReminders()
            reminderManager.fetchLists()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        Group {
            switch selectedTab {
            case .reminders: remindersSidebar
            case .statistics: statisticsSidebar
            case .settings: settingsSidebar
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            Picker("", selection: $selectedTab) {
                ForEach(TopTab.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 8).padding(.top, 8)
        }
    }

    // MARK: Reminders Sidebar

    private var remindersSidebar: some View {
        List(selection: $selectedList) {
            Section("提醒事项") {
                Label("全部", systemImage: "tray.full").tag(ListFilter.all)
                Label("旗标", systemImage: "flag.fill").foregroundColor(.orange).tag(ListFilter.flagged)
            }
            Section("列表") {
                ForEach(reminderManager.lists, id: \.calendarIdentifier) { list in
                    HStack {
                        Circle().fill(Color(cgColor: list.cgColor)).frame(width: 9, height: 9)
                        Text(list.title).lineLimit(1)
                        Spacer()
                        Text("\(countForList(list.title))").font(.caption2).foregroundColor(.secondary)
                    }
                    .tag(ListFilter.list(list.title))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button(action: { showNewReminder = true }) {
                        Label("新建", systemImage: "plus.circle.fill").font(.caption)
                    }.buttonStyle(.plain)
                    Spacer()
                    Toggle("已完成", isOn: $showCompleted).font(.caption).toggleStyle(.switch).controlSize(.small)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }.background(.regularMaterial)
        }
    }

    // MARK: Statistics Sidebar

    private var statisticsSidebar: some View {
        List(selection: $selectedStatPage) {
            Section("统计") {
                Label("概览", systemImage: "chart.bar").tag(StatPage.overview)
                Label("所有数据", systemImage: "tablecells").tag(StatPage.allData)
                Label("Log", systemImage: "doc.text").tag(StatPage.log)
            }
        }
    }

    // MARK: Settings Sidebar

    private var settingsSidebar: some View {
        List(selection: $selectedSettingsCategory) {
            Section("悬浮窗") {
                ForEach([SettingsCategory.floatAppearance, .floatColor, .floatLayout, .floatAnimation, .floatWidget, .floatBehavior], id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }
            Section("工作模式") {
                ForEach([SettingsCategory.workSize, .workColor], id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }
            Section("通用") {
                ForEach([SettingsCategory.mainList, .statusBar, .aiModel, .about], id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .reminders:
            reminderDetail
        case .statistics:
            StatisticsView(selectedPage: $selectedStatPage)
        case .settings:
            SettingsPanelView(selectedCategory: $selectedSettingsCategory)
        }
    }

    // MARK: - Reminder Detail

    private var reminderDetail: some View {
        VStack(spacing: 0) {
            // AI bar
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundColor(.accentColor).font(.system(size: 14))
                TextField("AI 自然语言添加...", text: $aiInputText)
                    .textFieldStyle(.roundedBorder).controlSize(.small)
                    .onSubmit { submitAI() }
                Toggle(config.aiMultiMode ? "多" : "单", isOn: $config.aiMultiMode)
                    .toggleStyle(.button).controlSize(.small)
                Button("添加") { submitAI() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(aiInputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            Divider()

            // Toolbar
            HStack {
                Text(titleText).font(.headline)
                Spacer()
                Button(action: { showNewReminder = true }) { Image(systemName: "plus") }.buttonStyle(.plain).help("新建")
                Button(action: { Task { await reminderManager.fetchReminders() } }) { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).help("刷新")
            }.padding(.horizontal, 14).padding(.vertical, 6)
            Divider()

            // List
            if filteredReminders.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle").font(.system(size: 38)).foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "暂无待办" : "无搜索结果").foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List { ForEach(filteredReminders) { item in reminderRow(item).tag(item.id) } }
                    .listStyle(.plain)
            }
        }
    }

    private func submitAI() {
        let t = aiInputText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        Task {
            do {
                _ = try await SmartReminderCoordinator.shared.processInput(t, multiMode: config.aiMultiMode)
                aiInputText = ""
                NotificationCenter.default.post(name: .remindersChanged, object: nil)
            } catch {}
        }
    }

    private var titleText: String {
        switch selectedList {
        case .all: return "全部提醒"
        case .flagged: return "旗标"
        case .list(let n): return n
        }
    }

    private var filteredReminders: [ReminderItem] {
        var items = reminderManager.reminders
        if !showCompleted { items = items.filter { !$0.isCompleted } }
        switch selectedList {
        case .all: break
        case .flagged: items = items.filter { $0.flagged }
        case .list(let n): items = items.filter { $0.listName == n }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.notes ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.location ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    private func countForList(_ name: String) -> Int {
        reminderManager.reminders.filter { $0.listName == name && !$0.isCompleted }.count
    }

    // MARK: - Row

    private func reminderRow(_ item: ReminderItem) -> some View {
        HStack(spacing: 8) {
            Button(action: { Task { try? await reminderManager.toggleCompletion(for: item) } }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15)).foregroundColor(item.isCompleted ? .green : .secondary)
            }.buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if item.flagged { Image(systemName: "flag.fill").font(.system(size: 9)).foregroundColor(.orange) }
                    if item.priority == 1 { Image(systemName: "exclamationmark").font(.system(size: 9)).foregroundColor(.red) }
                    Text(item.title).font(.system(size: config.listFontSize)).strikethrough(item.isCompleted)
                }
                HStack(spacing: 5) {
                    if let ln = item.listName {
                        HStack(spacing: 2) {
                            Circle().fill(item.listColor).frame(width: 5, height: 5); Text(ln)
                        }.font(.system(size: 10)).padding(.horizontal, 3).padding(.vertical, 1)
                        .background(item.listColor.opacity(0.12)).cornerRadius(2)
                    }
                    if let d = item.dueDate { dateBadge(d) }
                    if let loc = item.location { Label(loc, systemImage: "mappin").font(.system(size: 10)).foregroundColor(.blue).lineLimit(1) }
                    if let n = item.notes, !n.isEmpty { Text(n).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1) }
                    if let r = item.recurrenceRule { Label(r, systemImage: "repeat").font(.system(size: 9)).foregroundColor(.purple) }
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Button(action: { editingItem = item }) { Image(systemName: "pencil").font(.system(size: 11)) }.buttonStyle(.plain).foregroundColor(.secondary)
                Button(action: { Task { try? await reminderManager.deleteReminder(id: item.id) } }) { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain).foregroundColor(.red.opacity(0.5))
            }
        }.padding(.vertical, 2)
    }

    private func dateBadge(_ date: Date) -> some View {
        let cal = Calendar.current
        let isOverdue = date < Date() && !cal.isDateInToday(date)
        return Text(formatDate(date)).font(.system(size: 10)).foregroundColor(isOverdue ? .red : .orange)
    }

    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current; let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) { f.dateFormat = "HH:mm"; return "今天 \(f.string(from: date))" }
        if cal.isDateInTomorrow(date) { f.dateFormat = "HH:mm"; return "明天 \(f.string(from: date))" }
        f.dateFormat = "M/d HH:mm"; return f.string(from: date)
    }
}

// MARK: - Settings Panel (with Draft + Live Preview + Category Selection)

struct SettingsPanelView: View {
    @EnvironmentObject var config: AppearanceConfig
    @EnvironmentObject var llmService: LLMService

    @Binding var selectedCategory: MainWindowView.SettingsCategory

    // Draft
    @State private var draft: SettingsDraft
    @State private var hasChanges = false
    @State private var showProviderEditor = false
    @State private var editingProvider: LLMProviderConfig?

    // Color picker sync
    @State private var pBg = Color.white; @State private var pText = Color.white
    @State private var pAccent = Color.white; @State private var pFlag = Color.white
    @State private var pDueDate = Color.white; @State private var pWidget = Color.white
    // Work mode color pickers
    @State private var pWorkBg = Color.white; @State private var pWorkText = Color.white
    @State private var pWorkAccent = Color.white; @State private var pWorkCurBg = Color.white
    @State private var pWorkCurText = Color.white; @State private var pWorkDoneBg = Color.white
    @State private var pWorkDoneText = Color.white; @State private var pWorkPendBg = Color.white

    init(selectedCategory: Binding<MainWindowView.SettingsCategory>) {
        _selectedCategory = selectedCategory
        _draft = State(initialValue: SettingsDraft(from: AppearanceConfig.shared))
    }

    var body: some View {
        HSplitView {
            // Left: settings form for selected category
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Save bar
                    if hasChanges {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("有未保存的更改").font(.callout).foregroundColor(.orange)
                            Spacer()
                            Button("取消") { resetDraft() }.buttonStyle(.bordered).controlSize(.small)
                            Button("应用") { applyDraft() }.buttonStyle(.borderedProminent).controlSize(.small)
                                .keyboardShortcut("s", modifiers: [.command])
                        }
                        .padding(10).background(Color.orange.opacity(0.08))
                        Divider()
                    }

                    Form {
                        categoryForm
                    }
                    .formStyle(.grouped)
                }
            }
            .frame(minWidth: 340)

            // Right: Live Preview
            livePreview
                .frame(minWidth: 260, idealWidth: 300)
        }
        .onAppear { syncPickers() }
    }

    // MARK: - Category Form Router

    @ViewBuilder
    private var categoryForm: some View {
        switch selectedCategory {
        case .floatAppearance: floatAppearanceForm
        case .floatColor: floatColorForm
        case .floatLayout: floatLayoutForm
        case .floatAnimation: floatAnimationForm
        case .floatWidget: floatWidgetForm
        case .floatBehavior: floatBehaviorForm
        case .workSize: workSizeForm
        case .workColor: workColorForm
        case .mainList: mainListForm
        case .statusBar: statusBarForm
        case .aiModel: aiModelForm
        case .about: aboutForm
        }
    }

    // MARK: - Float Appearance

    @ViewBuilder
    private var floatAppearanceForm: some View {
        Section {
            sizeRow("宽度", v: $draft.floatWidth, range: 100...600) { hasChanges = true }
            sizeRow("高度", v: $draft.floatHeight, range: 36...400) { hasChanges = true }
            sizeRow("字号", v: $draft.floatFontSize, range: 8...28) { hasChanges = true }
            sizeRow("副标题字号", v: $draft.floatSubFontSize, range: 6...20) { hasChanges = true }
            sizeRow("圆角", v: $draft.floatCornerRadius, range: 0...30) { hasChanges = true }
            sizeDoubleRow("透明度", v: $draft.floatBgOpacity, range: 0.3...1.0, step: 0.05) { hasChanges = true }
        } header: { sectionHeader("悬浮窗外观") }
    }

    // MARK: - Float Color

    @ViewBuilder
    private var floatColorForm: some View {
        Section {
            colorRow("背景色", draftHex: $draft.floatBgColorHex, picker: $pBg) { hasChanges = true }
            colorRow("文字色", draftHex: $draft.floatTextColorHex, picker: $pText) { hasChanges = true }
            colorRow("强调色", draftHex: $draft.floatAccentColorHex, picker: $pAccent) { hasChanges = true }
            colorRow("旗标色", draftHex: $draft.floatFlagColorHex, picker: $pFlag) { hasChanges = true }
            colorRow("日期色", draftHex: $draft.floatDueDateColorHex, picker: $pDueDate) { hasChanges = true }
        } header: { sectionHeader("悬浮窗颜色") }
    }

    // MARK: - Float Layout

    @ViewBuilder
    private var floatLayoutForm: some View {
        Section {
            Picker("水平对齐", selection: $draft.floatAlignH) {
                Text("左").tag("left"); Text("中").tag("center"); Text("右").tag("right")
            }.pickerStyle(.segmented).onChange(of: draft.floatAlignH) { _, _ in hasChanges = true }

            Picker("垂直对齐", selection: $draft.floatAlignV) {
                Text("上").tag("top"); Text("中").tag("center"); Text("下").tag("bottom")
            }.pickerStyle(.segmented).onChange(of: draft.floatAlignV) { _, _ in hasChanges = true }

            sizeRow("水平缩进", v: $draft.floatAlignPaddingH, range: 0...80) { hasChanges = true }
            sizeRow("垂直偏移", v: $draft.floatAlignPaddingV, range: 0...60) { hasChanges = true }
        } header: { sectionHeader("布局对齐") }

        Section {
            FieldSelectorView(title: "标题行", value: $draft.floatLayoutTitleFields,
                options: ["flag","priority","title"], labels: ["旗标","优先级","标题"])
                .onChange(of: draft.floatLayoutTitleFields) { _, _ in hasChanges = true }
            FieldSelectorView(title: "副标题行", value: $draft.floatLayoutSubtitleFields,
                options: ["listName","dueDate","location","notes","tags"],
                labels: ["列表","日期","位置","备注","标签"])
                .onChange(of: draft.floatLayoutSubtitleFields) { _, _ in hasChanges = true }
            Picker("角标", selection: $draft.floatLayoutBadgeField) {
                Text("无").tag("none"); Text("优先级").tag("priority"); Text("旗标").tag("flag"); Text("标签").tag("tags")
            }.onChange(of: draft.floatLayoutBadgeField) { _, _ in hasChanges = true }
        } header: { sectionHeader("显示字段") }
    }

    // MARK: - Float Animation

    @ViewBuilder
    private var floatAnimationForm: some View {
        Section {
            Picker("展示模式", selection: $draft.floatScrollMode) {
                Text("翻页切换").tag("page")
                Text("连续滚动").tag("continuousScroll")
            }.pickerStyle(.segmented)
            .onChange(of: draft.floatScrollMode) { _, _ in hasChanges = true }

            if draft.floatScrollMode == "page" {
                Picker("切换动画", selection: $draft.floatAnimMode) {
                    Text("淡入淡出").tag("fade")
                    Text("水平滑动").tag("horizontalSlide")
                    Text("垂直滑动").tag("verticalSlide")
                    Text("翻转").tag("flip")
                    Text("3D旋转").tag("rotate3D")
                }.onChange(of: draft.floatAnimMode) { _, _ in hasChanges = true }

                sizeDoubleRow("切换时长", v: $draft.floatAnimDuration, range: 0.1...2.0, step: 0.05) { hasChanges = true }

                Stepper("每页条数: \(draft.floatItemsPerPage)", value: $draft.floatItemsPerPage, in: 1...10)
                    .onChange(of: draft.floatItemsPerPage) { _, _ in hasChanges = true }

                sizeDoubleRow("切换间隔", v: $draft.floatScrollInterval, range: 1...30, step: 0.5) { hasChanges = true }
            } else {
                sizeRow("滚动速度(px/s)", v: $draft.floatAnimSpeed, range: 5...200) { hasChanges = true }
            }
        } header: { sectionHeader("展示与动画") }
    }

    // MARK: - Float Widget

    @ViewBuilder
    private var floatWidgetForm: some View {
        Section {
            Toggle("启用插件", isOn: $draft.floatWidgetEnabled)
                .onChange(of: draft.floatWidgetEnabled) { _, _ in hasChanges = true }
            if draft.floatWidgetEnabled {
                Picker("位置", selection: $draft.floatWidgetPosition) {
                    Text("左上").tag("topLeft"); Text("右上").tag("topRight")
                    Text("左下").tag("bottomLeft"); Text("右下").tag("bottomRight")
                }.onChange(of: draft.floatWidgetPosition) { _, _ in hasChanges = true }
                Picker("内容", selection: $draft.floatWidgetContent) {
                    Text("剩余待办数").tag("remaining"); Text("当前时间").tag("time"); Text("日期").tag("date")
                }.onChange(of: draft.floatWidgetContent) { _, _ in hasChanges = true }
                sizeRow("字号", v: $draft.floatWidgetFontSize, range: 7...18) { hasChanges = true }
                sizeDoubleRow("透明度", v: $draft.floatWidgetOpacity, range: 0.2...1.0, step: 0.05) { hasChanges = true }
                colorRow("颜色", draftHex: $draft.floatWidgetColorHex, picker: $pWidget) { hasChanges = true }
            }
        } header: { sectionHeader("插件 Widget") }
    }

    // MARK: - Float Behavior

    @ViewBuilder
    private var floatBehaviorForm: some View {
        Section {
            Toggle("悬停暂停轮播", isOn: $draft.floatPauseOnHover).onChange(of: draft.floatPauseOnHover) { _, _ in hasChanges = true }
            Toggle("允许拖拽调大小", isOn: $draft.floatResizable).onChange(of: draft.floatResizable) { _, _ in hasChanges = true }
            Toggle("显示 AI 输入", isOn: $draft.floatShowInput).onChange(of: draft.floatShowInput) { _, _ in hasChanges = true }
            Toggle("允许完成操作", isOn: $draft.floatAllowComplete).onChange(of: draft.floatAllowComplete) { _, _ in hasChanges = true }
            Picker("默认筛选", selection: $draft.floatFilterMode) {
                Text("全部").tag("all"); Text("仅旗标").tag("flagged"); Text("指定列表").tag("lists")
            }.onChange(of: draft.floatFilterMode) { _, _ in hasChanges = true }
        } header: { sectionHeader("行为") }
    }

    // MARK: - Work Size

    @ViewBuilder
    private var workSizeForm: some View {
        Section {
            sizeRow("宽度", v: $draft.workWidth, range: 200...600) { hasChanges = true }
            sizeRow("高度", v: $draft.workHeight, range: 200...800) { hasChanges = true }
            sizeRow("字号", v: $draft.workFontSize, range: 10...24) { hasChanges = true }
            sizeRow("副标题字号", v: $draft.workSubFontSize, range: 7...18) { hasChanges = true }
            sizeRow("圆角", v: $draft.workCornerRadius, range: 0...30) { hasChanges = true }
            sizeDoubleRow("透明度", v: $draft.workBgOpacity, range: 0.3...1.0, step: 0.05) { hasChanges = true }
            sizeRow("行高", v: $draft.workRowHeight, range: 28...80) { hasChanges = true }
            sizeRow("行距", v: $draft.workRowSpacing, range: 0...16) { hasChanges = true }
            sizeRow("标题字号", v: $draft.workHeaderFontSize, range: 10...22) { hasChanges = true }
            TextField("顶栏文字", text: $draft.workHeaderText)
                .font(.caption).textFieldStyle(.roundedBorder)
                .onChange(of: draft.workHeaderText) { _, _ in hasChanges = true }
            Toggle("显示序号", isOn: $draft.workShowIndex).onChange(of: draft.workShowIndex) { _, _ in hasChanges = true }
            Toggle("显示副标题", isOn: $draft.workShowSubtitle).onChange(of: draft.workShowSubtitle) { _, _ in hasChanges = true }
            Toggle("允许拖拽调大小", isOn: $draft.workResizable).onChange(of: draft.workResizable) { _, _ in hasChanges = true }
        } header: { sectionHeader("工作模式 — 尺寸") }
    }

    // MARK: - Work Color

    @ViewBuilder
    private var workColorForm: some View {
        Section {
            colorRow("背景色", draftHex: $draft.workBgColorHex, picker: $pWorkBg) { hasChanges = true }
            colorRow("文字色", draftHex: $draft.workTextColorHex, picker: $pWorkText) { hasChanges = true }
            colorRow("强调色", draftHex: $draft.workAccentColorHex, picker: $pWorkAccent) { hasChanges = true }
            colorRow("当前背景", draftHex: $draft.workCurrentBgColorHex, picker: $pWorkCurBg) { hasChanges = true }
            colorRow("当前文字", draftHex: $draft.workCurrentTextColorHex, picker: $pWorkCurText) { hasChanges = true }
            colorRow("已完成背景", draftHex: $draft.workDoneBgColorHex, picker: $pWorkDoneBg) { hasChanges = true }
            colorRow("已完成文字", draftHex: $draft.workDoneTextColorHex, picker: $pWorkDoneText) { hasChanges = true }
            colorRow("待完成背景", draftHex: $draft.workPendingBgColorHex, picker: $pWorkPendBg) { hasChanges = true }
        } header: { sectionHeader("工作模式 — 颜色") }
    }

    // MARK: - Main List

    @ViewBuilder
    private var mainListForm: some View {
        Section {
            sizeRow("字号", v: $draft.listFontSize, range: 10...18) { hasChanges = true }
            Toggle("显示备注", isOn: $draft.showNotes).onChange(of: draft.showNotes) { _, _ in hasChanges = true }
            Toggle("显示位置", isOn: $draft.showLocation).onChange(of: draft.showLocation) { _, _ in hasChanges = true }
            Toggle("显示日期", isOn: $draft.showDueDate).onChange(of: draft.showDueDate) { _, _ in hasChanges = true }
            Toggle("显示列表名", isOn: $draft.showListName).onChange(of: draft.showListName) { _, _ in hasChanges = true }
        } header: { sectionHeader("主列表") }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBarForm: some View {
        Section {
            Picker("图标", selection: $draft.statusBarIconName) {
                Text("checklist").tag("checklist")
                Text("checkmark.circle").tag("checkmark.circle")
                Text("list.bullet").tag("list.bullet")
                Text("square.grid.2x2").tag("square.grid.2x2")
                Text("bell.badge").tag("bell.badge")
            }.onChange(of: draft.statusBarIconName) { _, _ in hasChanges = true }
        } header: { sectionHeader("状态栏") }
    }

    // MARK: - AI Model

    @ViewBuilder
    private var aiModelForm: some View {
        Section {
            Toggle("多任务模式", isOn: $draft.aiMultiMode).onChange(of: draft.aiMultiMode) { _, _ in hasChanges = true }
        } header: { sectionHeader("AI 模型") }

        Section {
            ForEach(llmService.providers, id: \.id) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 12, weight: .medium))
                        Text(p.modelName).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    if p.id == llmService.currentProvider.id {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                    }
                    Button("编辑") { editingProvider = p; showProviderEditor = true }
                        .font(.system(size: 10)).buttonStyle(.plain)
                    Button("删除") { llmService.removeProvider(p) }
                        .font(.system(size: 10)).buttonStyle(.plain).foregroundColor(.red)
                }.padding(.vertical, 1)
            }
            HStack {
                Button(action: {
                    editingProvider = LLMProviderConfig(id: UUID(), name: "", baseURL: "https://api.openai.com/v1/chat/completions", modelName: "gpt-4o-mini", apiKey: "")
                    showProviderEditor = true
                }) { Label("添加", systemImage: "plus").font(.caption) }.buttonStyle(.plain)
                Spacer()
                if llmService.isProcessing { ProgressView().scaleEffect(0.6) }
                Button("测试连接") { Task { do { _ = try await llmService.parseNaturalLanguage("test") } catch {} } }
                    .font(.caption).buttonStyle(.bordered).controlSize(.small)
            }
        } header: { sectionHeader("API 供应商") }
        .sheet(isPresented: $showProviderEditor) {
            if let p = editingProvider {
                ProviderEditSheet(provider: p) { u in
                    if llmService.providers.contains(where: { $0.id == u.id }) { llmService.updateProvider(u) }
                    else { llmService.addProvider(u) }
                }
            }
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutForm: some View {
        Section {
            HStack {
                Text("SmartRemind").font(.headline)
                Spacer()
                Text("v1.1.0").foregroundColor(.secondary)
            }
        } header: { sectionHeader("关于") }
    }

    // MARK: - Live Preview

    private var livePreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("实时预览").font(.headline).foregroundColor(.secondary)
                Spacer()
                if hasChanges {
                    Text("(草稿)")
                        .font(.caption).foregroundColor(.orange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().stroke(Color.orange))
                }
            }
            .padding(.horizontal, 10).padding(.top, 10)

            Spacer()

            if selectedCategory.isFloatCategory {
                floatPreviewWindow.padding(12)
            } else if selectedCategory.isWorkCategory {
                workModePreview.padding(12)
            } else {
                generalPreview.padding(12)
            }

            Spacer()

            Text("预览会跟随设置变化实时更新")
                .font(.caption2).foregroundColor(.secondary)
                .padding(.bottom, 10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: Float Preview Window

    private var floatPreviewWindow: some View {
        let draftConfig = PreviewConfig(from: draft)
        return ZStack {
            RoundedRectangle(cornerRadius: draftConfig.cornerRadius)
                .fill(draftConfig.bgColor.opacity(draftConfig.bgOpacity))
                .shadow(radius: 4)

            VStack(spacing: 0) {
                if draft.floatAlignV == "bottom" || draft.floatAlignV == "center" { Spacer(minLength: 0) }

                VStack(alignment: draftConfig.hAlignment, spacing: 2) {
                    HStack(spacing: 4) {
                        if draft.floatAlignH == "center" || draft.floatAlignH == "right" { Spacer(minLength: 0) }
                        if draft.floatLayoutTitleFields.contains("flag") {
                            Image(systemName: "flag.fill")
                                .font(.system(size: draftConfig.fontSize * 0.7))
                                .foregroundColor(draftConfig.flagColor)
                        }
                        if draft.floatLayoutTitleFields.contains("title") {
                            Text("示例提醒事项")
                                .font(.system(size: draftConfig.fontSize, weight: .medium))
                                .foregroundColor(draftConfig.flagColor)
                                .lineLimit(1)
                        }
                        if draft.floatAlignH == "center" || draft.floatAlignH == "left" { Spacer(minLength: 0) }
                    }

                    HStack(spacing: 4) {
                        if draft.floatAlignH == "center" || draft.floatAlignH == "right" { Spacer(minLength: 0) }
                        if draft.floatLayoutSubtitleFields.contains("listName") {
                            HStack(spacing: 2) {
                                Circle().fill(.blue).frame(width: draftConfig.subFontSize * 0.7, height: draftConfig.subFontSize * 0.7)
                                Text("工作")
                            }
                            .font(.system(size: draftConfig.subFontSize))
                            .padding(.horizontal, 2).padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15)).cornerRadius(2)
                            .foregroundColor(draftConfig.textColor.opacity(0.7))
                        }
                        if draft.floatLayoutSubtitleFields.contains("dueDate") {
                            Text("今天 14:30")
                                .font(.system(size: draftConfig.subFontSize))
                                .foregroundColor(draftConfig.dueDateColor)
                        }
                        if draft.floatAlignH == "center" || draft.floatAlignH == "left" { Spacer(minLength: 0) }
                    }
                }
                .padding(.leading, draft.floatAlignPaddingH)
                .padding(.top, draft.floatAlignV == "top" ? draft.floatAlignPaddingV : 0)

                if draft.floatAlignV == "center" || draft.floatAlignV == "top" { Spacer(minLength: 0) }
            }

            // Widget in preview
            if draft.floatWidgetEnabled {
                let a: Alignment = {
                    switch draft.floatWidgetPosition {
                    case "topLeft": return .topLeading
                    case "topRight": return .topTrailing
                    case "bottomLeft": return .bottomLeading
                    case "bottomRight": return .bottomTrailing
                    default: return .topTrailing
                    }
                }()
                ZStack(alignment: a) {
                    Color.clear
                    Text("3项待办")
                        .font(.system(size: draft.floatWidgetFontSize))
                        .foregroundColor(draftConfig.widgetColor.opacity(draft.floatWidgetOpacity))
                        .padding(6)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: draftConfig.cornerRadius))
        .frame(width: draft.floatWidth > 0 ? draft.floatWidth : 260,
               height: draft.floatHeight > 0 ? draft.floatHeight : 64)
    }

    // MARK: Work Mode Preview

    private var workModePreview: some View {
        let bgColor = config.color(from: draft.workBgColorHex)
        let textColor = config.color(from: draft.workTextColorHex)
        let accentColor = config.color(from: draft.workAccentColorHex)
        let curBg = config.color(from: draft.workCurrentBgColorHex)
        let curText = config.color(from: draft.workCurrentTextColorHex)
        let doneBg = config.color(from: draft.workDoneBgColorHex)
        let doneText = config.color(from: draft.workDoneTextColorHex)
        let pendBg = config.color(from: draft.workPendingBgColorHex)

        let sampleTasks: [(String, String)] = [
            ("完成报告", "done"),
            ("发送邮件", "current"),
            ("准备会议", "pending"),
            ("更新文档", "pending"),
        ]

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text(draft.workHeaderText)
                    .font(.system(size: draft.workHeaderFontSize, weight: .bold))
                    .foregroundColor(accentColor)
                Spacer()
                Text("2/4").font(.system(size: draft.workSubFontSize)).foregroundColor(textColor.opacity(0.6))
            }
            .padding(.horizontal, 10).padding(.vertical, 8)

            Divider().background(textColor.opacity(0.2))

            // Task rows
            VStack(spacing: draft.workRowSpacing) {
                ForEach(Array(sampleTasks.enumerated()), id: \.offset) { idx, task in
                    let (title, state) = task
                    let rowBg = state == "done" ? doneBg : (state == "current" ? curBg : pendBg)
                    let rowText = state == "done" ? doneText : (state == "current" ? curText : textColor)

                    HStack(spacing: 6) {
                        if draft.workShowIndex {
                            Text("\(idx + 1)")
                                .font(.system(size: draft.workSubFontSize, design: .monospaced))
                                .foregroundColor(rowText.opacity(0.5))
                                .frame(width: 18)
                        }
                        Image(systemName: state == "done" ? "checkmark.circle.fill" : (state == "current" ? "circle.inset.filled" : "circle"))
                            .font(.system(size: draft.workFontSize * 0.85))
                            .foregroundColor(state == "done" ? .green.opacity(0.7) : (state == "current" ? accentColor : rowText.opacity(0.4)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .font(.system(size: draft.workFontSize, weight: state == "current" ? .semibold : .regular))
                                .foregroundColor(rowText)
                                .strikethrough(state == "done")
                            if draft.workShowSubtitle {
                                Text("工作 · 今天 14:00")
                                    .font(.system(size: draft.workSubFontSize))
                                    .foregroundColor(rowText.opacity(0.5))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .frame(height: draft.workRowHeight)
                    .background(RoundedRectangle(cornerRadius: 6).fill(rowBg))
                }
            }
            .padding(8)

            Spacer(minLength: 0)
        }
        .background(
            RoundedRectangle(cornerRadius: draft.workCornerRadius)
                .fill(bgColor.opacity(draft.workBgOpacity))
        )
        .clipShape(RoundedRectangle(cornerRadius: draft.workCornerRadius))
        .shadow(radius: 4)
        .frame(width: min(draft.workWidth, 280), height: min(draft.workHeight, 360))
    }

    // MARK: General Preview (non-float, non-work categories)

    private var generalPreview: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedCategory.icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text(selectedCategory.rawValue)
                .font(.title3).foregroundColor(.secondary)
            Text("更改此类别的设置后，将在对应界面中生效。")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Draft Actions

    private func applyDraft() {
        draft.apply(to: config)
        hasChanges = false
        syncPickers()
        // Notify floating panel to refresh
        NotificationCenter.default.post(name: .toggleFloatingPanel, object: nil) // close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .toggleFloatingPanel, object: nil) // reopen
        }
    }

    private func resetDraft() {
        draft = SettingsDraft(from: config)
        hasChanges = false
        syncPickers()
    }

    private func syncPickers() {
        pBg = config.color(from: draft.floatBgColorHex)
        pText = config.color(from: draft.floatTextColorHex)
        pAccent = config.color(from: draft.floatAccentColorHex)
        pFlag = config.color(from: draft.floatFlagColorHex)
        pDueDate = config.color(from: draft.floatDueDateColorHex)
        pWidget = config.color(from: draft.floatWidgetColorHex)
        // Work mode
        pWorkBg = config.color(from: draft.workBgColorHex)
        pWorkText = config.color(from: draft.workTextColorHex)
        pWorkAccent = config.color(from: draft.workAccentColorHex)
        pWorkCurBg = config.color(from: draft.workCurrentBgColorHex)
        pWorkCurText = config.color(from: draft.workCurrentTextColorHex)
        pWorkDoneBg = config.color(from: draft.workDoneBgColorHex)
        pWorkDoneText = config.color(from: draft.workDoneTextColorHex)
        pWorkPendBg = config.color(from: draft.workPendingBgColorHex)
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.accentColor)
    }

    private func sizeRow(_ label: String, v: Binding<Double>, range: ClosedRange<Double>, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 70, alignment: .leading).font(.caption)
            Slider(value: v, in: range).frame(width: 120)
            TextField("", value: v, format: .number)
                .textFieldStyle(.roundedBorder).frame(width: 50).font(.system(size: 10, design: .monospaced))
                .onChange(of: v.wrappedValue) { _, _ in onChange() }
        }
    }

    private func sizeDoubleRow(_ label: String, v: Binding<Double>, range: ClosedRange<Double>, step: Double, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 70, alignment: .leading).font(.caption)
            Slider(value: v, in: range, step: step).frame(width: 120)
            TextField("", value: v, format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder).frame(width: 50).font(.system(size: 10, design: .monospaced))
                .onChange(of: v.wrappedValue) { _, _ in onChange() }
        }
    }

    private func colorRow(_ label: String, draftHex: Binding<String>, picker: Binding<Color>, onChange: @escaping () -> Void) -> some View {
        HStack {
            Text(label).frame(width: 50, alignment: .leading).font(.caption)
            ColorPicker("", selection: picker, supportsOpacity: false).labelsHidden().frame(width: 28)
                .onChange(of: picker.wrappedValue) { _, c in
                    draftHex.wrappedValue = AppearanceConfig.hexFromNSColor(NSColor(c))
                    onChange()
                }
            TextField("#", text: draftHex)
                .font(.system(size: 10, design: .monospaced)).frame(width: 64)
                .textFieldStyle(.roundedBorder)
                .onChange(of: draftHex.wrappedValue) { _, hex in
                    picker.wrappedValue = config.color(from: hex)
                    onChange()
                }
        }
    }
}

// MARK: - Preview Config (small helper for live preview)

struct PreviewConfig {
    let fontSize: Double; let subFontSize: Double
    let cornerRadius: Double; let bgOpacity: Double
    let bgColor: Color; let textColor: Color
    let flagColor: Color; let dueDateColor: Color; let widgetColor: Color
    let hAlignment: HorizontalAlignment

    init(from draft: SettingsDraft) {
        fontSize = draft.floatFontSize
        subFontSize = draft.floatSubFontSize
        cornerRadius = draft.floatCornerRadius
        bgOpacity = draft.floatBgOpacity
        bgColor = AppearanceConfig.shared.color(from: draft.floatBgColorHex)
        textColor = AppearanceConfig.shared.color(from: draft.floatTextColorHex)
        flagColor = AppearanceConfig.shared.color(from: draft.floatFlagColorHex)
        dueDateColor = AppearanceConfig.shared.color(from: draft.floatDueDateColorHex)
        widgetColor = AppearanceConfig.shared.color(from: draft.floatWidgetColorHex)
        switch draft.floatAlignH {
        case "left": hAlignment = .leading
        case "right": hAlignment = .trailing
        default: hAlignment = .center
        }
    }
}

// MARK: - Field Selector

struct FieldSelectorView: View {
    let title: String
    @Binding var value: String
    let options: [String]
    let labels: [String]

    private var selectedFields: Set<String> {
        Set(value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            FlowLayout(spacing: 4) {
                ForEach(Array(zip(options, labels)), id: \.0) { opt, lbl in
                    Toggle(lbl, isOn: Binding(get: { selectedFields.contains(opt) }, set: { on in
                        var f = selectedFields
                        if on { f.insert(opt) } else { f.remove(opt) }
                        value = f.sorted().joined(separator: ",")
                    }))
                    .toggleStyle(.button).controlSize(.small)
                }
            }
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? .infinity,
                       height: rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * spacing)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowMaxH = row.maxHeight
            var x = bounds.minX
            for sv in row.items {
                let w = sv.sizeThatFits(.unspecified).width
                let h = sv.sizeThatFits(.unspecified).height
                sv.place(at: CGPoint(x: x, y: y + (rowMaxH - h) / 2), proposal: .unspecified)
                x += w + spacing
            }
            y += rowMaxH + spacing
        }
    }
    private struct Row { let items: [LayoutSubview]; var maxHeight: CGFloat { items.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 } }
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxW = proposal.width ?? .infinity
        var rows: [Row] = []; var cur: [LayoutSubview] = []; var cw: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if cur.isEmpty { cur = [sv]; cw = sz.width }
            else if cw + spacing + sz.width <= maxW { cur.append(sv); cw += spacing + sz.width }
            else { rows.append(Row(items: cur)); cur = [sv]; cw = sz.width }
        }
        if !cur.isEmpty { rows.append(Row(items: cur)) }
        return rows
    }
}

// MARK: - Provider Editor

struct ProviderEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var baseURL: String
    @State private var modelName: String
    @State private var apiKey: String
    let providerId: UUID
    let onSave: (LLMProviderConfig) -> Void

    init(provider: LLMProviderConfig, onSave: @escaping (LLMProviderConfig) -> Void) {
        self.providerId = provider.id; self.onSave = onSave
        _name = State(initialValue: provider.name); _baseURL = State(initialValue: provider.baseURL)
        _modelName = State(initialValue: provider.modelName); _apiKey = State(initialValue: provider.apiKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("编辑 API 供应商").font(.headline)
            TextField("名称", text: $name).textFieldStyle(.roundedBorder)
            TextField("API URL", text: $baseURL).textFieldStyle(.roundedBorder)
            TextField("模型名称", text: $modelName).textFieldStyle(.roundedBorder)
            SecureField("API Key", text: $apiKey).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("保存") {
                    onSave(LLMProviderConfig(id: providerId, name: name, baseURL: baseURL, modelName: modelName, apiKey: apiKey))
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(name.isEmpty || baseURL.isEmpty || modelName.isEmpty)
            }
        }.padding(20).frame(width: 400)
    }
}

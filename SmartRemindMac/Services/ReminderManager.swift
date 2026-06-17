import Foundation
import EventKit
import CoreLocation
import Combine

/// ReminderManager — EventKit 核心封装单例
/// 负责：权限管理、读取分类/提醒事项、创建提醒事项（支持标题/日期/分类/位置/备注）
@MainActor
final class ReminderManager: ObservableObject {

    static let shared = ReminderManager()

    // MARK: - Published State

    @Published var isAuthorized: Bool = false
    @Published var reminders: [ReminderItem] = []
    @Published var lists: [EKCalendar] = []
    @Published var errorMessage: String?

    // MARK: - Private

    let eventStore = EKEventStore()

    private init() {
        // 检查当前授权状态
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            self.isAuthorized = (status == .fullAccess)
        } else {
            self.isAuthorized = (status == .authorized)
        }
    }

    // MARK: - 权限请求

    /// 请求提醒事项访问权限
    func requestAccess() async {
        do {
            // macOS 14+ 使用 requestFullAccessToReminders()
            // macOS 13 及以下使用 requestAccess(to:)
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToReminders()
            } else {
                granted = try await eventStore.requestAccess(to: .reminder)
            }
            self.isAuthorized = granted
            if granted {
                fetchLists()
                await fetchReminders()
            } else {
                self.errorMessage = "用户拒绝了提醒事项访问权限。请前往「系统设置 → 隐私与安全性 → 提醒事项」中授权。"
            }
        } catch {
            self.isAuthorized = false
            self.errorMessage = "请求权限失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 获取分类（Lists）

    /// 获取所有提醒事项分类
    func fetchLists() {
        guard isAuthorized else { return }
        lists = eventStore.calendars(for: .reminder)
    }

    /// 根据名称查找分类，找不到则返回默认分类
    func findList(named name: String?) -> EKCalendar? {
        guard let name = name, !name.isEmpty else {
            return eventStore.defaultCalendarForNewReminders()
        }
        return lists.first(where: { $0.title.lowercased() == name.lowercased() })
            ?? eventStore.defaultCalendarForNewReminders()
    }

    // MARK: - 读取提醒事项

    /// 获取所有未完成的提醒事项（按截止日期排序）
    func fetchReminders() async {
        guard isAuthorized else { return }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let ekReminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        // 转换并排序：有截止日期的在前，按日期升序
        let items = ekReminders.map { ReminderItem(from: $0) }
        self.reminders = items.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (dateA?, dateB?):
                return dateA < dateB
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return a.title < b.title
            }
        }
    }

    /// 按分类获取提醒事项
    func fetchReminders(forList calendar: EKCalendar) async -> [ReminderItem] {
        guard isAuthorized else { return [] }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: [calendar]
        )

        let ekReminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        return ekReminders.map { ReminderItem(from: $0) }
    }

    // MARK: - 创建提醒事项

    /// 创建提醒事项的输入参数
    struct CreateReminderInput {
        let title: String
        let listName: String?
        let dueDate: Date?
        let location: String?
        let notes: String?
        let priority: Int?
        let flagged: Bool?
        let tags: [String]?
        let reminderDate: Date?
        let recurrenceRule: String?
        let url: String?

        init(title: String,
             listName: String? = nil,
             dueDate: Date? = nil,
             location: String? = nil,
             notes: String? = nil,
             priority: Int? = nil,
             flagged: Bool? = nil,
             tags: [String]? = nil,
             reminderDate: Date? = nil,
             recurrenceRule: String? = nil,
             url: String? = nil) {
            self.title = title
            self.listName = listName
            self.dueDate = dueDate
            self.location = location
            self.notes = notes
            self.priority = priority
            self.flagged = flagged
            self.tags = tags
            self.reminderDate = reminderDate
            self.recurrenceRule = recurrenceRule
            self.url = url
        }
    }

    /// 创建新提醒事项并写入系统
    /// - Returns: 创建成功的 ReminderItem
    @discardableResult
    func createReminder(_ input: CreateReminderInput) async throws -> ReminderItem {
        guard isAuthorized else {
            throw ReminderError.notAuthorized
        }
        guard !input.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ReminderError.invalidInput("标题不能为空")
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = input.title
        reminder.notes = input.notes
        reminder.calendar = findList(named: input.listName)

        // 设置截止日期
        if let dueDate = input.dueDate {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: dueDate
            )
            reminder.dueDateComponents = components

            // 为有截止日期的提醒添加到期提醒
            let alarm = EKAlarm(absoluteDate: dueDate)
            reminder.addAlarm(alarm)
        }

        // 设置优先级
        if let priority = input.priority {
            reminder.priority = priority
        }

        // 旗标
        if let flagged = input.flagged, flagged {
            reminder.priority = 1
        }

        // URL
        if let urlStr = input.url, let url = URL(string: urlStr) {
            reminder.url = url
        }

        // 提醒时间（非截止日期）
        if let reminderDate = input.reminderDate {
            let alarm = EKAlarm(absoluteDate: reminderDate)
            reminder.addAlarm(alarm)
        }

        // 重复规则
        if let rule = input.recurrenceRule {
            if let recurrence = parseRecurrenceRule(rule) {
                reminder.addRecurrenceRule(recurrence)
            }
        }

        // 处理位置提醒
        if let locationText = input.location, !locationText.isEmpty {
            await setLocationAlarm(for: reminder, address: locationText)
        }

        // 保存到 EventKit
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw ReminderError.saveFailed(error.localizedDescription)
        }

        let item = ReminderItem(from: reminder)

        // 刷新列表
        await fetchReminders()

        return item
    }

    // MARK: - 完成/取消完成

    /// 切换提醒事项完成状态
    func toggleCompletion(for item: ReminderItem) async throws {
        guard isAuthorized else { throw ReminderError.notAuthorized }
        guard let ekReminder = eventStore.calendarItem(withIdentifier: item.id) as? EKReminder else {
            throw ReminderError.invalidInput("找不到该提醒事项")
        }
        ekReminder.isCompleted = !ekReminder.isCompleted
        try eventStore.save(ekReminder, commit: true)
        await fetchReminders()
    }

    // MARK: - 编辑提醒事项

    /// 编辑已有提醒事项
    func updateReminder(id: String, title: String?, dueDate: Date?, listName: String?, notes: String?, location: String?) async throws {
        guard isAuthorized else { throw ReminderError.notAuthorized }
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.invalidInput("找不到该提醒事项")
        }

        if let t = title { ekReminder.title = t }
        if let n = notes { ekReminder.notes = n }

        if let d = dueDate {
            ekReminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: d
            )
        }

        if let ln = listName, let cal = findList(named: ln) {
            ekReminder.calendar = cal
        }

        if let loc = location, !loc.isEmpty {
            // 清除旧位置 alarm
            ekReminder.alarms?.removeAll(where: { $0.structuredLocation != nil })
            await setLocationAlarm(for: ekReminder, address: loc)
        }

        try eventStore.save(ekReminder, commit: true)
        await fetchReminders()
    }

    // MARK: - 删除提醒事项

    /// 删除提醒事项
    func deleteReminder(id: String) async throws {
        guard isAuthorized else { throw ReminderError.notAuthorized }
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.invalidInput("找不到该提醒事项")
        }
        try eventStore.remove(ekReminder, commit: true)
        await fetchReminders()
    }

    // MARK: - 重复规则解析

    private func parseRecurrenceRule(_ text: String) -> EKRecurrenceRule? {
        let lower = text.lowercased()
        if lower.contains("每天") || lower.contains("daily") {
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        } else if lower.contains("每周") || lower.contains("weekly") {
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        } else if lower.contains("每月") || lower.contains("monthly") {
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        } else if lower.contains("每年") || lower.contains("yearly") {
            return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        } else if lower.contains("工作日") || lower.contains("weekday") {
            let days = [EKRecurrenceDayOfWeek(.monday), EKRecurrenceDayOfWeek(.tuesday),
                       EKRecurrenceDayOfWeek(.wednesday), EKRecurrenceDayOfWeek(.thursday),
                       EKRecurrenceDayOfWeek(.friday)]
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: days,
                                   daysOfTheMonth: nil, monthsOfTheYear: nil,
                                   weeksOfTheYear: nil, daysOfTheYear: nil,
                                   setPositions: nil, end: nil)
        }
        return nil
    }

    // MARK: - 位置处理

    /// 将文本地址转为坐标并设置位置提醒
    private func setLocationAlarm(for reminder: EKReminder, address: String) async {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let placemark = placemarks.first, let location = placemark.location {
                let structuredLocation = EKStructuredLocation(title: address)
                structuredLocation.geoLocation = location
                structuredLocation.radius = 100 // 100 米触发范围

                let alarm = EKAlarm()
                alarm.structuredLocation = structuredLocation
                alarm.proximity = .enter // 到达时提醒
                reminder.addAlarm(alarm)
            }
        } catch {
            // Geocoding 失败不阻塞创建，仅记录
            print("[SmartRemind] Geocoding failed for '\(address)': \(error.localizedDescription)")
        }
    }

    // MARK: - 错误类型

    enum ReminderError: LocalizedError {
        case notAuthorized
        case invalidInput(String)
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "未获得提醒事项访问权限"
            case .invalidInput(let msg):
                return "输入无效: \(msg)"
            case .saveFailed(let msg):
                return "保存失败: \(msg)"
            }
        }
    }
}

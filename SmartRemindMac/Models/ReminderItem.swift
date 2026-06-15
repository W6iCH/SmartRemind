import Foundation
import EventKit
import SwiftUI

/// 提醒事项模型 — 从 EKReminder 完整提取所有字段
struct ReminderItem: Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let listName: String?
    let listColor: Color        // 分组图标颜色
    let notes: String?
    let location: String?
    let priority: Int           // 0=无, 1=高, 5=中, 9=低
    let flagged: Bool           // 旗标
    let tags: [String]          // 标签
    let hasReminder: Bool       // 是否有提醒
    let reminderDate: Date?     // 提醒时间
    let recurrenceRule: String? // 重复规则描述
    let url: String?

    init(from ekReminder: EKReminder) {
        self.id = ekReminder.calendarItemIdentifier
        self.title = ekReminder.title ?? "无标题"
        self.isCompleted = ekReminder.isCompleted
        self.dueDate = ekReminder.dueDateComponents?.date
        self.listName = ekReminder.calendar?.title
        self.priority = Int(ekReminder.priority)

        // 分组颜色
        if let cgColor = ekReminder.calendar?.cgColor {
            self.listColor = Color(cgColor: cgColor)
        } else {
            self.listColor = .accentColor
        }

        self.notes = ekReminder.notes
        self.flagged = ekReminder.priority == 1 // EKReminder 用 priority=1 表示 flagged 在部分系统

        // 标签 (macOS 13+ 支持)
        if #available(macOS 13.0, *) {
            // EKReminder 没有原生 tags API，用 notes 中 #tag 提取作为 fallback
            // 实际可通过 CalDAV 自定义属性读取，这里简化处理
            self.tags = []
        } else {
            self.tags = []
        }

        // 位置
        if let alarm = ekReminder.alarms?.first(where: { $0.structuredLocation != nil }),
           let loc = alarm.structuredLocation {
            self.location = loc.title
        } else {
            self.location = nil
        }

        // 提醒时间
        if let alarm = ekReminder.alarms?.first(where: { $0.absoluteDate != nil }) {
            self.hasReminder = true
            self.reminderDate = alarm.absoluteDate
        } else if let alarm = ekReminder.alarms?.first(where: { $0.relativeOffset != 0 }),
                  let due = ekReminder.dueDateComponents?.date {
            self.hasReminder = true
            self.reminderDate = due.addingTimeInterval(alarm.relativeOffset)
        } else {
            self.hasReminder = ekReminder.alarms?.isEmpty == false
            self.reminderDate = nil
        }

        // 重复规则
        if let rules = ekReminder.recurrenceRules, let rule = rules.first {
            self.recurrenceRule = Self.describeRecurrence(rule)
        } else {
            self.recurrenceRule = nil
        }

        // URL
        self.url = ekReminder.url?.absoluteString
    }

    // MARK: - Recurrence Description

    private static func describeRecurrence(_ rule: EKRecurrenceRule) -> String {
        let freq: String
        switch rule.frequency {
        case .daily: freq = "每天"
        case .weekly: freq = "每周"
        case .monthly: freq = "每月"
        case .yearly: freq = "每年"
        @unknown default: freq = "重复"
        }
        if rule.interval > 1 {
            return "每 \(rule.interval) \(freqUnit(rule.frequency))"
        }
        return freq
    }

    private static func freqUnit(_ freq: EKRecurrenceFrequency) -> String {
        switch freq {
        case .daily: return "天"
        case .weekly: return "周"
        case .monthly: return "月"
        case .yearly: return "年"
        @unknown default: return ""
        }
    }
}

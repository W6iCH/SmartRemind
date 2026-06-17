import EventKit

extension ReminderManager {

    // MARK: - Edit Operations

    /// Set priority on a reminder.
    /// EKReminder priority values: 0 = none, 1 = high, 5 = medium, 9 = low.
    func setPriority(id: String, priority: Int) async throws {
        guard let item = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw NSError(
                domain: "ReminderManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Reminder not found for id: \(id)"]
            )
        }
        item.priority = priority
        try eventStore.save(item, commit: true)
        await fetchReminders()
    }

    /// Set or unset the flagged state on a reminder.
    /// Apple Reminders represents "flagged" as priority == 1.
    func setFlagged(id: String, flagged: Bool) async throws {
        guard let item = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw NSError(
                domain: "ReminderManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Reminder not found for id: \(id)"]
            )
        }
        if flagged {
            item.priority = 1
        } else {
            // Only clear if currently flagged (priority 1); otherwise leave unchanged.
            if item.priority == 1 {
                item.priority = 0
            }
        }
        try eventStore.save(item, commit: true)
        await fetchReminders()
    }

    /// Move a reminder to a different list (calendar) by name.
    func moveToList(id: String, listName: String) async throws {
        guard let item = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw NSError(
                domain: "ReminderManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Reminder not found for id: \(id)"]
            )
        }

        let calendars = eventStore.calendars(for: .reminder)
        guard let targetCalendar = calendars.first(where: { $0.title == listName }) else {
            throw NSError(
                domain: "ReminderManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "List not found: \(listName)"]
            )
        }

        item.calendar = targetCalendar
        try eventStore.save(item, commit: true)
        await fetchReminders()
    }
}

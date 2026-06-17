import Foundation
import SwiftUI

// MARK: - Data Models

struct WorkSessionRecord: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let totalSeconds: Int          // total elapsed (excluding pauses)
    let tasksSelected: Int
    let tasksCompleted: Int
    let taskDetails: [TaskDetail]  // individual task records

    struct TaskDetail: Codable {
        let title: String
        let completed: Bool
        let listName: String?
    }
}

struct ReminderCountSnapshot: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let totalCount: Int
    let completedCount: Int       // completed that day
    let addedCount: Int           // new that day (estimated)
}

// MARK: - WorkSessionStore

@MainActor
final class WorkSessionStore: ObservableObject {

    static let shared = WorkSessionStore()

    // MARK: Published State

    @Published var sessions: [WorkSessionRecord] = []
    @Published var dailySnapshots: [ReminderCountSnapshot] = []

    // MARK: UserDefaults Keys

    private static let sessionsKey   = "work.sessions.json"
    private static let snapshotsKey  = "work.snapshots.json"

    // MARK: JSON Helpers

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: Init

    private init() {
        loadSessions()
        loadSnapshots()
    }

    // MARK: - Persistence (Sessions)

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: Self.sessionsKey) else { return }
        do {
            sessions = try decoder.decode([WorkSessionRecord].self, from: data)
        } catch {
            print("[WorkSessionStore] Failed to decode sessions: \(error)")
        }
    }

    private func persistSessions() {
        do {
            let data = try encoder.encode(sessions)
            UserDefaults.standard.set(data, forKey: Self.sessionsKey)
        } catch {
            print("[WorkSessionStore] Failed to encode sessions: \(error)")
        }
    }

    // MARK: - Persistence (Snapshots)

    private func loadSnapshots() {
        guard let data = UserDefaults.standard.data(forKey: Self.snapshotsKey) else { return }
        do {
            dailySnapshots = try decoder.decode([ReminderCountSnapshot].self, from: data)
        } catch {
            print("[WorkSessionStore] Failed to decode snapshots: \(error)")
        }
    }

    private func persistSnapshots() {
        do {
            let data = try encoder.encode(dailySnapshots)
            UserDefaults.standard.set(data, forKey: Self.snapshotsKey)
        } catch {
            print("[WorkSessionStore] Failed to encode snapshots: \(error)")
        }
    }

    // MARK: - Public API

    func saveSession(_ record: WorkSessionRecord) {
        sessions.append(record)
        persistSessions()
    }

    func recordDailySnapshot(total: Int, completed: Int, added: Int) {
        let snapshot = ReminderCountSnapshot(
            date: Date(),
            totalCount: total,
            completedCount: completed,
            addedCount: added
        )
        dailySnapshots.append(snapshot)
        persistSnapshots()
    }

    // MARK: - Computed Properties

    /// Sum of totalSeconds across all recorded sessions.
    var totalWorkSeconds: Int {
        sessions.reduce(0) { $0 + $1.totalSeconds }
    }

    /// Sum of tasksCompleted across all recorded sessions.
    var totalTasksCompleted: Int {
        sessions.reduce(0) { $0 + $1.tasksCompleted }
    }

    /// Sessions whose startDate falls within the current ISO calendar week.
    var sessionsThisWeek: [WorkSessionRecord] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }
        return sessions.filter { weekInterval.contains($0.startDate) }
    }

    // MARK: - Clear

    func clearAll() {
        sessions = []
        dailySnapshots = []
        UserDefaults.standard.removeObject(forKey: Self.sessionsKey)
        UserDefaults.standard.removeObject(forKey: Self.snapshotsKey)
    }
}

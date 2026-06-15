import Foundation

/// 业务协调器 — 串联 LLM 解析与 EventKit 写入
@MainActor
final class SmartReminderCoordinator: ObservableObject {

    static let shared = SmartReminderCoordinator()

    private let llmService = LLMService.shared
    private let reminderManager = ReminderManager.shared

    @Published var isProcessing: Bool = false
    @Published var currentStage: ProcessingStage = .idle
    @Published var lastResult: ProcessResult?
    @Published var error: String?

    enum ProcessingStage: Equatable {
        case idle, parsingWithAI, geocoding, savingToReminders, done
    }

    struct ProcessResult {
        let items: [ParsedReminder]
        let createdCount: Int
        let timestamp: Date
    }

    private init() {}

    // MARK: - 处理输入（根据 multiMode 决定单/多）

    func processInput(_ text: String, multiMode: Bool = false) async throws -> ProcessResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CoordinatorError.emptyInput }

        isProcessing = true; error = nil; lastResult = nil
        defer {
            isProcessing = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if self.currentStage == .done { self.currentStage = .idle }
            }
        }

        // Step 1: LLM 解析
        currentStage = .parsingWithAI
        let parsedItems: [ParsedReminder]
        do {
            if multiMode {
                parsedItems = try await llmService.parseMultipleReminders(trimmed)
            } else {
                let single = try await llmService.parseNaturalLanguage(trimmed)
                parsedItems = [single]
            }
        } catch {
            self.error = "AI 解析失败: \(error.localizedDescription)"
            currentStage = .idle; throw error
        }

        // Step 2: 逐个创建
        currentStage = .savingToReminders
        var createdCount = 0
        for parsed in parsedItems {
            let dueDate = parseDueDate(parsed.dueDate)
            let reminderDate = parseDueDate(parsed.reminderDate)

            if parsed.location != nil { currentStage = .geocoding }

            let input = ReminderManager.CreateReminderInput(
                title: parsed.title,
                listName: parsed.listName,
                dueDate: dueDate,
                location: parsed.location,
                notes: parsed.notes,
                priority: parsed.priority,
                flagged: parsed.flagged,
                tags: parsed.tags,
                reminderDate: reminderDate,
                recurrenceRule: parsed.recurrenceRule,
                url: parsed.url
            )

            do {
                try await reminderManager.createReminder(input)
                createdCount += 1
            } catch {
                // 单个失败不阻塞其余
                print("[SmartRemind] Failed to create '\(parsed.title)': \(error)")
            }
        }

        currentStage = .done
        let result = ProcessResult(items: parsedItems, createdCount: createdCount, timestamp: Date())
        lastResult = result
        return result
    }

    // MARK: - Date Parse

    private func parseDueDate(_ dateString: String?) -> Date? {
        guard let str = dateString, !str.isEmpty, str != "null" else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }

        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                    "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            fallback.dateFormat = fmt
            if let d = fallback.date(from: str) { return d }
        }
        return nil
    }

    enum CoordinatorError: LocalizedError {
        case emptyInput
        var errorDescription: String? { "输入不能为空" }
    }
}

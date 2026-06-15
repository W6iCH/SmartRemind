import Foundation

/// LLM 供应商配置
struct LLMProviderConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var baseURL: String
    var modelName: String
    var apiKey: String

    static let defaultDeepSeek = LLMProviderConfig(
        id: UUID(), name: "DeepSeek",
        baseURL: "https://api.deepseek.com/v1/chat/completions",
        modelName: "deepseek-chat", apiKey: ""
    )

    static let defaultOpenAI = LLMProviderConfig(
        id: UUID(), name: "OpenAI",
        baseURL: "https://api.openai.com/v1/chat/completions",
        modelName: "gpt-4o-mini", apiKey: ""
    )
}

/// LLM 解析结果 — 单个提醒
struct ParsedReminder: Codable {
    let title: String
    let listName: String?
    let dueDate: String?
    let location: String?
    let notes: String?
    let flagged: Bool?
    let priority: Int?          // 0=无, 1=高, 5=中, 9=低
    let tags: [String]?
    let reminderDate: String?   // ISO8601，提醒时间
    let recurrenceRule: String? // 自然语言重复描述
    let url: String?
}

/// LLM 解析结果 — 多个提醒（多任务模式）
struct ParsedReminders: Codable {
    let items: [ParsedReminder]
}

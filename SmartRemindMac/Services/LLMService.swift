import Foundation

/// LLM 服务 — 调用 OpenAI 兼容格式 API，将自然语言解析为结构化提醒
@MainActor
final class LLMService: ObservableObject {

    static let shared = LLMService()

    @Published var currentProvider: LLMProviderConfig
    @Published var providers: [LLMProviderConfig]
    @Published var isProcessing: Bool = false
    @Published var lastError: String?

    private let providersKey = "llm_providers"
    private let activeProviderKey = "llm_active_provider_id"

    private init() {
        let savedProviders: [LLMProviderConfig]
        if let data = UserDefaults.standard.data(forKey: providersKey),
           let saved = try? JSONDecoder().decode([LLMProviderConfig].self, from: data) {
            savedProviders = saved
        } else {
            savedProviders = [LLMProviderConfig.defaultDeepSeek]
        }
        self.providers = savedProviders

        let activeId = UserDefaults.standard.string(forKey: activeProviderKey)
        if let id = activeId.flatMap({ UUID(uuidString: $0) }),
           let provider = savedProviders.first(where: { $0.id == id }) {
            self.currentProvider = provider
        } else {
            self.currentProvider = savedProviders.first ?? LLMProviderConfig.defaultDeepSeek
        }
        loadApiKeys()
    }

    // MARK: - Provider Management

    func saveProviders() {
        if let data = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(data, forKey: providersKey)
        }
        UserDefaults.standard.set(currentProvider.id.uuidString, forKey: activeProviderKey)
    }

    func addProvider(_ provider: LLMProviderConfig) {
        providers.append(provider); saveApiKey(for: provider); saveProviders()
    }

    func updateProvider(_ provider: LLMProviderConfig) {
        if let i = providers.firstIndex(where: { $0.id == provider.id }) { providers[i] = provider }
        if currentProvider.id == provider.id { currentProvider = provider }
        saveApiKey(for: provider); saveProviders()
    }

    func removeProvider(_ provider: LLMProviderConfig) {
        providers.removeAll(where: { $0.id == provider.id })
        KeychainHelper.delete(key: "apikey_\(provider.id.uuidString)")
        if currentProvider.id == provider.id { currentProvider = providers.first ?? LLMProviderConfig.defaultDeepSeek }
        saveProviders()
    }

    func setActiveProvider(_ provider: LLMProviderConfig) {
        currentProvider = provider; saveProviders()
    }

    private func saveApiKey(for provider: LLMProviderConfig) {
        guard !provider.apiKey.isEmpty else { return }
        _ = KeychainHelper.save(key: "apikey_\(provider.id.uuidString)", value: provider.apiKey)
    }

    private func loadApiKeys() {
        for i in providers.indices {
            if let key = KeychainHelper.read(key: "apikey_\(providers[i].id.uuidString)") {
                providers[i].apiKey = key
            }
        }
        if let key = KeychainHelper.read(key: "apikey_\(currentProvider.id.uuidString)") {
            currentProvider.apiKey = key
        }
    }

    // MARK: - Parse (Single)

    func parseNaturalLanguage(_ text: String) async throws -> ParsedReminder {
        guard !currentProvider.apiKey.isEmpty else { throw LLMError.noApiKey }
        guard let url = URL(string: currentProvider.baseURL) else { throw LLMError.invalidURL }

        isProcessing = true; lastError = nil
        defer { isProcessing = false }

        let existingLists = ReminderManager.shared.lists.map { $0.title }
        let requestBody = buildRequestBody(userInput: text, multiMode: false, existingLists: existingLists)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(currentProvider.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw LLMError.apiError(statusCode: http.statusCode, message: body)
        }

        return try parseSingleResponse(data: data)
    }

    // MARK: - Parse (Multi)

    func parseMultipleReminders(_ text: String) async throws -> [ParsedReminder] {
        guard !currentProvider.apiKey.isEmpty else { throw LLMError.noApiKey }
        guard let url = URL(string: currentProvider.baseURL) else { throw LLMError.invalidURL }

        isProcessing = true; lastError = nil
        defer { isProcessing = false }

        let existingLists = ReminderManager.shared.lists.map { $0.title }
        let requestBody = buildRequestBody(userInput: text, multiMode: true, existingLists: existingLists)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(currentProvider.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw LLMError.apiError(statusCode: http.statusCode, message: body)
        }

        return try parseMultiResponse(data: data)
    }

    // MARK: - Build Request

    private func buildRequestBody(userInput: String, multiMode: Bool, existingLists: [String]) -> [String: Any] {
        let listsStr = existingLists.isEmpty ? "（无现有分组）" : existingLists.joined(separator: "、")
        let now = ISO8601DateFormatter().string(from: Date())

        let singleSchema = """
        {
            "title": "提醒事项标题",
            "listName": "分组名（从现有分组选择，找不到合适的则为 null）",
            "dueDate": "ISO8601 截止时间或 null",
            "location": "地点或 null",
            "notes": "备注或 null",
            "flagged": true/false 或 null（是否标记旗标）,
            "priority": 0/1/5/9 或 null（0无/1高/5中/9低）,
            "tags": ["标签1", "标签2"] 或 null,
            "reminderDate": "ISO8601 提醒时间或 null（不同于截止时间）",
            "recurrenceRule": "重复规则自然语言描述或 null（如\"每天\"、\"每周一\"）",
            "url": "相关链接或 null"
        }
        """

        let multiSchema = """
        {
            "items": [
                { 同上单个 schema },
                ...
            ]
        }
        """

        let modeInstruction = multiMode
            ? "用户输入可能包含多个任务。请将其拆分为独立的提醒事项，输出 JSON 包含 items 数组。\n输出 Schema:\n\(multiSchema)"
            : "从用户输入中提取一个最重要的提醒事项。\n输出 Schema:\n\(singleSchema)"

        let systemPrompt = """
        你是一个智能提醒事项解析助手。

        现有分组列表：\(listsStr)
        当前时间：\(now)

        规则：
        1. title 必须有值，简洁清晰。
        2. listName 必须从现有分组中选择最合适的。如果没有合适的分组，设为 null（不要创建新分组名）。
        3. 时间词（如「明天」「下周一」「后天3点」）需转换为 ISO8601。
        4. 只有用户明确提到的字段才设置，未提及的设为 null。
        5. flagged 只有用户说「标记」「旗标」「重要」等才设为 true。
        6. priority 只有用户说「高优先级」「紧急」等才设。
        7. tags 只有用户明确提到标签时才设。
        8. recurrenceRule 只有用户说「每天」「每周」等才设。
        9. 严格输出纯 JSON，不要 markdown 代码块。

        \(modeInstruction)
        """

        return [
            "model": currentProvider.modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userInput]
            ],
            "temperature": 0.1,
            "max_tokens": 1000,
            "response_format": ["type": "json_object"]
        ]
    }

    // MARK: - Parse Response

    private func parseSingleResponse(data: Data) throws -> ParsedReminder {
        let content = try extractContent(from: data)
        let cleaned = cleanJSON(content)
        guard let jsonData = cleaned.data(using: .utf8) else { throw LLMError.parseError("编码失败") }

        // 尝试先解析为单个
        do {
            let parsed = try JSONDecoder().decode(ParsedReminder.self, from: jsonData)
            guard !parsed.title.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw LLMError.parseError("标题为空")
            }
            return parsed
        } catch let e as LLMError { throw e }
        catch {
            // 可能返回了 items 格式
            if let multi = try? JSONDecoder().decode(ParsedReminders.self, from: jsonData),
               let first = multi.items.first {
                return first
            }
            throw LLMError.parseError("JSON 解析失败: \(error.localizedDescription)")
        }
    }

    private func parseMultiResponse(data: Data) throws -> [ParsedReminder] {
        let content = try extractContent(from: data)
        let cleaned = cleanJSON(content)
        guard let jsonData = cleaned.data(using: .utf8) else { throw LLMError.parseError("编码失败") }

        // 尝试 items 数组
        if let multi = try? JSONDecoder().decode(ParsedReminders.self, from: jsonData) {
            return multi.items
        }
        // fallback 单个
        if let single = try? JSONDecoder().decode(ParsedReminder.self, from: jsonData) {
            return [single]
        }
        throw LLMError.parseError("无法解析多任务响应")
    }

    private func extractContent(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        return content
    }

    private func cleanJSON(_ content: String) -> String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Error

    enum LLMError: LocalizedError {
        case noApiKey, invalidURL, invalidResponse
        case apiError(statusCode: Int, message: String)
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .noApiKey: return "未配置 API Key"
            case .invalidURL: return "API URL 无效"
            case .apiError(let c, let m): return "API 错误 (\(c)): \(m)"
            case .invalidResponse: return "API 返回格式无效"
            case .parseError(let m): return "解析失败: \(m)"
            }
        }
    }
}

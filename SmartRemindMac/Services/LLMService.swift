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

    /// 多任务模式：先本地拆分编号列表，再逐个调用 LLM 解析
    func parseMultipleReminders(_ text: String) async throws -> [ParsedReminder] {
        guard !currentProvider.apiKey.isEmpty else { throw LLMError.noApiKey }
        guard let url = URL(string: currentProvider.baseURL) else { throw LLMError.invalidURL }

        isProcessing = true; lastError = nil
        defer { isProcessing = false }

        let existingLists = ReminderManager.shared.lists.map { $0.title }

        // Step 1: 本地拆分编号列表
        let taskItems = splitNumberedTasks(text)

        // Step 2: 逐个调用 LLM 解析（每个任务走单任务模式单次调用）
        var results: [ParsedReminder] = []
        for taskText in taskItems {
            let requestBody = buildRequestBody(userInput: taskText, multiMode: false, existingLists: existingLists)

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

            let parsed = try parseSingleResponse(data: data)
            results.append(parsed)
        }

        return results
    }


    // MARK: - Client-Side Numbered List Splitter

    /// 将编号列表拆分为独立任务文本数组
    /// 例如："1、xxx；2、yyy" -> ["xxx", "yyy"]
    /// 自动提取前缀（如"下周前完成："）作为第一条任务的截止时间等上下文
    private func splitNumberedTasks(_ text: String) -> [String] {
        // 必须用普通字符串：\\\\d 在 Swift 字符串中变成 \\d，传给 NSRegularExpression 即 \\d（匹配数字）
        let pattern = "\\d+[、.)）]\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [text]
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matchResults = regex.matches(in: text, options: [], range: nsRange)

        // >=2 个匹配项说明是编号列表
        guard matchResults.count >= 2 else { return [text] }

        // 提取前置上下文
        var prefix = ""
        let firstMatchStart = matchResults[0].range.location
        if firstMatchStart > 0 {
            if let pr = Range(NSRange(location: 0, length: firstMatchStart), in: text) {
                prefix = String(text[pr]).trimmingCharacters(in: CharacterSet(charactersIn: "：:\n\r "))
            }
        }

        var tasks: [String] = []
        for i in 0 ..< matchResults.count {
            let contentStart = matchResults[i].range.location + matchResults[i].range.length
            let nextStart = (i + 1 < matchResults.count) ? matchResults[i + 1].range.location : text.count

            guard contentStart < nextStart else { continue }
            guard let cr = Range(NSRange(location: contentStart, length: nextStart - contentStart), in: text) else { continue }

            var taskText = String(text[cr])
            taskText = taskText.trimmingCharacters(in: CharacterSet(charactersIn: "；;、,\n\r "))

            if !taskText.isEmpty {
                if i == 0 && !prefix.isEmpty {
                    taskText = prefix + " " + taskText
                }
                tasks.append(taskText)
            }
        }

        return tasks.isEmpty ? [text] : tasks
    }

    // MARK: - Build Request

    private func buildRequestBody(userInput: String, multiMode: Bool, existingLists: [String]) -> [String: Any] {
        let listsStr = existingLists.isEmpty ? "（无现有分组）" : existingLists.joined(separator: "、")
        let now = ISO8601DateFormatter().string(from: Date())

        let itemSchema = """
        {
            "title": "提醒事项标题（必填）",
            "listName": "分组名（从现有分组中选择最匹配的，找不到则为 null）",
            "dueDate": "ISO8601 截止时间或 null",
            "location": "地点或 null",
            "notes": "备注或 null",
            "flagged": true 或 false（根据语气推断，紧急/重要的事项设为 true）,
            "priority": 0/1/5/9（1=高优先级，5=中优先级，9=低优先级，0或null=普通）,
            "tags": ["标签1", "标签2"] 或 null,
            "reminderDate": "ISO8601 提醒时间或 null",
            "recurrenceRule": "重复规则（如每天、每周一）或 null",
            "url": "相关链接或 null"
        }
        """

        let maxTokens = multiMode ? 2000 : 1000

        let modeInstruction: String
        if multiMode {
            modeInstruction = """
            【多任务模式开关已打开 — 必须拆分！】

            ⚠️ 编号列表：输入中 "||" 是任务分隔符，每个分隔符后是一项独立任务。
            输入包含多少个 "||"，就至少要输出多少条提醒！

            示例 — 输入：「1||问卷设计 2||模型制作 3||服务器搭建」
            → 输出 3 条提醒，不要合并！

            示例 — 自然语言：「明天交报告，后天开会，顺便买菜」
            → 输出 3 条提醒

            仅当输入是单一短句（如「买牛奶」）且没有任何分隔时才输出 1 条。
            其他情况必须拆成多条。

            输出格式（纯 JSON，不要 markdown 代码块）：
            {
                "items": [
                    { ... 单个提醒事项 ... },
                    ...
                ]
            }
            """
        } else {
            modeInstruction = """
            【单任务模式 — 严格只输出一条】
            ⚠️ 重要：无论用户输入多长、包含多少个任务，你都必须只输出 一个 提醒事项（单个 JSON 对象）。
            永远不要使用 items 数组格式。
            如果输入包含多个任务，请选择最主要或最紧急的那一个，忽略其他。
            如果无法识别出任何任务，用输入全文作为 title。

            输出格式（纯 JSON，不要 markdown 代码块）：
            直接输出单个对象 { 如上 schema }，不要包裹在 items 数组中。
            """
        }

        let systemPrompt = """
        你是一个智能提醒事项解析助手。

        现有分组列表：\(listsStr)
        当前时间：\(now)

        === 解析规则 ===

        1. title（必填）：必须简洁清晰，从用户输入中提取最重要的任务描述。
        2. listName：从现有分组中选择最匹配的。找不到合适的分组则设为 null（不要编造新分组名）。
        3. 时间解析：所有时间词（如「明天」「后天下午3点」「下周一早上」「今晚」「大后天」）需基于当前时间转换为 ISO8601 格式。
        4. flagged（旗标）：根据语气和内容自动推断！不要仅靠关键词。
           — 紧急语气、感叹号结尾、「紧急」「立刻」「马上」「重要」「必须」「加急」「务必」→ true
           — 普通待办事项 → false
           — 不要设为 null，必须有 true 或 false
        5. priority（优先级）：根据语气和紧急程度自动推断！
           — 非常紧急：「立刻」「立即」「紧急」「加急」「今天必须」→ 1（高优先级）
           — 中等紧急：「尽快」「尽量」「希望」「最好」「这周内」→ 5（中优先级）
           — 轻松备忘：「有空」「随便」「回头再说」→ 9（低优先级）
           — 普通任务 → 0 或 null
        6. tags：从输入中提取提到的类别、项目名或主题作为标签，没有则为 null。
        7. recurrenceRule：只有用户明确说「每天」「每周」「每月」「工作日」等才设置，否则为 null。
        8. notes：提取额外的说明文字，没有则为 null。
        9. 严格输出纯 JSON，不要 markdown 代码块，不要额外文字。

        \(modeInstruction)
        """

        return [
            "model": currentProvider.modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userInput]
            ],
            "temperature": 0.1,
            "max_tokens": maxTokens,
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

// HistoryScanner.swift
// ClaudeDash - Claude Code 历史 JSONL 扫描器
// 扫描 ~/.claude/projects/ 下的所有 JSONL 文件，提取 session 统计数据

import Foundation
import CryptoKit
import SQLite3

// MARK: - 扫描结果模型

/// 从 JSONL 解析出的单个 session 统计
struct ScannedSession: Identifiable, Codable, Sendable {
    var id: String { sessionId }
    let sessionId: String
    let projectDir: String
    let projectName: String
    let startTime: Date
    let endTime: Date
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let messageCount: Int
    let toolUseCount: Int
    let model: String
    let filePath: String
    /// 工具调用分布 (tool name → 调用次数)
    let toolDistribution: [String: Int]
    /// 数据来源（Claude Code 或 Kimi CLI）
    let source: SessionSource

    /// 总 token 数（输入 + 输出）
    var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens }

    enum CodingKeys: String, CodingKey {
        case sessionId, projectDir, projectName, startTime, endTime
        case inputTokens, outputTokens, cacheReadTokens, cacheCreationTokens
        case messageCount, toolUseCount, model, filePath, toolDistribution, source
    }

    init(sessionId: String, projectDir: String, projectName: String,
         startTime: Date, endTime: Date, inputTokens: Int, outputTokens: Int,
         cacheReadTokens: Int, cacheCreationTokens: Int, messageCount: Int,
         toolUseCount: Int, model: String, filePath: String,
         toolDistribution: [String: Int], source: SessionSource) {
        self.sessionId = sessionId
        self.projectDir = projectDir
        self.projectName = projectName
        self.startTime = startTime
        self.endTime = endTime
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.messageCount = messageCount
        self.toolUseCount = toolUseCount
        self.model = model
        self.filePath = filePath
        self.toolDistribution = toolDistribution
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        projectDir = try container.decode(String.self, forKey: .projectDir)
        projectName = try container.decode(String.self, forKey: .projectName)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        cacheReadTokens = try container.decode(Int.self, forKey: .cacheReadTokens)
        cacheCreationTokens = try container.decode(Int.self, forKey: .cacheCreationTokens)
        messageCount = try container.decode(Int.self, forKey: .messageCount)
        toolUseCount = try container.decode(Int.self, forKey: .toolUseCount)
        model = try container.decode(String.self, forKey: .model)
        filePath = try container.decode(String.self, forKey: .filePath)
        toolDistribution = try container.decode([String: Int].self, forKey: .toolDistribution)
        source = try container.decodeIfPresent(SessionSource.self, forKey: .source) ?? .claude
    }

    /// 估算成本 USD（基于公开的 API 定价估算）
    var estimatedCost: Double {
        // 粗略估算，使用 Claude Opus 4 定价参考
        // input: $15/M tokens, output: $75/M tokens, cache read: $1.5/M, cache creation: $18.75/M
        let inputCost = Double(inputTokens) / 1_000_000 * 15.0
        let outputCost = Double(outputTokens) / 1_000_000 * 75.0
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * 1.5
        let cacheCreationCost = Double(cacheCreationTokens) / 1_000_000 * 18.75
        return inputCost + outputCost + cacheReadCost + cacheCreationCost
    }

    /// session 持续时间（秒）
    var durationSeconds: Double {
        endTime.timeIntervalSince(startTime)
    }
}

// MARK: - 扫描器

enum HistoryScanner {
    private struct CachedScanEntry: Codable, Sendable {
        let filePath: String
        let fileSize: Int64
        let modifiedAt: TimeInterval
        let session: ScannedSession

        func matches(fileSize: Int64, modifiedAt: TimeInterval) -> Bool {
            self.fileSize == fileSize && abs(self.modifiedAt - modifiedAt) < 0.5
        }
    }

    private struct CachedScanStore: Codable, Sendable {
        let version: Int
        let entries: [String: CachedScanEntry]
    }

    private static let cacheVersion = 3

    /// Claude Code 项目目录
    private static var claudeProjectsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    /// Kimi CLI sessions 目录
    private static var kimiSessionsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kimi/sessions")
    }

    /// Codex CLI state 数据库
    private static var codexStateDBPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/state_5.sqlite").path
    }

    /// 历史扫描缓存文件
    private static var defaultCacheFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let supportDir = appSupport.appendingPathComponent("ClaudeDash", isDirectory: true)
        return supportDir.appendingPathComponent("history-scan-cache.json")
    }

    /// 扫描所有 JSONL 文件，返回 session 统计列表
    static func scanAll(
        claudeBaseDir: URL? = nil,
        kimiBaseDir: URL? = nil,
        cacheFileURL: URL? = nil
    ) -> [ScannedSession] {
        let cacheURL = cacheFileURL ?? defaultCacheFileURL
        let cacheStore = loadCache(from: cacheURL)
        var updatedEntries: [String: CachedScanEntry] = [:]

        let claudeSessions = scanClaude(baseDir: claudeBaseDir, cacheStore: cacheStore, updatedEntries: &updatedEntries)
        let kimiSessions = scanKimi(baseDir: kimiBaseDir, cacheStore: cacheStore, updatedEntries: &updatedEntries)
        let codexSessions = scanCodex(cacheStore: cacheStore, updatedEntries: &updatedEntries)

        persistCache(CachedScanStore(version: cacheVersion, entries: updatedEntries), to: cacheURL)
        return (claudeSessions + kimiSessions + codexSessions).sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Claude Code 扫描

    private static func scanClaude(
        baseDir: URL? = nil,
        cacheStore: CachedScanStore,
        updatedEntries: inout [String: CachedScanEntry]
    ) -> [ScannedSession] {
        let baseDir = baseDir ?? claudeProjectsDir
        guard FileManager.default.fileExists(atPath: baseDir.path) else { return [] }

        var sessions: [ScannedSession] = []

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: baseDir, includingPropertiesForKeys: nil
        ) else { return [] }

        for projectDir in projectDirs {
            guard projectDir.hasDirectoryPath else { continue }

            let projectDirName = projectDir.lastPathComponent
            let projectName = extractProjectName(from: projectDirName)

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: projectDir, includingPropertiesForKeys: nil
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
                guard let values = try? file.resourceValues(forKeys: resourceKeys),
                      values.isRegularFile != false else { continue }

                let sessionId = file.deletingPathExtension().lastPathComponent
                let filePath = file.path
                let modifiedAt = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                let fileSize = Int64(values.fileSize ?? 0)

                if let cached = cacheStore.entries[filePath],
                   cached.matches(fileSize: fileSize, modifiedAt: modifiedAt) {
                    sessions.append(cached.session)
                    updatedEntries[filePath] = cached
                    continue
                }

                if let session = parseClaudeJSONL(
                    at: file,
                    sessionId: sessionId,
                    projectDir: projectDirName,
                    projectName: projectName
                ) {
                    sessions.append(session)
                    updatedEntries[filePath] = CachedScanEntry(
                        filePath: filePath,
                        fileSize: fileSize,
                        modifiedAt: modifiedAt,
                        session: session
                    )
                }
            }
        }

        return sessions
    }

    // MARK: - Kimi CLI 扫描

    private static func scanKimi(
        baseDir: URL? = nil,
        cacheStore: CachedScanStore,
        updatedEntries: inout [String: CachedScanEntry]
    ) -> [ScannedSession] {
        let baseDir = baseDir ?? kimiSessionsDir
        guard FileManager.default.fileExists(atPath: baseDir.path) else { return [] }

        var sessions: [ScannedSession] = []
        let workDirMap = loadKimiWorkDirMap()

        guard let hashDirs = try? FileManager.default.contentsOfDirectory(
            at: baseDir, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        for hashDir in hashDirs {
            guard hashDir.hasDirectoryPath else { continue }
            let hashDirName = hashDir.lastPathComponent

            guard let uuidDirs = try? FileManager.default.contentsOfDirectory(
                at: hashDir, includingPropertiesForKeys: [.isDirectoryKey]
            ) else { continue }

            for uuidDir in uuidDirs {
                guard uuidDir.hasDirectoryPath else { continue }
                let wireURL = uuidDir.appendingPathComponent("wire.jsonl")
                guard FileManager.default.fileExists(atPath: wireURL.path) else { continue }

                let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
                guard let values = try? wireURL.resourceValues(forKeys: resourceKeys),
                      values.isRegularFile != false else { continue }

                let sessionId = uuidDir.lastPathComponent
                let filePath = wireURL.path
                let modifiedAt = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                let fileSize = Int64(values.fileSize ?? 0)

                if let cached = cacheStore.entries[filePath],
                   cached.matches(fileSize: fileSize, modifiedAt: modifiedAt) {
                    sessions.append(cached.session)
                    updatedEntries[filePath] = cached
                    continue
                }

                let workDir = workDirMap[hashDirName]
                let fallbackName = workDir.map { URL(fileURLWithPath: $0).lastPathComponent } ?? hashDirName
                let projectName = kimiStateTitle(at: wireURL) ?? fallbackName

                if let session = parseKimiJSONL(
                    at: wireURL,
                    sessionId: sessionId,
                    projectDir: hashDirName,
                    projectName: projectName
                ) {
                    sessions.append(session)
                    updatedEntries[filePath] = CachedScanEntry(
                        filePath: filePath,
                        fileSize: fileSize,
                        modifiedAt: modifiedAt,
                        session: session
                    )
                }
            }
        }

        return sessions
    }

    /// 从项目目录名提取可读项目名
    /// 格式: "-Users-cj-Documents-personal-project-myapp" → "myapp"
    private static func extractProjectName(from dirName: String) -> String {
        let parts = dirName.split(separator: "-")
        // 取最后一个非空部分
        if let last = parts.last, !last.isEmpty {
            return String(last)
        }
        return dirName
    }

    // MARK: - Claude JSONL 解析

    private static func parseClaudeJSONL(
        at fileURL: URL,
        sessionId: String,
        projectDir: String,
        projectName: String
    ) -> ScannedSession? {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return nil }

        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var inputTokens = 0
        var outputTokens = 0
        var cacheReadTokens = 0
        var cacheCreationTokens = 0
        var messageCount = 0
        var toolUseCount = 0
        var toolDistribution: [String: Int] = [:]
        var model = ""

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let ts = json["timestamp"] as? String, let date = isoFormatter.date(from: ts) {
                if firstTimestamp == nil { firstTimestamp = date }
                lastTimestamp = date
            }

            let type = json["type"] as? String ?? ""

            switch type {
            case "assistant":
                messageCount += 1
                if let message = json["message"] as? [String: Any] {
                    if model.isEmpty, let m = message["model"] as? String {
                        model = m
                    }
                    if let usage = message["usage"] as? [String: Any] {
                        inputTokens += usage["input_tokens"] as? Int ?? 0
                        outputTokens += usage["output_tokens"] as? Int ?? 0
                        cacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
                        cacheCreationTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
                    }
                    if let content = message["content"] as? [[String: Any]] {
                        for block in content {
                            if let blockType = block["type"] as? String, blockType == "tool_use" {
                                toolUseCount += 1
                                if let toolName = block["name"] as? String {
                                    toolDistribution[toolName, default: 0] += 1
                                }
                            }
                        }
                    }
                }

            case "user":
                messageCount += 1

            default:
                break
            }
        }

        guard let start = firstTimestamp, let end = lastTimestamp else { return nil }

        return ScannedSession(
            sessionId: sessionId,
            projectDir: projectDir,
            projectName: projectName,
            startTime: start,
            endTime: end,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens,
            messageCount: messageCount,
            toolUseCount: toolUseCount,
            model: model,
            filePath: fileURL.path,
            toolDistribution: toolDistribution,
            source: .claude
        )
    }

    // MARK: - Kimi JSONL 解析

    private static func parseKimiJSONL(
        at fileURL: URL,
        sessionId: String,
        projectDir: String,
        projectName: String
    ) -> ScannedSession? {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return nil }

        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var messageCount = 0
        var toolUseCount = 0
        var toolDistribution: [String: Int] = [:]
        var inputTokens = 0
        var outputTokens = 0
        var cacheReadTokens = 0
        var cacheCreationTokens = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if json["type"] as? String == "metadata" { continue }

            if let ts = json["timestamp"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: ts)
                if firstTimestamp == nil { firstTimestamp = date }
                lastTimestamp = date
            }

            guard let message = json["message"] as? [String: Any],
                  let messageType = message["type"] as? String else {
                continue
            }

            let payload = message["payload"] as? [String: Any] ?? [:]

            switch messageType {
            case "ContentPart":
                if let partType = payload["type"] as? String,
                   partType == "text" || partType == "think" {
                    messageCount += 1
                }

            case "ToolCall":
                toolUseCount += 1
                if let function = payload["function"] as? [String: Any],
                   let toolName = function["name"] as? String {
                    toolDistribution[toolName, default: 0] += 1
                } else if let name = payload["name"] as? String {
                    toolDistribution[name, default: 0] += 1
                }

            case "StatusUpdate":
                if let tokenUsage = payload["token_usage"] as? [String: Any] {
                    inputTokens += tokenUsage["input_other"] as? Int ?? 0
                    outputTokens += tokenUsage["output"] as? Int ?? 0
                    cacheReadTokens += tokenUsage["input_cache_read"] as? Int ?? 0
                    cacheCreationTokens += tokenUsage["input_cache_creation"] as? Int ?? 0
                }

            default:
                break
            }
        }

        guard let start = firstTimestamp, let end = lastTimestamp else { return nil }

        return ScannedSession(
            sessionId: sessionId,
            projectDir: projectDir,
            projectName: projectName,
            startTime: start,
            endTime: end,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens,
            messageCount: messageCount,
            toolUseCount: toolUseCount,
            model: "",
            filePath: fileURL.path,
            toolDistribution: toolDistribution,
            source: .kimi
        )
    }

    // MARK: - Codex CLI 扫描（SQLite 索引 + JSONL 工具分布）

    private static func scanCodex(
        cacheStore: CachedScanStore,
        updatedEntries: inout [String: CachedScanEntry]
    ) -> [ScannedSession] {
        let dbPath = codexStateDBPath
        guard FileManager.default.fileExists(atPath: dbPath) else { return [] }

        let threads = loadCodexThreads(dbPath: dbPath)
        guard !threads.isEmpty else { return [] }

        var sessions: [ScannedSession] = []

        for thread in threads {
            let filePath = thread.rolloutPath
            guard !filePath.isEmpty,
                  FileManager.default.fileExists(atPath: filePath) else { continue }

            let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
            let fileURL = URL(fileURLWithPath: filePath)
            let modifiedAt: TimeInterval
            let fileSize: Int64
            if let values = try? fileURL.resourceValues(forKeys: resourceKeys) {
                modifiedAt = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                fileSize = Int64(values.fileSize ?? 0)
            } else {
                modifiedAt = thread.updatedAt
                fileSize = 0
            }

            if let cached = cacheStore.entries[filePath],
               cached.matches(fileSize: fileSize, modifiedAt: modifiedAt) {
                sessions.append(cached.session)
                updatedEntries[filePath] = cached
                continue
            }

            let toolInfo = parseCodexJSONLTools(at: fileURL)

            let projectName = URL(fileURLWithPath: thread.cwd).lastPathComponent
            let startTime = Date(timeIntervalSince1970: thread.createdAt)
            let endTime = Date(timeIntervalSince1970: thread.updatedAt)
            guard endTime.timeIntervalSince(startTime) > 0 else { continue }

            let session = ScannedSession(
                sessionId: thread.id,
                projectDir: thread.cwd,
                projectName: projectName,
                startTime: startTime,
                endTime: endTime,
                inputTokens: thread.tokensUsed,
                outputTokens: 0,
                cacheReadTokens: 0,
                cacheCreationTokens: 0,
                messageCount: toolInfo.messageCount,
                toolUseCount: toolInfo.toolUseCount,
                model: thread.model,
                filePath: filePath,
                toolDistribution: toolInfo.toolDistribution,
                source: .codex
            )
            sessions.append(session)
            updatedEntries[filePath] = CachedScanEntry(
                filePath: filePath,
                fileSize: fileSize,
                modifiedAt: modifiedAt,
                session: session
            )
        }

        return sessions
    }

    private struct CodexThread {
        let id: String
        let cwd: String
        let title: String
        let model: String
        let tokensUsed: Int
        let createdAt: TimeInterval
        let updatedAt: TimeInterval
        let rolloutPath: String
    }

    private static func loadCodexThreads(dbPath: String) -> [CodexThread] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let db else { return [] }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT id, cwd, title, model, tokens_used, created_at, updated_at, rollout_path
            FROM threads
            WHERE rollout_path IS NOT NULL AND rollout_path != ''
            ORDER BY updated_at DESC
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }

        var threads: [CodexThread] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let cwd = String(cString: sqlite3_column_text(stmt, 1))
            let title = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let model = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
            let tokensUsed = Int(sqlite3_column_int64(stmt, 4))
            let createdAt = Double(sqlite3_column_int64(stmt, 5))
            let updatedAt = Double(sqlite3_column_int64(stmt, 6))
            let rolloutPath = sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? ""

            threads.append(CodexThread(
                id: id, cwd: cwd, title: title, model: model,
                tokensUsed: tokensUsed, createdAt: createdAt, updatedAt: updatedAt,
                rolloutPath: rolloutPath
            ))
        }
        return threads
    }

    private struct CodexToolInfo {
        let toolUseCount: Int
        let messageCount: Int
        let toolDistribution: [String: Int]
    }

    private static func parseCodexJSONLTools(at fileURL: URL) -> CodexToolInfo {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return CodexToolInfo(toolUseCount: 0, messageCount: 0, toolDistribution: [:])
        }

        var toolUseCount = 0
        var messageCount = 0
        var toolDistribution: [String: Int] = [:]

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            let type = json["type"] as? String ?? ""
            let payload = json["payload"] as? [String: Any] ?? [:]

            switch type {
            case "response_item":
                let itemType = payload["type"] as? String ?? ""
                if itemType == "function_call" || itemType == "custom_tool_call" {
                    toolUseCount += 1
                    if let toolName = payload["name"] as? String {
                        toolDistribution[toolName, default: 0] += 1
                    }
                }

            case "event_msg":
                let eventType = payload["type"] as? String ?? ""
                if eventType == "agent_message" || eventType == "user_message" {
                    messageCount += 1
                }

            default:
                break
            }
        }

        return CodexToolInfo(
            toolUseCount: toolUseCount,
            messageCount: messageCount,
            toolDistribution: toolDistribution
        )
    }

    // MARK: - Kimi 辅助方法

    private static func loadKimiWorkDirMap() -> [String: String] {
        let kimiConfigPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kimi/kimi.json").path
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: kimiConfigPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let workDirs = json["work_dirs"] as? [[String: Any]] else {
            return [:]
        }
        var map: [String: String] = [:]
        for entry in workDirs {
            if let path = entry["path"] as? String {
                let hash = md5Hash(of: path)
                map[hash] = path
            }
        }
        return map
    }

    private static func md5Hash(of string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func kimiStateTitle(at wireURL: URL) -> String? {
        let stateURL = wireURL.deletingLastPathComponent().appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: stateURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["custom_title"] as? String,
              !title.isEmpty else {
            return nil
        }
        return title
    }

    private static func loadCache(from url: URL) -> CachedScanStore {
        guard let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(CachedScanStore.self, from: data),
              store.version == cacheVersion else {
            return CachedScanStore(version: cacheVersion, entries: [:])
        }
        return store
    }

    private static func persistCache(_ store: CachedScanStore, to url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(store) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

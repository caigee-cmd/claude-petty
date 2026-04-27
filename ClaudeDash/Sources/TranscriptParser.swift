// TranscriptParser.swift
// ClaudeDash - JSONL Transcript real-time parser
// Incremental parsing of ~/.claude/projects/{project}/{session}.jsonl

import Foundation
import Combine

enum TranscriptParserRules {
    private static let interruptionMarker = "[request interrupted by user"
    private static let clearCommandMarker = "<command-name>/clear</command-name>"
    private static let commandNameMarker = "<command-name>/"
    private static let localCommandStdoutMarker = "<local-command-stdout>"
    private static let localCommandStderrMarker = "<local-command-stderr>"

    static func userLineRepresentsInterruption(_ json: [String: Any]) -> Bool {
        if containsInterruptionMarker(in: json["toolUseResult"]) {
            return true
        }

        guard let message = json["message"] as? [String: Any] else { return false }
        return containsInterruptionMarker(in: message["content"])
    }

    private static func containsInterruptionMarker(in value: Any?) -> Bool {
        switch value {
        case let text as String:
            return text.lowercased().contains(interruptionMarker)
        case let dictionary as [String: Any]:
            if let interrupted = dictionary["interrupted"] as? Bool, interrupted {
                return true
            }
            return dictionary.values.contains { containsInterruptionMarker(in: $0) }
        case let array as [Any]:
            return array.contains { containsInterruptionMarker(in: $0) }
        default:
            return false
        }
    }

    static func userLineShouldActivateSession(_ json: [String: Any]) -> Bool {
        if json["isMeta"] as? Bool == true {
            return false
        }

        guard let message = json["message"] as? [String: Any] else {
            return false
        }

        return contentShouldActivateSession(message["content"])
    }

    static func userLineStatus(_ json: [String: Any]) -> SessionStatus? {
        userLineShouldActivateSession(json) ? .thinking : nil
    }

    static func systemLineShouldActivateSession(_ json: [String: Any]) -> Bool {
        let subtype = (json["subtype"] as? String)?.lowercased()
        return subtype != "local_command"
    }

    private static func contentShouldActivateSession(_ content: Any?) -> Bool {
        switch content {
        case let text as String:
            return !containsPassiveCommandMarker(text)
        case let block as [String: Any]:
            return contentBlockShouldActivateSession(block)
        case let blocks as [[String: Any]]:
            return blocks.contains { contentBlockShouldActivateSession($0) }
        case let items as [Any]:
            return items.contains { contentShouldActivateSession($0) }
        case nil:
            return false
        default:
            return true
        }
    }

    private static func contentBlockShouldActivateSession(_ block: [String: Any]) -> Bool {
        let blockType = (block["type"] as? String)?.lowercased()

        switch blockType {
        case "tool_result":
            return false
        case "text":
            return contentShouldActivateSession(block["text"])
        default:
            if let content = block["content"] {
                return contentShouldActivateSession(content)
            }
            return true
        }
    }

    private static func containsPassiveCommandMarker(_ text: String) -> Bool {
        let lowered = text.lowercased()

        if lowered.contains(clearCommandMarker) {
            return true
        }

        if lowered.contains(commandNameMarker) {
            return true
        }

        if lowered.contains(localCommandStdoutMarker) || lowered.contains(localCommandStderrMarker) {
            return true
        }

        return false
    }

    static func assistantLineStatus(_ json: [String: Any]) -> SessionStatus? {
        guard let message = json["message"] as? [String: Any] else { return nil }
        let contentBlocks = message["content"] as? [[String: Any]] ?? []
        let stopReason = (message["stop_reason"] as? String)?.lowercased()

        let blockTypes = Set(contentBlocks.compactMap { $0["type"] as? String })
        if blockTypes.contains("tool_use") {
            return .toolRunning
        }
        if blockTypes.contains("thinking") || blockTypes.contains("redacted_thinking") {
            return .thinking
        }
        if blockTypes.contains("text") {
            return stopReason == "end_turn" ? .completed : .thinking
        }

        return nil
    }
}

final class TranscriptParser: ObservableObject, @unchecked Sendable {
    @Published private(set) var lastMessages: [TranscriptMessage] = []
    @Published private(set) var currentStatus: SessionStatus = .unknown
    @Published private(set) var currentTool: ToolType = .unknown
    @Published private(set) var tokenUsage: Double = 0.0

    let filePath: String

    private let parseQueue = DispatchQueue(
        label: "ClaudeDash.TranscriptParser",
        qos: .utility
    )
    private let maxContextTokens: Double = 200_000

    private var fileOffset: UInt64 = 0
    private var totalInputTokens: Int = 0
    private var totalOutputTokens: Int = 0
    private var bufferedMessages: [TranscriptMessage] = []
    private var statusValue: SessionStatus = .unknown
    private var toolValue: ToolType = .unknown
    private var tokenUsageValue: Double = 0.0
    private var format: TranscriptFormat = .claude

    private enum TranscriptFormat {
        case claude
        case kimi
        case codex
    }

    init(filePath: String) {
        self.filePath = filePath
        parseNewContent()
    }

    // MARK: - Incremental parse

    func parseNewContent() {
        parseQueue.async { [weak self] in
            self?.parseNewContentSync()
        }
    }

    private func parseNewContentSync() {
        guard FileManager.default.fileExists(atPath: filePath),
              let fileHandle = FileHandle(forReadingAtPath: filePath) else { return }
        defer { fileHandle.closeFile() }

        fileHandle.seek(toFileOffset: fileOffset)
        let newData = fileHandle.readDataToEndOfFile()
        guard !newData.isEmpty else { return }

        fileOffset = fileHandle.offsetInFile

        guard let content = String(data: newData, encoding: .utf8) else { return }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            parseLine(trimmed)
        }

        publishState()
    }

    // MARK: - Line parsing

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if format == .claude {
            if json["protocol_version"] != nil {
                format = .kimi
                return
            }
            let lineType = json["type"] as? String ?? ""
            if lineType == "session_meta",
               let payload = json["payload"] as? [String: Any],
               payload["cli_version"] != nil {
                format = .codex
                return
            }
        }

        switch format {
        case .kimi:
            parseKimiLine(json)
        case .codex:
            parseCodexLine(json)
        case .claude:
            let lineType = json["type"] as? String ?? ""
            switch lineType {
            case "assistant":
                parseAssistantLine(json)
            case "user":
                parseUserLine(json)
            case "progress":
                parseProgressLine(json)
            default:
                break
            }
        }
    }

    private func parseKimiLine(_ json: [String: Any]) {
        guard let message = json["message"] as? [String: Any] else { return }
        let messageType = message["type"] as? String ?? ""
        let payload = message["payload"] as? [String: Any] ?? [:]

        switch messageType {
        case "TurnBegin", "StepBegin":
            statusValue = .thinking
            toolValue = .unknown

        case "ContentPart":
            let partType = payload["type"] as? String ?? ""
            if partType == "think" || partType == "text" {
                statusValue = .thinking
            }

            // Extract summary text for messages
            if partType == "text" || partType == "think" {
                let text = payload["text"] as? String
                    ?? payload["think"] as? String
                    ?? ""
                if !text.isEmpty {
                    appendMessage(TranscriptMessage(role: "assistant", content: String(text.prefix(200))))
                }
            }

        case "ToolCall":
            statusValue = .toolRunning
            if let function = payload["function"] as? [String: Any],
               let toolName = function["name"] as? String {
                toolValue = mapToolName(toolName)
                appendMessage(TranscriptMessage(role: "assistant", content: "[\(toolName)]", toolName: toolName))
            } else if let name = payload["name"] as? String {
                toolValue = mapToolName(name)
                appendMessage(TranscriptMessage(role: "assistant", content: "[\(name)]", toolName: name))
            }

        case "ToolCallPart":
            // Incremental tool call arguments; ignore for state
            break

        case "ToolResult":
            statusValue = .thinking
            // Keep tool value until next explicit state change

        case "TurnEnd":
            statusValue = .completed
            toolValue = .unknown

        case "StatusUpdate":
            if let contextTokens = payload["context_tokens"] as? Int,
               let maxContextTokens = payload["max_context_tokens"] as? Int,
               maxContextTokens > 0 {
                tokenUsageValue = min(1.0, Double(contextTokens) / Double(maxContextTokens))
            } else if let tokenUsage = payload["token_usage"] as? [String: Any] {
                var total = 0
                if let input = tokenUsage["input_other"] as? Int { total += input }
                if let output = tokenUsage["output"] as? Int { total += output }
                if let cacheRead = tokenUsage["input_cache_read"] as? Int { total += cacheRead }
                tokenUsageValue = min(1.0, Double(total) / maxContextTokens)
            }

        default:
            break
        }
    }

    private func parseCodexLine(_ json: [String: Any]) {
        let type = json["type"] as? String ?? ""
        let payload = json["payload"] as? [String: Any] ?? [:]

        switch type {
        case "event_msg":
            let eventType = payload["type"] as? String ?? ""
            switch eventType {
            case "task_started":
                statusValue = .thinking

            case "agent_message":
                statusValue = .thinking
                if let text = payload["message"] as? String, !text.isEmpty {
                    appendMessage(TranscriptMessage(role: "assistant", content: String(text.prefix(200))))
                }

            case "user_message":
                statusValue = .thinking
                appendMessage(TranscriptMessage(role: "user", content: "user input"))

            case "task_complete":
                statusValue = .completed
                toolValue = .unknown

            case "token_count":
                if let rateLimits = payload["rate_limits"] as? [String: Any],
                   let primary = rateLimits["primary"] as? [String: Any],
                   let usedPercent = primary["used_percent"] as? Double {
                    tokenUsageValue = min(1.0, usedPercent / 100.0)
                }

            default:
                break
            }

        case "response_item":
            let itemType = payload["type"] as? String ?? ""
            switch itemType {
            case "function_call", "custom_tool_call":
                statusValue = .toolRunning
                if let toolName = payload["name"] as? String {
                    toolValue = mapToolName(toolName)
                    appendMessage(TranscriptMessage(role: "assistant", content: "[\(toolName)]", toolName: toolName))
                }

            case "reasoning":
                statusValue = .thinking

            case "function_call_output", "custom_tool_call_output":
                statusValue = .thinking

            default:
                break
            }

        default:
            break
        }
    }

    private func parseAssistantLine(_ json: [String: Any]) {
        guard let message = json["message"] as? [String: Any] else { return }

        let contentBlocks = message["content"] as? [[String: Any]] ?? []

        var toolName: String?
        var textContent = ""
        for block in contentBlocks {
            let blockType = block["type"] as? String ?? ""
            if blockType == "tool_use" {
                toolName = block["name"] as? String
            } else if blockType == "text" {
                textContent += block["text"] as? String ?? ""
            }
        }

        if let usage = message["usage"] as? [String: Any] {
            if let input = usage["input_tokens"] as? Int {
                totalInputTokens = input
            }
            if let output = usage["output_tokens"] as? Int {
                totalOutputTokens = output
            }
            if let cacheRead = usage["cache_read_input_tokens"] as? Int {
                totalInputTokens = max(totalInputTokens, cacheRead)
            }
            let total = Double(totalInputTokens + totalOutputTokens)
            tokenUsageValue = min(1.0, total / maxContextTokens)
        }

        let summary = toolName.map { "[\($0)]" } ?? String(textContent.prefix(200))
        appendMessage(TranscriptMessage(role: "assistant", content: summary, toolName: toolName))

        if let nextStatus = TranscriptParserRules.assistantLineStatus(json) {
            statusValue = nextStatus
        }

        if let toolName {
            toolValue = mapToolName(toolName)
        } else if statusValue != .toolRunning {
            toolValue = .unknown
        }
    }

    private func parseUserLine(_ json: [String: Any]) {
        if TranscriptParserRules.userLineRepresentsInterruption(json) {
            statusValue = .completed
            toolValue = .unknown
            appendMessage(TranscriptMessage(role: "user", content: "[interrupted]"))
            return
        }

        guard let nextStatus = TranscriptParserRules.userLineStatus(json) else { return }

        guard let message = json["message"] as? [String: Any] else { return }
        let contentBlocks = message["content"] as? [[String: Any]] ?? []

        let hasToolResult = contentBlocks.contains { $0["type"] as? String == "tool_result" }
        statusValue = nextStatus
        appendMessage(TranscriptMessage(role: "user", content: hasToolResult ? "[tool_result]" : "user input"))
    }

    private func parseProgressLine(_ json: [String: Any]) {
        guard let progressData = json["data"] as? [String: Any] else { return }
        let dataType = progressData["type"] as? String ?? ""

        guard dataType == "hook_progress" else { return }
        let hookEvent = progressData["hookEvent"] as? String ?? ""
        let hookName = progressData["hookName"] as? String ?? ""

        switch hookEvent {
        case "PreToolUse":
            statusValue = .toolRunning
            if let toolPart = hookName.split(separator: ":").last {
                toolValue = mapToolName(String(toolPart))
            }
        case "PostToolUse":
            statusValue = .unknown
            toolValue = .unknown
        case "Stop":
            statusValue = .completed
        default:
            break
        }
    }

    // MARK: - Helpers

    private func publishState() {
        let messages = bufferedMessages
        let status = statusValue
        let tool = toolValue
        let usage = tokenUsageValue

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            lastMessages = messages
            currentStatus = status
            currentTool = tool
            tokenUsage = usage
        }
    }

    private func appendMessage(_ message: TranscriptMessage) {
        bufferedMessages.append(message)
        if bufferedMessages.count > 5 {
            bufferedMessages.removeFirst(bufferedMessages.count - 5)
        }
    }

    private func mapToolName(_ name: String) -> ToolType {
        let lowered = name.lowercased()
        if lowered.contains("edit") { return .edit }
        if lowered.contains("read") { return .read }
        if lowered.contains("write") { return .write }
        if lowered.contains("grep") { return .grep }
        if lowered.contains("glob") { return .glob }
        if lowered.contains("bash") || lowered.contains("terminal") { return .bash }
        if lowered == "exec_command" || lowered == "write_stdin" { return .bash }
        if lowered == "apply_patch" { return .edit }
        return .unknown
    }
}

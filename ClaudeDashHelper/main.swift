// main.swift
// ClaudeDashHelper - 独立命令行工具
// 由 Claude Code Stop Hook 调用，从 stdin 读取 JSON 数据
// 判断时长阈值 → 发送系统通知 → 写入 session 数据

import Foundation
import UserNotifications

// MARK: - 常量

/// App Support 目录
let appSupportDir: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return base.appendingPathComponent("ClaudeDash")
}()

/// sessions.json 路径
let sessionsFilePath = appSupportDir.appendingPathComponent("sessions.json")

func loadSharedDefaults() -> UserDefaults {
    UserDefaults(suiteName: "com.claudedash.shared") ?? .standard
}

let monitoringMode = loadSharedDefaults().string(forKey: "ClaudeDash_monitoringMode") ?? "passive"
if monitoringMode != "enhanced" {
    exit(0)
}

// MARK: - 1. 从 stdin 读取 JSON

let inputData = FileHandle.standardInput.readDataToEndOfFile()

guard !inputData.isEmpty else {
    fputs("[ClaudeDashHelper] 错误：stdin 无数据\n", stderr)
    exit(1)
}

guard let hookInput = try? JSONDecoder().decode(StopHookInput.self, from: inputData) else {
    fputs("[ClaudeDashHelper] 错误：无法解析 stdin JSON\n", stderr)
    exit(1)
}

// MARK: - 2. 提取字段

let cwd = hookInput.cwd ?? FileManager.default.currentDirectoryPath
let project = URL(fileURLWithPath: cwd).lastPathComponent
let durationMs = hookInput.total_duration_ms ?? 0
let cost = hookInput.cost ?? 0
let summary = hookInput.last_assistant_message ?? ""
let transcriptPath = hookInput.transcript_path ?? ""

// MARK: - 3. 时长阈值过滤

/// 从 UserDefaults 读取最小触发时长（秒），默认 15 秒
let minDurationSeconds: Double = {
    // 尝试从共享 UserDefaults 读取
    let value = loadSharedDefaults().double(forKey: "ClaudeDash_minDuration")
    return value > 0 ? value : 15.0
}()

let longTaskOnly: Bool = loadSharedDefaults().bool(forKey: "ClaudeDash_longTaskOnly")

if longTaskOnly && Double(durationMs) / 1000.0 < minDurationSeconds {
    // 低于阈值，静默退出
    exit(0)
}

// MARK: - 4. 发送系统通知

func sendNotification() {
    let center = UNUserNotificationCenter.current()
    let semaphore = DispatchSemaphore(value: 0)

    // 读取模板和声音设置
    let defaults = loadSharedDefaults()
    let template = defaults.string(forKey: "ClaudeDash_notificationTemplate")
        ?? "{project} 已完成 - 耗时 {duration}，费用 {cost}"
    let soundName = defaults.string(forKey: "ClaudeDash_notificationSound") ?? "Glass"
    let enableSummary = defaults.bool(forKey: "ClaudeDash_enableSummary")

    // 展开模板变量
    var body = template
    body = body.replacingOccurrences(of: "{project}", with: project)
    body = body.replacingOccurrences(of: "{duration}", with: durationMs.humanReadableDuration)
    body = body.replacingOccurrences(of: "{cost}", with: cost.usdFormatted)
    body = body.replacingOccurrences(of: "{summary}", with: String(summary.prefix(100)))

    // 构建通知
    let content = UNMutableNotificationContent()
    content.title = ClaudeDashCopy.notificationTitle
    content.body = body
    content.userInfo = ["cwd": cwd]

    // 设置声音
    if soundName != "None" {
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
    }

    // 智能总结
    if enableSummary && !summary.isEmpty {
        content.subtitle = String(summary.prefix(100))
    }

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )

    center.add(request) { error in
        if let error = error {
            fputs("[ClaudeDashHelper] 通知发送失败: \(error)\n", stderr)
        }
        semaphore.signal()
    }

    // 等待通知发送完成（最多 5 秒）
    _ = semaphore.wait(timeout: .now() + 5)
}

// MARK: - 5. 写入 session 数据到 sessions.json

func writeSessionData() {
    // 确保目录存在
    try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

    let source: SessionSource = transcriptPath.contains(".kimi/sessions") ? .kimi : .claude
    let record = SessionRecord(
        project: project,
        cwd: cwd,
        durationMs: durationMs,
        cost: cost,
        summary: String(summary.prefix(500)),
        transcriptPath: transcriptPath,
        source: source
    )

    // 使用文件锁避免并发写入冲突
    let lockPath = appSupportDir.appendingPathComponent("sessions.lock").path
    let lockFd = open(lockPath, O_CREAT | O_WRONLY, 0o644)
    defer {
        if lockFd >= 0 {
            flock(lockFd, LOCK_UN)
            close(lockFd)
        }
    }

    if lockFd >= 0 {
        flock(lockFd, LOCK_EX)
    }

    // 读取已有数据
    var sessions: [SessionRecord] = []
    if let data = try? Data(contentsOf: sessionsFilePath) {
        sessions = (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
    }

    // 追加新记录
    sessions.append(record)

    // 写回文件
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted

    if let data = try? encoder.encode(sessions) {
        try? data.write(to: sessionsFilePath, options: .atomic)
    }
}

// MARK: - 执行

sendNotification()
writeSessionData()

exit(0)

// MARK: - 共享模型（Helper 需要的子集）

/// Session 来源
enum SessionSource: String, Codable {
    case claude
    case kimi
}

/// Session 记录（与主 App 共享结构）
struct SessionRecord: Codable {
    let id: UUID
    let project: String
    let cwd: String
    let durationMs: Int
    let cost: Double
    let summary: String
    let transcriptPath: String
    let completedAt: Date
    let source: SessionSource

    init(project: String, cwd: String, durationMs: Int, cost: Double, summary: String, transcriptPath: String, source: SessionSource = .claude) {
        self.id = UUID()
        self.project = project
        self.cwd = cwd
        self.durationMs = durationMs
        self.cost = cost
        self.summary = summary
        self.transcriptPath = transcriptPath
        self.completedAt = Date()
        self.source = source
    }
}

/// Stop Hook JSON 输入
struct StopHookInput: Codable {
    let last_assistant_message: String?
    let cwd: String?
    let total_duration_ms: Int?
    let cost: Double?
    let transcript_path: String?
}

/// 辅助扩展
extension Int {
    var humanReadableDuration: String {
        let totalSeconds = self / 1000
        if totalSeconds < 60 { return "\(totalSeconds)s" }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes < 60 { return "\(minutes)m \(seconds)s" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

extension Double {
    var usdFormatted: String { String(format: "$%.4f", self) }
}

// Models.swift
// ClaudeDash - 共享数据模型定义
// 所有 target 共用的数据结构

import CoreGraphics
import Foundation
import SwiftUI

enum ClaudeDashDefaults {
    static let suiteName = "com.claudedash.shared"
    nonisolated(unsafe) static let shared = UserDefaults(suiteName: suiteName) ?? .standard

    private static let migratableKeys = [
        MonitoringMode.userDefaultsKey,
        "ClaudeDash_minDuration",
        "ClaudeDash_notificationTemplate",
        "ClaudeDash_notificationSound",
        "ClaudeDash_enableSummary",
        "ClaudeDash_longTaskOnly",
        "ClaudeDash_dailyCostBudget",
        FloatingMascotAppearanceOption.userDefaultsKey,
        FloatingMascotSizeOption.userDefaultsKey,
        FloatingMascotAnimationSpeedOption.userDefaultsKey,
        FloatingMascotPreferences.enabledUserDefaultsKey,
        FloatingMascotPreferences.didCompleteSetupUserDefaultsKey
    ]

    static func migrateFromStandardIfNeeded() {
        let standard = UserDefaults.standard
        for key in migratableKeys where shared.object(forKey: key) == nil {
            guard let value = standard.object(forKey: key) else { continue }
            shared.set(value, forKey: key)
        }
    }
}

enum FloatingMascotPreferences {
    static let enabledUserDefaultsKey = "ClaudeDash_floatingMascotEnabled"
    static let didCompleteSetupUserDefaultsKey = "ClaudeDash_floatingMascotDidCompleteSetup"

    static func isEnabled(defaults: UserDefaults = ClaudeDashDefaults.shared) -> Bool {
        defaults.bool(forKey: enabledUserDefaultsKey)
    }

    static func didCompleteSetup(defaults: UserDefaults = ClaudeDashDefaults.shared) -> Bool {
        defaults.bool(forKey: didCompleteSetupUserDefaultsKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = ClaudeDashDefaults.shared) {
        defaults.set(enabled, forKey: enabledUserDefaultsKey)
        defaults.set(true, forKey: didCompleteSetupUserDefaultsKey)
    }

    static func markSetupCompleted(defaults: UserDefaults = ClaudeDashDefaults.shared) {
        defaults.set(true, forKey: didCompleteSetupUserDefaultsKey)
    }
}

/// Session 数据来源（历史扫描用）
enum SessionSource: String, Codable, Sendable {
    case claude
    case kimi
    case codex

    /// 来源品牌色
    var brandColor: Color {
        switch self {
        case .claude: return .claudePurple
        case .kimi: return .kimiCyan
        case .codex: return .codexGreen
        }
    }

    /// 来源图标（SF Symbol）
    var iconName: String {
        switch self {
        case .claude: return "bubble.left.fill"
        case .kimi: return "sparkles"
        case .codex: return "cpu"
        }
    }

    /// 来源显示名
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .kimi: return "Kimi"
        case .codex: return "Codex"
        }
    }
}

/// 统计数据面板筛选器
enum StatsDataSource: String, CaseIterable, Identifiable, Sendable {
    case all
    case claude
    case kimi
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .claude: return "Claude"
        case .kimi: return "Kimi"
        case .codex: return "Codex"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .claude: return "bubble.left.fill"
        case .kimi: return "sparkles"
        case .codex: return "cpu"
        }
    }

    var color: Color {
        switch self {
        case .all: return .secondary
        case .claude: return .claudePurple
        case .kimi: return .kimiCyan
        case .codex: return .codexGreen
        }
    }
}

enum FloatingMascotAppearanceOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case runner
    case catDrink
    case catHide
    case catBall
    case catGuitar
    case catSax
    case catSurprise
    case catBalloons

    static let userDefaultsKey = "ClaudeDash_floatingMascotAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runner: return "跑步"
        case .catDrink: return "喝水"
        case .catHide: return "躲藏"
        case .catBall: return "篮球"
        case .catGuitar: return "吉他"
        case .catSax: return "萨克斯"
        case .catSurprise: return "惊讶"
        case .catBalloons: return "气球"
        }
    }

    var resourceName: String {
        switch self {
        case .runner: return "sweet-run-cycle"
        case .catDrink: return "cat-drink"
        case .catHide: return "cat-hide"
        case .catBall: return "cat-ball"
        case .catGuitar: return "cat-guitar"
        case .catSax: return "cat-sax"
        case .catSurprise: return "cat-surprise"
        case .catBalloons: return "cat-balloons"
        }
    }
}

// MARK: - Session 记录（Helper 写入，主 App 读取）

/// 单次 Claude Code 任务完成的记录
struct SessionRecord: Codable, Identifiable, Sendable {
    let id: UUID
    /// 项目名称（从 cwd 提取）
    let project: String
    /// 工作目录完整路径
    let cwd: String
    /// 总耗时（毫秒）
    let durationMs: Int
    /// 费用（USD）
    let cost: Double
    /// 最后 assistant 消息摘要
    let summary: String
    /// transcript 文件路径
    let transcriptPath: String
    /// 完成时间戳
    let completedAt: Date
    /// 数据来源
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

    enum CodingKeys: String, CodingKey {
        case id, project, cwd, durationMs, cost, summary, transcriptPath, completedAt, source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        project = try container.decode(String.self, forKey: .project)
        cwd = try container.decode(String.self, forKey: .cwd)
        durationMs = try container.decode(Int.self, forKey: .durationMs)
        cost = try container.decode(Double.self, forKey: .cost)
        summary = try container.decode(String.self, forKey: .summary)
        transcriptPath = try container.decode(String.self, forKey: .transcriptPath)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        source = try container.decodeIfPresent(SessionSource.self, forKey: .source) ?? .claude
    }
}

// MARK: - 每日统计汇总

/// 单日统计数据
struct DailySummary: Codable, Identifiable, Sendable {
    var id: String { dateString }
    /// 日期字符串 yyyy-MM-dd
    let dateString: String
    /// 当日完成次数
    var completionCount: Int
    /// 当日总成本 USD
    var totalCost: Double
    /// 当日总耗时（秒）
    var totalDurationSeconds: Double
    /// 当日 input tokens 总量
    var totalInputTokens: Int
    /// 当日 output tokens 总量
    var totalOutputTokens: Int
    /// 每小时完成次数分布（0-23）
    var hourlyDistribution: [Int]
    /// Cache read tokens（命中缓存，更便宜）
    var totalCacheReadTokens: Int
    /// Cache creation tokens（首次缓存创建）
    var totalCacheCreationTokens: Int
    /// 当日工具调用总次数
    var totalToolUseCount: Int
    /// 当日消息总数（user + assistant）
    var totalMessageCount: Int
    /// 工具调用分布 (tool name → count)
    var toolDistribution: [String: Int]

    /// 总 token 数
    var totalTokens: Int { totalInputTokens + totalOutputTokens }

    init(dateString: String) {
        self.dateString = dateString
        self.completionCount = 0
        self.totalCost = 0
        self.totalDurationSeconds = 0
        self.totalInputTokens = 0
        self.totalOutputTokens = 0
        self.hourlyDistribution = Array(repeating: 0, count: 24)
        self.totalCacheReadTokens = 0
        self.totalCacheCreationTokens = 0
        self.totalToolUseCount = 0
        self.totalMessageCount = 0
        self.toolDistribution = [:]
    }
}

extension DailySummary {
    var shortDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }

        let display = DateFormatter()
        display.dateFormat = "M/d"
        return display.string(from: date)
    }
}

// MARK: - Stop Hook JSON（Claude Code 传入的数据结构）

/// Claude Code Stop Hook 通过 stdin 传入的 JSON 结构
struct StopHookInput: Codable {
    /// 最后 assistant 消息内容
    let last_assistant_message: String?
    /// 工作目录
    let cwd: String?
    /// 总耗时毫秒
    let total_duration_ms: Int?
    /// 费用 USD
    let cost: Double?
    /// transcript 文件路径
    let transcript_path: String?
}

// MARK: - App 设置

enum MonitoringMode: String, Codable, CaseIterable, Sendable {
    case passive
    case enhanced

    static let userDefaultsKey = "ClaudeDash_monitoringMode"

    var title: String {
        switch self {
        case .passive: return "零侵入"
        case .enhanced: return "增强模式"
        }
    }

    var description: String {
        switch self {
        case .passive:
            return "只监听 transcript 文件，不修改 Claude 配置"
        case .enhanced:
            return "额外启用 Hook，提供更精确的完成事件与通知"
        }
    }
}

enum HookIntegrationStatus: Equatable, Sendable {
    case inactive
    case installed
    case missing
    case helperUnavailable

    var description: String {
        switch self {
        case .inactive:
            return "增强模式未启用"
        case .installed:
            return "Hook 已安装并生效"
        case .missing:
            return "Hook 配置缺失"
        case .helperUnavailable:
            return "Helper 不可执行"
        }
    }

    var canAutoRepair: Bool {
        self == .missing
    }
}

enum FloatingMascotSizeOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case compact
    case small
    case medium
    case large
    case extraLarge
    case jumbo

    static let userDefaultsKey = "ClaudeDash_floatingMascotSize"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return "更小"
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        case .extraLarge: return "更大"
        case .jumbo: return "超大"
        }
    }

    var description: String {
        switch self {
        case .compact:
            return "最紧凑，尽量减少存在感。"
        case .small:
            return "更轻巧，但已经足够清晰。"
        case .medium:
            return "默认推荐，观感更平衡。"
        case .large:
            return "存在感最强，陪伴感更明显。"
        case .extraLarge:
            return "更醒目，动画细节更容易看清。"
        case .jumbo:
            return "上限更高，适合想要明显存在感。"
        }
    }

    var mascotLength: CGFloat {
        switch self {
        case .compact: return 78
        case .small: return 88
        case .medium: return 100
        case .large: return 114
        case .extraLarge: return 128
        case .jumbo: return 220
        }
    }
}

enum FloatingMascotAnimationSpeedOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case slow
    case normal
    case fast
    case veryFast

    static let userDefaultsKey = "ClaudeDash_floatingMascotAnimationSpeed"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow: return "慢"
        case .normal: return "标准"
        case .fast: return "快"
        case .veryFast: return "很快"
        }
    }

    var description: String {
        switch self {
        case .slow: return "更安静、更从容。"
        case .normal: return "默认推荐。"
        case .fast: return "更有活力。"
        case .veryFast: return "动作更明显。"
        }
    }

    var multiplier: Double {
        switch self {
        case .slow: return 0.85
        case .normal: return 1.0
        case .fast: return 1.18
        case .veryFast: return 1.35
        }
    }
}

/// 通知声音选项
enum NotificationSound: String, Codable, CaseIterable {
    case glass = "Glass"
    case ping = "Ping"
    case blow = "Blow"
    case submarine = "Submarine"
    case none = "None"

    /// 系统声音文件名
    var soundFileName: String? {
        switch self {
        case .none: return nil
        default: return rawValue
        }
    }
}

// MARK: - Transcript 解析相关

/// Session 当前状态
enum SessionStatus: String, Codable, Sendable {
    case thinking = "思考中"
    case toolRunning = "工具执行中"
    case completed = "已完成"
    case unknown = "未知"
}

/// 工具类型及对应 SF Symbol
enum ToolType: String, Sendable {
    case edit = "Edit"
    case read = "Read"
    case write = "Write"
    case grep = "Grep"
    case glob = "Glob"
    case bash = "Bash"
    case unknown = "Unknown"

    /// 对应的 SF Symbol 名称
    var sfSymbol: String {
        switch self {
        case .edit: return "pencil"
        case .read: return "doc.text"
        case .write: return "doc.badge.plus"
        case .grep: return "magnifyingglass"
        case .glob: return "folder.badge.magnifyingglass"
        case .bash: return "terminal"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Transcript 中的单条消息
struct TranscriptMessage: Identifiable, Sendable {
    let id = UUID()
    let role: String
    let content: String
    let toolName: String?
    let timestamp: Date

    init(role: String, content: String, toolName: String? = nil) {
        self.role = role
        self.content = content
        self.toolName = toolName
        self.timestamp = Date()
    }
}

/// 活跃 Session 信息（用于监控 Tab 显示）
struct ActiveSession: Identifiable {
    let id: String
    let project: String
    let transcriptPath: String
    var status: SessionStatus
    var lastMessages: [TranscriptMessage]
    var currentTool: ToolType
    var tokenUsage: Double  // 0.0 - 1.0 比例
    var startTime: Date
    var source: SessionSource

    init(project: String, transcriptPath: String, source: SessionSource = .claude) {
        self.id = transcriptPath
        self.project = project
        self.transcriptPath = transcriptPath
        self.status = .unknown
        self.lastMessages = []
        self.currentTool = .unknown
        self.tokenUsage = 0.0
        self.startTime = Date()
        self.source = source
    }
}

// MARK: - 项目统计汇总

/// 按项目聚合的统计数据
struct ProjectStat: Identifiable, Sendable {
    let id: String
    let project: String
    var sessionCount: Int
    var totalCost: Double
    var totalDurationSeconds: Double
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var totalToolUseCount: Int
    var totalMessageCount: Int
    var totalCacheReadTokens: Int
    var totalCacheCreationTokens: Int

    var averageCost: Double { sessionCount > 0 ? totalCost / Double(sessionCount) : 0 }
    var averageDuration: Double { sessionCount > 0 ? totalDurationSeconds / Double(sessionCount) : 0 }
    var averageToolUses: Double { sessionCount > 0 ? Double(totalToolUseCount) / Double(sessionCount) : 0 }
    /// token 数格式化（如 "1.2M"）
    var tokensFormatted: String { totalInputTokens.tokenFormatted }
}

// MARK: - 周统计汇总

struct WeekSummary: Sendable {
    let sessions: Int
    let cost: Double
    let tokens: Int
    let duration: Double
    let activeDays: Int
    let toolUses: Int
    let messages: Int
}

// MARK: - 时长分布桶

struct DurationBucket: Identifiable, Sendable {
    var id: String { label }
    let label: String
    let range: String
    let count: Int
}

// MARK: - 辅助扩展

extension Int {
    /// 毫秒转人类可读耗时字符串
    var humanReadableDuration: String {
        let totalSeconds = self / 1000
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes < 60 {
            return "\(minutes)m \(seconds)s"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

extension Int {
    /// Token 数格式化（如 "1.2M", "456K"）
    var tokenFormatted: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.0fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

extension Double {
    /// USD 格式化
    var usdFormatted: String {
        if self >= 1.0 {
            return String(format: "$%.2f", self)
        }
        return String(format: "$%.4f", self)
    }

    /// 秒数转人类可读耗时
    var durationFormatted: String {
        Int(self * 1000).humanReadableDuration
    }
}

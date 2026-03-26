// StatsManager.swift
// ClaudeDash - 数据统计与持久化管理器
// 启动时扫描 ~/.claude/projects/ JSONL 历史数据
// 运行时通过 Hook 和文件监听增量更新

import Foundation
import Combine

private struct StatsScanSnapshot: Sendable {
    let sessions: [ScannedSession]
    let dailyMap: [String: DailySummary]
    let derived: StatsDerivedCache
}

private struct StatsDerivedCache: Sendable {
    let heatmapDailyCounts: [String: Int]
    let projectStats: [ProjectStat]
    let maxProjectSessionCount: Int
    let totalCacheSavings: Double
    let allTimeToolDistribution: [String: Int]
    let toolDistributionSorted: [(tool: String, count: Int)]
    let totalToolUseCountAllTime: Int
    let modelDistribution: [(model: String, count: Int)]
    let averageMessagesPerSession: Double
    let averageToolUsesPerSession: Double
    let thisWeekSummary: WeekSummary
    let lastWeekSummary: WeekSummary
    let durationBuckets: [DurationBucket]
    let weeklyHourlyHeatmap: [[Int]]
    let todaySessions: [ScannedSession]
    let thisWeekSessions: [ScannedSession]
    let weeklyInsights: [StatsManager.Insight]
    let totalScannedSessionCount: Int
}

private enum StatsComputation {
    private static let durationBucketDefinitions: [(label: String, range: String, min: Double, max: Double)] = [
        ("<1m", "0-60s", 0, 60),
        ("1-5m", "1-5 min", 60, 300),
        ("5-15m", "5-15 min", 300, 900),
        ("15-30m", "15-30 min", 900, 1800),
        ("30m-1h", "30-60 min", 1800, 3600),
        ("1h+", ">1 hour", 3600, .infinity),
    ]

    static let emptyWeekSummary = WeekSummary(
        sessions: 0,
        cost: 0,
        tokens: 0,
        duration: 0,
        activeDays: 0,
        toolUses: 0,
        messages: 0
    )

    static func scanSnapshot(
        from sessions: [ScannedSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StatsScanSnapshot {
        let dailyMap = buildDailyMap(from: sessions, calendar: calendar)
        let derived = buildDerivedCache(from: sessions, now: now, calendar: calendar)
        return StatsScanSnapshot(sessions: sessions, dailyMap: dailyMap, derived: derived)
    }

    static func buildDailyMap(
        from sessions: [ScannedSession],
        calendar: Calendar = .current
    ) -> [String: DailySummary] {
        var dailyMap: [String: DailySummary] = [:]

        for session in sessions {
            let dateStr = dayString(for: session.startTime)
            var summary = dailyMap[dateStr] ?? DailySummary(dateString: dateStr)
            summary.completionCount += 1
            summary.totalCost += session.estimatedCost
            summary.totalDurationSeconds += session.durationSeconds
            summary.totalInputTokens += session.inputTokens + session.cacheReadTokens + session.cacheCreationTokens
            summary.totalOutputTokens += session.outputTokens
            summary.totalCacheReadTokens += session.cacheReadTokens
            summary.totalCacheCreationTokens += session.cacheCreationTokens
            summary.totalToolUseCount += session.toolUseCount
            summary.totalMessageCount += session.messageCount

            for (tool, count) in session.toolDistribution {
                summary.toolDistribution[tool, default: 0] += count
            }

            let hour = calendar.component(.hour, from: session.startTime)
            if hour >= 0 && hour < 24 {
                summary.hourlyDistribution[hour] += 1
            }

            dailyMap[dateStr] = summary
        }

        return dailyMap
    }

    static func buildDerivedCache(
        from sessions: [ScannedSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StatsDerivedCache {
        var heatmapDailyCounts: [String: Int] = [:]
        var projectMap: [String: ProjectStat] = [:]
        var allTimeToolDistribution: [String: Int] = [:]
        var modelDistributionMap: [String: Int] = [:]
        var totalCacheReadTokens = 0
        var totalToolUseCount = 0
        var totalMessages = 0
        var messageSessions = 0
        var totalToolUsesForAverage = 0
        var toolSessions = 0
        var durationBucketCounts = Array(repeating: 0, count: durationBucketDefinitions.count)
        var weeklyHourlyHeatmap = Array(repeating: Array(repeating: 0, count: 24), count: 7)

        let todayString = dayString(for: now)
        let thisWeekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let lastWeekStart = thisWeekInterval.flatMap { calendar.date(byAdding: .weekOfYear, value: -1, to: $0.start) }
        let lastWeekInterval = lastWeekStart.map { start in
            DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start) ?? start)
        }

        var todaySessions: [ScannedSession] = []
        var thisWeekSessions: [ScannedSession] = []
        var lastWeekSessions: [ScannedSession] = []

        for session in sessions {
            let dateStr = dayString(for: session.startTime)
            heatmapDailyCounts[dateStr, default: 0] += 1

            if var stat = projectMap[session.projectName] {
                stat.sessionCount += 1
                stat.totalCost += session.estimatedCost
                stat.totalDurationSeconds += session.durationSeconds
                stat.totalInputTokens += session.totalTokens
                stat.totalOutputTokens += session.outputTokens
                stat.totalToolUseCount += session.toolUseCount
                stat.totalMessageCount += session.messageCount
                stat.totalCacheReadTokens += session.cacheReadTokens
                stat.totalCacheCreationTokens += session.cacheCreationTokens
                projectMap[session.projectName] = stat
            } else {
                projectMap[session.projectName] = ProjectStat(
                    id: session.projectName,
                    project: session.projectName,
                    sessionCount: 1,
                    totalCost: session.estimatedCost,
                    totalDurationSeconds: session.durationSeconds,
                    totalInputTokens: session.totalTokens,
                    totalOutputTokens: session.outputTokens,
                    totalToolUseCount: session.toolUseCount,
                    totalMessageCount: session.messageCount,
                    totalCacheReadTokens: session.cacheReadTokens,
                    totalCacheCreationTokens: session.cacheCreationTokens
                )
            }

            totalCacheReadTokens += session.cacheReadTokens
            totalToolUseCount += session.toolUseCount

            for (tool, count) in session.toolDistribution {
                allTimeToolDistribution[tool, default: 0] += count
            }

            if !session.model.isEmpty {
                modelDistributionMap[simplifiedModelName(session.model), default: 0] += 1
            }

            if session.messageCount > 0 {
                totalMessages += session.messageCount
                messageSessions += 1
            }

            if session.toolUseCount > 0 {
                totalToolUsesForAverage += session.toolUseCount
                toolSessions += 1
            }

            for (index, definition) in durationBucketDefinitions.enumerated() {
                if session.durationSeconds >= definition.min && session.durationSeconds < definition.max {
                    durationBucketCounts[index] += 1
                    break
                }
            }

            let weekday = calendar.component(.weekday, from: session.startTime)
            let hour = calendar.component(.hour, from: session.startTime)
            let row = (weekday + 5) % 7
            weeklyHourlyHeatmap[row][hour] += 1

            if dateStr == todayString {
                todaySessions.append(session)
            }

            if let thisWeekInterval,
               session.startTime >= thisWeekInterval.start,
               session.startTime < thisWeekInterval.end {
                thisWeekSessions.append(session)
            } else if let lastWeekInterval,
                      session.startTime >= lastWeekInterval.start,
                      session.startTime < lastWeekInterval.end {
                lastWeekSessions.append(session)
            }
        }

        todaySessions.sort { $0.startTime < $1.startTime }
        thisWeekSessions.sort { $0.startTime < $1.startTime }
        lastWeekSessions.sort { $0.startTime < $1.startTime }

        let projectStats = Array(projectMap.values).sorted { $0.sessionCount > $1.sessionCount }
        let thisWeekSummary = summary(from: thisWeekSessions, calendar: calendar)
        let lastWeekSummary = summary(from: lastWeekSessions, calendar: calendar)

        return StatsDerivedCache(
            heatmapDailyCounts: heatmapDailyCounts,
            projectStats: projectStats,
            maxProjectSessionCount: projectStats.first?.sessionCount ?? 1,
            totalCacheSavings: Double(totalCacheReadTokens) / 1_000_000 * 13.5,
            allTimeToolDistribution: allTimeToolDistribution,
            toolDistributionSorted: allTimeToolDistribution
                .map { (tool: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count },
            totalToolUseCountAllTime: totalToolUseCount,
            modelDistribution: modelDistributionMap
                .map { (model: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count },
            averageMessagesPerSession: messageSessions > 0
                ? Double(totalMessages) / Double(messageSessions)
                : 0,
            averageToolUsesPerSession: toolSessions > 0
                ? Double(totalToolUsesForAverage) / Double(toolSessions)
                : 0,
            thisWeekSummary: thisWeekSummary,
            lastWeekSummary: lastWeekSummary,
            durationBuckets: durationBucketDefinitions.enumerated().map { index, definition in
                DurationBucket(label: definition.label, range: definition.range, count: durationBucketCounts[index])
            },
            weeklyHourlyHeatmap: weeklyHourlyHeatmap,
            todaySessions: todaySessions,
            thisWeekSessions: thisWeekSessions,
            weeklyInsights: weeklyInsights(
                weekSessions: thisWeekSessions,
                thisWeek: thisWeekSummary,
                lastWeek: lastWeekSummary,
                calendar: calendar
            ),
            totalScannedSessionCount: sessions.count
        )
    }

    static func summary(
        from sessions: [ScannedSession],
        calendar: Calendar
    ) -> WeekSummary {
        guard !sessions.isEmpty else { return emptyWeekSummary }

        return WeekSummary(
            sessions: sessions.count,
            cost: sessions.reduce(0) { $0 + $1.estimatedCost },
            tokens: sessions.reduce(0) { $0 + $1.totalTokens },
            duration: sessions.reduce(0) { $0 + $1.durationSeconds },
            activeDays: Set(sessions.map { calendar.component(.weekday, from: $0.startTime) }).count,
            toolUses: sessions.reduce(0) { $0 + $1.toolUseCount },
            messages: sessions.reduce(0) { $0 + $1.messageCount }
        )
    }

    private static func weeklyInsights(
        weekSessions: [ScannedSession],
        thisWeek: WeekSummary,
        lastWeek: WeekSummary,
        calendar: Calendar
    ) -> [StatsManager.Insight] {
        var insights: [StatsManager.Insight] = []

        if let longest = weekSessions.max(by: { $0.durationSeconds < $1.durationSeconds }) {
            insights.append(StatsManager.Insight(
                icon: "timer",
                title: "Longest Session",
                detail: "\(longest.durationSeconds.durationFormatted) - \(longest.projectName)",
                colorName: "blue"
            ))
        }

        if let expensive = weekSessions.max(by: { $0.estimatedCost < $1.estimatedCost }) {
            insights.append(StatsManager.Insight(
                icon: "dollarsign.circle",
                title: "Most Expensive",
                detail: "\(expensive.estimatedCost.usdFormatted) - \(expensive.projectName)",
                colorName: "orange"
            ))
        }

        var projectCounts: [String: Int] = [:]
        for session in weekSessions {
            projectCounts[session.projectName, default: 0] += 1
        }
        if let top = projectCounts.max(by: { $0.value < $1.value }) {
            insights.append(StatsManager.Insight(
                icon: "folder.fill",
                title: "Most Active Project",
                detail: "\(top.key) - \(top.value) sessions",
                colorName: "purple"
            ))
        }

        var hourCounts: [Int: Int] = [:]
        for session in weekSessions {
            hourCounts[calendar.component(.hour, from: session.startTime), default: 0] += 1
        }
        if let peakHour = hourCounts.max(by: { $0.value < $1.value }) {
            insights.append(StatsManager.Insight(
                icon: "clock.fill",
                title: "Peak Hour",
                detail: "\(peakHour.key):00 - \(peakHour.value) sessions",
                colorName: "cyan"
            ))
        }

        if lastWeek.sessions > 0 {
            let change = weekChangePercent(thisWeek.sessions, lastWeek.sessions)
            let direction = change >= 0 ? "up" : "down"
            insights.append(StatsManager.Insight(
                icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                title: "Week over Week",
                detail: "\(abs(Int(change)))% \(direction) (\(thisWeek.sessions) vs \(lastWeek.sessions) sessions)",
                colorName: change >= 0 ? "green" : "red"
            ))
        }

        if !weekSessions.isEmpty {
            let avgDuration = weekSessions.reduce(0.0) { $0 + $1.durationSeconds } / Double(weekSessions.count)
            insights.append(StatsManager.Insight(
                icon: "gauge.medium",
                title: "Avg Session Length",
                detail: avgDuration.durationFormatted,
                colorName: "indigo"
            ))
        }

        let toolTotal = weekSessions.reduce(0) { $0 + $1.toolUseCount }
        if toolTotal > 0 {
            insights.append(StatsManager.Insight(
                icon: "wrench.and.screwdriver",
                title: "Tool Invocations",
                detail: "\(toolTotal) this week",
                colorName: "teal"
            ))
        }

        let cacheRead = weekSessions.reduce(0) { $0 + $1.cacheReadTokens }
        let pureInput = weekSessions.reduce(0) { $0 + $1.inputTokens }
        if cacheRead > 0, pureInput > 0 {
            let hitRate = Double(cacheRead) / Double(cacheRead + pureInput) * 100
            insights.append(StatsManager.Insight(
                icon: "memorychip",
                title: "Cache Hit Rate",
                detail: String(format: "%.0f%% - saved %@", hitRate, (Double(cacheRead) / 1_000_000 * 13.5).usdFormatted),
                colorName: "mint"
            ))
        }

        return insights
    }

    static func rangeInsights(
        sessions: [ScannedSession],
        currentSummary: WeekSummary,
        previousSummary: WeekSummary,
        calendar: Calendar
    ) -> [StatsManager.Insight] {
        var insights: [StatsManager.Insight] = []

        if let longest = sessions.max(by: { $0.durationSeconds < $1.durationSeconds }) {
            insights.append(StatsManager.Insight(
                icon: "timer",
                title: "Longest Session",
                detail: "\(longest.durationSeconds.durationFormatted) - \(longest.projectName)",
                colorName: "blue"
            ))
        }

        if let expensive = sessions.max(by: { $0.estimatedCost < $1.estimatedCost }) {
            insights.append(StatsManager.Insight(
                icon: "dollarsign.circle",
                title: "Most Expensive",
                detail: "\(expensive.estimatedCost.usdFormatted) - \(expensive.projectName)",
                colorName: "orange"
            ))
        }

        var projectCounts: [String: Int] = [:]
        for session in sessions {
            projectCounts[session.projectName, default: 0] += 1
        }
        if let top = projectCounts.max(by: { $0.value < $1.value }) {
            insights.append(StatsManager.Insight(
                icon: "folder.fill",
                title: "Top Project",
                detail: "\(top.key) - \(top.value) sessions",
                colorName: "purple"
            ))
        }

        var hourCounts: [Int: Int] = [:]
        for session in sessions {
            hourCounts[calendar.component(.hour, from: session.startTime), default: 0] += 1
        }
        if let peakHour = hourCounts.max(by: { $0.value < $1.value }) {
            insights.append(StatsManager.Insight(
                icon: "clock.fill",
                title: "Peak Hour",
                detail: "\(peakHour.key):00 - \(peakHour.value) sessions",
                colorName: "cyan"
            ))
        }

        if previousSummary.sessions > 0 {
            let change = weekChangePercent(currentSummary.sessions, previousSummary.sessions)
            let direction = change >= 0 ? "up" : "down"
            insights.append(StatsManager.Insight(
                icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                title: "Change vs Previous",
                detail: "\(abs(Int(change)))% \(direction) (\(currentSummary.sessions) vs \(previousSummary.sessions) sessions)",
                colorName: change >= 0 ? "green" : "red"
            ))
        }

        if !sessions.isEmpty {
            let avgDuration = sessions.reduce(0.0) { $0 + $1.durationSeconds } / Double(sessions.count)
            insights.append(StatsManager.Insight(
                icon: "gauge.medium",
                title: "Avg Session Length",
                detail: avgDuration.durationFormatted,
                colorName: "indigo"
            ))
        }

        let toolTotal = sessions.reduce(0) { $0 + $1.toolUseCount }
        if toolTotal > 0 {
            insights.append(StatsManager.Insight(
                icon: "wrench.and.screwdriver",
                title: "Tool Invocations",
                detail: "\(toolTotal) in range",
                colorName: "teal"
            ))
        }

        let cacheRead = sessions.reduce(0) { $0 + $1.cacheReadTokens }
        let pureInput = sessions.reduce(0) { $0 + $1.inputTokens }
        if cacheRead > 0, pureInput > 0 {
            let hitRate = Double(cacheRead) / Double(cacheRead + pureInput) * 100
            insights.append(StatsManager.Insight(
                icon: "memorychip",
                title: "Cache Hit Rate",
                detail: String(format: "%.0f%% - saved %@", hitRate, (Double(cacheRead) / 1_000_000 * 13.5).usdFormatted),
                colorName: "mint"
            ))
        }

        return insights
    }

    private static func simplifiedModelName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-20250", with: "")
    }

    static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func weekChangePercent(_ thisWeek: Int, _ lastWeek: Int) -> Double {
        guard lastWeek > 0 else { return thisWeek > 0 ? 100 : 0 }
        return (Double(thisWeek - lastWeek) / Double(lastWeek)) * 100
    }
}

@MainActor
final class StatsManager: ObservableObject {
    struct RangeSnapshot: Sendable {
        let dailySummaries: [DailySummary]
        let aggregate: DailySummary
        let previousAggregate: DailySummary
        let currentSummary: WeekSummary
        let previousSummary: WeekSummary
        let projectStats: [ProjectStat]
        let maxProjectSessionCount: Int
        let toolDistributionSorted: [(tool: String, count: Int)]
        let totalToolUseCount: Int
        let modelDistribution: [(model: String, count: Int)]
        let averageMessagesPerSession: Double
        let averageToolUsesPerSession: Double
        let durationBuckets: [DurationBucket]
        let weeklyHourlyHeatmap: [[Int]]
        let sessions: [ScannedSession]
        let insights: [Insight]
        let totalSessionCount: Int

        var inputTokens: Int { aggregate.totalInputTokens }
        var outputTokens: Int { aggregate.totalOutputTokens }
        var totalTokens: Int { aggregate.totalTokens }
        var totalCost: Double { aggregate.totalCost }
        var totalDurationSeconds: Double { aggregate.totalDurationSeconds }
        var averageCostPerSession: Double {
            currentSummary.sessions > 0 ? aggregate.totalCost / Double(currentSummary.sessions) : 0
        }
        var averageDurationPerSession: Double {
            currentSummary.sessions > 0 ? aggregate.totalDurationSeconds / Double(currentSummary.sessions) : 0
        }
        var completionTrend: Int {
            aggregate.completionCount - previousAggregate.completionCount
        }
        var costTrend: Double {
            aggregate.totalCost - previousAggregate.totalCost
        }
        var durationTrend: Double {
            aggregate.totalDurationSeconds - previousAggregate.totalDurationSeconds
        }
        var pureInputTokens: Int {
            max(inputTokens - aggregate.totalCacheReadTokens - aggregate.totalCacheCreationTokens, 0)
        }
        var cacheHitRate: Double {
            let total = aggregate.totalCacheReadTokens + pureInputTokens
            return total > 0 ? Double(aggregate.totalCacheReadTokens) / Double(total) : 0
        }
        var cacheSavings: Double {
            Double(aggregate.totalCacheReadTokens) / 1_000_000 * 13.5
        }
        var tokensPerMinute: Double {
            guard totalDurationSeconds > 60 else { return 0 }
            return Double(totalTokens) / (totalDurationSeconds / 60.0)
        }
        var tokensPerDollar: Double {
            guard totalCost > 0.001 else { return 0 }
            return Double(totalTokens) / totalCost
        }
        var peakHour: Int? {
            let maxCount = aggregate.hourlyDistribution.max() ?? 0
            guard maxCount > 0 else { return nil }
            return aggregate.hourlyDistribution.firstIndex(of: maxCount)
        }
    }

    // MARK: - 单例

    static let shared = StatsManager()

    // MARK: - 发布属性（驱动 UI 更新）

    @Published var todayCompletionCount: Int = 0
    @Published var todayCost: Double = 0
    @Published var todayDurationSeconds: Double = 0
    @Published var todayInputTokens: Int = 0
    @Published var todayOutputTokens: Int = 0
    @Published var todayHourlyDistribution: [Int] = Array(repeating: 0, count: 24)
    @Published var history: [DailySummary] = []
    @Published var recentSessions: [SessionRecord] = []
    @Published var scanComplete: Bool = false
    @Published var todayCacheReadTokens: Int = 0
    @Published var todayCacheCreationTokens: Int = 0
    @Published var todayToolUseCount: Int = 0
    @Published var todayMessageCount: Int = 0
    @Published var todayToolDistribution: [String: Int] = [:]
    @Published var dailyCostBudget: Double = 0

    // MARK: - 私有属性

    private let keyPrefix = "ClaudeDash_"
    private let sessionsFileURL: URL
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var cachedHeatmapDailyCounts: [String: Int] = [:]
    private var cachedAllSessions: [ScannedSession] = []
    private var cachedRangeSnapshots: [Int: RangeSnapshot] = [:]
    private var cachedProjectStats: [ProjectStat] = []
    private var cachedMaxProjectSessionCount: Int = 1
    private var cachedTotalCacheSavings: Double = 0
    private var cachedAllTimeToolDistribution: [String: Int] = [:]
    private var cachedToolDistributionSorted: [(tool: String, count: Int)] = []
    private var cachedTotalToolUseCountAllTime: Int = 0
    private var cachedModelDistribution: [(model: String, count: Int)] = []
    private var cachedAverageMessagesPerSession: Double = 0
    private var cachedAverageToolUsesPerSession: Double = 0
    private var cachedThisWeekSummary: WeekSummary = StatsComputation.emptyWeekSummary
    private var cachedLastWeekSummary: WeekSummary = StatsComputation.emptyWeekSummary
    private var cachedDurationBuckets: [DurationBucket] = []
    private var cachedWeeklyHourlyHeatmap = Array(repeating: Array(repeating: 0, count: 24), count: 7)
    private var cachedTodaySessions: [ScannedSession] = []
    private var cachedThisWeekSessions: [ScannedSession] = []
    private var cachedWeeklyInsights: [Insight] = []
    private var cachedTotalScannedSessionCount: Int = 0

    // MARK: - 初始化

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let supportDir = appSupport.appendingPathComponent("ClaudeDash", isDirectory: true)
        self.sessionsFileURL = supportDir.appendingPathComponent("sessions.json")

        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

        let savedBudget = UserDefaults.standard.double(forKey: "\(keyPrefix)dailyCostBudget")
        if savedBudget > 0 {
            dailyCostBudget = savedBudget
        }

        Task {
            await scanHistory()
        }
    }

    // MARK: - 历史扫描

    private func scanHistory() async {
        let snapshot = await Task.detached(priority: .userInitiated) {
            let sessions = HistoryScanner.scanAll()
            return StatsComputation.scanSnapshot(from: sessions)
        }.value

        apply(snapshot)
        scanComplete = true
        print("[StatsManager] 扫描完成: \(snapshot.sessions.count) 个 session")
    }

    private func apply(_ snapshot: StatsScanSnapshot) {
        cachedAllSessions = snapshot.sessions
        cachedRangeSnapshots.removeAll()

        let todayKey = dateFormatter.string(from: Date())
        let todaySummary = snapshot.dailyMap[todayKey] ?? DailySummary(dateString: todayKey)
        applyTodaySummary(todaySummary)

        let historySummaries = snapshot.dailyMap
            .filter { $0.key != todayKey }
            .map(\.value)
            .sorted { $0.dateString < $1.dateString }
        history = Array(historySummaries.suffix(30))

        applyDerivedCache(snapshot.derived)
    }

    private func applyTodaySummary(_ summary: DailySummary) {
        todayCompletionCount = summary.completionCount
        todayCost = summary.totalCost
        todayDurationSeconds = summary.totalDurationSeconds
        todayInputTokens = summary.totalInputTokens
        todayOutputTokens = summary.totalOutputTokens
        todayHourlyDistribution = summary.hourlyDistribution
        todayCacheReadTokens = summary.totalCacheReadTokens
        todayCacheCreationTokens = summary.totalCacheCreationTokens
        todayToolUseCount = summary.totalToolUseCount
        todayMessageCount = summary.totalMessageCount
        todayToolDistribution = summary.toolDistribution
    }

    private func applyDerivedCache(_ derived: StatsDerivedCache) {
        cachedHeatmapDailyCounts = derived.heatmapDailyCounts
        cachedProjectStats = derived.projectStats
        cachedMaxProjectSessionCount = derived.maxProjectSessionCount
        cachedTotalCacheSavings = derived.totalCacheSavings
        cachedAllTimeToolDistribution = derived.allTimeToolDistribution
        cachedToolDistributionSorted = derived.toolDistributionSorted
        cachedTotalToolUseCountAllTime = derived.totalToolUseCountAllTime
        cachedModelDistribution = derived.modelDistribution
        cachedAverageMessagesPerSession = derived.averageMessagesPerSession
        cachedAverageToolUsesPerSession = derived.averageToolUsesPerSession
        cachedThisWeekSummary = derived.thisWeekSummary
        cachedLastWeekSummary = derived.lastWeekSummary
        cachedDurationBuckets = derived.durationBuckets
        cachedWeeklyHourlyHeatmap = derived.weeklyHourlyHeatmap
        cachedTodaySessions = derived.todaySessions
        cachedThisWeekSessions = derived.thisWeekSessions
        cachedWeeklyInsights = derived.weeklyInsights
        cachedTotalScannedSessionCount = derived.totalScannedSessionCount
    }

    // MARK: - 增量更新（Hook 触发时）

    func addSession(_ record: SessionRecord) {
        todayCompletionCount += 1
        todayCost += record.cost
        todayDurationSeconds += Double(record.durationMs) / 1000.0
        cachedRangeSnapshots.removeAll()

        let hour = Calendar.current.component(.hour, from: record.completedAt)
        if hour >= 0 && hour < 24 {
            todayHourlyDistribution[hour] += 1
        }

        recentSessions.append(record)
        if recentSessions.count > 5 {
            recentSessions.removeFirst(recentSessions.count - 5)
        }
    }

    func refreshFromSessionsFile() {
        guard FileManager.default.fileExists(atPath: sessionsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: sessionsFileURL)
            let sessions = try JSONDecoder().decode([SessionRecord].self, from: data)
            recentSessions = Array(sessions.suffix(5))
            cachedRangeSnapshots.removeAll()
        } catch {
            print("[StatsManager] 刷新 sessions 文件失败: \(error)")
        }
    }

    // MARK: - 计算属性

    var yesterdaySummary: DailySummary? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let key = dateFormatter.string(from: yesterday)
        return history.first { $0.dateString == key }
    }

    var completionTrend: Int {
        todayCompletionCount - (yesterdaySummary?.completionCount ?? 0)
    }

    var costTrend: Double {
        todayCost - (yesterdaySummary?.totalCost ?? 0)
    }

    var durationTrend: Double {
        todayDurationSeconds - (yesterdaySummary?.totalDurationSeconds ?? 0)
    }

    var averageCostPerTask: Double {
        todayCompletionCount > 0 ? todayCost / Double(todayCompletionCount) : 0
    }

    var averageDurationPerTask: Double {
        todayCompletionCount > 0 ? todayDurationSeconds / Double(todayCompletionCount) : 0
    }

    var todayTotalTokens: Int {
        todayInputTokens + todayOutputTokens
    }

    var last7Days: [DailySummary] {
        buildRollingWindow(days: 7)
    }

    var usageStreak: Int {
        let calendar = Calendar.current
        var streak = todayCompletionCount > 0 ? 1 : 0
        var checkDate = Date()

        for _ in 0..<30 {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            let key = dateFormatter.string(from: checkDate)
            if let day = history.first(where: { $0.dateString == key }), day.completionCount > 0 {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    var peakHour: Int? {
        let maxCount = todayHourlyDistribution.max() ?? 0
        guard maxCount > 0 else { return nil }
        return todayHourlyDistribution.firstIndex(of: maxCount)
    }

    var totalCostAllTime: Double {
        history.reduce(0) { $0 + $1.totalCost } + todayCost
    }

    var totalCompletionsAllTime: Int {
        history.reduce(0) { $0 + $1.completionCount } + todayCompletionCount
    }

    var totalTokensAllTime: Int {
        let historyTokens = history.reduce(0) { $0 + $1.totalInputTokens + $1.totalOutputTokens }
        return historyTokens + todayInputTokens + todayOutputTokens
    }

    var dailyAverageSessions: Double {
        let days = last7Days.filter { $0.completionCount > 0 }
        guard !days.isEmpty else { return 1 }
        return Double(days.reduce(0) { $0 + $1.completionCount }) / Double(days.count)
    }

    var dailyAverageCost: Double {
        let days = last7Days.filter { $0.totalCost > 0 }
        guard !days.isEmpty else { return 0.01 }
        return days.reduce(0) { $0 + $1.totalCost } / Double(days.count)
    }

    var dailyAverageTokens: Double {
        let days = last7Days.filter { $0.totalTokens > 0 }
        guard !days.isEmpty else { return 1000 }
        return Double(days.reduce(0) { $0 + $1.totalTokens }) / Double(days.count)
    }

    var sessionRingProgress: Double {
        let target = max(dailyAverageSessions * 1.5, 1)
        return min(Double(todayCompletionCount) / target, 1.0)
    }

    var weeklyActivityProgress: Double {
        let activeDays = last7Days.filter { $0.completionCount > 0 }.count
        return Double(activeDays) / 7.0
    }

    var tokenRingProgress: Double {
        let target = max(dailyAverageTokens * 1.5, 1000)
        return min(Double(todayTotalTokens) / target, 1.0)
    }

    var heatmapDailyCounts: [String: Int] {
        var map = cachedHeatmapDailyCounts
        let todayKey = dateFormatter.string(from: Date())
        if todayCompletionCount > 0 {
            map[todayKey] = todayCompletionCount
        }
        return map
    }

    var last14Days: [DailySummary] {
        buildRollingWindow(days: 14)
    }

    var projectStats: [ProjectStat] {
        cachedProjectStats
    }

    var maxProjectSessionCount: Int {
        cachedMaxProjectSessionCount
    }

    var todayPureInputTokens: Int {
        max(todayInputTokens - todayCacheReadTokens - todayCacheCreationTokens, 0)
    }

    var cacheHitRate: Double {
        let total = todayCacheReadTokens + todayPureInputTokens
        return total > 0 ? Double(todayCacheReadTokens) / Double(total) : 0
    }

    var cacheSavings: Double {
        Double(todayCacheReadTokens) / 1_000_000 * 13.5
    }

    var totalCacheSavings: Double {
        cachedTotalCacheSavings
    }

    var allTimeToolDistribution: [String: Int] {
        cachedAllTimeToolDistribution
    }

    var toolDistributionSorted: [(tool: String, count: Int)] {
        cachedToolDistributionSorted
    }

    var totalToolUseCountAllTime: Int {
        cachedTotalToolUseCountAllTime
    }

    var modelDistribution: [(model: String, count: Int)] {
        cachedModelDistribution
    }

    var averageMessagesPerSession: Double {
        cachedAverageMessagesPerSession
    }

    var averageToolUsesPerSession: Double {
        cachedAverageToolUsesPerSession
    }

    var thisWeekSummary: WeekSummary {
        cachedThisWeekSummary
    }

    var lastWeekSummary: WeekSummary {
        cachedLastWeekSummary
    }

    func weekChangePercent(_ thisWeek: Int, _ lastWeek: Int) -> Double {
        StatsComputation.weekChangePercent(thisWeek, lastWeek)
    }

    func weekChangePercent(_ thisWeek: Double, _ lastWeek: Double) -> Double {
        guard lastWeek > 0.001 else { return thisWeek > 0.001 ? 100 : 0 }
        return ((thisWeek - lastWeek) / lastWeek) * 100
    }

    var durationBuckets: [DurationBucket] {
        cachedDurationBuckets
    }

    var weeklyHourlyHeatmap: [[Int]] {
        cachedWeeklyHourlyHeatmap
    }

    var tokensPerMinute: Double {
        guard todayDurationSeconds > 60 else { return 0 }
        return Double(todayTotalTokens) / (todayDurationSeconds / 60.0)
    }

    var tokensPerDollar: Double {
        guard todayCost > 0.001 else { return 0 }
        return Double(todayTotalTokens) / todayCost
    }

    var costBudgetProgress: Double {
        guard dailyCostBudget > 0.001 else { return 0 }
        return todayCost / dailyCostBudget
    }

    var todaySessions: [ScannedSession] {
        cachedTodaySessions
    }

    var thisWeekSessions: [ScannedSession] {
        cachedThisWeekSessions
    }

    struct Insight: Identifiable, Sendable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let colorName: String
    }

    var weeklyInsights: [Insight] {
        cachedWeeklyInsights
    }

    var totalScannedSessionCount: Int {
        cachedTotalScannedSessionCount
    }

    func snapshot(forLastDays days: Int) -> RangeSnapshot {
        let clampedDays = min(max(days, 1), 30)
        if let cached = cachedRangeSnapshots[clampedDays] {
            return cached
        }

        let calendar = Calendar.current
        let now = Date()
        let currentStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(clampedDays - 1), to: now) ?? now)
        let currentEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let previousStart = calendar.date(byAdding: .day, value: -clampedDays, to: currentStart) ?? currentStart

        let currentSessions = cachedAllSessions
            .filter { $0.startTime >= currentStart && $0.startTime < currentEnd }
            .sorted { $0.startTime < $1.startTime }
        let previousSessions = cachedAllSessions
            .filter { $0.startTime >= previousStart && $0.startTime < currentStart }
            .sorted { $0.startTime < $1.startTime }

        let currentDailyMap = StatsComputation.buildDailyMap(from: currentSessions, calendar: calendar)
        let previousDailyMap = StatsComputation.buildDailyMap(from: previousSessions, calendar: calendar)
        let currentDerived = StatsComputation.buildDerivedCache(from: currentSessions, now: now, calendar: calendar)

        let currentWindow = buildRollingWindow(
            days: clampedDays,
            referenceDate: now,
            dailyMap: currentDailyMap
        )
        let currentAggregate = aggregateSummary(
            from: currentWindow,
            dateString: dateFormatter.string(from: now)
        )
        let previousAggregate = aggregateSummary(
            from: Array(previousDailyMap.values),
            dateString: dateFormatter.string(from: previousStart)
        )
        let currentSummary = StatsComputation.summary(from: currentSessions, calendar: calendar)
        let previousSummary = StatsComputation.summary(from: previousSessions, calendar: calendar)

        let snapshot = RangeSnapshot(
            dailySummaries: currentWindow,
            aggregate: currentAggregate,
            previousAggregate: previousAggregate,
            currentSummary: currentSummary,
            previousSummary: previousSummary,
            projectStats: currentDerived.projectStats,
            maxProjectSessionCount: currentDerived.maxProjectSessionCount,
            toolDistributionSorted: currentDerived.toolDistributionSorted,
            totalToolUseCount: currentDerived.totalToolUseCountAllTime,
            modelDistribution: currentDerived.modelDistribution,
            averageMessagesPerSession: currentDerived.averageMessagesPerSession,
            averageToolUsesPerSession: currentDerived.averageToolUsesPerSession,
            durationBuckets: currentDerived.durationBuckets,
            weeklyHourlyHeatmap: currentDerived.weeklyHourlyHeatmap,
            sessions: currentSessions,
            insights: StatsComputation.rangeInsights(
                sessions: currentSessions,
                currentSummary: currentSummary,
                previousSummary: previousSummary,
                calendar: calendar
            ),
            totalSessionCount: currentSessions.count
        )

        cachedRangeSnapshots[clampedDays] = snapshot
        return snapshot
    }

    // MARK: - 数据导出

    func exportCSV() -> String {
        var csv = "Date,Sessions,Cost(USD),Duration(s),InputTokens,OutputTokens,CacheReadTokens,CacheCreationTokens,ToolUses,Messages\n"
        let allDays = (history + [currentTodaySummary]).sorted { $0.dateString < $1.dateString }
        for day in allDays {
            csv += "\(day.dateString),\(day.completionCount),\(String(format: "%.4f", day.totalCost)),\(String(format: "%.0f", day.totalDurationSeconds)),\(day.totalInputTokens),\(day.totalOutputTokens),\(day.totalCacheReadTokens),\(day.totalCacheCreationTokens),\(day.totalToolUseCount),\(day.totalMessageCount)\n"
        }
        return csv
    }

    func exportJSON() -> String {
        let allDays = (history + [currentTodaySummary]).sorted { $0.dateString < $1.dateString }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(allDays) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private var currentTodaySummary: DailySummary {
        var summary = DailySummary(dateString: dateFormatter.string(from: Date()))
        summary.completionCount = todayCompletionCount
        summary.totalCost = todayCost
        summary.totalDurationSeconds = todayDurationSeconds
        summary.totalInputTokens = todayInputTokens
        summary.totalOutputTokens = todayOutputTokens
        summary.hourlyDistribution = todayHourlyDistribution
        summary.totalCacheReadTokens = todayCacheReadTokens
        summary.totalCacheCreationTokens = todayCacheCreationTokens
        summary.totalToolUseCount = todayToolUseCount
        summary.totalMessageCount = todayMessageCount
        summary.toolDistribution = todayToolDistribution
        return summary
    }

    private func aggregateSummary(from summaries: [DailySummary], dateString: String) -> DailySummary {
        var summary = DailySummary(dateString: dateString)
        for day in summaries {
            summary.completionCount += day.completionCount
            summary.totalCost += day.totalCost
            summary.totalDurationSeconds += day.totalDurationSeconds
            summary.totalInputTokens += day.totalInputTokens
            summary.totalOutputTokens += day.totalOutputTokens
            summary.totalCacheReadTokens += day.totalCacheReadTokens
            summary.totalCacheCreationTokens += day.totalCacheCreationTokens
            summary.totalToolUseCount += day.totalToolUseCount
            summary.totalMessageCount += day.totalMessageCount

            for (index, count) in day.hourlyDistribution.enumerated() {
                if index < summary.hourlyDistribution.count {
                    summary.hourlyDistribution[index] += count
                }
            }

            for (tool, count) in day.toolDistribution {
                summary.toolDistribution[tool, default: 0] += count
            }
        }
        return summary
    }

    private func buildRollingWindow(days: Int) -> [DailySummary] {
        let todayKey = dateFormatter.string(from: Date())
        let todaySummary = currentTodaySummary
        let calendar = Calendar.current

        var result: [DailySummary] = []
        if days > 1 {
            for offset in (1..<(days)).reversed() {
                let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
                let key = dateFormatter.string(from: date)
                result.append(history.first(where: { $0.dateString == key }) ?? DailySummary(dateString: key))
            }
        }

        if todaySummary.dateString == todayKey {
            result.append(todaySummary)
        }

        return result
    }

    private func buildRollingWindow(
        days: Int,
        referenceDate: Date,
        dailyMap: [String: DailySummary]
    ) -> [DailySummary] {
        let calendar = Calendar.current
        var result: [DailySummary] = []

        for offset in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate) ?? referenceDate
            let key = dateFormatter.string(from: date)
            result.append(dailyMap[key] ?? DailySummary(dateString: key))
        }

        return result
    }

    // MARK: - 预算管理

    func updateDailyCostBudget(_ budget: Double) {
        dailyCostBudget = budget
        UserDefaults.standard.set(budget, forKey: "\(keyPrefix)dailyCostBudget")
    }
}

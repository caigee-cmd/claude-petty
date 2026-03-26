// StatsDetailView.swift
// ClaudeDash - 详细统计窗口
// Liquid Glass 设计：5 Tab — Overview / Tokens / Tools / Projects / Insights

import SwiftUI
import Charts

struct StatsDetailView: View {
    @EnvironmentObject var statsManager: StatsManager
    @State private var selectedTab: StatsTab = .overview
    @State private var selectedRange: StatsQuickRange = .fourteenDays

    enum StatsTab: String, CaseIterable {
        case overview = "Overview"
        case tokens = "Tokens"
        case tools = "Tools"
        case projects = "Projects"
        case insights = "Insights"
    }

    enum StatsQuickRange: String, CaseIterable, Identifiable {
        case today
        case sevenDays
        case fourteenDays
        case thirtyDays

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .today: return 1
            case .sevenDays: return 7
            case .fourteenDays: return 14
            case .thirtyDays: return 30
            }
        }

        var title: String {
            switch self {
            case .today: return "Today"
            case .sevenDays: return "7D"
            case .fourteenDays: return "14D"
            case .thirtyDays: return "30D"
            }
        }

        var longTitle: String {
            switch self {
            case .today: return "Today"
            case .sevenDays: return "Last 7 Days"
            case .fourteenDays: return "Last 14 Days"
            case .thirtyDays: return "Last 30 Days"
            }
        }

        var comparisonTitle: String {
            self == .today ? "Day Comparison" : "Range Comparison"
        }

        var comparisonTrailing: String {
            self == .today ? "today vs yesterday" : "\(title.lowercased()) vs previous \(title.lowercased())"
        }

        var previousLabel: String {
            self == .today ? "Yesterday" : "Previous \(title)"
        }

        var timelineTitle: String {
            self == .today ? "Today's Timeline" : "\(title) Timeline"
        }
    }

    private var selectedSnapshot: StatsManager.RangeSnapshot {
        statsManager.snapshot(forLastDays: selectedRange.days)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)

            tabBar
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            quickRangeBar
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            if statsManager.scanComplete {
                ScrollView(.vertical, showsIndicators: false) {
                    switch selectedTab {
                    case .overview: overviewContent
                    case .tokens: tokensContent
                    case .tools: toolsContent
                    case .projects: projectsContent
                    case .insights: insightsContent
                    }
                }
            } else {
                statsLoadingState
            }
        }
        .frame(minWidth: 740, minHeight: 660)
        .background(statsWindowBackground)
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ClaudeGradients.primary)

                Text("Statistics")
                    .font(.system(size: 20, weight: .bold))

                if statsManager.usageStreak > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("\(statsManager.usageStreak)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .statsBackground(cornerRadius: 8)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                miniStat(icon: "sum", label: "Sessions", value: "\(statsManager.totalCompletionsAllTime)")
                miniStat(icon: ClaudeDashSymbols.totalCost, label: "Cost", value: statsManager.totalCostAllTime.usdFormatted)
                miniStat(icon: "textformat.123", label: "Tokens", value: statsManager.totalTokensAllTime.tokenFormatted)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(StatsTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? Color.primary : Color.primary.opacity(StatsPanelStyle.inactiveTextOpacity))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(.white.opacity(0.1))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .statsBackground(cornerRadius: 14)
    }

    private var quickRangeBar: some View {
        HStack(spacing: 6) {
            ForEach(StatsQuickRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.title)
                        .font(.system(size: 12, weight: selectedRange == range ? .semibold : .medium))
                        .foregroundStyle(selectedRange == range ? Color.primary : Color.primary.opacity(StatsPanelStyle.inactiveTextOpacity))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            if selectedRange == range {
                                Capsule()
                                    .fill(.white.opacity(0.10))
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(selectedRange.longTitle)
                .font(StatsPanelStyle.miniLabel)
                .foregroundStyle(.primary.opacity(StatsPanelStyle.tertiaryTextOpacity))
        }
        .padding(4)
        .statsBackground(cornerRadius: 14)
    }

    private func miniStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: StatsPanelStyle.compactSpacing) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(StatsPanelStyle.miniLabel)
                    .foregroundStyle(.primary.opacity(StatsPanelStyle.inactiveTextOpacity))
                    .lineLimit(1)

                Text(value)
                    .font(StatsPanelStyle.miniValue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(.primary.opacity(StatsPanelStyle.secondaryTextOpacity))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .statsBackground(cornerRadius: 10)
    }

    private var statsWindowBackground: some View {
        Color(nsColor: .windowBackgroundColor)
    }

    // MARK: - Overview Tab

    private var overviewContent: some View {
        LazyVStack(spacing: 16) {
            // 趋势主图 + 今日详情
            HStack(alignment: .top, spacing: 16) {
                StatsTrendHeroCard(
                    data: selectedSnapshot.dailySummaries,
                    headlineValue: selectedSnapshot.totalTokens.tokenFormatted,
                    headlineLabel: selectedRange.longTitle,
                    rangeBadge: selectedRange.title,
                    sessionCount: selectedSnapshot.aggregate.completionCount,
                    activeDays: selectedSnapshot.currentSummary.activeDays,
                    totalCost: selectedSnapshot.totalCost
                )
                .frame(maxWidth: .infinity)
                .statsCard(cornerRadius: 20)

                VStack(spacing: StatsPanelStyle.regularSpacing) {
                    detailStatCard(title: "Sessions", value: "\(selectedSnapshot.aggregate.completionCount)", trend: selectedSnapshot.completionTrend, icon: "checkmark.circle.fill", color: .green)
                    detailStatCard(title: "Cost", value: selectedSnapshot.totalCost.usdFormatted, trendValue: selectedSnapshot.costTrend, icon: "dollarsign.circle.fill", color: .orange)
                    detailStatCard(title: "Duration", value: selectedSnapshot.totalDurationSeconds.durationFormatted, trendDuration: selectedSnapshot.durationTrend, icon: "clock.fill", color: .blue)
                    detailStatCard(title: "Avg / Session", value: selectedSnapshot.averageDurationPerSession.durationFormatted, subtitle: selectedSnapshot.averageCostPerSession.usdFormatted + " avg cost", icon: "gauge.medium", color: .claudePurple)
                }
                .frame(width: 220)
            }
            .padding(.horizontal, 24)

            // 范围对比
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: selectedRange.comparisonTitle, trailing: selectedRange.comparisonTrailing)

                RangeComparisonView(
                    currentSummary: selectedSnapshot.currentSummary,
                    previousSummary: selectedSnapshot.previousSummary,
                    changePercent: statsManager.weekChangePercent,
                    changePercentDouble: statsManager.weekChangePercent,
                    previousLabel: selectedRange.previousLabel
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 热力图
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Contribution Activity", trailing: "last 13 weeks")

                ContributionHeatmapView(
                    dailyCounts: statsManager.heatmapDailyCounts,
                    cellSize: 15,
                    cellSpacing: 3,
                    numWeeks: 13,
                    showDayLabels: true,
                    showMonthLabels: true
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 14 天趋势
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Activity Trend", trailing: selectedRange.title)

                UsageTrendChartView(
                    data: selectedSnapshot.dailySummaries,
                    height: 160,
                    showAxes: true,
                    showPeakAnnotation: true
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 今日小时分布
            hourlyHeatmapSection(
                distribution: selectedSnapshot.aggregate.hourlyDistribution,
                peakHour: selectedSnapshot.peakHour,
                title: selectedRange == .today ? "Hourly Distribution" : "Hourly Distribution — \(selectedRange.title)"
            )
                .padding(.horizontal, 24)

            Spacer(minLength: 24)
        }
        .padding(.top, 4)
    }

    // MARK: - Tokens & Cost Tab

    private var tokensContent: some View {
        LazyVStack(spacing: 16) {
            // Token 概览卡片
            HStack(spacing: 10) {
                tokenOverviewCard(title: "Input", value: selectedSnapshot.inputTokens.tokenFormatted, color: .claudeCyan, icon: "arrow.down.circle.fill")
                tokenOverviewCard(title: "Output", value: selectedSnapshot.outputTokens.tokenFormatted, color: .claudePurple, icon: "arrow.up.circle.fill")
                tokenOverviewCard(title: "Total", value: selectedSnapshot.totalTokens.tokenFormatted, color: .indigo, icon: "sum")
                tokenOverviewCard(title: "Cost", value: selectedSnapshot.totalCost.usdFormatted, color: .orange, icon: "dollarsign.circle.fill")
            }
            .padding(.horizontal, 24)

            // Cache 效率
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Cache Efficiency", trailing: "saved \(selectedSnapshot.cacheSavings.usdFormatted)")

                CacheEfficiencyView(
                    hitRate: selectedSnapshot.cacheHitRate,
                    savings: selectedSnapshot.cacheSavings,
                    cacheReadTokens: selectedSnapshot.aggregate.totalCacheReadTokens,
                    cacheCreateTokens: selectedSnapshot.aggregate.totalCacheCreationTokens,
                    pureInputTokens: selectedSnapshot.pureInputTokens,
                    outputTokens: selectedSnapshot.outputTokens
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 成本细分
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Cost Breakdown", trailing: selectedRange.title)

                CostBreakdownView(
                    inputCost: Double(selectedSnapshot.pureInputTokens) / 1_000_000 * 15.0,
                    outputCost: Double(selectedSnapshot.outputTokens) / 1_000_000 * 75.0,
                    cacheReadCost: Double(selectedSnapshot.aggregate.totalCacheReadTokens) / 1_000_000 * 1.5,
                    cacheCreateCost: Double(selectedSnapshot.aggregate.totalCacheCreationTokens) / 1_000_000 * 18.75,
                    height: 100
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // Token 趋势图
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Token Usage", trailing: selectedRange.title)

                TokenTrendChartView(data: selectedSnapshot.dailySummaries, height: 180)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.claudeCyan.opacity(0.7)).frame(width: 6, height: 6)
                        Text("Input").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.claudePurple.opacity(0.7)).frame(width: 6, height: 6)
                        Text("Output").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 成本趋势图
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Cost Trend", trailing: selectedRange.title)

                CostTrendChartView(data: selectedSnapshot.dailySummaries, height: 160)
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            Spacer(minLength: 24)
        }
        .padding(.top, 4)
    }

    // MARK: - Tools Tab (NEW)

    private var toolsContent: some View {
        LazyVStack(spacing: 16) {
            // 工具分布
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Tool Distribution", trailing: "\(selectedSnapshot.totalToolUseCount) calls")

                ToolDistributionView(
                    distribution: selectedSnapshot.toolDistributionSorted,
                    totalCount: selectedSnapshot.totalToolUseCount
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 模型使用分布
            if !selectedSnapshot.modelDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    GlassSectionHeader(title: "Model Usage")

                    VStack(spacing: 6) {
                        ForEach(selectedSnapshot.modelDistribution, id: \.model) { item in
                            modelRow(item)
                        }
                    }
                }
                .padding(16)
                .statsCard(cornerRadius: 20)
                .padding(.horizontal, 24)
            }

            // 工具调用趋势
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Tool Usage", trailing: selectedRange.title)

                ToolTrendChartView(data: selectedSnapshot.dailySummaries, height: 160)
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 对话深度
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Conversation Depth")

                HStack(spacing: 10) {
                    depthCard(icon: "bubble.left.and.bubble.right", label: "Avg Messages", value: String(format: "%.1f", selectedSnapshot.averageMessagesPerSession), color: .blue)
                    depthCard(icon: "wrench.and.screwdriver", label: "Avg Tool Calls", value: String(format: "%.1f", selectedSnapshot.averageToolUsesPerSession), color: .claudePurple)
                    depthCard(icon: "clock.arrow.circlepath", label: "Avg Duration", value: selectedSnapshot.averageDurationPerSession.durationFormatted, color: .green)
                    depthCard(icon: "dollarsign.circle", label: "Avg Cost", value: selectedSnapshot.averageCostPerSession.usdFormatted, color: .orange)
                }
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            Spacer(minLength: 24)
        }
        .padding(.top, 4)
    }

    // MARK: - Projects Tab

    private var projectsContent: some View {
        LazyVStack(spacing: 16) {
            if selectedSnapshot.projectStats.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("暂无项目数据")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    GlassSectionHeader(title: "Project Ranking", trailing: selectedRange.title)

                    ForEach(Array(selectedSnapshot.projectStats.prefix(10).enumerated()), id: \.element.id) { index, stat in
                        projectRow(index: index, stat: stat)
                    }
                }
                .padding(16)
                .statsCard(cornerRadius: 20)
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 24)
        }
        .padding(.top, 4)
    }

    // MARK: - Insights Tab (NEW)

    private var insightsContent: some View {
        LazyVStack(spacing: 16) {
            // 效率指标面板
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Efficiency Metrics")

                EfficiencyMetricsView(
                    tokensPerMinute: selectedSnapshot.tokensPerMinute,
                    tokensPerDollar: selectedSnapshot.tokensPerDollar,
                    avgMessagesPerSession: selectedSnapshot.averageMessagesPerSession,
                    avgToolUsesPerSession: selectedSnapshot.averageToolUsesPerSession,
                    cacheHitRate: selectedSnapshot.cacheHitRate,
                    streak: statsManager.usageStreak
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 智能洞察
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Range Insights", trailing: selectedRange.title)

                InsightsListView(insights: selectedSnapshot.insights)
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 7×24 全周热力图
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Activity Punch Card", trailing: selectedRange.title)

                WeeklyPunchCardView(
                    heatmap: selectedSnapshot.weeklyHourlyHeatmap,
                    cellSize: 14,
                    cellSpacing: 2
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // Session 时长分布
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Session Duration Distribution", trailing: selectedRange.title)

                DurationDistributionView(
                    buckets: selectedSnapshot.durationBuckets,
                    height: 140
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 今日 Session 时间线
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: selectedRange.timelineTitle, trailing: "\(selectedSnapshot.sessions.count) sessions")

                SessionTimelineView(sessions: selectedSnapshot.sessions)
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            // 导出按钮
            VStack(alignment: .leading, spacing: 8) {
                GlassSectionHeader(title: "Data Export")

                ExportButtonsView(
                    onExportCSV: { exportData(format: "csv") },
                    onExportJSON: { exportData(format: "json") }
                )
            }
            .padding(16)
            .statsCard(cornerRadius: 20)
            .padding(.horizontal, 24)

            Spacer(minLength: 24)
        }
        .padding(.top, 4)
    }

    // MARK: - 子组件

    private func detailStatCard(
        title: String, value: String,
        trend: Int? = nil, trendValue: Double? = nil, trendDuration: Double? = nil,
        subtitle: String? = nil, icon: String, color: Color
    ) -> some View {
        HStack(spacing: StatsPanelStyle.cardPadding) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(subtitle ?? title)
                    .font(StatsPanelStyle.secondaryLabel)
                    .foregroundStyle(.primary.opacity(StatsPanelStyle.secondaryTextOpacity))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer()

            if let t = trend, t != 0 {
                trendBadge(direction: t > 0 ? 1 : -1, text: "\(abs(t))")
            } else if let tv = trendValue, abs(tv) > 0.001 {
                trendBadge(direction: tv > 0 ? 1 : -1, text: abs(tv).usdFormatted)
            } else if let td = trendDuration, abs(td) > 0.5 {
                trendBadge(direction: td > 0 ? 1 : -1, text: abs(td).durationFormatted)
            }
        }
        .padding(StatsPanelStyle.cardPadding)
        .statsCard(cornerRadius: 14)
    }

    private func trendBadge(direction: Int, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: direction > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(StatsPanelStyle.metaValue)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(direction > 0 ? .green : .red)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            (direction > 0 ? Color.green : Color.red).opacity(0.1),
            in: Capsule()
        )
    }

    private func tokenOverviewCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .statsCard(cornerRadius: 16)
    }

    private var statsLoadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("正在构建统计快照")
                .font(.system(size: 15, weight: .semibold))
            Text("首次扫描可能需要几秒，之后会显著更快。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - 每小时热力图

    private func hourlyHeatmapSection(
        distribution: [Int],
        peakHour: Int?,
        title: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GlassSectionHeader(title: title)
                Spacer()
                if let peak = peakHour {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                        Text("Peak: \(peak):00")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .statsBackground(cornerRadius: 8)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 12),
                spacing: 4
            ) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = distribution[hour]
                    let maxCount = max(distribution.max() ?? 1, 1)

                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(hourlyColor(count: count, max: maxCount))
                            .frame(height: 32)
                            .overlay {
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }

                        Text("\(hour)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .statsCard(cornerRadius: 20)
    }

    private func hourlyColor(count: Int, max: Int) -> Color {
        if count == 0 { return .white.opacity(0.04) }
        let intensity = Double(count) / Double(max)
        if intensity < 0.33 { return .claudePurple.opacity(0.35) }
        if intensity < 0.66 { return .claudePurple.opacity(0.6) }
        return .claudeCyan.opacity(0.8)
    }

    // MARK: - 模型行

    private func modelRow(_ item: (model: String, count: Int)) -> some View {
        let totalSessions = selectedSnapshot.totalSessionCount
        let pct = totalSessions > 0 ? Double(item.count) / Double(totalSessions) : 0

        return HStack(spacing: 10) {
            Image(systemName: ClaudeDashSymbols.model)
                .font(.system(size: 10))
                .foregroundStyle(Color.claudePurple)
                .frame(width: 14)

            Text(item.model)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)

            Spacer()

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.04))
                    Capsule()
                        .fill(LinearGradient(colors: [.claudePurple.opacity(0.5), .claudeCyan.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * pct))
                }
            }
            .frame(width: 80, height: 4)

            Text("\(item.count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 35, alignment: .trailing)

            Text(String(format: "%.0f%%", pct * 100))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .statsBackground(cornerRadius: 8)
    }

    // MARK: - 深度卡片

    private func depthCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .statsCard(cornerRadius: 14)
    }

    // MARK: - 项目行

    private func projectRow(index: Int, stat: ProjectStat) -> some View {
        let maxSessions = selectedSnapshot.maxProjectSessionCount
        let barWidth = Double(stat.sessionCount) / Double(max(maxSessions, 1))

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(rankColor(index).opacity(0.15))
                    .frame(width: 22, height: 22)
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(rankColor(index))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.project)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.04))
                        Capsule()
                            .fill(LinearGradient(colors: [.claudePurple.opacity(0.6), .claudeCyan.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, geo.size.width * barWidth))
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                    Text("\(stat.sessionCount)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.primary.opacity(0.65))

                Text(stat.totalCost.usdFormatted)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.orange)
                    .frame(width: 60, alignment: .trailing)

                Text(stat.tokensFormatted)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.claudeCyan)
                    .frame(width: 50, alignment: .trailing)

                Text(stat.totalDurationSeconds.durationFormatted)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            index == 0 ? AnyShapeStyle(.orange.opacity(0.05)) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .statsBackground(cornerRadius: 10)
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .gray
        case 2: return Color(red: 205 / 255, green: 127 / 255, blue: 50 / 255)
        default: return .secondary
        }
    }

    // MARK: - 导出

    private func exportData(format: String) {
        let content: String
        let ext: String
        if format == "csv" {
            content = statsManager.exportCSV()
            ext = "csv"
        } else {
            content = statsManager.exportJSON()
            ext = "json"
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "claude_glance_stats.\(ext)"
        panel.allowedContentTypes = ext == "csv" ? [.commaSeparatedText] : [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

private struct StatsTrendHeroCard: View {
    let data: [DailySummary]
    let headlineValue: String
    let headlineLabel: String
    let rangeBadge: String
    let sessionCount: Int
    let activeDays: Int
    let totalCost: Double

    private var latestDay: DailySummary? {
        data.last
    }

    private var peakDay: DailySummary? {
        data.max(by: { $0.completionCount < $1.completionCount })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headlineValue)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(headlineLabel)
                        .font(StatsPanelStyle.secondaryLabel)
                        .foregroundStyle(.primary.opacity(StatsPanelStyle.secondaryTextOpacity))
                }

                Spacer()

                Text(rangeBadge)
                    .font(StatsPanelStyle.miniLabel)
                    .foregroundStyle(.primary.opacity(StatsPanelStyle.secondaryTextOpacity))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
            }

            Chart(data) { day in
                AreaMark(
                    x: .value("Day", day.shortDateLabel),
                    y: .value("Sessions", day.completionCount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .claudeCyan.opacity(0.22),
                            .claudePurple.opacity(0.16),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", day.shortDateLabel),
                    y: .value("Sessions", day.completionCount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.claudeCyan, .claudePurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                if day.dateString == peakDay?.dateString {
                    PointMark(
                        x: .value("Day", day.shortDateLabel),
                        y: .value("Sessions", day.completionCount)
                    )
                    .foregroundStyle(Color.claudeCyan)
                    .symbolSize(34)
                }

                if day.dateString == latestDay?.dateString {
                    PointMark(
                        x: .value("Day", day.shortDateLabel),
                        y: .value("Sessions", day.completionCount)
                    )
                    .foregroundStyle(Color.white.opacity(0.95))
                    .symbolSize(20)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel()
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.primary.opacity(StatsPanelStyle.tertiaryTextOpacity))
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3]))
                        .foregroundStyle(.white.opacity(0.06))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel()
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.primary.opacity(StatsPanelStyle.tertiaryTextOpacity))
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3]))
                        .foregroundStyle(.white.opacity(0.06))
                }
            }
            .frame(height: 208)

            HStack(spacing: 10) {
                trendSummaryChip(title: "Sessions", value: "\(sessionCount)", accent: .green)
                trendSummaryChip(title: "Active Days", value: "\(activeDays)", accent: .claudeCyan)
                trendSummaryChip(title: "Cost", value: totalCost.usdFormatted, accent: .claudePurple)
            }
        }
        .padding(20)
    }

    private func trendSummaryChip(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(StatsPanelStyle.miniLabel)
                    .foregroundStyle(.primary.opacity(StatsPanelStyle.tertiaryTextOpacity))
                Text(value)
                    .font(StatsPanelStyle.legendValue)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .statsBackground(cornerRadius: 12)
    }
}

private struct RangeComparisonView: View {
    let currentSummary: WeekSummary
    let previousSummary: WeekSummary
    let changePercent: (Int, Int) -> Double
    let changePercentDouble: (Double, Double) -> Double
    let previousLabel: String

    var body: some View {
        VStack(spacing: StatsPanelStyle.blockSpacing) {
            HStack(alignment: .top, spacing: StatsPanelStyle.regularSpacing) {
                comparisonCard(
                    icon: "checkmark.circle.fill",
                    label: "Sessions",
                    currentValue: "\(currentSummary.sessions)",
                    previousValue: "\(previousSummary.sessions)",
                    change: changePercent(currentSummary.sessions, previousSummary.sessions),
                    color: .green
                )
                comparisonCard(
                    icon: "dollarsign.circle.fill",
                    label: "Cost",
                    currentValue: currentSummary.cost.usdFormatted,
                    previousValue: previousSummary.cost.usdFormatted,
                    change: changePercentDouble(currentSummary.cost, previousSummary.cost),
                    color: .orange
                )
                comparisonCard(
                    icon: "textformat.123",
                    label: "Tokens",
                    currentValue: currentSummary.tokens.tokenFormatted,
                    previousValue: previousSummary.tokens.tokenFormatted,
                    change: changePercent(currentSummary.tokens, previousSummary.tokens),
                    color: .claudeCyan
                )
                comparisonCard(
                    icon: "clock.fill",
                    label: "Duration",
                    currentValue: currentSummary.duration.durationFormatted,
                    previousValue: previousSummary.duration.durationFormatted,
                    change: changePercentDouble(currentSummary.duration, previousSummary.duration),
                    color: .blue
                )
            }

            HStack(spacing: StatsPanelStyle.regularSpacing) {
                miniComparison(label: "Active Days", currentValue: "\(currentSummary.activeDays)", previousValue: "\(previousSummary.activeDays)")
                miniComparison(label: "Tool Uses", currentValue: "\(currentSummary.toolUses)", previousValue: "\(previousSummary.toolUses)")
                miniComparison(label: "Messages", currentValue: "\(currentSummary.messages)", previousValue: "\(previousSummary.messages)")
            }
        }
    }

    private func comparisonCard(
        icon: String,
        label: String,
        currentValue: String,
        previousValue: String,
        change: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: StatsPanelStyle.regularSpacing) {
            HStack(spacing: StatsPanelStyle.compactSpacing) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 14)

                Text(label)
                    .font(StatsPanelStyle.secondaryLabel)
                    .foregroundStyle(.primary.opacity(StatsPanelStyle.secondaryTextOpacity))
                    .lineLimit(1)
            }

            Text(currentValue)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .bottom, spacing: 8) {
                comparisonChangeBadge(change: change)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(previousLabel)
                        .font(StatsPanelStyle.miniLabel)
                        .foregroundStyle(.primary.opacity(StatsPanelStyle.tertiaryTextOpacity))
                        .lineLimit(1)

                    Text(previousValue)
                        .font(StatsPanelStyle.metaValue)
                        .foregroundStyle(.primary.opacity(StatsPanelStyle.inactiveTextOpacity))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, StatsPanelStyle.cardPadding)
        .padding(.vertical, StatsPanelStyle.cardPadding)
        .statsCard(cornerRadius: 14)
    }

    private func miniComparison(label: String, currentValue: String, previousValue: String) -> some View {
        VStack(alignment: .leading, spacing: StatsPanelStyle.compactSpacing) {
            Text(label)
                .font(StatsPanelStyle.secondaryLabel)
                .foregroundStyle(.primary.opacity(StatsPanelStyle.secondaryTextOpacity))
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(currentValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text("vs")
                    .font(StatsPanelStyle.miniLabel)
                    .foregroundStyle(.primary.opacity(StatsPanelStyle.tertiaryTextOpacity))
                Text(previousValue)
                    .font(StatsPanelStyle.metaValue)
                    .foregroundStyle(.primary.opacity(StatsPanelStyle.inactiveTextOpacity))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, StatsPanelStyle.cardPadding)
        .padding(.vertical, 11)
        .statsBackground(cornerRadius: 10)
    }

    private func comparisonChangeBadge(change: Double) -> some View {
        HStack(spacing: 3) {
            if abs(change) > 0.5 {
                Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))

                Text(String(format: "%.0f%%", abs(change)))
                    .monospacedDigit()
            } else {
                Text("Flat")
            }
        }
        .font(StatsPanelStyle.secondaryLabel)
        .lineLimit(1)
        .foregroundStyle(change > 0 ? .green : (abs(change) > 0.5 ? .red : .secondary))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            (change > 0 ? Color.green : (abs(change) > 0.5 ? Color.red : Color.secondary)).opacity(0.1),
            in: Capsule()
        )
    }
}

// MARK: - DetailStatCard (保留兼容)

struct DetailStatCard: View {
    let title: String
    let value: String
    var trend: Int? = nil
    var trendValue: Double? = nil
    var trendDuration: Double? = nil
    var trendLabel: String? = nil
    var subtitle: String? = nil
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(subtitle ?? title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .statsCard(cornerRadius: 14)
    }
}

#Preview {
    StatsDetailView()
        .environmentObject(StatsManager.shared)
        .frame(width: 740, height: 680)
}

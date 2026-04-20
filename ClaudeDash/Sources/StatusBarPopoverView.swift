// StatusBarPopoverView.swift
// ClaudeDash - Compact popover: quick glance at today's stats + active sessions

import SwiftUI
import Charts

private enum PopoverPanelStyle {
    static let width: CGFloat = 364
    static let outerPadding: CGFloat = 14
    static let metricSpacing: CGFloat = 4
    static let sectionLabelSpacing: CGFloat = 6
    static let borderOpacity: Double = 0.08
    static let panelMaterialOpacity: Double = 0.78
    static let panelHighlightOpacity: Double = 0.035
    static let surfaceFillOpacity: Double = 0.024
    static let surfaceStrokeOpacity: Double = 0.05
    static let subtlePillOpacity: Double = 0.038
    static let selectedPillOpacity: Double = 0.075
    static let rowFillOpacity: Double = 0.042
    static let rowHoverFillOpacity: Double = 0.058
    static let rowStrokeOpacity: Double = 0.055
    static let dividerOpacity: Double = 0.05
    static let secondaryTextOpacity: Double = 0.68
    static let tertiaryTextOpacity: Double = 0.52
    static let microChartHeight: CGFloat = 24

    static var titleFont: Font {
        .system(size: 15, weight: .semibold)
    }

    static var metricLabelFont: Font {
        .system(size: 9, weight: .semibold)
    }

    static var metricValueFont: Font {
        .system(size: 15, weight: .bold, design: .rounded)
    }

    static var metricHeroFont: Font {
        .system(size: 16, weight: .bold, design: .rounded)
    }

    static var sectionTitleFont: Font {
        .system(size: 11, weight: .semibold)
    }

    static var rowTitleFont: Font {
        .system(size: 12, weight: .semibold)
    }

    static var rowMetaFont: Font {
        .system(size: 10, weight: .medium)
    }
}

private enum PopoverQuickRange: String, CaseIterable, Identifiable {
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
}

struct StatusBarPopoverView: View {
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var sessionMonitor: SessionMonitor
    @AppStorage(
        FloatingMascotPreferences.enabledUserDefaultsKey,
        store: ClaudeDashDefaults.shared
    ) private var isMascotEnabled = false
    @State private var selectedOverviewRange: PopoverQuickRange = .sevenDays

    var onOpenStats: () -> Void
    var onTestNotification: () -> Void
    var onInstallHook: () -> Void
    var onTogglePanel: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, PopoverPanelStyle.outerPadding)
                .padding(.top, 12)
                .padding(.bottom, 8)

            overviewSection
                .padding(.horizontal, PopoverPanelStyle.outerPadding)
                .padding(.bottom, 8)

            if !sessionMonitor.activeSessions.isEmpty {
                sectionDivider

                activeSessionsSection
                    .padding(.horizontal, PopoverPanelStyle.outerPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
            }

            if !statsManager.recentSessions.isEmpty {
                sectionDivider

                recentCompletionsSection
                    .padding(.horizontal, PopoverPanelStyle.outerPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
            }

            if sessionMonitor.activeSessions.isEmpty && statsManager.recentSessions.isEmpty {
                sectionDivider

                emptyState
                    .padding(.horizontal, PopoverPanelStyle.outerPadding)
                    .padding(.vertical, 12)
            }

            sectionDivider

            actionBar
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: PopoverPanelStyle.width)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(PopoverPanelStyle.panelMaterialOpacity))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(PopoverPanelStyle.panelHighlightOpacity),
                                    Color.white.opacity(0.012),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(PopoverPanelStyle.borderOpacity), lineWidth: 0.5)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        .onAppear {
            selectedOverviewRange = .sevenDays
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.026))

                Image(systemName: ClaudeDashSymbols.appBadge)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.58))
            }
            .frame(width: 22, height: 22)

            Circle()
                .fill(headerAccent)
                .frame(width: 5, height: 5)
                .shadow(color: headerAccent.opacity(0.26), radius: 2)

            Spacer()

            if statsManager.usageStreak > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(statsManager.usageStreak)d")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.032))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.04), lineWidth: 0.5)
                        )
                )
            }
        }
    }

    // MARK: - Trend Overview

    private var selectedOverviewSnapshot: StatsManager.RangeSnapshot {
        statsManager.snapshot(forLastDays: selectedOverviewRange.days)
    }

    private var overviewSection: some View {
        VStack(spacing: 8) {
            popoverQuickRangeBar

            PopoverTrendHero(data: selectedOverviewSnapshot.dailySummaries)
                .frame(maxWidth: .infinity)
                .popoverSurfaceBackground(cornerRadius: 14)
        }
    }

    private var popoverQuickRangeBar: some View {
        HStack(spacing: 6) {
            ForEach(PopoverQuickRange.allCases) { range in
                Button {
                    selectedOverviewRange = range
                } label: {
                    Text(range.title)
                        .font(.system(size: 11, weight: selectedOverviewRange == range ? .semibold : .medium))
                        .foregroundStyle(
                            selectedOverviewRange == range
                                ? Color.primary
                                : Color.primary.opacity(PopoverPanelStyle.secondaryTextOpacity)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            if selectedOverviewRange == range {
                                Capsule()
                                    .fill(Color.white.opacity(PopoverPanelStyle.selectedPillOpacity))
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .popoverSurfaceBackground(cornerRadius: 12)
        .padding(4)
    }

    // MARK: - Active Sessions

    private var activeSessionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Active", count: sessionMonitor.activeSessions.count, accent: .yellow)

            ForEach(sessionMonitor.activeSessions.prefix(3)) { session in
                ActiveSessionRow(session: session)
            }
        }
    }

    // MARK: - Recent Completions

    private var recentCompletionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Recent", accent: .green)

            ForEach(statsManager.recentSessions.suffix(3)) { session in
                RecentSessionRow(session: session)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: ClaudeDashSymbols.appBadge)
                .font(.system(size: 20))
                .foregroundStyle(.quaternary)

            VStack(alignment: .leading, spacing: 2) {
                Text("No sessions yet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Start a task to light this up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(PopoverPanelStyle.tertiaryTextOpacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .popoverSurfaceBackground(cornerRadius: 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 4) {
            actionButton(icon: "chart.bar.fill", label: "Charts", prominence: .primary, showsLabel: false, action: onOpenStats)
            actionButton(
                icon: ClaudeDashSymbols.panelAction,
                label: isMascotEnabled ? "Mascot" : "Panel",
                prominence: isMascotEnabled ? .primary : .regular,
                showsLabel: false,
                action: onTogglePanel
            )
            actionButton(icon: "gearshape", label: "Settings", showsLabel: false, action: onOpenSettings)
            actionButton(icon: ClaudeDashSymbols.quitAction, label: "Quit", showsLabel: false, action: onQuit)
        }
        .padding(4)
        .popoverSurfaceBackground(cornerRadius: 16)
    }

    // MARK: - Helpers

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(PopoverPanelStyle.dividerOpacity))
            .frame(height: 0.5)
            .padding(.horizontal, 10)
    }

    private func sectionLabel(_ title: String, count: Int? = nil, accent: Color = .primary) -> some View {
        HStack(spacing: PopoverPanelStyle.sectionLabelSpacing) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)

            Text(title.uppercased())
                .font(PopoverPanelStyle.sectionTitleFont)
                .foregroundStyle(.primary.opacity(PopoverPanelStyle.secondaryTextOpacity))
                .tracking(0.55)

            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(PopoverPanelStyle.tertiaryTextOpacity))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(PopoverPanelStyle.subtlePillOpacity)))
            }
        }
    }

    private var headerAccent: Color {
        if !sessionMonitor.activeSessions.isEmpty {
            .green
        } else if statsManager.todayCompletionCount > 0 {
            .claudeCyan
        } else {
            .white.opacity(0.5)
        }
    }

    private enum ActionProminence {
        case regular
        case primary
    }

    private func actionButton(
        icon: String,
        label: String,
        prominence: ActionProminence = .regular,
        showsLabel: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: showsLabel ? 4 : 0) {
                Image(systemName: icon)
                    .font(.system(size: 11))

                if showsLabel {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
            .background {
                if prominence == .primary {
                    Capsule()
                        .fill(Color.white.opacity(PopoverPanelStyle.selectedPillOpacity))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(PopoverPanelStyle.surfaceStrokeOpacity), lineWidth: 0.5)
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .help(label)
        .buttonStyle(.plain)
        .foregroundStyle(prominence == .primary ? Color.primary : Color.primary.opacity(0.72))
    }
}

private struct PopoverTrendHero: View {
    let data: [DailySummary]
    @State private var lineRevealProgress: Double = 0.18
    @State private var hoveredIndex: Int?

    private struct AnimatedTrendPoint: Identifiable {
        let id: String
        let label: String
        let value: Double
    }

    private var animatedData: [AnimatedTrendPoint] {
        data.map { day in
            AnimatedTrendPoint(
                id: day.dateString,
                label: day.shortDateLabel,
                value: Double(day.totalTokens) * lineRevealProgress
            )
        }
    }

    private var yAxisUpperBound: Double {
        max(Double(data.map(\.totalTokens).max() ?? 0), 1) * 1.15
    }

    private var dataSignature: String {
        data.map { "\($0.dateString):\($0.totalTokens)" }
            .joined(separator: "|")
    }

    private var hoveredDay: DailySummary? {
        guard let hoveredIndex, data.indices.contains(hoveredIndex) else { return nil }
        return data[hoveredIndex]
    }

    private var hoveredAnimatedPoint: AnimatedTrendPoint? {
        guard let hoveredIndex, animatedData.indices.contains(hoveredIndex) else { return nil }
        return animatedData[hoveredIndex]
    }

    var body: some View {
        Chart(animatedData) { point in
            AreaMark(
                x: .value("Day", point.label),
                y: .value("Tokens", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.claudeCyan.opacity(0.28),
                        Color.claudePurple.opacity(0.14),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Day", point.label),
                y: .value("Tokens", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.claudeCyan, .claudePurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))

            if point.id == hoveredAnimatedPoint?.id {
                RuleMark(x: .value("Day", point.label))
                    .foregroundStyle(Color.white.opacity(0.14))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("Day", point.label),
                    y: .value("Tokens", point.value)
                )
                .foregroundStyle(Color.white)
                .symbolSize(52)
                .annotation(position: .top, spacing: 8) {
                    if let hoveredDay {
                        hoverCallout(hoveredDay)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
            } else if hoveredIndex == nil && point.id == data.last?.dateString {
                PointMark(
                    x: .value("Day", point.label),
                    y: .value("Tokens", point.value)
                )
                .foregroundStyle(Color.claudeCyan)
                .symbolSize(30)
            }
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: 0...yAxisUpperBound)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.35, dash: [2, 3]))
                    .foregroundStyle(Color.white.opacity(0.07))

                AxisValueLabel(formattedTokenAxisValue(value.as(Double.self) ?? 0))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.primary.opacity(0.34))
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(Color.clear)
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredIndex = hoveredIndex(
                                for: location,
                                proxy: proxy,
                                geometry: geometry
                            )
                        case .ended:
                            hoveredIndex = nil
                        }
                    }
            }
        }
        .frame(height: 104)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .onAppear(perform: restartRevealAnimation)
        .onChange(of: dataSignature) {
            restartRevealAnimation()
        }
        .animation(.easeOut(duration: 0.14), value: hoveredIndex)
    }

    private func restartRevealAnimation() {
        lineRevealProgress = 0.18
        withAnimation(.easeOut(duration: 0.42)) {
            lineRevealProgress = 1
        }
    }

    private func formattedTokenAxisValue(_ value: Double) -> String {
        Int(value.rounded()).tokenFormatted
    }

    private func hoveredIndex(
        for location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) -> Int? {
        guard !data.isEmpty else { return nil }

        guard let plotFrameAnchor = proxy.plotFrame else { return nil }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else { return nil }

        if data.count == 1 {
            return 0
        }

        let relativeX = min(max(location.x - plotFrame.minX, 0), plotFrame.width)
        let step = plotFrame.width / CGFloat(max(data.count - 1, 1))
        let rawIndex = Int((relativeX / step).rounded())
        return min(max(rawIndex, 0), data.count - 1)
    }

    private func hoverCallout(_ day: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.shortDateLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.68))

            Text("\(day.totalTokens.tokenFormatted) tokens")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("\(day.completionCount) sessions")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary.opacity(0.55))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Active Session Row

struct ActiveSessionRow: View {
    let session: ActiveSession
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.5), radius: 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    BrandIcon(source: session.source, size: 11)
                        .foregroundStyle(session.source.brandColor)
                    Text(session.project)
                        .font(PopoverPanelStyle.rowTitleFont)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(elapsedTime)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary.opacity(PopoverPanelStyle.secondaryTextOpacity))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(PopoverPanelStyle.subtlePillOpacity)))
                }

                HStack(spacing: 7) {
                    CompactMetricStrip(
                        icon: "waveform",
                        progress: max(session.tokenUsage, 0.12),
                        color: statusColor
                    )
                    CompactMetricStrip(
                        icon: "clock",
                        progress: elapsedProgress,
                        color: .white.opacity(0.82)
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    Color.white.opacity(
                        isHovered
                            ? PopoverPanelStyle.rowHoverFillOpacity
                            : PopoverPanelStyle.rowFillOpacity
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(PopoverPanelStyle.rowStrokeOpacity), lineWidth: 0.5)
                }
        }
        .brightness(isHovered ? 0.03 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var statusColor: Color {
        switch session.status {
        case .thinking: return .yellow
        case .toolRunning: return .blue
        case .completed: return .green
        case .unknown: return .gray
        }
    }

    private var elapsedTime: String {
        let seconds = Int(-session.startTime.timeIntervalSinceNow)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var elapsedProgress: Double {
        min(Double(Int(-session.startTime.timeIntervalSinceNow)) / 3600.0, 1.0)
    }
}


// MARK: - Mini Token Bar

struct MiniTokenBar: View {
    let usage: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                Capsule()
                    .fill(barColor)
                    .frame(width: max(0, geo.size.width * min(usage, 1.0)))
            }
        }
        .frame(height: 3)
    }

    private var barColor: Color {
        if usage < 0.5 { return .green.opacity(0.7) }
        if usage < 0.8 { return .yellow.opacity(0.7) }
        return .red.opacity(0.8)
    }
}

// MARK: - Recent Session Row

struct RecentSessionRow: View {
    let session: SessionRecord
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            BrandIcon(source: session.source, size: 11)
                .foregroundStyle(session.source.brandColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.project)
                        .font(PopoverPanelStyle.rowTitleFont)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(session.cost.usdFormatted)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.78))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(PopoverPanelStyle.subtlePillOpacity)))
                }

                HStack(spacing: 7) {
                    CompactMetricStrip(
                        icon: "clock",
                        progress: durationProgress,
                        color: .blue
                    )
                    CompactMetricStrip(
                        icon: "dollarsign",
                        progress: costProgress,
                        color: .orange
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    Color.white.opacity(
                        isHovered
                            ? PopoverPanelStyle.rowHoverFillOpacity
                            : PopoverPanelStyle.rowFillOpacity
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(PopoverPanelStyle.rowStrokeOpacity), lineWidth: 0.5)
                }
        }
        .brightness(isHovered ? 0.03 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var durationProgress: Double {
        min(Double(session.durationMs) / 3_600_000.0, 1.0)
    }

    private var costProgress: Double {
        min(session.cost / 20.0, 1.0)
    }
}

private struct CompactMetricStrip: View {
    let icon: String
    let progress: Double
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(color.opacity(0.88))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))

                    Capsule()
                        .fill(color.opacity(0.88))
                        .frame(width: max(proxy.size.width * min(max(progress, 0.08), 1.0), 6))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PopoverStatCard (compat)

struct PopoverStatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    var trend: Int? = nil
    var trendDouble: Double? = nil

    var body: some View {
        GlassMetricCard(
            icon: icon,
            value: value,
            label: label,
            accentColor: color,
            trend: trend,
            trendDouble: trendDouble
        )
    }
}

// MARK: - PopoverActionButton (compat)

struct PopoverActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}

private extension View {
    func popoverSurfaceBackground(cornerRadius: CGFloat = 12) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(PopoverPanelStyle.surfaceFillOpacity))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(PopoverPanelStyle.surfaceStrokeOpacity), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Date Extension

extension Date {
    var timeAgo: String {
        let seconds = Int(-self.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}

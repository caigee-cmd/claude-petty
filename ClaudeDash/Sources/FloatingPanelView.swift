// FloatingPanelView.swift
// ClaudeDash - Compact mascot island with hover task list

import SwiftUI

enum FloatingPanelMotionAuthority: Equatable {
    case capsule
}

enum FloatingPanelMotionRules {
    static let authority: FloatingPanelMotionAuthority = .capsule
    static let allowsDetachedTopHighlight = false
    static let allowsGreenShellAccent = false
    static let allowsIndependentRowShimmer = false
    static let allowsIndependentRowGlow = false
    static let allowsIndependentDotPulse = false
}

struct FloatingPanelMotionField {
    let breathPhase: Double
    let flowProgress: Double
    let accentBlend: Double
    let rowLiftProgress: Double
    let dotHaloProgress: Double
    let idleTypingProgress: Double
    let hasLiveActivity: Bool

    init(time: Double, hasLiveActivity: Bool) {
        breathPhase = (sin(time * 0.9) + 1) / 2
        flowProgress = time * 0.16
        accentBlend = (sin(time * 0.45 + .pi / 3) + 1) / 2
        rowLiftProgress = (sin(time * 0.9 + .pi / 6) + 1) / 2
        dotHaloProgress = (sin(time * 0.9 + .pi / 2) + 1) / 2
        idleTypingProgress = time * 2.1
        self.hasLiveActivity = hasLiveActivity
    }

    var wrappedFlowProgress: Double {
        flowProgress - floor(flowProgress)
    }

    var idleTypingStep: Int {
        Int(idleTypingProgress).quotientAndRemainder(dividingBy: 4).remainder
    }

    var idleTypingFraction: Double {
        idleTypingProgress - floor(idleTypingProgress)
    }
}

struct FloatingPanelShellStyle {
    let accentColor: Color
    let borderOpacity: Double
    let baseShadowOpacity: Double
    let usesDetachedTopHighlight: Bool
    let usesGreenShellAccent: Bool

    init(field: FloatingPanelMotionField, hasToolRunning: Bool, hasThinking _: Bool) {
        accentColor = hasToolRunning ? .claudeCyan : .claudePurple
        borderOpacity = 0.07 + (field.breathPhase * 0.025)
        baseShadowOpacity = 0.04
        usesDetachedTopHighlight = false
        usesGreenShellAccent = false
    }
}

struct FloatingMascotStageStyle {
    let usesTransparentStage: Bool
    let showsGlassShell: Bool
    let groundShadowOpacity: Double

    init(field: FloatingPanelMotionField, accentColor _: Color) {
        usesTransparentStage = true
        showsGlassShell = false
        groundShadowOpacity = 0.05 + (field.breathPhase * 0.01)
    }
}

struct FloatingTaskBubbleStyle {
    let size: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let shadowOpacity: Double
    let haloOpacity: Double
    let ringOpacity: Double

    init(taskCount _: Int) {
        size = 22
        offsetX = 7
        offsetY = -4
        shadowOpacity = 0.22
        haloOpacity = 0.14
        ringOpacity = 0.30
    }
}

struct IslandSessionRowStyle {
    let usesIndependentShimmer: Bool
    let usesIndependentDualGlow: Bool
    let usesIndependentDotPulse: Bool
    let usesCapsuleDrivenLift: Bool
    let rowLiftOpacity: Double
    let rowTintOpacity: Double
    let rowVerticalOffset: CGFloat
    let waveOpacity: Double
    let waveHighlightOpacity: Double
    let waveWidth: CGFloat
    let waveTravel: Double
    let dotHaloOpacity: Double
    let dotHaloScaleUpperBound: Double
    let timerOpacity: Double
    let toolIconOpacity: Double

    init(status: SessionStatus, field: FloatingPanelMotionField) {
        let isActive = status == .thinking || status == .toolRunning
        let isToolRunning = status == .toolRunning
        usesIndependentShimmer = false
        usesIndependentDualGlow = false
        usesIndependentDotPulse = false
        usesCapsuleDrivenLift = isActive
        rowLiftOpacity = isActive ? (0.025 + field.rowLiftProgress * 0.03) : 0
        rowTintOpacity = isActive
            ? ((isToolRunning ? 0.042 : 0.030) + field.rowLiftProgress * 0.02)
            : 0
        rowVerticalOffset = isActive ? CGFloat(-0.5 - field.rowLiftProgress * 0.7) : 0
        waveOpacity = isActive ? (isToolRunning ? 0.07 : 0.05) : 0
        waveHighlightOpacity = isActive ? (isToolRunning ? 0.10 : 0.07) : 0
        waveWidth = isToolRunning ? 56 : 46
        waveTravel = field.wrappedFlowProgress
        dotHaloOpacity = isActive
            ? ((isToolRunning ? 0.09 : 0.06) + field.dotHaloProgress * (isToolRunning ? 0.04 : 0.03))
            : 0
        dotHaloScaleUpperBound = isToolRunning ? 1.22 : 1.16
        timerOpacity = 0.34
        toolIconOpacity = isToolRunning ? 0.68 : 0.64
    }
}

struct FloatingPanelView: View {
    @EnvironmentObject var sessionMonitor: SessionMonitor
    @AppStorage(
        FloatingMascotAppearanceOption.userDefaultsKey,
        store: ClaudeDashDefaults.shared
    ) private var mascotAppearanceRawValue = FloatingMascotAppearanceOption.runner.rawValue
    @AppStorage(
        FloatingMascotSizeOption.userDefaultsKey,
        store: ClaudeDashDefaults.shared
    ) private var mascotSizeRawValue = FloatingMascotSizeOption.extraLarge.rawValue
    @ObservedObject var interactionModel: FloatingPanelInteractionModel

    init(interactionModel: FloatingPanelInteractionModel) {
        self.interactionModel = interactionModel
    }

    private var allSessions: [ActiveSession] {
        sessionMonitor.activeSessions
    }

    private var visibleSessions: [ActiveSession] {
        Array(
            allSessions.prefix(
                FloatingPanelLayout.visibleSessionCount(
                    for: interactionModel.displayMode,
                    totalSessionCount: taskCount
                )
            )
        )
    }

    private var taskCount: Int {
        allSessions.count
    }

    private var mascotSizeOption: FloatingMascotSizeOption {
        FloatingMascotSizeOption(rawValue: mascotSizeRawValue) ?? .extraLarge
    }

    private var mascotAppearanceOption: FloatingMascotAppearanceOption {
        FloatingMascotAppearanceOption(rawValue: mascotAppearanceRawValue) ?? .runner
    }

    private var mascotSize: CGFloat {
        FloatingPanelLayout.mascotSize(for: mascotSizeOption)
    }

    private var compactIslandSize: CGSize {
        FloatingPanelLayout.compactIslandSize(for: mascotSizeOption)
    }

    private var hiddenPreviewCount: Int {
        max(taskCount - visibleSessions.count, 0)
    }

    private var hasThinking: Bool {
        allSessions.contains { $0.status == .thinking }
    }

    private var hasToolRunning: Bool {
        allSessions.contains { $0.status == .toolRunning }
    }

    private var hasLiveActivity: Bool {
        hasThinking || hasToolRunning
    }

    private var showsTaskList: Bool {
        interactionModel.displayMode != .compact
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / FloatingPanelTransition.targetFPS)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let field = FloatingPanelMotionField(time: time, hasLiveActivity: hasLiveActivity)
                let hostSize = proxy.size
                let previewSurfaceHeight = FloatingPanelLayout.previewSurfaceHeight(
                    forVisibleRows: visibleSessions.count,
                    isIdle: visibleSessions.isEmpty
                )
                let previewOffsetY = FloatingPanelLayout.previewSurfaceVerticalOffset(
                    hostHeight: hostSize.height,
                    surfaceHeight: previewSurfaceHeight
                )
                let canShowTaskList = showsTaskList
                    && hostSize.width > compactIslandSize.width

                ZStack(alignment: .topTrailing) {
                    Group {
                        if canShowTaskList {
                            taskListPanel(now: context.date, field: field, hostSize: hostSize)
                                .offset(
                                    x: -(compactIslandSize.width + FloatingPanelLayout.previewPanelGap),
                                    y: interactionModel.displayMode == .hoverList ? previewOffsetY : 6
                                )
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .trailing)),
                                        removal: .opacity
                                    )
                                )
                                .zIndex(0)
                        }
                    }
                    .animation(FloatingPanelTransition.swiftUIAnimation, value: interactionModel.displayMode)

                    mascotIsland(field: field)
                        .zIndex(1)
                }
                .frame(width: hostSize.width, height: hostSize.height, alignment: .topTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .contentShape(Rectangle())
            }
        }
        .contextMenu {
            if interactionModel.displayMode == .expanded {
                Button("Collapse Panel") {
                    interactionModel.collapseExpandedPanel()
                }
            }

            Button("Close Panel") {
                NotificationCenter.default.post(name: .hideFloatingPanel, object: nil)
            }
        }
    }

    private func mascotIsland(field: FloatingPanelMotionField) -> some View {
        let stageStyle = FloatingMascotStageStyle(
            field: field,
            accentColor: hasToolRunning ? .claudeCyan : .claudePurple
        )
        let stageSide = compactIslandSize.width
        let shadowWidth = max(64, mascotSize * 0.82) + (CGFloat(field.breathPhase) * 8)
        let shadowHeight = 12 + (CGFloat(field.breathPhase) * 1.2)
        let shadowOffsetY = (stageSide * 0.34) - 2

        return ZStack {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(stageStyle.groundShadowOpacity))
                    .frame(
                        width: shadowWidth,
                        height: shadowHeight
                    )
                    .blur(radius: 12)
                    .offset(y: shadowOffsetY)

                FloatingMascotLottieView(
                    appearance: mascotAppearanceOption,
                    playbackState: interactionModel.mascotPlaybackState
                )
                    .frame(width: mascotSize, height: mascotSize)
                    .scaleEffect(0.98 + (Double(interactionModel.tapBoostCount) * 0.02))

                FloatingMascotInteractionSurface {
                    interactionModel.handleMascotTap()
                } onDragStateChanged: { isDragging in
                    interactionModel.setDraggingMascot(isDragging)
                }
                .frame(
                    width: compactIslandSize.width,
                    height: compactIslandSize.height
                )
            }
            .frame(width: compactIslandSize.width, height: compactIslandSize.height)
        }
        .frame(width: compactIslandSize.width, height: compactIslandSize.height)
        .contentShape(Rectangle())
        .onHover { interactionModel.setHoveringMascot($0) }
        .help("点击精灵可以临时加速动画")
    }

    private func taskListPanel(
        now: Date,
        field: FloatingPanelMotionField,
        hostSize: CGSize
    ) -> some View {
        let isHoverPreview = interactionModel.displayMode == .hoverList
        let shape = RoundedRectangle(
            cornerRadius: isHoverPreview ? 22 : 26,
            style: .continuous
        )
        let style = FloatingPanelShellStyle(
            field: field,
            hasToolRunning: hasToolRunning,
            hasThinking: hasThinking
        )
        let surfaceWidth = max(
            hostSize.width - compactIslandSize.width - FloatingPanelLayout.previewPanelGap,
            0
        )
        let surfaceHeight = isHoverPreview
            ? FloatingPanelLayout.previewSurfaceHeight(
                forVisibleRows: visibleSessions.count,
                isIdle: visibleSessions.isEmpty
            )
            : max(hostSize.height - 10, compactIslandSize.height - 10)
        let stackSpacing = isHoverPreview ? FloatingPanelLayout.previewSectionSpacing : 8
        let contentPadding = isHoverPreview ? FloatingPanelLayout.previewContentPadding : FloatingPanelLayout.panelContentPadding

        return VStack(alignment: .leading, spacing: stackSpacing) {
            if !isHoverPreview {
                taskListHeader
            }

            if visibleSessions.isEmpty {
                idleState(field: field)
            } else if isHoverPreview {
                VStack(spacing: FloatingPanelLayout.previewRowSpacing) {
                    ForEach(Array(visibleSessions.enumerated()), id: \.element.id) { index, session in
                        HoverPreviewSessionPill(
                            session: session,
                            isTruncated: index == 0 && hiddenPreviewCount > 0
                        )
                    }
                }
            } else {
                VStack(spacing: FloatingPanelLayout.rowSpacing) {
                    ForEach(visibleSessions) { session in
                        IslandSessionRow(
                            session: session,
                            now: now,
                            field: field,
                            displayMode: interactionModel.displayMode
                        )
                    }
                }
            }
        }
        .padding(contentPadding)
        .frame(width: surfaceWidth, height: surfaceHeight, alignment: .topLeading)
        .contentShape(shape)
        .onHover { interactionModel.setHoveringTaskPanel($0) }
        .onTapGesture {
            guard isHoverPreview else { return }
            interactionModel.toggleExpanded()
        }
        .background {
            shape
                .fill(.thinMaterial.opacity(0.86))
                .overlay {
                    shape.fill(
                        Color(red: 0.78, green: 0.82, blue: 0.90)
                            .opacity(0.05 + field.breathPhase * 0.01)
                    )
                }
                .overlay {
                    shape.fill(Color.white.opacity(0.075 + field.breathPhase * 0.012))
                }
                .overlay(alignment: .top) {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.045),
                                    Color.white.opacity(0.012),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(shape)
                }
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(style.borderOpacity + 0.018),
                                style.accentColor.opacity(0.009 + field.accentBlend * 0.007),
                            ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 0.45
                    )
                }
                .overlay {
                    shape.strokeBorder(
                        Color.black.opacity(0.04),
                        lineWidth: 0.5
                    )
                }
                .shadow(color: .black.opacity(style.baseShadowOpacity), radius: 8, y: 3)
                .shadow(color: .black.opacity(0.024), radius: 14, y: 6)
        }
        .modifier(HoverPreviewHelpModifier(isEnabled: isHoverPreview))
    }

    @ViewBuilder
    private var taskListHeader: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Button {
                interactionModel.toggleExpanded()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.60))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func idleState(field: FloatingPanelMotionField) -> some View {
        let visibleDotCount = field.idleTypingStep
        let typingFraction = field.idleTypingFraction

        return HStack {
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    let isVisible = index < visibleDotCount
                    let isTrailingDot = visibleDotCount > 0 && index == visibleDotCount - 1
                    let highlight = isTrailingDot ? typingFraction : 0

                    Circle()
                        .fill(
                            Color(red: 0.38, green: 0.44, blue: 0.56)
                                .opacity(isVisible ? (0.54 + highlight * 0.18) : 0.16)
                        )
                        .frame(width: 4.5, height: 4.5)
                        .scaleEffect(isVisible ? (1 + highlight * 0.08) : 0.9)
                        .offset(y: isVisible ? -highlight * 0.7 : 0)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: interactionModel.displayMode == .hoverList
                ? FloatingPanelLayout.previewIdleHeight
                : FloatingPanelLayout.idleRowHeight,
            alignment: .center
        )
    }
}

private struct HoverPreviewHelpModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.help("点击展开完整面板")
        } else {
            content
        }
    }
}

// MARK: - Session Row

struct IslandSessionRow: View {
    let session: ActiveSession
    let now: Date
    let field: FloatingPanelMotionField
    let displayMode: FloatingPanelDisplayMode

    private var statusColor: Color {
        switch session.status {
        case .thinking: return .claudePurple
        case .toolRunning: return .claudeCyan
        case .completed: return .green
        case .unknown: return .gray
        }
    }

    private var rowStyle: IslandSessionRowStyle {
        IslandSessionRowStyle(status: session.status, field: field)
    }

    private var titleColor: Color {
        Color(red: 0.18, green: 0.24, blue: 0.35)
    }

    private var secondaryColor: Color {
        Color(red: 0.28, green: 0.34, blue: 0.46)
    }

    private var timerColor: Color {
        Color(red: 0.24, green: 0.29, blue: 0.41)
    }

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                if rowStyle.dotHaloOpacity > 0 {
                    Circle()
                        .strokeBorder(statusColor.opacity(rowStyle.dotHaloOpacity), lineWidth: 1.1)
                        .frame(width: 16, height: 16)
                        .scaleEffect(1 + field.dotHaloProgress * (rowStyle.dotHaloScaleUpperBound - 1))
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: statusColor.opacity(session.status == .unknown ? 0.12 : 0.20), radius: 2.5)
            }
            .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.project)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(secondaryColor.opacity(0.92))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if session.status == .toolRunning, session.currentTool != .unknown {
                Image(systemName: session.currentTool.sfSymbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.claudeCyan.opacity(rowStyle.toolIconOpacity))
            }

            Text(elapsedTime)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(timerColor.opacity(0.78 + rowStyle.timerOpacity * 0.18))
        }
        .padding(.horizontal, 11)
        .frame(height: FloatingPanelLayout.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                }
                .overlay {
                    if rowStyle.usesCapsuleDrivenLift {
                        rowLiftBackground
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    statusColor.opacity(rowStyle.usesCapsuleDrivenLift ? 0.08 + field.rowLiftProgress * 0.05 : 0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.7
                        )
                }
                .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
        }
        .offset(y: rowStyle.rowVerticalOffset)
    }

    private var rowLiftBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                statusColor.opacity(rowStyle.rowTintOpacity)
            )
            .overlay {
                if rowStyle.waveOpacity > 0 {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        let travelX = (width + rowStyle.waveWidth * 2) * rowStyle.waveTravel - rowStyle.waveWidth

                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            statusColor.opacity(0),
                                            statusColor.opacity(rowStyle.waveOpacity),
                                            Color.white.opacity(rowStyle.waveHighlightOpacity),
                                            statusColor.opacity(rowStyle.waveOpacity),
                                            statusColor.opacity(0),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: rowStyle.waveWidth, height: proxy.size.height - 8)
                                .blur(radius: 7)
                                .offset(x: travelX, y: 4)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        statusColor.opacity(0.07 + rowStyle.rowLiftOpacity * 0.6),
                        lineWidth: 0.55
                    )
            }
    }

    private var subtitle: String? {
        guard displayMode == .expanded else { return nil }

        if session.status == .toolRunning, session.currentTool != .unknown {
            return session.currentTool.rawValue
        }

        return nil
    }

    private var elapsedTime: String {
        let seconds = max(Int(now.timeIntervalSince(session.startTime)), 0)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct HoverPreviewSessionPill: View {
    let session: ActiveSession
    let isTruncated: Bool

    private var statusColor: Color {
        switch session.status {
        case .thinking: return .claudePurple
        case .toolRunning: return .claudeCyan
        case .completed: return .green
        case .unknown: return .gray
        }
    }

    private var compactProjectLabel: String {
        let trimmed = session.project.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Task" }
        guard trimmed.count > 13 else { return trimmed }
        return "\(trimmed.prefix(13))…"
    }

    private var titleColor: Color {
        Color(red: 0.20, green: 0.25, blue: 0.35)
    }

    private var secondaryColor: Color {
        Color(red: 0.34, green: 0.39, blue: 0.50)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.24), radius: 2)

            Text(compactProjectLabel)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(titleColor)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isTruncated {
                Text("+")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryColor.opacity(0.86))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: FloatingPanelLayout.previewRowHeight)
        .background {
            Capsule(style: .continuous)
                .fill(
                    Color(red: 0.78, green: 0.82, blue: 0.90)
                        .opacity(0.09)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.07))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.black.opacity(0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                }
                .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
        }
    }
}

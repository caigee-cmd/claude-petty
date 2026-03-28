import SwiftUI
import XCTest
@testable import ClaudeGlance

final class ClaudeDashVisualsTests: XCTestCase {
    private let mascotDefaultsKeys = [
        FloatingMascotAppearanceOption.userDefaultsKey,
        FloatingMascotSizeOption.userDefaultsKey,
        FloatingMascotAnimationSpeedOption.userDefaultsKey,
        FloatingMascotPreferences.enabledUserDefaultsKey,
        FloatingMascotPreferences.didCompleteSetupUserDefaultsKey
    ]
    private var preservedMascotDefaults: [String: Any] = [:]

    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        preserveMascotDefaults()
        resetMascotDefaults()
    }

    override func tearDownWithError() throws {
        restoreMascotDefaults()
        try super.tearDownWithError()
    }

    private func makeActiveSession(status: SessionStatus) -> ActiveSession {
        var session = ActiveSession(
            project: "ClaudeDash",
            transcriptPath: "/tmp/\(UUID().uuidString).jsonl"
        )
        session.status = status
        return session
    }

    private func preserveMascotDefaults() {
        preservedMascotDefaults = [:]
        let defaults = ClaudeDashDefaults.shared

        for key in mascotDefaultsKeys {
            if let value = defaults.object(forKey: key) {
                preservedMascotDefaults[key] = value
            }
        }
    }

    private func resetMascotDefaults() {
        let defaults = ClaudeDashDefaults.shared
        defaults.set(FloatingMascotAppearanceOption.runner.rawValue, forKey: FloatingMascotAppearanceOption.userDefaultsKey)
        defaults.set(FloatingMascotSizeOption.extraLarge.rawValue, forKey: FloatingMascotSizeOption.userDefaultsKey)
        defaults.set(
            FloatingMascotAnimationSpeedOption.normal.rawValue,
            forKey: FloatingMascotAnimationSpeedOption.userDefaultsKey
        )
        defaults.set(false, forKey: FloatingMascotPreferences.enabledUserDefaultsKey)
        defaults.set(false, forKey: FloatingMascotPreferences.didCompleteSetupUserDefaultsKey)
    }

    private func restoreMascotDefaults() {
        let defaults = ClaudeDashDefaults.shared

        for key in mascotDefaultsKeys {
            if let value = preservedMascotDefaults[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        preservedMascotDefaults = [:]
    }

    func testNotificationTitleUsesPlainTextWithoutEmoji() {
        XCTAssertEqual(ClaudeDashCopy.notificationTitle, "Claude Code Task Complete")
    }

    func testPrimarySymbolsUseUpdatedSet() {
        XCTAssertEqual(ClaudeDashSymbols.appBadge, "circle.grid.2x2.fill")
        XCTAssertEqual(ClaudeDashSymbols.panelAction, "pip")
        XCTAssertEqual(ClaudeDashSymbols.quitAction, "xmark.circle")
        XCTAssertEqual(ClaudeDashSymbols.monitorTab, "waveform.path.ecg")
        XCTAssertEqual(ClaudeDashSymbols.monitorEmptyState, "dot.radiowaves.left.and.right.slash")
        XCTAssertEqual(ClaudeDashSymbols.monitorSelectionState, "rectangle.stack")
        XCTAssertEqual(ClaudeDashSymbols.totalCost, "dollarsign.circle")
        XCTAssertEqual(ClaudeDashSymbols.model, "square.stack.3d.up")
    }

    func testMascotAppearanceOptionsExposeExpectedTitlesAndUniqueResources() {
        XCTAssertEqual(
            FloatingMascotAppearanceOption.allCases.map(\.title),
            ["跑步", "喝水", "躲藏", "篮球", "吉他", "萨克斯", "惊讶", "气球"]
        )

        let resourceNames = FloatingMascotAppearanceOption.allCases.map(\.resourceName)
        XCTAssertEqual(Set(resourceNames).count, resourceNames.count)
        XCTAssertTrue(resourceNames.contains("sweet-run-cycle"))
        XCTAssertTrue(resourceNames.contains("cat-hide"))
    }

    func testFloatingPanelRulesUseCapsuleAsOnlyMotionAuthority() {
        XCTAssertEqual(FloatingPanelMotionRules.authority, .capsule)
    }

    func testFloatingPanelRulesDisallowDetachedTopHighlightAndGreenShellAccent() {
        XCTAssertFalse(FloatingPanelMotionRules.allowsDetachedTopHighlight)
        XCTAssertFalse(FloatingPanelMotionRules.allowsGreenShellAccent)
    }

    func testFloatingPanelRulesDisallowIndependentRowAndDotMotion() {
        XCTAssertFalse(FloatingPanelMotionRules.allowsIndependentRowShimmer)
        XCTAssertFalse(FloatingPanelMotionRules.allowsIndependentRowGlow)
        XCTAssertFalse(FloatingPanelMotionRules.allowsIndependentDotPulse)
    }

    func testFloatingPanelVisibilityRulesTreatOnlyThinkingAndToolRunningAsRunning() {
        XCTAssertFalse(
            FloatingPanelVisibilityRules.hasRunningSessions([
                makeActiveSession(status: .completed),
                makeActiveSession(status: .unknown),
            ])
        )
        XCTAssertTrue(
            FloatingPanelVisibilityRules.hasRunningSessions([
                makeActiveSession(status: .thinking),
            ])
        )
        XCTAssertTrue(
            FloatingPanelVisibilityRules.hasRunningSessions([
                makeActiveSession(status: .toolRunning),
            ])
        )
    }

    func testFloatingPanelVisibilityRulesAutoHideOnlyWhenAutoPresentedAndNoRunningSessions() {
        let idleSessions = [
            makeActiveSession(status: .completed),
            makeActiveSession(status: .unknown),
        ]

        XCTAssertTrue(
            FloatingPanelVisibilityRules.shouldAutoHide(
                isVisible: true,
                isManuallyPresented: false,
                sessions: idleSessions
            )
        )
        XCTAssertFalse(
            FloatingPanelVisibilityRules.shouldAutoHide(
                isVisible: true,
                isManuallyPresented: true,
                sessions: idleSessions
            )
        )
    }

    func testFloatingPanelMotionFieldProvidesNormalizedCapsuleOwnedValues() {
        let field = FloatingPanelMotionField(time: 10, hasLiveActivity: true)

        XCTAssertGreaterThanOrEqual(field.breathPhase, 0)
        XCTAssertLessThanOrEqual(field.breathPhase, 1)
        XCTAssertGreaterThanOrEqual(field.accentBlend, 0)
        XCTAssertLessThanOrEqual(field.accentBlend, 1)
        XCTAssertTrue(field.hasLiveActivity)
    }

    func testFloatingPanelMotionFieldDoesNotExposeRowOrDotLocalTimeFlags() {
        let mirror = String(
            describing: Mirror(reflecting: FloatingPanelMotionField(time: 10, hasLiveActivity: true))
                .children
                .map(\.label)
        )

        XCTAssertFalse(mirror.contains("rowTime"))
        XCTAssertFalse(mirror.contains("dotTime"))
    }

    func testFloatingPanelShellStyleNeverUsesGreenShellAccent() {
        let style = FloatingPanelShellStyle(
            field: FloatingPanelMotionField(time: 12, hasLiveActivity: false),
            hasToolRunning: false,
            hasThinking: false
        )

        XCTAssertFalse(style.usesGreenShellAccent)
        XCTAssertNotEqual(style.accentColor, .green)
    }

    func testFloatingPanelShellStyleDisablesDetachedTopHighlight() {
        let style = FloatingPanelShellStyle(
            field: FloatingPanelMotionField(time: 12, hasLiveActivity: true),
            hasToolRunning: true,
            hasThinking: false
        )

        XCTAssertFalse(style.usesDetachedTopHighlight)
    }

    func testFloatingPanelShellStyleUsesRestrainedShadowWeight() {
        let activeStyle = FloatingPanelShellStyle(
            field: FloatingPanelMotionField(time: 12, hasLiveActivity: true),
            hasToolRunning: true,
            hasThinking: false
        )
        let idleStyle = FloatingPanelShellStyle(
            field: FloatingPanelMotionField(time: 12, hasLiveActivity: false),
            hasToolRunning: false,
            hasThinking: false
        )

        XCTAssertEqual(activeStyle.baseShadowOpacity, 0.04, accuracy: 0.001)
        XCTAssertEqual(idleStyle.baseShadowOpacity, 0.04, accuracy: 0.001)
    }

    func testFloatingPanelShellStyleKeepsIdleAndCompletionStatesInShellPalette() {
        let idleStyle = FloatingPanelShellStyle(
            field: FloatingPanelMotionField(time: 12, hasLiveActivity: false),
            hasToolRunning: false,
            hasThinking: false
        )
        let completionStyle = FloatingPanelShellStyle(
            field: FloatingPanelMotionField(time: 12, hasLiveActivity: false),
            hasToolRunning: false,
            hasThinking: false
        )

        XCTAssertNotEqual(idleStyle.accentColor, .green)
        XCTAssertNotEqual(completionStyle.accentColor, .green)
    }

    func testIslandSessionRowStyleUsesCapsuleDrivenLiftWithoutIndependentShimmer() {
        let style = IslandSessionRowStyle(
            status: .thinking,
            field: FloatingPanelMotionField(time: 20, hasLiveActivity: true)
        )

        XCTAssertFalse(style.usesIndependentShimmer)
        XCTAssertFalse(style.usesIndependentDualGlow)
        XCTAssertTrue(style.usesCapsuleDrivenLift)
        XCTAssertGreaterThan(style.rowLiftOpacity, 0)
    }

    func testIslandSessionRowStyleKeepsDotHaloTightAndCapsuleDriven() {
        let style = IslandSessionRowStyle(
            status: .toolRunning,
            field: FloatingPanelMotionField(time: 20, hasLiveActivity: true)
        )

        XCTAssertFalse(style.usesIndependentDotPulse)
        XCTAssertLessThanOrEqual(style.dotHaloScaleUpperBound, 1.28)
        XCTAssertGreaterThan(style.dotHaloOpacity, 0)
    }

    func testIslandSessionRowStyleKeepsTimerAndToolIconStable() {
        let thinkingStyle = IslandSessionRowStyle(
            status: .thinking,
            field: FloatingPanelMotionField(time: 20, hasLiveActivity: true)
        )
        let toolStyle = IslandSessionRowStyle(
            status: .toolRunning,
            field: FloatingPanelMotionField(time: 20, hasLiveActivity: true)
        )

        XCTAssertEqual(thinkingStyle.timerOpacity, 0.34, accuracy: 0.001)
        XCTAssertEqual(toolStyle.timerOpacity, 0.34, accuracy: 0.001)
        XCTAssertEqual(toolStyle.toolIconOpacity, 0.68, accuracy: 0.001)
    }

    func testCompletedRowKeepsGreenLocalWithoutChangingShellRules() {
        let rowStyle = IslandSessionRowStyle(
            status: .completed,
            field: FloatingPanelMotionField(time: 20, hasLiveActivity: false)
        )
        let shellStyle = FloatingPanelShellStyle(
            field: FloatingPanelMotionField(time: 20, hasLiveActivity: false),
            hasToolRunning: false,
            hasThinking: false
        )

        XCTAssertEqual(rowStyle.rowLiftOpacity, 0, accuracy: 0.001)
        XCTAssertFalse(shellStyle.usesGreenShellAccent)
    }

    func testMascotStageUsesTransparentPresentationWithoutGlassShell() {
        let stageStyle = FloatingMascotStageStyle(
            field: FloatingPanelMotionField(time: 12, hasLiveActivity: true),
            accentColor: .claudePurple
        )

        XCTAssertTrue(stageStyle.usesTransparentStage)
        XCTAssertFalse(stageStyle.showsGlassShell)
        XCTAssertGreaterThan(stageStyle.groundShadowOpacity, 0)
    }

    func testMascotStageKeepsGroundShadowVeryLight() {
        let stageStyle = FloatingMascotStageStyle(
            field: FloatingPanelMotionField(time: 12, hasLiveActivity: true),
            accentColor: .claudePurple
        )

        XCTAssertLessThanOrEqual(stageStyle.groundShadowOpacity, 0.12)
    }

    func testMascotSurfaceNoLongerUsesTaskBubbleBadge() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("taskBadge"))
    }

    func testFloatingMascotLottieSourceUsesOfficialLottieFramework() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingMascotLottieView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("import Lottie"))
        XCTAssertFalse(source.contains("import WebKit"))
    }

    func testStatsTrendBadgeKeepsCurrencyAmountsOnSingleLine() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/StatsDetailView.swift")
        let source = try String(contentsOf: sourceURL)

        let trendBadgeSection = try XCTUnwrap(
            source.components(separatedBy: "private func trendBadge(direction: Int, text: String) -> some View {")
                .dropFirst()
                .first?
                .components(separatedBy: "private func tokenOverviewCard")
                .first
        )

        XCTAssertTrue(trendBadgeSection.contains(".monospacedDigit()"))
        XCTAssertTrue(trendBadgeSection.contains(".lineLimit(1)"))
        XCTAssertTrue(trendBadgeSection.contains(".minimumScaleFactor("))
    }

    func testStatsOverviewRightRailGivesMetricTextStableSingleLineLayout() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/StatsDetailView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains(".frame(width: 220)"))

        let detailCardSection = try XCTUnwrap(
            source.components(separatedBy: "private func detailStatCard(")
                .dropFirst()
                .first?
                .components(separatedBy: "private func trendBadge")
                .first
        )

        XCTAssertTrue(detailCardSection.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        XCTAssertTrue(detailCardSection.contains(".layoutPriority(1)"))
        XCTAssertTrue(detailCardSection.contains(".lineLimit(1)"))
    }

    func testWeekComparisonCardsUseLabeledLastWeekMetadataInsteadOfRawPrevCopy() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/WeekComparisonView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("prev:"))
        XCTAssertTrue(source.contains("Text(\"Last week\")"))

        let comparisonCardSection = try XCTUnwrap(
            source.components(separatedBy: "private func comparisonCard(")
                .dropFirst()
                .first?
                .components(separatedBy: "private func miniComparison")
                .first
        )

        XCTAssertTrue(comparisonCardSection.contains("VStack(alignment: .leading"))
        XCTAssertTrue(comparisonCardSection.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        XCTAssertTrue(comparisonCardSection.contains("Spacer(minLength: 0)"))
    }

    func testStatsTopBarMiniStatsUseLabeledSummaryChips() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/StatsDetailView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("miniStat(icon: \"sum\", label: \"Sessions\""))
        XCTAssertTrue(source.contains("miniStat(icon: ClaudeDashSymbols.totalCost, label: \"Cost\""))
        XCTAssertTrue(source.contains("miniStat(icon: \"textformat.123\", label: \"Tokens\""))

        let miniStatSection = try XCTUnwrap(
            source.components(separatedBy: "private func miniStat(")
                .dropFirst()
                .first?
                .components(separatedBy: "private var statsWindowBackground")
                .first
        )

        XCTAssertTrue(miniStatSection.contains("Text(label)"))
        XCTAssertTrue(miniStatSection.contains(".statsBackground(cornerRadius:"))
    }

    func testStatsPanelUsesSharedTypographyAndSpacingTokens() throws {
        let detailURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/StatsDetailView.swift")
        let detailSource = try String(contentsOf: detailURL)
        let comparisonURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/WeekComparisonView.swift")
        let comparisonSource = try String(contentsOf: comparisonURL)
        let themeURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/LiquidGlassTheme.swift")
        let themeSource = try String(contentsOf: themeURL)

        XCTAssertTrue(themeSource.contains("enum StatsPanelStyle"))
        XCTAssertTrue(themeSource.contains(".font(StatsPanelStyle.sectionHeader)"))
        XCTAssertTrue(detailSource.contains("StatsPanelStyle.miniLabel"))
        XCTAssertTrue(detailSource.contains("StatsPanelStyle.secondaryLabel"))
        XCTAssertTrue(detailSource.contains("StatsPanelStyle.cardPadding"))
        XCTAssertTrue(comparisonSource.contains("StatsPanelStyle.secondaryLabel"))
        XCTAssertTrue(comparisonSource.contains("StatsPanelStyle.compactSpacing"))
    }

    func testProjectManifestDeclaresOfficialLottiePackageDependency() throws {
        let manifestURL = projectRootURL.appendingPathComponent("project.yml")
        let manifest = try String(contentsOf: manifestURL)

        XCTAssertTrue(
            manifest.contains("url: https://github.com/airbnb/lottie-ios.git")
                || manifest.contains("url: https://github.com/airbnb/lottie-spm.git")
                || manifest.contains("path: Vendor/lottie-spm")
        )
        XCTAssertTrue(manifest.contains("- package: Lottie"))
    }

    func testVendoredLottiePackageUsesLocalOfficialXCFrameworkBinary() throws {
        let packageURL = projectRootURL.appendingPathComponent("Vendor/lottie-spm/Package.swift")
        let packageManifest = try String(contentsOf: packageURL)

        XCTAssertTrue(packageManifest.contains("name: \"Lottie\""))
        XCTAssertTrue(packageManifest.contains("path: \"../LottieBinary/Lottie.xcframework\""))
        XCTAssertFalse(packageManifest.contains("url: \"https://github.com/airbnb/lottie-ios/releases/download"))
    }

    func testFloatingPanelHoverHeaderAvoidsVerboseInstructionCopy() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("悬停查看，点右上角可固定展开"))
        XCTAssertFalse(source.contains("已固定展开，可直接查看完整任务面板"))
    }

    func testFloatingPanelRowsDoNotSurfaceRawLastMessageInHoverPanel() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("if let lastMessage = session.lastMessages.last?.content, !lastMessage.isEmpty"))
    }

    func testFloatingPanelUsesSeparateHoverZonesInsteadOfSingleSelfReferentialRootHover() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains(".onHover { interactionModel.setHovering($0) }"))
        XCTAssertTrue(source.contains("setHoveringMascot"))
        XCTAssertTrue(source.contains("setHoveringTaskPanel"))
    }

    func testFloatingPanelSourceDoesNotRenderTaskBadgeOverlay() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("if taskCount > 0"))
        XCTAssertFalse(source.contains("taskBadge"))
    }

    func testFloatingPanelSourceKeepsMascotTapForSpeedBoostOnly() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("interactionModel.handleMascotTap()"))
        XCTAssertFalse(source.contains("interactionModel.expandFromMascotTap()"))
    }

    func testFloatingPanelSourceAnchorsTaskPanelAsOverlayInsteadOfHStackReflow() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("ZStack(alignment: .topTrailing)"))
        XCTAssertTrue(source.contains("x: -(compactIslandSize.width + FloatingPanelLayout.previewPanelGap)"))
        XCTAssertFalse(source.contains("HStack(alignment: .top, spacing: showsTaskList ? -16 : 0)"))
        XCTAssertFalse(source.contains(".animation(.spring(response: 0.34, dampingFraction: 0.76), value: interactionModel.displayMode)"))
        XCTAssertTrue(source.contains(".animation(FloatingPanelTransition.swiftUIAnimation, value: interactionModel.displayMode)"))
    }

    func testFloatingPanelSourceUsesPreviewHeaderButtonForExpandedModeEntry() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("interactionModel.displayMode == .hoverList"))
        XCTAssertTrue(source.contains(".onTapGesture"))
        XCTAssertTrue(source.contains("interactionModel.toggleExpanded()"))
        XCTAssertFalse(source.contains("hoverPreviewToolbar"))
    }

    func testIslandSessionRowAvoidsGenericStatusCopyAndBadges() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("Claude 正在继续思考"))
        XCTAssertFalse(source.contains("工具正在处理当前任务"))
        XCTAssertFalse(source.contains("任务已经完成"))
        XCTAssertFalse(source.contains("等待新的活动"))
        XCTAssertFalse(source.contains("Text(statusLabel)"))
    }

    func testFloatingPanelExpandedHeaderAvoidsSecondaryCaptionCopy() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("Text(\"固定展开\")"))
        XCTAssertFalse(source.contains("Text(taskCount == 0 ? \"任务\" : \"任务 \\(taskCount)\")"))
    }

    func testFloatingPanelExpandedPanelOmitsFooterInstructionCopy() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("点击角色加速，停手约 1 秒后自动回到 1x"))
    }

    func testFloatingPanelControllerUsesSynchronizedWindowFrameAnimation() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelController.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("NSAnimationContext.runAnimationGroup"))
        XCTAssertTrue(source.contains("FloatingPanelTransition.duration"))
        XCTAssertTrue(source.contains("panel.animator().setFrame(frame, display: true)"))
        XCTAssertTrue(source.contains("panel.setFrame(frame, display: true, animate: false)"))
    }

    func testFloatingPanelSourceWaitsForHostGeometryBeforeRenderingTaskPanel() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("GeometryReader { proxy in"))
        XCTAssertTrue(source.contains("hostSize.width > compactIslandSize.width"))
    }

    func testFloatingPanelSourceUsesMinimalHoverPreviewPills() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("HoverPreviewSessionPill("))
        XCTAssertTrue(source.contains("isTruncated: index == 0 && hiddenPreviewCount > 0"))
    }

    func testFloatingPanelViewReadsMascotSizeFromSharedSettings() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("FloatingMascotSizeOption.userDefaultsKey"))
        XCTAssertTrue(source.contains("FloatingPanelLayout.mascotSize(for: mascotSizeOption)"))
    }

    func testSettingsSceneHostsSettingsViewAndPopoverOffersSettingsEntry() throws {
        let appSourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/ClaudeDashApp.swift")
        let appSource = try String(contentsOf: appSourceURL)
        XCTAssertTrue(appSource.contains("SettingsView()"))

        let popoverSourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/StatusBarPopoverView.swift")
        let popoverSource = try String(contentsOf: popoverSourceURL)
        XCTAssertTrue(popoverSource.contains("label: \"Settings\""))
        XCTAssertTrue(popoverSource.contains("icon: \"gearshape\""))
    }

    func testHoverPreviewPillDoesNotRenderToolIcon() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/FloatingPanelView.swift")
        let source = try String(contentsOf: sourceURL)
        guard
            let structRange = source.range(of: "struct HoverPreviewSessionPill: View {"),
            let endRange = source.range(of: "\n}\n", range: structRange.lowerBound..<source.endIndex)
        else {
            return XCTFail("Failed to locate HoverPreviewSessionPill source")
        }

        let previewSource = String(source[structRange.lowerBound..<endRange.upperBound])
        XCTAssertFalse(previewSource.contains("session.currentTool"))
        XCTAssertFalse(previewSource.contains("sfSymbol"))
    }

    func testTranscriptParserRulesRecognizePlainInterruptedUserText() {
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "content": [
                    [
                        "type": "text",
                        "text": "[Request interrupted by user]",
                    ],
                ],
            ],
        ]

        XCTAssertTrue(TranscriptParserRules.userLineRepresentsInterruption(json))
    }

    func testTranscriptParserRulesRecognizeInterruptedToolResultText() {
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "content": [
                    [
                        "type": "tool_result",
                        "content": "[Request interrupted by user for tool use]",
                        "is_error": true,
                    ],
                ],
            ],
            "toolUseResult": "Error: [Request interrupted by user for tool use]",
        ]

        XCTAssertTrue(TranscriptParserRules.userLineRepresentsInterruption(json))
    }

    func testTranscriptParserRulesDoNotTreatRegularToolResultAsInterruption() {
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "content": [
                    [
                        "type": "tool_result",
                        "content": "read complete",
                        "is_error": false,
                    ],
                ],
            ],
        ]

        XCTAssertFalse(TranscriptParserRules.userLineRepresentsInterruption(json))
    }

    func testTranscriptParserRulesIgnoreMetaStartupUserLineForActivation() {
        let json: [String: Any] = [
            "type": "user",
            "isMeta": true,
            "message": [
                "role": "user",
                "content": "<local-command-caveat>ignore me</local-command-caveat>",
            ],
        ]

        XCTAssertFalse(TranscriptParserRules.userLineShouldActivateSession(json))
    }

    func testTranscriptParserRulesIgnoreClearSlashCommandForActivation() {
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": "<command-name>/clear</command-name>\n<command-message>clear</command-message>",
            ],
        ]

        XCTAssertFalse(TranscriptParserRules.userLineShouldActivateSession(json))
    }

    func testTranscriptParserRulesIgnoreModelSlashCommandForActivation() {
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": "<command-name>/model</command-name>\n<command-message>model</command-message>",
            ],
        ]

        XCTAssertFalse(TranscriptParserRules.userLineShouldActivateSession(json))
    }

    func testTranscriptParserRulesIgnoreLocalCommandStdoutUserLineForActivation() {
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": "<local-command-stdout>Set model to Opus 4.6</local-command-stdout>",
            ],
        ]

        XCTAssertFalse(TranscriptParserRules.userLineShouldActivateSession(json))
    }

    func testTranscriptParserRulesIgnoreLocalCommandSystemLineForActivation() {
        let json: [String: Any] = [
            "type": "system",
            "subtype": "local_command",
            "content": "<local-command-stdout></local-command-stdout>",
        ]

        XCTAssertFalse(TranscriptParserRules.systemLineShouldActivateSession(json))
    }

    func testTranscriptParserRulesTreatPlainUserPromptAsRunning() {
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": "hi",
            ],
        ]

        XCTAssertEqual(TranscriptParserRules.userLineStatus(json), .thinking)
    }

    func testTranscriptParserRulesDoNotTreatSlashCommandAsRunning() {
        let json: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": "<command-name>/model</command-name>\n<command-message>model</command-message>",
            ],
        ]

        XCTAssertNil(TranscriptParserRules.userLineStatus(json))
    }

    func testTranscriptParserRulesTreatAssistantThinkingAsRunning() {
        let json: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [
                    [
                        "type": "thinking",
                        "thinking": "working",
                    ],
                ],
            ],
        ]

        XCTAssertEqual(TranscriptParserRules.assistantLineStatus(json), .thinking)
    }

    func testTranscriptParserRulesTreatAssistantToolUseAsRunning() {
        let json: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [
                    [
                        "type": "tool_use",
                        "name": "Bash",
                    ],
                ],
                "stop_reason": "tool_use",
            ],
        ]

        XCTAssertEqual(TranscriptParserRules.assistantLineStatus(json), .toolRunning)
    }

    func testTranscriptParserRulesTreatCompletedAssistantTextAsCompleted() {
        let json: [String: Any] = [
            "type": "assistant",
            "message": [
                "content": [
                    [
                        "type": "text",
                        "text": "done",
                    ],
                ],
                "stop_reason": "end_turn",
            ],
        ]

        XCTAssertEqual(TranscriptParserRules.assistantLineStatus(json), .completed)
    }

    func testTranscriptParserSourceDoesNotPromotePostToolUseIntoThinkingByDefault() throws {
        let sourceURL = projectRootURL.appendingPathComponent("ClaudeDash/Sources/TranscriptParser.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("case \"PostToolUse\":"))
        XCTAssertTrue(source.contains("statusValue = .unknown"))
        XCTAssertFalse(source.contains("case \"PostToolUse\":\n            statusValue = .thinking"))
    }

    func testPlaybackRulesIncreaseSpeedForRapidTapsAndClampAtCap() {
        XCTAssertEqual(FloatingPanelPlaybackRules.playbackSpeed(forTapCount: 0), 1.0, accuracy: 0.001)
        XCTAssertEqual(FloatingPanelPlaybackRules.playbackSpeed(forTapCount: 1), 1.35, accuracy: 0.001)
        XCTAssertEqual(FloatingPanelPlaybackRules.playbackSpeed(forTapCount: 10), 2.75, accuracy: 0.001)
    }

    func testPlaybackRulesResetTapStreakAfterIdleGap() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let rapidTapCount = FloatingPanelPlaybackRules.nextTapCount(
            previousTapCount: 2,
            lastTapAt: start,
            now: start.addingTimeInterval(0.4)
        )
        let resetTapCount = FloatingPanelPlaybackRules.nextTapCount(
            previousTapCount: rapidTapCount,
            lastTapAt: start,
            now: start.addingTimeInterval(FloatingPanelPlaybackRules.resetDelay + 0.05)
        )

        XCTAssertEqual(rapidTapCount, 3)
        XCTAssertEqual(resetTapCount, 1)
    }

    @MainActor
    func testInteractionModelRetainsTapBoostAfterPlaybackBecomesInactive() {
        let model = FloatingPanelInteractionModel()

        model.setPlaybackActive(true)
        model.handleMascotTap(now: Date(timeIntervalSinceReferenceDate: 120))

        switch model.mascotPlaybackState {
        case let .playing(speed):
            XCTAssertGreaterThan(speed, 1.0)
        case .stoppedAtFirstFrame:
            XCTFail("Expected mascot playback to be active after tap boost")
        }

        model.setPlaybackActive(false)

        switch model.mascotPlaybackState {
        case let .playing(speed):
            XCTAssertGreaterThan(speed, 1.0)
        case .stoppedAtFirstFrame:
            XCTFail("Expected tap-triggered playback to continue briefly after live playback stops")
        }
    }

    @MainActor
    func testInteractionModelAllowsTapBoostWhenPlaybackInactive() {
        let model = FloatingPanelInteractionModel()

        model.handleMascotTap(now: Date(timeIntervalSinceReferenceDate: 140))

        switch model.mascotPlaybackState {
        case let .playing(speed):
            XCTAssertGreaterThan(speed, 1.0)
        case .stoppedAtFirstFrame:
            XCTFail("Expected tap-triggered playback even without live tasks")
        }
        XCTAssertEqual(model.tapBoostCount, 1)
    }

    @MainActor
    func testInteractionModelStopsAtFirstFrameWhenPlaybackInactiveWithoutTapBoost() {
        let model = FloatingPanelInteractionModel()

        model.setPlaybackActive(true)
        model.setPlaybackActive(false)

        XCTAssertEqual(model.mascotPlaybackState, .stoppedAtFirstFrame)
        XCTAssertEqual(model.tapBoostCount, 0)
        XCTAssertEqual(model.playbackSpeed, 1.0, accuracy: 0.001)
    }

    @MainActor
    func testInteractionModelKeepsExpandedPanelPinnedAfterHoverEnds() async {
        let model = FloatingPanelInteractionModel(
            hoverRules: FloatingPanelHoverRules(revealDelay: 0.01, collapseDelay: 0.01)
        )

        model.setHovering(true)
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(model.displayMode, .hoverList)

        model.toggleExpanded()
        XCTAssertEqual(model.displayMode, .expanded)

        model.setHovering(false)
        XCTAssertEqual(model.displayMode, .expanded)

        model.toggleExpanded()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(model.displayMode, .compact)
    }

    @MainActor
    func testInteractionModelKeepsHoverListVisibleWhileEitherHoverZoneIsActive() async {
        let model = FloatingPanelInteractionModel(
            hoverRules: FloatingPanelHoverRules(revealDelay: 0.01, collapseDelay: 0.01)
        )

        model.setHoveringMascot(true)
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(model.displayMode, .hoverList)

        model.setHoveringTaskPanel(true)
        model.setHoveringMascot(false)
        XCTAssertEqual(model.displayMode, .hoverList)

        model.setHoveringTaskPanel(false)
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(model.displayMode, .compact)
    }

    @MainActor
    func testInteractionModelDelaysHoverPreviewUntilThreshold() async {
        let model = FloatingPanelInteractionModel(
            hoverRules: FloatingPanelHoverRules(revealDelay: 0.01, collapseDelay: 0.01)
        )

        model.setHoveringMascot(true)
        XCTAssertEqual(model.displayMode, .compact)

        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(model.displayMode, .hoverList)
    }

    @MainActor
    func testInteractionModelDelaysCollapseAfterHoverLeaves() async {
        let model = FloatingPanelInteractionModel(
            hoverRules: FloatingPanelHoverRules(revealDelay: 0.01, collapseDelay: 0.02)
        )

        model.setHoveringMascot(true)
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(model.displayMode, .hoverList)

        model.setHoveringMascot(false)
        XCTAssertEqual(model.displayMode, .hoverList)

        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(model.displayMode, .compact)
    }

    @MainActor
    func testInteractionModelRestoresPlaybackSpeedAfterIdleReset() {
        let model = FloatingPanelInteractionModel()
        let start = Date(timeIntervalSinceReferenceDate: 200)
        let lastTap = start.addingTimeInterval(0.2)

        model.setPlaybackActive(true)
        model.handleMascotTap(now: start)
        model.handleMascotTap(now: lastTap)
        XCTAssertGreaterThan(model.playbackSpeed, 1.0)

        model.resetPlaybackIfNeeded(now: lastTap.addingTimeInterval(FloatingPanelPlaybackRules.resetDelay + 0.05))

        XCTAssertEqual(model.playbackSpeed, 1.0, accuracy: 0.001)
        XCTAssertEqual(model.tapBoostCount, 0)
    }

    @MainActor
    func testInteractionModelReturnsToFirstFrameAfterIdleResetWhenTapActivatedWithoutLivePlayback() {
        let model = FloatingPanelInteractionModel()
        let tapTime = Date(timeIntervalSinceReferenceDate: 240)

        model.handleMascotTap(now: tapTime)
        XCTAssertEqual(model.tapBoostCount, 1)

        model.resetPlaybackIfNeeded(
            now: tapTime.addingTimeInterval(FloatingPanelPlaybackRules.resetDelay + 0.05)
        )

        XCTAssertEqual(model.mascotPlaybackState, .stoppedAtFirstFrame)
        XCTAssertEqual(model.playbackSpeed, 1.0, accuracy: 0.001)
        XCTAssertEqual(model.tapBoostCount, 0)
    }
}

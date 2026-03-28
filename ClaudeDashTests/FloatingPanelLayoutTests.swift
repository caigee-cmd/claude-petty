import XCTest
@testable import ClaudeGlance

final class FloatingPanelLayoutTests: XCTestCase {
    func testVisibleSessionCountIsCappedForTaskListStates() {
        XCTAssertEqual(FloatingPanelLayout.visibleSessionCount(forTotalSessionCount: 0), 1)
        XCTAssertEqual(FloatingPanelLayout.visibleSessionCount(forTotalSessionCount: 1), 1)
        XCTAssertEqual(FloatingPanelLayout.visibleSessionCount(forTotalSessionCount: 4), 4)
        XCTAssertEqual(FloatingPanelLayout.visibleSessionCount(forTotalSessionCount: 9), FloatingPanelLayout.maxVisibleSessions)
    }

    func testCompactModeUsesMascotOnlyFootprint() {
        let size = FloatingPanelLayout.panelSize(for: .compact, totalSessionCount: 3)

        XCTAssertEqual(size.width, FloatingPanelLayout.defaultCompactIslandSize.width, accuracy: 0.1)
        XCTAssertEqual(size.height, FloatingPanelLayout.defaultCompactIslandSize.height, accuracy: 0.1)
    }

    func testCompactModeUsesSlightlyLargerMascotWithinSameHitArea() {
        XCTAssertEqual(FloatingPanelLayout.defaultMascotSize, FloatingMascotSizeOption.extraLarge.mascotLength, accuracy: 0.1)
        XCTAssertLessThan(FloatingPanelLayout.defaultMascotSize, FloatingPanelLayout.defaultCompactIslandSize.width)
        XCTAssertLessThan(FloatingPanelLayout.defaultMascotSize, FloatingPanelLayout.defaultCompactIslandSize.height)
    }

    func testMascotSizeOptionsProvideOrderedSizesWithinCompactHitArea() {
        let compact = FloatingPanelLayout.mascotSize(for: .compact)
        let small = FloatingPanelLayout.mascotSize(for: .small)
        let medium = FloatingPanelLayout.mascotSize(for: .medium)
        let large = FloatingPanelLayout.mascotSize(for: .large)
        let extraLarge = FloatingPanelLayout.mascotSize(for: .extraLarge)
        let jumbo = FloatingPanelLayout.mascotSize(for: .jumbo)
        let jumboHitArea = FloatingPanelLayout.compactIslandSize(for: .jumbo)

        XCTAssertLessThan(compact, small)
        XCTAssertLessThan(small, medium)
        XCTAssertLessThan(medium, large)
        XCTAssertLessThan(large, extraLarge)
        XCTAssertLessThan(extraLarge, jumbo)
        XCTAssertLessThan(jumbo, jumboHitArea.width)
        XCTAssertLessThan(jumbo, jumboHitArea.height)
    }

    func testPreviewPanelGapCreatesVisibleSeparationFromMascot() {
        XCTAssertGreaterThan(FloatingPanelLayout.previewPanelGap, 0)
        XCTAssertLessThan(FloatingPanelLayout.previewPanelGap, FloatingPanelLayout.defaultCompactIslandSize.width / 2)
    }

    func testHoverPreviewUsesTighterWidthAndShortSingleRowSurface() {
        XCTAssertLessThan(FloatingPanelLayout.hoverPanelWidth, 292)
        XCTAssertGreaterThan(FloatingPanelLayout.hoverPanelWidth, FloatingPanelLayout.defaultCompactIslandSize.width)
        XCTAssertLessThan(
            FloatingPanelLayout.previewSurfaceHeight(forVisibleRows: 1),
            FloatingPanelLayout.defaultCompactIslandSize.height
        )
    }

    func testHoverPreviewUsesFewerVisibleRowsThanExpandedPanel() {
        XCTAssertEqual(
            FloatingPanelLayout.visibleSessionCount(for: .hoverList, totalSessionCount: 5),
            3
        )
        XCTAssertEqual(
            FloatingPanelLayout.visibleSessionCount(for: .expanded, totalSessionCount: 5),
            FloatingPanelLayout.maxVisibleSessions
        )
    }

    func testHoverListModeExpandsIntoGlassyTaskSurface() {
        let compact = FloatingPanelLayout.panelSize(for: .compact, totalSessionCount: 2)
        let hover = FloatingPanelLayout.panelSize(for: .hoverList, totalSessionCount: 2)

        XCTAssertGreaterThan(hover.width, compact.width)
        XCTAssertGreaterThanOrEqual(hover.height, compact.height)
    }

    func testExpandedModePinsLargerPanelThanHoverCard() {
        let hover = FloatingPanelLayout.panelSize(for: .hoverList, totalSessionCount: 3)
        let expanded = FloatingPanelLayout.panelSize(for: .expanded, totalSessionCount: 3)

        XCTAssertGreaterThan(expanded.width, hover.width)
        XCTAssertGreaterThan(expanded.height, hover.height)
    }

    func testClampedOriginPullsOffscreenPositionBackIntoVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 50, width: 1710, height: 1022)
        let proposedOrigin = CGPoint(x: 1730, y: 725)
        let size = CGSize(width: 92, height: 92)

        let clamped = FloatingPanelLayout.clampedOrigin(
            for: proposedOrigin,
            panelSize: size,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(clamped.x, 1618, accuracy: 0.1)
        XCTAssertEqual(clamped.y, 725, accuracy: 0.1)
    }

    func testClampedOriginPreservesVisiblePosition() {
        let visibleFrame = CGRect(x: 0, y: 50, width: 1710, height: 1022)
        let proposedOrigin = CGPoint(x: 1500, y: 700)
        let size = CGSize(width: 92, height: 92)

        let clamped = FloatingPanelLayout.clampedOrigin(
            for: proposedOrigin,
            panelSize: size,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(clamped.x, proposedOrigin.x, accuracy: 0.1)
        XCTAssertEqual(clamped.y, proposedOrigin.y, accuracy: 0.1)
    }

    func testDraggedOriginFollowsPointerTranslationWithinVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 50, width: 1710, height: 1022)
        let initialOrigin = CGPoint(x: 1200, y: 700)
        let size = CGSize(width: 92, height: 92)

        let dragged = FloatingPanelLayout.draggedOrigin(
            from: initialOrigin,
            dragTranslation: CGSize(width: -140, height: -36),
            panelSize: size,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(dragged.x, 1060, accuracy: 0.1)
        XCTAssertEqual(dragged.y, 664, accuracy: 0.1)
    }

    func testDraggedOriginClampsWhenGestureWouldMovePanelOffscreen() {
        let visibleFrame = CGRect(x: 0, y: 50, width: 1710, height: 1022)
        let initialOrigin = CGPoint(x: 1610, y: 940)
        let size = CGSize(width: 92, height: 92)

        let dragged = FloatingPanelLayout.draggedOrigin(
            from: initialOrigin,
            dragTranslation: CGSize(width: 200, height: 140),
            panelSize: size,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(dragged.x, 1618, accuracy: 0.1)
        XCTAssertEqual(dragged.y, 980, accuracy: 0.1)
    }
}

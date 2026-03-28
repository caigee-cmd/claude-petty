import CoreGraphics
import Foundation
import SwiftUI
import QuartzCore

enum FloatingPanelDisplayMode: Equatable {
    case compact
    case hoverList
    case expanded
}

enum FloatingPanelTransition {
    static let targetFPS: Double = 60
    static let duration: TimeInterval = 0.26
    static let swiftUIAnimation: Animation = .interactiveSpring(
        response: 0.28,
        dampingFraction: 0.86,
        blendDuration: 0.12
    )
    @MainActor
    static var timingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.24, 1.0)
    }
}

enum FloatingPanelLayout {
    static let hoverTaskPanelWidth: CGFloat = 114
    static let expandedTaskPanelWidth: CGFloat = 308
    static let previewPanelGap: CGFloat = 2
    static let panelContentPadding: CGFloat = 12
    static let previewContentPadding: CGFloat = 8
    static let previewSectionSpacing: CGFloat = 0
    static let previewToolbarHeight: CGFloat = 0
    static let listHeaderHeight: CGFloat = 20
    static let compactFooterHeight: CGFloat = 0
    static let expandedFooterHeight: CGFloat = 34
    static let previewRowHeight: CGFloat = 24
    static let previewIdleHeight: CGFloat = 16
    static let previewRowSpacing: CGFloat = 3
    static let rowHeight: CGFloat = 42
    static let idleRowHeight: CGFloat = 20
    static let rowSpacing: CGFloat = 6
    static let defaultMascotSize: CGFloat = FloatingMascotSizeOption.extraLarge.mascotLength
    static let defaultCompactIslandSize = compactIslandSize(for: .extraLarge)
    static let badgeSize: CGFloat = 24
    static let maxVisibleSessions = 4
    static let previewVisibleSessions = 3

    static let panelWidth: CGFloat = defaultCompactIslandSize.width
    static let horizontalPadding: CGFloat = panelContentPadding
    static let verticalPadding: CGFloat = panelContentPadding
    static let hoverPanelWidth: CGFloat = defaultCompactIslandSize.width + previewPanelGap + hoverTaskPanelWidth

    static func mascotSize(for option: FloatingMascotSizeOption) -> CGFloat {
        option.mascotLength
    }

    static func compactIslandSize(for option: FloatingMascotSizeOption) -> CGSize {
        let side = max(92, option.mascotLength + 12)
        return CGSize(width: side, height: side)
    }

    static func visibleSessionCount(forTotalSessionCount totalCount: Int) -> Int {
        min(max(totalCount, 1), maxVisibleSessions)
    }

    static func visibleSessionCount(
        for mode: FloatingPanelDisplayMode,
        totalSessionCount totalCount: Int
    ) -> Int {
        switch mode {
        case .compact:
            1
        case .hoverList:
            min(max(totalCount, 1), previewVisibleSessions)
        case .expanded:
            visibleSessionCount(forTotalSessionCount: totalCount)
        }
    }

    static func panelSize(
        for mode: FloatingPanelDisplayMode,
        totalSessionCount totalCount: Int
    ) -> CGSize {
        panelSize(for: mode, totalSessionCount: totalCount, mascotSizeOption: .extraLarge)
    }

    static func panelSize(
        for mode: FloatingPanelDisplayMode,
        totalSessionCount totalCount: Int,
        mascotSizeOption: FloatingMascotSizeOption
    ) -> CGSize {
        let compactIslandSize = compactIslandSize(for: mascotSizeOption)

        switch mode {
        case .compact:
            return compactIslandSize
        case .hoverList:
            let contentRowHeight = totalCount == 0 ? previewIdleHeight : previewRowHeight
            return CGSize(
                width: compactIslandSize.width + previewPanelGap + hoverTaskPanelWidth,
                height: max(
                    compactIslandSize.height,
                    taskListHeight(
                        forVisibleRows: visibleSessionCount(for: mode, totalSessionCount: totalCount),
                        headerHeight: previewToolbarHeight,
                        rowHeight: contentRowHeight,
                        rowSpacing: previewRowSpacing,
                        footerHeight: compactFooterHeight
                    )
                )
            )
        case .expanded:
            let contentRowHeight = totalCount == 0 ? idleRowHeight : rowHeight
            return CGSize(
                width: compactIslandSize.width + previewPanelGap + expandedTaskPanelWidth,
                height: max(
                    compactIslandSize.height + 44,
                    taskListHeight(
                        forVisibleRows: visibleSessionCount(for: mode, totalSessionCount: totalCount),
                        headerHeight: listHeaderHeight,
                        rowHeight: contentRowHeight,
                        rowSpacing: rowSpacing,
                        footerHeight: expandedFooterHeight
                    )
                )
            )
        }
    }

    static func previewSurfaceHeight(forVisibleRows rowCount: Int, isIdle: Bool = false) -> CGFloat {
        let rows = CGFloat(max(rowCount, 1))
        let rowHeight = isIdle ? previewIdleHeight : previewRowHeight
        let spacing = isIdle ? 0 : CGFloat(max(rowCount - 1, 0)) * previewRowSpacing

        return (previewContentPadding * 2)
            + previewToolbarHeight
            + previewSectionSpacing
            + (rows * rowHeight)
            + spacing
    }

    static func previewSurfaceVerticalOffset(hostHeight: CGFloat, surfaceHeight: CGFloat) -> CGFloat {
        max((hostHeight - surfaceHeight) / 2, 0)
    }

    static func panelHeight(forTotalSessionCount totalCount: Int) -> CGFloat {
        panelHeight(forTotalSessionCount: totalCount, mascotSizeOption: .extraLarge)
    }

    static func panelHeight(
        forTotalSessionCount totalCount: Int,
        mascotSizeOption: FloatingMascotSizeOption
    ) -> CGFloat {
        panelSize(for: .compact, totalSessionCount: totalCount, mascotSizeOption: mascotSizeOption).height
    }

    static func clampedOrigin(
        for proposedOrigin: CGPoint,
        panelSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - panelSize.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - panelSize.height)

        return CGPoint(
            x: min(max(proposedOrigin.x, visibleFrame.minX), maxX),
            y: min(max(proposedOrigin.y, visibleFrame.minY), maxY)
        )
    }

    static func draggedOrigin(
        from initialOrigin: CGPoint,
        dragTranslation: CGSize,
        panelSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        clampedOrigin(
            for: CGPoint(
                x: initialOrigin.x + dragTranslation.width,
                y: initialOrigin.y + dragTranslation.height
            ),
            panelSize: panelSize,
            visibleFrame: visibleFrame
        )
    }

    private static func taskListHeight(
        forVisibleRows rowCount: Int,
        headerHeight: CGFloat,
        rowHeight: CGFloat,
        rowSpacing: CGFloat,
        footerHeight: CGFloat
    ) -> CGFloat {
        let rows = CGFloat(max(rowCount, 1))
        let spacing = CGFloat(max(rowCount - 1, 0)) * rowSpacing

        return (panelContentPadding * 2) + headerHeight + (rows * rowHeight) + spacing + footerHeight
    }
}

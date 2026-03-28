// FloatingPanelController.swift
// ClaudeDash - Floating progress panel for active sessions
// NSPanel always-on-top, auto-show/hide, draggable

import AppKit
import SwiftUI
import Combine

extension Notification.Name {
    static let hideFloatingPanel = Notification.Name("hideFloatingPanel")
    static let floatingMascotSizeDidChange = Notification.Name("floatingMascotSizeDidChange")
}

enum FloatingPanelVisibilityRules {
    static func hasRunningSessions(_ sessions: [ActiveSession]) -> Bool {
        sessions.contains { $0.status == .thinking || $0.status == .toolRunning }
    }

    static func shouldAutoShow(
        isVisible: Bool,
        isManuallyHidden: Bool,
        sessions: [ActiveSession]
    ) -> Bool {
        !isVisible && !isManuallyHidden && hasRunningSessions(sessions)
    }

    static func shouldAutoHide(
        isVisible: Bool,
        isManuallyPresented: Bool,
        sessions: [ActiveSession]
    ) -> Bool {
        isVisible && !isManuallyPresented && !hasRunningSessions(sessions)
    }
}

@MainActor
final class FloatingPanelController {
    private var panel: NSPanel?
    private let sessionMonitor: SessionMonitor
    private let interactionModel = FloatingPanelInteractionModel()
    private var cancellables = Set<AnyCancellable>()
    private var isVisible = false
    private var isManuallyHidden = false
    private var isManuallyPresented = false
    private var autoShowWorkItem: DispatchWorkItem?
    private var lastDisplayMode: FloatingPanelDisplayMode = .compact

    // Saved position
    private let positionXKey = "ClaudeDash_panelX"
    private let positionYKey = "ClaudeDash_panelY"

    init(sessionMonitor: SessionMonitor) {
        self.sessionMonitor = sessionMonitor
        observeSessionChanges()
        observeHideNotification()
        observeInteractionChanges()
        observeSettingsChanges()
        restorePreferredVisibilityIfNeeded()
    }

    // MARK: - Observe

    private func observeSessionChanges() {
        sessionMonitor.$activeSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let self else { return }
                guard self.isMascotEnabled else {
                    self.autoShowWorkItem?.cancel()
                    self.autoShowWorkItem = nil
                    self.interactionModel.setPlaybackActive(false)
                    if self.isVisible {
                        self.hidePanel(manual: false)
                    }
                    return
                }

                let hasRunningSessions = FloatingPanelVisibilityRules.hasRunningSessions(sessions)

                self.interactionModel.setPlaybackActive(hasRunningSessions)

                if !self.isVisible && !self.isManuallyHidden {
                    self.showPanel(manual: false)
                }

                self.updatePanelSize(activeCount: sessions.count, animateTransition: false)
            }
            .store(in: &cancellables)
    }

    private func observeHideNotification() {
        NotificationCenter.default.publisher(for: .hideFloatingPanel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.hidePanel(manual: true)
            }
            .store(in: &cancellables)
    }

    private func observeInteractionChanges() {
        interactionModel.$displayMode
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                guard let self else { return }
                let previousMode = self.lastDisplayMode
                self.lastDisplayMode = mode
                self.updatePanelSize(
                    activeCount: self.sessionMonitor.activeSessions.count,
                    animateTransition: self.shouldAnimateWindowResize(from: previousMode, to: mode)
                )
            }
            .store(in: &cancellables)
    }

    private func observeSettingsChanges() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: ClaudeDashDefaults.shared)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyMascotPreference()
                self.interactionModel.refreshPlaybackBaseSpeed()
                self.updatePanelSize(activeCount: self.sessionMonitor.activeSessions.count, animateTransition: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .floatingMascotSizeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updatePanelSize(activeCount: self.sessionMonitor.activeSessions.count, animateTransition: false)
            }
            .store(in: &cancellables)
    }

    // MARK: - Show / Hide

    func showPanel(manual: Bool = false) {
        if panel == nil {
            createPanel()
        }
        isManuallyHidden = false
        if manual {
            isManuallyPresented = true
        }
        panel?.orderFrontRegardless()
        isVisible = true
    }

    func hidePanel(manual: Bool = true) {
        savePosition()
        panel?.orderOut(nil)
        isVisible = false
        isManuallyPresented = false
        if manual {
            isManuallyHidden = true
        }
    }

    func togglePanel() {
        setMascotEnabled(!isMascotEnabled)
    }

    var isMascotEnabled: Bool {
        FloatingMascotPreferences.isEnabled()
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let contentView = FloatingPanelView(interactionModel: interactionModel)
            .environmentObject(sessionMonitor)

        let hostingView = NSHostingView(rootView: contentView)
        let initialActiveCount = sessionMonitor.activeSessions.count
        let metrics = FloatingPanelLayout.panelSize(
            for: interactionModel.displayMode,
            totalSessionCount: initialActiveCount,
            mascotSizeOption: currentMascotSizeOption
        )
        let initialSize = NSSize(width: metrics.width, height: metrics.height)
        hostingView.setFrameSize(initialSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .utilityWindow
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false

        // Restore saved position or default to top-right
        let defaults = UserDefaults.standard
        if defaults.object(forKey: positionXKey) != nil {
            let savedOrigin = NSPoint(
                x: defaults.double(forKey: positionXKey),
                y: defaults.double(forKey: positionYKey)
            )
            panel.setFrameOrigin(constrainedOrigin(savedOrigin, size: initialSize))
        } else if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let proposedOrigin = NSPoint(
                x: screenFrame.maxX - initialSize.width - 20,
                y: screenFrame.maxY - 92
            )
            panel.setFrameOrigin(constrainedOrigin(proposedOrigin, size: initialSize))
        }

        self.panel = panel
        observePanelMovement(panel)
        savePosition()
    }

    // MARK: - Resize

    private func updatePanelSize(activeCount: Int, animateTransition: Bool) {
        guard let panel else { return }
        let size = FloatingPanelLayout.panelSize(
            for: interactionModel.displayMode,
            totalSessionCount: activeCount,
            mascotSizeOption: currentMascotSizeOption
        )
        var frame = panel.frame
        let oldWidth = frame.width
        let oldHeight = frame.height
        frame.size.width = size.width
        frame.size.height = size.height
        // Keep top-right corner fixed while mode changes.
        frame.origin.x += oldWidth - size.width
        frame.origin.y += oldHeight - size.height
        frame.origin = constrainedOrigin(frame.origin, size: frame.size)
        guard !frame.equalTo(panel.frame) else { return }

        if isVisible && animateTransition {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = FloatingPanelTransition.duration
                context.timingFunction = FloatingPanelTransition.timingFunction
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true, animate: false)
        }
    }

    private func shouldAnimateWindowResize(
        from previousMode: FloatingPanelDisplayMode,
        to newMode: FloatingPanelDisplayMode
    ) -> Bool {
        previousMode != newMode && (previousMode == .expanded || newMode == .expanded)
    }

    private var currentMascotSizeOption: FloatingMascotSizeOption {
        let rawValue = ClaudeDashDefaults.shared.string(forKey: FloatingMascotSizeOption.userDefaultsKey)
        return FloatingMascotSizeOption(rawValue: rawValue ?? FloatingMascotSizeOption.extraLarge.rawValue) ?? .extraLarge
    }

    private func restorePreferredVisibilityIfNeeded() {
        guard isMascotEnabled else { return }
        showPanel(manual: false)
    }

    private func applyMascotPreference() {
        if isMascotEnabled {
            isManuallyHidden = false
            if !isVisible {
                showPanel(manual: false)
            }
        } else {
            autoShowWorkItem?.cancel()
            autoShowWorkItem = nil
            interactionModel.setPlaybackActive(false)
            if isVisible {
                hidePanel(manual: false)
            }
        }
    }

    private func setMascotEnabled(_ enabled: Bool) {
        FloatingMascotPreferences.setEnabled(enabled)
        applyMascotPreference()
    }

    // MARK: - Position Persistence

    private func savePosition() {
        guard let panel else { return }
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: positionXKey)
        UserDefaults.standard.set(origin.y, forKey: positionYKey)
    }

    private func observePanelMovement(_ panel: NSPanel) {
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: panel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.savePosition()
            }
            .store(in: &cancellables)
    }

    private func constrainedOrigin(_ proposedOrigin: NSPoint, size: NSSize) -> NSPoint {
        guard let visibleFrame = preferredVisibleFrame(for: proposedOrigin, size: size) else {
            return proposedOrigin
        }

        let clamped = FloatingPanelLayout.clampedOrigin(
            for: proposedOrigin,
            panelSize: size,
            visibleFrame: visibleFrame
        )
        return NSPoint(x: clamped.x, y: clamped.y)
    }

    private func preferredVisibleFrame(for proposedOrigin: NSPoint, size: NSSize) -> NSRect? {
        let proposedFrame = NSRect(origin: proposedOrigin, size: size)
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let bestScreen = screens.max { lhs, rhs in
            intersectionArea(of: lhs.visibleFrame, with: proposedFrame)
                < intersectionArea(of: rhs.visibleFrame, with: proposedFrame)
        }

        return bestScreen?.visibleFrame ?? NSScreen.main?.visibleFrame
    }

    private func intersectionArea(of lhs: NSRect, with rhs: NSRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}

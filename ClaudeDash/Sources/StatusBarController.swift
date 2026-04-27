// StatusBarController.swift
// ClaudeDash - 状态栏控制器
// 管理 NSStatusItem、Popover 面板、动态徽章、统计窗口

import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController: NSObject {
    // MARK: - 属性

    private var statusItem: NSStatusItem
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var statsWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let statsManager: StatsManager
    private let sessionMonitor: SessionMonitor
    private let notificationSender: NotificationSender
    private var floatingPanel: FloatingPanelController?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init(statsManager: StatsManager, sessionMonitor: SessionMonitor, notificationSender: NotificationSender) {
        self.statsManager = statsManager
        self.sessionMonitor = sessionMonitor
        self.notificationSender = notificationSender
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupStatusBarIcon()
        setupPopover()
        observeBadgeUpdates()

        // Floating progress panel
        self.floatingPanel = FloatingPanelController(sessionMonitor: sessionMonitor)
    }

    // MARK: - 状态栏图标

    private func setupStatusBarIcon() {
        guard let button = statusItem.button else { return }

        if let assetImage = NSImage(named: NSImage.Name("MenuBarIcon"))?.copy() as? NSImage {
            assetImage.size = NSSize(width: 20, height: 20)
            assetImage.isTemplate = true
            button.image = assetImage
            button.imagePosition = .imageLeading
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            if let image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "Claude Glance") {
                let configured = image.withSymbolConfiguration(config) ?? image
                configured.isTemplate = true
                button.image = configured
                button.imagePosition = .imageLeading
            }
        }

        button.action = #selector(togglePopover)
        button.target = self
    }

    // MARK: - 动态徽章

    private func updateBadge(count: Int) {
        guard let button = statusItem.button else { return }
        button.title = count > 0 ? " \(count)" : ""
    }

    private func observeBadgeUpdates() {
        statsManager.$todayCompletionCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.updateBadge(count: count)
            }
            .store(in: &cancellables)
    }

    // MARK: - Popover

    private func setupPopover() {
        let popoverView = StatusBarPopoverView(
            onOpenStats: { [weak self] in
                self?.closePopover()
                self?.openStatsDetail()
            },
            onTestNotification: {
                // 通知功能已禁用
            },
            onInstallHook: { [weak self] in
                self?.closePopover()
                HookInstaller.install()
            },
            onTogglePanel: { [weak self] in
                self?.floatingPanel?.togglePanel()
            },
            onOpenSettings: { [weak self] in
                self?.closePopover()
                self?.openSettingsDetail()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        .environmentObject(statsManager)
        .environmentObject(sessionMonitor)

        popover.contentViewController = NSHostingController(rootView: popoverView)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        button.highlight(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        statusItem.button?.highlight(false)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - 统计详情窗口

    private func openStatsDetail() {
        if let window = statsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let statsView = StatsDetailView()
            .environmentObject(statsManager)

        let window = makeWindow(
            title: "Claude Glance 统计",
            size: NSSize(width: 740, height: 680),
            content: statsView
        )
        self.statsWindow = window
    }

    private func openSettingsDetail() {
        openSettingsDetail(isFirstLaunchSetup: false)
    }

    func presentInitialMascotSetupIfNeeded() {
        guard !FloatingMascotPreferences.didCompleteSetup() else { return }
        openSettingsDetail(isFirstLaunchSetup: true)
    }

    private func openSettingsDetail(isFirstLaunchSetup: Bool) {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            isFirstLaunchSetup: isFirstLaunchSetup,
            onFinishSetup: { [weak self] in
                guard let self else { return }
                if FloatingMascotPreferences.didCompleteSetup() {
                    self.settingsWindow?.performClose(nil)
                }
            }
        )
        let window = makeWindow(
            title: "Claude Glance 设置",
            size: NSSize(width: 488, height: isFirstLaunchSetup ? 502 : 472),
            content: settingsView
        )
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        self.settingsWindow = window
    }

    // MARK: - 窗口工厂

    private func makeWindow<V: View>(title: String, size: NSSize, content: V) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        return window
    }

    /// 当所有独立窗口关闭时，恢复 accessory 模式（不显示 Dock 图标）
    private func revertToAccessoryIfNeeded() {
        let hasVisibleWindow = statsWindow?.isVisible == true || settingsWindow?.isVisible == true
        if !hasVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - NSWindowDelegate

extension StatusBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as AnyObject? === statsWindow {
            statsWindow = nil
        }
        if notification.object as AnyObject? === settingsWindow {
            settingsWindow = nil
        }
        // 窗口关闭后恢复 accessory 模式
        DispatchQueue.main.async { [weak self] in
            self?.revertToAccessoryIfNeeded()
        }
    }
}

// MARK: - NSPopoverDelegate

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

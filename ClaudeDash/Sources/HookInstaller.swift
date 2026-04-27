// HookInstaller.swift
// ClaudeDash - Claude Code Stop Hook 安装器
// 自动备份 settings.json、合并写入 hook 配置、创建支持目录

import Foundation
import AppKit
import Combine

enum HookInstallOutcome: Equatable {
    case installed
    case alreadyInstalled
}

struct HookMergeResult {
    let settings: [String: Any]
    let outcome: HookInstallOutcome
}

enum HookInstaller {
    // MARK: - 路径常量

    /// Claude 配置目录
    private static var claudeDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    /// settings.json 路径
    private static var settingsPath: URL {
        claudeDir.appendingPathComponent("settings.json")
    }

    /// App Support 目录
    private static var supportDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ClaudeDash")
    }

    /// Helper 可执行文件路径（App Bundle 内）
    private static var helperPath: String {
        // Bundle API 查找（最可靠）
        if let url = Bundle.main.url(forResource: "ClaudeDashHelper", withExtension: nil) {
            return url.path
        }
        // Fallback: Resources 目录
        return Bundle.main.bundlePath + "/Contents/Resources/ClaudeDashHelper"
    }

    /// 检测 App 是否在稳定位置（非 DerivedData / 临时目录）
    private static var isInStableLocation: Bool {
        let path = Bundle.main.bundlePath
        if path.contains("/DerivedData/") || path.contains("/tmp/") || path.contains("/private/var/") || path.contains("/private/tmp/") {
            return false
        }
        return true
    }

    /// 验证 Helper 二进制是否存在且可执行
    private static var isHelperValid: Bool {
        FileManager.default.isExecutableFile(atPath: helperPath)
    }

    // MARK: - 安装入口

    /// 执行完整 Hook 安装流程
    @MainActor
    static func install() {
        // 检查 App 是否在稳定位置
        if !isInStableLocation {
            let alert = NSAlert()
            alert.messageText = "建议先移动 App"
            alert.informativeText = "Claude Glance 当前运行在临时构建目录中。\n建议先将 ClaudeGlance.app 拖入 /Applications 目录，再安装 Hook。\n\n是否仍然使用当前路径安装？\n\n当前路径：\n\(Bundle.main.bundlePath)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "仍然安装")
            alert.addButton(withTitle: "取消")
            let response = alert.runModal()
            if response != .alertFirstButtonReturn {
                return
            }
        }

        do {
            // 0. 验证 Helper 存在
            if !isHelperValid {
                showAlert(
                    title: "Helper not found",
                    message: "Claude Glance helper binary not found at:\n\(helperPath)\n\nPlease rebuild the app.",
                    style: .critical
                )
                return
            }

            // 1. 创建支持目录
            try createSupportDirectory()

            // 2. 备份已有 settings.json
            try backupSettings()

            // 3. 安装 Hook
            let outcome = try installHook()

            switch outcome {
            case .installed:
                showAlert(
                    title: "Hook 安装成功！",
                    message: "Stop Hook 已添加到 ~/.claude/settings.json。\nHelper 路径：\(helperPath)\n\n请重启 Claude Code 以使 Hook 生效。",
                    style: .informational
                )
            case .alreadyInstalled:
                showAlert(
                    title: "已安装",
                    message: "Claude Glance Hook 已存在于配置中，无需重复安装。",
                    style: .informational
                )
            }
        } catch {
            // 失败提示
            showAlert(
                title: "Hook 安装失败",
                message: "错误详情：\(error.localizedDescription)",
                style: .critical
            )
        }
    }

    // MARK: - 步骤实现

    /// 创建 ~/Library/Application Support/ClaudeDash/ 目录
    private static func createSupportDirectory() throws {
        try FileManager.default.createDirectory(
            at: supportDir,
            withIntermediateDirectories: true
        )
    }

    /// 备份 settings.json（带时间戳）
    private static func backupSettings() throws {
        let settingsURL = settingsPath
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            // 文件不存在，无需备份
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupURL = claudeDir.appendingPathComponent("settings.json.backup.\(timestamp)")

        try FileManager.default.copyItem(at: settingsURL, to: backupURL)
        print("[HookInstaller] 已备份: \(backupURL.path)")
    }

    /// 安装 Stop Hook 到 settings.json
    @discardableResult
    private static func installHook() throws -> HookInstallOutcome {
        let settingsURL = settingsPath

        // 确保 .claude 目录存在
        try FileManager.default.createDirectory(
            at: claudeDir,
            withIntermediateDirectories: true
        )

        // 读取或创建 settings.json
        var settings: [String: Any]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            let data = try Data(contentsOf: settingsURL)
            settings = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        } else {
            settings = [:]
        }

        let mergeResult = mergeStopHook(into: settings, helperCommand: helperPath)
        if mergeResult.outcome == .alreadyInstalled {
            return .alreadyInstalled
        }

        let jsonData = try JSONSerialization.data(
            withJSONObject: mergeResult.settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try jsonData.write(to: settingsURL, options: .atomic)

        print("[HookInstaller] Hook 安装完成: \(helperPath)")
        return mergeResult.outcome
    }

    static func mergeStopHook(into settings: [String: Any], helperCommand: String) -> HookMergeResult {
        var mergedSettings = settings
        var hooks = mergedSettings["hooks"] as? [String: Any] ?? [:]
        var stopHooks = hooks["Stop"] as? [[String: Any]] ?? []

        let alreadyInstalled = stopHooks.contains { hook in
            (hook["command"] as? String) == helperCommand
        }

        if alreadyInstalled {
            return HookMergeResult(settings: mergedSettings, outcome: .alreadyInstalled)
        }

        stopHooks.append([
            "type": "command",
            "command": helperCommand
        ])
        hooks["Stop"] = stopHooks
        mergedSettings["hooks"] = hooks

        return HookMergeResult(settings: mergedSettings, outcome: .installed)
    }

    static func hookStatus(
        for settings: [String: Any],
        helperCommand: String,
        helperIsExecutable: Bool
    ) -> HookIntegrationStatus {
        guard helperIsExecutable else {
            return .helperUnavailable
        }

        let hooks = settings["hooks"] as? [String: Any]
        let stopHooks = hooks?["Stop"] as? [[String: Any]] ?? []
        let isInstalled = stopHooks.contains { hook in
            (hook["command"] as? String) == helperCommand
        }
        return isInstalled ? .installed : .missing
    }

    static func currentHookStatus() -> HookIntegrationStatus {
        let settings = loadSettings()
        return hookStatus(
            for: settings,
            helperCommand: helperPath,
            helperIsExecutable: isHelperValid
        )
    }

    static func loadSettings() -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsPath.path),
              let data = try? Data(contentsOf: settingsPath),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return settings
    }

    // MARK: - Alert 弹窗

    /// 显示原生 NSAlert
    @MainActor
    private static func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

@MainActor
final class HookIntegrationManager: ObservableObject {
    static let shared = HookIntegrationManager()

    @Published private(set) var monitoringMode: MonitoringMode
    @Published private(set) var hookStatus: HookIntegrationStatus = .inactive

    private let userDefaults: UserDefaults
    private var healthCheckTimer: Timer?
    private var lastRepairPromptedStatus: HookIntegrationStatus?

    init(userDefaults: UserDefaults = ClaudeDashDefaults.shared) {
        self.userDefaults = userDefaults
        self.monitoringMode = MonitoringMode(
            rawValue: userDefaults.string(forKey: MonitoringMode.userDefaultsKey) ?? ""
        ) ?? .passive
    }

    func start() {
        refreshStatus(promptForRepair: true)
        scheduleHealthChecks()
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    func setMonitoringMode(_ mode: MonitoringMode) {
        userDefaults.set(mode.rawValue, forKey: MonitoringMode.userDefaultsKey)
        monitoringMode = mode
        refreshStatus(promptForRepair: mode == .enhanced)
    }

    func refreshStatus(promptForRepair: Bool = false) {
        monitoringMode = MonitoringMode(
            rawValue: userDefaults.string(forKey: MonitoringMode.userDefaultsKey) ?? ""
        ) ?? .passive

        let nextStatus: HookIntegrationStatus = monitoringMode == .enhanced
            ? HookInstaller.currentHookStatus()
            : .inactive

        hookStatus = nextStatus
        if nextStatus == .installed || nextStatus == .inactive {
            lastRepairPromptedStatus = nil
        }

        guard promptForRepair,
              monitoringMode == .enhanced,
              nextStatus.canAutoRepair,
              lastRepairPromptedStatus != nextStatus else {
            return
        }

        lastRepairPromptedStatus = nextStatus
        let shouldRepair = requestRepairPermission()
        if shouldRepair {
            HookInstaller.install()
            hookStatus = HookInstaller.currentHookStatus()
            if hookStatus == .installed {
                lastRepairPromptedStatus = nil
            }
        }
    }

    private func scheduleHealthChecks() {
        guard healthCheckTimer == nil else { return }
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus(promptForRepair: true)
            }
        }
    }

    private func requestRepairPermission() -> Bool {
        let alert = NSAlert()
        alert.messageText = "增强模式 Hook 已失效"
        alert.informativeText = "Claude Glance 检测到 settings.json 中缺少 Hook 配置。\n\n是否允许 Claude Glance 自动修复？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "自动修复")
        alert.addButton(withTitle: "暂不处理")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

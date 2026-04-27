// SessionMonitor.swift
// ClaudeDash - Active session detection via JSONL file monitoring
// Uses filesystem events for active transcripts and a low-frequency reconcile scan.

import Foundation
import Combine
import Darwin
import CryptoKit

struct SessionDirectoryScanFile: Equatable, Sendable {
    let path: String
    let projectName: String
    let lastModified: Date
}

struct SessionDirectoryScanResult: Equatable, Sendable {
    let activeFiles: [SessionDirectoryScanFile]
    let completedPaths: [String]
}

enum SessionDirectoryScanner {
    static func scan(
        baseDir: String,
        trackedActivity: [String: Bool],
        activeThreshold: TimeInterval,
        completionThreshold: TimeInterval,
        now: Date = Date()
    ) -> SessionDirectoryScanResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: baseDir),
              let projectDirs = try? fileManager.contentsOfDirectory(atPath: baseDir) else {
            return SessionDirectoryScanResult(activeFiles: [], completedPaths: [])
        }

        var activeFiles: [SessionDirectoryScanFile] = []
        var completedPaths = Set<String>()

        for projectDir in projectDirs {
            let projectPath = (baseDir as NSString).appendingPathComponent(projectDir)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: projectPath, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  let files = try? fileManager.contentsOfDirectory(atPath: projectPath) else {
                continue
            }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = (projectPath as NSString).appendingPathComponent(file)
                guard let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                      let modDate = attrs[.modificationDate] as? Date else {
                    continue
                }

                let age = now.timeIntervalSince(modDate)
                if age < activeThreshold {
                    activeFiles.append(SessionDirectoryScanFile(
                        path: filePath,
                        projectName: SessionMonitor.extractProjectName(from: projectDir),
                        lastModified: modDate
                    ))
                } else if trackedActivity[filePath] == true,
                          age > completionThreshold {
                    completedPaths.insert(filePath)
                }
            }
        }

        return SessionDirectoryScanResult(
            activeFiles: activeFiles.sorted { $0.lastModified > $1.lastModified },
            completedPaths: completedPaths.sorted()
        )
    }
}

@MainActor
final class SessionMonitor: ObservableObject {
    static let shared = SessionMonitor()

    @Published var activeSessions: [ActiveSession] = []

    private let maxSessions = 10
    private let scanQueue = DispatchQueue(label: "ClaudeDash.SessionMonitor.scan", qos: .utility)
    private let reconcileInterval: TimeInterval = 30
    private let rescanDebounce: TimeInterval = 1.0
    private let activeThreshold: TimeInterval = 120
    private let completionThreshold: TimeInterval = 180
    private let completedRemovalDelay: TimeInterval = 30
    private var completedTimestamps: [String: Date] = [:]
    private let projectsBaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)
    private let kimiBaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".kimi/sessions", isDirectory: true)
    private let codexBaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/sessions", isDirectory: true)

    private var reconcileTimer: Timer?
    private var trackedFiles: [String: TrackedFile] = [:]
    private var parsers: [String: TranscriptParser] = [:]
    private var cancellables: [String: Set<AnyCancellable>] = [:]
    private var fileSources: [String: DispatchSourceFileSystemObject] = [:]
    private var projectDirectorySources: [String: DispatchSourceFileSystemObject] = [:]
    private var projectDirectoryDescriptors: [String: CInt] = [:]
    private var fileDescriptors: [String: CInt] = [:]
    private var rootDirectorySource: DispatchSourceFileSystemObject?
    private var rootDirectoryDescriptor: CInt = -1
    private var isScanInFlight = false
    private var pendingRescanWorkItem: DispatchWorkItem?

    private struct TrackedFile: Sendable {
        let path: String
        let projectName: String
        var lastModified: Date
        var isActive: Bool
    }

    // MARK: - Start / Stop

    func startMonitoring() {
        refreshDirectoryMonitoring()
        scheduleReconcileTimer(fireImmediately: true)
    }

    func stopAllMonitoring() {
        reconcileTimer?.invalidate()
        reconcileTimer = nil

        pendingRescanWorkItem?.cancel()
        pendingRescanWorkItem = nil

        cancelRootDirectoryWatcher()
        cancelProjectDirectoryWatchers()
        cancelTranscriptWatchers()

        parsers.removeAll()
        cancellables.removeAll()
        trackedFiles.removeAll()
        completedTimestamps.removeAll()
        activeSessions.removeAll()
        isScanInFlight = false
    }

    // MARK: - Directory Scanning

    private func scheduleReconcileTimer(fireImmediately: Bool) {
        guard reconcileTimer == nil else {
            if fireImmediately {
                reconcileTimer?.fire()
            }
            return
        }

        reconcileTimer = Timer.scheduledTimer(withTimeInterval: reconcileInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performReconcile()
            }
        }

        if fireImmediately {
            reconcileTimer?.fire()
        }
    }

    private func performReconcile() {
        refreshDirectoryMonitoring()
        scanAllDirectories()
        removeStaleCompletedSessions()
    }

    private func scheduleRescan() {
        pendingRescanWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.performReconcile()
            }
        }
        pendingRescanWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + rescanDebounce, execute: workItem)
    }

    private func scanAllDirectories() {
        guard !isScanInFlight else { return }
        isScanInFlight = true

        let trackedSnapshot = trackedFiles.mapValues(\.isActive)
        let claudeBaseDir = projectsBaseURL.path
        let kimiBaseDir = kimiBaseURL.path
        let codexBaseDir = codexBaseURL.path
        let activeThreshold = activeThreshold
        let completionThreshold = completionThreshold

        scanQueue.async { [weak self] in
            var allActiveFiles: [SessionDirectoryScanFile] = []
            var allCompletedPaths = Set<String>()

            // Scan Claude Code directory
            let claudeResult = SessionDirectoryScanner.scan(
                baseDir: claudeBaseDir,
                trackedActivity: trackedSnapshot,
                activeThreshold: activeThreshold,
                completionThreshold: completionThreshold
            )
            allActiveFiles.append(contentsOf: claudeResult.activeFiles)
            allCompletedPaths.formUnion(claudeResult.completedPaths)

            // Scan Kimi CLI directory
            let kimiResult = Self.scanKimiDirectory(
                baseDir: kimiBaseDir,
                trackedSnapshot: trackedSnapshot,
                activeThreshold: activeThreshold,
                completionThreshold: completionThreshold
            )
            allActiveFiles.append(contentsOf: kimiResult.activeFiles)
            allCompletedPaths.formUnion(kimiResult.completedPaths)

            // Scan Codex CLI directory
            let codexResult = Self.scanCodexDirectory(
                baseDir: codexBaseDir,
                trackedSnapshot: trackedSnapshot,
                activeThreshold: activeThreshold,
                completionThreshold: completionThreshold
            )
            allActiveFiles.append(contentsOf: codexResult.activeFiles)
            allCompletedPaths.formUnion(codexResult.completedPaths)

            let mergedResult = SessionDirectoryScanResult(
                activeFiles: allActiveFiles.sorted { $0.lastModified > $1.lastModified },
                completedPaths: allCompletedPaths.sorted()
            )

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isScanInFlight = false
                self.applyScanResult(mergedResult)
            }
        }
    }

    private nonisolated static func scanKimiDirectory(
        baseDir: String,
        trackedSnapshot: [String: Bool],
        activeThreshold: TimeInterval,
        completionThreshold: TimeInterval,
        now: Date = Date()
    ) -> SessionDirectoryScanResult {
        let fileManager = FileManager.default
        var activeFiles: [SessionDirectoryScanFile] = []
        var completedPaths = Set<String>()

        guard fileManager.fileExists(atPath: baseDir),
              let hashDirs = try? fileManager.contentsOfDirectory(atPath: baseDir) else {
            return SessionDirectoryScanResult(activeFiles: [], completedPaths: [])
        }

        let workDirMap = loadKimiWorkDirMap()

        for hashDir in hashDirs {
            let hashPath = (baseDir as NSString).appendingPathComponent(hashDir)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: hashPath, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  let uuidDirs = try? fileManager.contentsOfDirectory(atPath: hashPath) else {
                continue
            }

            var hashSessions: [(path: String, modDate: Date, projectName: String)] = []

            for uuidDir in uuidDirs {
                let uuidPath = (hashPath as NSString).appendingPathComponent(uuidDir)
                guard fileManager.fileExists(atPath: uuidPath, isDirectory: &isDirectory),
                      isDirectory.boolValue else { continue }

                let wirePath = (uuidPath as NSString).appendingPathComponent("wire.jsonl")
                guard fileManager.fileExists(atPath: wirePath),
                      let attrs = try? fileManager.attributesOfItem(atPath: wirePath),
                      let modDate = attrs[.modificationDate] as? Date else {
                    continue
                }

                let age = now.timeIntervalSince(modDate)
                if age < activeThreshold {
                    let workDir = workDirMap[hashDir]
                    let workDirName = workDir.map { URL(fileURLWithPath: $0).lastPathComponent }
                    let stateTitle = projectNameFromKimiState(at: wirePath)
                    let projectName = workDirName ?? stateTitle ?? hashDir
                    hashSessions.append((wirePath, modDate, projectName))
                } else if trackedSnapshot[wirePath] == true,
                          age > completionThreshold {
                    completedPaths.insert(wirePath)
                }
            }

            // Keep only the most recent active session per work directory (hash).
            // Older ones from the same directory are marked completed to avoid
            // duplicate floating panels for the same project.
            if let mostRecent = hashSessions.max(by: { $0.modDate < $1.modDate }) {
                activeFiles.append(SessionDirectoryScanFile(
                    path: mostRecent.path,
                    projectName: mostRecent.projectName,
                    lastModified: mostRecent.modDate
                ))
                for session in hashSessions where session.path != mostRecent.path {
                    if trackedSnapshot[session.path] == true {
                        completedPaths.insert(session.path)
                    }
                }
            }
        }

        return SessionDirectoryScanResult(
            activeFiles: activeFiles,
            completedPaths: completedPaths.sorted()
        )
    }

    private nonisolated static func loadKimiWorkDirMap() -> [String: String] {
        let kimiConfigPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kimi/kimi.json").path
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: kimiConfigPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let workDirs = json["work_dirs"] as? [[String: Any]] else {
            return [:]
        }
        var map: [String: String] = [:]
        for entry in workDirs {
            if let path = entry["path"] as? String {
                let hash = md5Hash(of: path)
                map[hash] = path
            }
        }
        return map
    }

    private nonisolated static func md5Hash(of string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func projectNameFromKimiState(at wirePath: String) -> String? {
        let statePath = URL(fileURLWithPath: wirePath)
            .deletingLastPathComponent()
            .appendingPathComponent("state.json")
            .path
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: statePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let title = json["custom_title"] as? String, !title.isEmpty,
           title != "hi" {
            return title
        }
        return nil
    }

    private nonisolated static func scanCodexDirectory(
        baseDir: String,
        trackedSnapshot: [String: Bool],
        activeThreshold: TimeInterval,
        completionThreshold: TimeInterval,
        now: Date = Date()
    ) -> SessionDirectoryScanResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: baseDir) else {
            return SessionDirectoryScanResult(activeFiles: [], completedPaths: [])
        }

        var activeFiles: [SessionDirectoryScanFile] = []
        var completedPaths = Set<String>()

        let calendar = Calendar.current
        let today = now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let dateDirs = [today, yesterday].compactMap { date -> String? in
            let y = calendar.component(.year, from: date)
            let m = calendar.component(.month, from: date)
            let d = calendar.component(.day, from: date)
            let path = (baseDir as NSString)
                .appendingPathComponent(String(format: "%04d", y))
                .appending("/\(String(format: "%02d", m))")
                .appending("/\(String(format: "%02d", d))")
            return fileManager.fileExists(atPath: path) ? path : nil
        }

        for dayDir in dateDirs {
            guard let files = try? fileManager.contentsOfDirectory(atPath: dayDir) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = (dayDir as NSString).appendingPathComponent(file)
                guard let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                      let modDate = attrs[.modificationDate] as? Date else {
                    continue
                }

                let age = now.timeIntervalSince(modDate)
                if age < activeThreshold {
                    let projectName = codexProjectName(forFile: filePath) ?? file
                    activeFiles.append(SessionDirectoryScanFile(
                        path: filePath,
                        projectName: projectName,
                        lastModified: modDate
                    ))
                } else if trackedSnapshot[filePath] == true,
                          age > completionThreshold {
                    completedPaths.insert(filePath)
                }
            }
        }

        return SessionDirectoryScanResult(
            activeFiles: activeFiles.sorted { $0.lastModified > $1.lastModified },
            completedPaths: completedPaths.sorted()
        )
    }

    private nonisolated static func codexProjectName(forFile path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { fileHandle.closeFile() }

        // The first line can be 20KB+ due to base_instructions — full JSON parsing fails
        // on a truncated chunk. cwd appears within the first ~200 bytes, so string search suffices.
        let chunk = fileHandle.readData(ofLength: 512)
        guard !chunk.isEmpty,
              let text = String(data: chunk, encoding: .utf8),
              let cwdRange = text.range(of: "\"cwd\":\"") else { return nil }

        let valueStart = text[cwdRange.upperBound...]
        guard let endQuote = valueStart.firstIndex(of: "\"") else { return nil }
        let cwd = String(valueStart[valueStart.startIndex..<endQuote])
        guard !cwd.isEmpty else { return nil }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }

    private func applyScanResult(_ result: SessionDirectoryScanResult) {
        for tracked in result.activeFiles {
            if trackedFiles[tracked.path] == nil {
                startTrackingSession(tracked)
                continue
            }

            // Only reactivate if file was modified AFTER what we last recorded
            // (i.e., genuinely new content, not just the scan re-seeing the same mtime)
            let previousModified = trackedFiles[tracked.path]?.lastModified ?? .distantPast
            let isNewlyModified = tracked.lastModified > previousModified

            trackedFiles[tracked.path]?.lastModified = tracked.lastModified

            if let index = activeSessions.firstIndex(where: { $0.id == tracked.path }),
               activeSessions[index].status == .completed {
                // Session was completed by parser (Stop event).
                // Only reactivate if the file has genuinely new writes.
                if isNewlyModified {
                    activeSessions[index].status = .unknown
                    trackedFiles[tracked.path]?.isActive = true
                                    }
            } else {
                trackedFiles[tracked.path]?.isActive = true
                            }
        }

        for path in result.completedPaths where trackedFiles[path]?.isActive == true {
            markSessionCompleted(path: path)
        }
    }

    // MARK: - Filesystem Watching

    private func refreshDirectoryMonitoring() {
        guard FileManager.default.fileExists(atPath: projectsBaseURL.path) else {
            cancelRootDirectoryWatcher()
            cancelProjectDirectoryWatchers()
            return
        }

        installRootDirectoryWatcherIfNeeded()
        refreshProjectDirectoryWatchers()
    }

    private func installRootDirectoryWatcherIfNeeded() {
        guard rootDirectorySource == nil else { return }
        let fd = open(projectsBaseURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleRescan()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        rootDirectoryDescriptor = fd
        rootDirectorySource = source
        source.resume()
    }

    private func refreshProjectDirectoryWatchers() {
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsBaseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            cancelProjectDirectoryWatchers()
            return
        }

        let projectPaths = Set(projectDirs.compactMap { url -> String? in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true else {
                return nil
            }
            return url.path
        })

        for existingPath in projectDirectorySources.keys where !projectPaths.contains(existingPath) {
            cancelProjectDirectoryWatcher(path: existingPath)
        }

        for path in projectPaths where projectDirectorySources[path] == nil {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in
                    self?.scheduleRescan()
                }
            }
            source.setCancelHandler {
                close(fd)
            }

            projectDirectoryDescriptors[path] = fd
            projectDirectorySources[path] = source
            source.resume()
        }
    }

    private func startWatchingTranscriptFile(at path: String) {
        guard fileSources[path] == nil else { return }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            let flags = source.data
            if flags.contains(.rename) || flags.contains(.delete) || flags.contains(.revoke) {
                Task { @MainActor [weak self] in
                    self?.handleTranscriptInvalidated(path: path)
                }
                return
            }

            Task { @MainActor [weak self] in
                self?.handleTranscriptChanged(path: path)
            }
        }
        source.setCancelHandler {
            close(fd)
        }

        fileDescriptors[path] = fd
        fileSources[path] = source
        source.resume()
    }

    private func handleTranscriptChanged(path: String) {
        guard let parser = parsers[path] else { return }

        let modDate: Date
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let value = attributes[.modificationDate] as? Date {
            modDate = value
        } else {
            modDate = Date()
        }

        let previousModified = trackedFiles[path]?.lastModified ?? .distantPast
        trackedFiles[path]?.lastModified = modDate

        // Only reactivate completed sessions when file has genuinely new content
        if modDate > previousModified {
            trackedFiles[path]?.isActive = true

            if let index = activeSessions.firstIndex(where: { $0.id == path }),
               activeSessions[index].status == .completed {
                activeSessions[index].status = .unknown
            }
        }

        parser.parseNewContent()
    }

    private func handleTranscriptInvalidated(path: String) {
        markSessionCompleted(path: path)
        scheduleRescan()
    }

    // MARK: - Session Tracking

    private func startTrackingSession(_ tracked: SessionDirectoryScanFile) {
        let path = tracked.path
        guard parsers[path] == nil else { return }

        if parsers.count >= maxSessions {
            removeOldestSession()
        }

        // When a new transcript appears in the same project directory,
        // mark older sessions from that directory as completed.
        // This handles /clear which creates a new file without writing Stop to the old one.
        // For Kimi CLI, "same project" means same work directory (hash).
        let newDir = (path as NSString).deletingLastPathComponent
        let newProjectDir = Self.isKimiPath(path)
            ? (newDir as NSString).deletingLastPathComponent
            : newDir
        for existing in activeSessions where existing.id != path {
            let existingDir = (existing.transcriptPath as NSString).deletingLastPathComponent
            let existingProjectDir = Self.isKimiPath(existing.transcriptPath)
                ? (existingDir as NSString).deletingLastPathComponent
                : existingDir
            if existingProjectDir == newProjectDir,
               existing.status != .completed,
               let existingMod = trackedFiles[existing.id]?.lastModified,
               existingMod <= tracked.lastModified {
                markSessionCompleted(path: existing.id)
            }
        }

        trackedFiles[path] = TrackedFile(
            path: tracked.path,
            projectName: tracked.projectName,
            lastModified: tracked.lastModified,
            isActive: true
        )

        let parser = TranscriptParser(filePath: path)
        parsers[path] = parser
        startWatchingTranscriptFile(at: path)

        let source: SessionSource
        if Self.isKimiPath(path) {
            source = .kimi
        } else if Self.isCodexPath(path) {
            source = .codex
        } else {
            source = .claude
        }
        let session = ActiveSession(project: tracked.projectName, transcriptPath: path, source: source)
        var subscriptions = Set<AnyCancellable>()

        parser.$lastMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                guard let self,
                      let index = self.activeSessions.firstIndex(where: { $0.id == path }) else { return }
                self.activeSessions[index].lastMessages = messages
            }
            .store(in: &subscriptions)

        parser.$currentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self,
                      let index = self.activeSessions.firstIndex(where: { $0.id == path }) else { return }
                // Skip stale parser updates for sessions already marked inactive
                // (e.g. /clear created a new transcript, old session was completed externally)
                if self.trackedFiles[path]?.isActive == false, status != .completed {
                    return
                }
                if status == .completed {
                    self.markSessionCompleted(path: path)
                } else {
                    self.activeSessions[index].status = status
                    // Reactivated after completion — clear the removal timestamp
                    self.completedTimestamps.removeValue(forKey: path)
                }
            }
            .store(in: &subscriptions)

        parser.$currentTool
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tool in
                guard let self,
                      let index = self.activeSessions.firstIndex(where: { $0.id == path }) else { return }
                self.activeSessions[index].currentTool = tool
            }
            .store(in: &subscriptions)

        parser.$tokenUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                guard let self,
                      let index = self.activeSessions.firstIndex(where: { $0.id == path }) else { return }
                self.activeSessions[index].tokenUsage = usage
            }
            .store(in: &subscriptions)

        cancellables[path] = subscriptions
        activeSessions.append(session)
    }

    private func markSessionCompleted(path: String) {
        guard let index = activeSessions.firstIndex(where: { $0.id == path }) else { return }
        if activeSessions[index].status != .completed {
            activeSessions[index].status = .completed
            completedTimestamps[path] = Date()
        }
        trackedFiles[path]?.isActive = false
    }

    private func removeStaleCompletedSessions() {
        let now = Date()
        let stale = completedTimestamps.filter { now.timeIntervalSince($0.value) > completedRemovalDelay }
        for (path, _) in stale {
            removeSession(path: path)
            completedTimestamps.removeValue(forKey: path)
        }
    }

    // MARK: - Cleanup

    private func removeSession(path: String) {
        cancelTranscriptWatcher(path: path)
        parsers.removeValue(forKey: path)
        cancellables.removeValue(forKey: path)
        trackedFiles.removeValue(forKey: path)
        completedTimestamps.removeValue(forKey: path)
        activeSessions.removeAll { $0.id == path }
    }

    private func removeOldestSession() {
        guard let oldest = activeSessions.min(by: { $0.startTime < $1.startTime }) else { return }
        removeSession(path: oldest.transcriptPath)
    }

    private static func isKimiPath(_ path: String) -> Bool {
        path.contains(".kimi/sessions")
    }

    private static func isCodexPath(_ path: String) -> Bool {
        path.contains(".codex/sessions")
    }

    private func cancelRootDirectoryWatcher() {
        rootDirectorySource?.cancel()
        rootDirectorySource = nil
        rootDirectoryDescriptor = -1
    }

    private func cancelProjectDirectoryWatchers() {
        for path in Array(projectDirectorySources.keys) {
            cancelProjectDirectoryWatcher(path: path)
        }
        projectDirectoryDescriptors.removeAll()
    }

    private func cancelProjectDirectoryWatcher(path: String) {
        projectDirectorySources[path]?.cancel()
        projectDirectorySources.removeValue(forKey: path)
        projectDirectoryDescriptors.removeValue(forKey: path)
    }

    private func cancelTranscriptWatchers() {
        for path in Array(fileSources.keys) {
            cancelTranscriptWatcher(path: path)
        }
        fileDescriptors.removeAll()
    }

    private func cancelTranscriptWatcher(path: String) {
        fileSources[path]?.cancel()
        fileSources.removeValue(forKey: path)
        fileDescriptors.removeValue(forKey: path)
    }

    // MARK: - Helpers

    nonisolated static func extractProjectName(from dirName: String) -> String {
        let components = dirName.split(separator: "-")
        if let last = components.last, !last.isEmpty {
            return String(last)
        }
        return dirName
    }
}

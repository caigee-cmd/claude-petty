// MonitorTab.swift
// ClaudeDash - 实时监控 Tab
// 活跃 session 列表 + 选中详情（状态/消息预览/Token 进度条/工具图标）

import SwiftUI

struct MonitorTab: View {
    @EnvironmentObject var sessionMonitor: SessionMonitor

    /// 当前选中的 session ID
    @State private var selectedSessionID: String?

    var body: some View {
        HSplitView {
            // 左侧：Session 列表
            sessionList
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            // 右侧：选中 session 的详情
            sessionDetail
                .frame(minWidth: 300)
        }
        .padding(.top, 20)
    }

    // MARK: - Session 列表

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("活跃 Session")
                    .font(.headline)
                Spacer()
                Text("\(sessionMonitor.activeSessions.count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2), in: Capsule())
            }
            .padding(.horizontal)
            .padding(.top, 10)

            if sessionMonitor.activeSessions.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: ClaudeDashSymbols.monitorEmptyState)
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("暂无活跃 Session")
                        .foregroundStyle(.secondary)
                    Text("等待 Claude Code 任务开始...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(sessionMonitor.activeSessions, selection: $selectedSessionID) { session in
                    SessionRow(session: session)
                        .tag(session.id)
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Session 详情

    @ViewBuilder
    private var sessionDetail: some View {
        if let sessionID = selectedSessionID,
           let session = sessionMonitor.activeSessions.first(where: { $0.id == sessionID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 项目名 + 状态
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.project)
                                .font(.title3.bold())
                            StatusBadge(status: session.status)
                        }
                        Spacer()
                        // 当前工具图标
                        ToolBadge(tool: session.currentTool)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // Token 使用进度条
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Token 使用")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(session.tokenUsage * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        TokenProgressBar(usage: session.tokenUsage)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // 最后 5 条消息预览
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近消息")
                            .font(.headline)

                        if session.lastMessages.isEmpty {
                            Text("暂无消息")
                                .foregroundStyle(.tertiary)
                                .padding()
                        } else {
                            ForEach(session.lastMessages) { msg in
                                MessageRow(message: msg)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    Spacer()
                }
                .padding()
            }
        } else {
            // 未选中状态
            VStack(spacing: 12) {
                Spacer()
                    Image(systemName: ClaudeDashSymbols.monitorSelectionState)
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("选择一个 Session 查看详情")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Session 列表行

struct SessionRow: View {
    let session: ActiveSession

    var body: some View {
        HStack(spacing: 8) {
            // 状态指示圆点
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    BrandIcon(source: session.source, size: 12)
                        .foregroundStyle(session.source.brandColor)
                    Text(session.project)
                        .font(.body)
                        .lineLimit(1)
                }
                Text(session.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 当前工具小图标
            if session.currentTool != .unknown {
                Image(systemName: session.currentTool.sfSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch session.status {
        case .thinking: return .yellow
        case .toolRunning: return .blue
        case .completed: return .green
        case .unknown: return .gray
        }
    }
}

// MARK: - 状态徽章

struct StatusBadge: View {
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(status.rawValue)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .thinking: return .yellow
        case .toolRunning: return .blue
        case .completed: return .green
        case .unknown: return .gray
        }
    }
}

// MARK: - 工具徽章

struct ToolBadge: View {
    let tool: ToolType

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: tool.sfSymbol)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(tool.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Token 进度条

struct TokenProgressBar: View {
    let usage: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)

                // 进度
                RoundedRectangle(cornerRadius: 4)
                    .fill(progressColor)
                    .frame(width: max(0, geometry.size.width * usage))
            }
        }
        .frame(height: 8)
    }

    /// 颜色随使用率变化：绿 < 50%、黄 50-80%、红 > 80%
    private var progressColor: Color {
        if usage < 0.5 { return .green }
        if usage < 0.8 { return .yellow }
        return .red
    }
}

// MARK: - 消息行

struct MessageRow: View {
    let message: TranscriptMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 角色图标
            Image(systemName: roleIcon)
                .font(.caption)
                .foregroundStyle(roleColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                // 工具名（如有）
                if let tool = message.toolName {
                    Text(tool)
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
                // 内容预览
                Text(message.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var roleIcon: String {
        switch message.role {
        case "assistant": return "sparkles"
        case "user": return "person"
        case "tool": return "wrench"
        default: return "circle"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case "assistant": return .purple
        case "user": return .blue
        case "tool": return .orange
        default: return .gray
        }
    }
}

#Preview {
    MonitorTab()
        .environmentObject(SessionMonitor.shared)
        .frame(width: 700, height: 500)
}

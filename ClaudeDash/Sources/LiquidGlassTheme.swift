// LiquidGlassTheme.swift
// ClaudeDash - Liquid Glass 设计系统
// 颜色、渐变、玻璃效果修饰器、可复用卡片组件

import SwiftUI

// MARK: - Claude 品牌色

extension Color {
    /// Claude 紫 #7C3AED
    static let claudePurple = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)
    /// Claude 青 #22D3EE
    static let claudeCyan = Color(red: 34 / 255, green: 211 / 255, blue: 238 / 255)
    /// Kimi 蓝 #0EA5E9
    static let kimiCyan = Color(red: 14 / 255, green: 165 / 255, blue: 233 / 255)
    /// Codex 绿 #10A37F
    static let codexGreen = Color(red: 16 / 255, green: 163 / 255, blue: 127 / 255)
    /// 警告橙 #F97316
    static let claudeWarningOrange = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    /// 警告红 #EF4444
    static let claudeWarningRed = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
}

// MARK: - 渐变预设

enum ClaudeGradients {
    /// 主渐变：紫 → 青
    static let primary = LinearGradient(
        colors: [.claudePurple, .claudeCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 警告渐变：橙 → 红
    static let warning = LinearGradient(
        colors: [.claudeWarningOrange, .claudeWarningRed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 自适应渐变（usage > 85% 切换为警告）
    static func adaptive(isWarning: Bool) -> LinearGradient {
        isWarning ? warning : primary
    }

    /// 主色角渐变（用于环形图）
    static let primaryAngular = AngularGradient(
        colors: [.claudePurple, .claudeCyan, .claudePurple],
        center: .center
    )

    /// 微光叠加（玻璃高光）
    static let glassHighlight = LinearGradient(
        colors: [.white.opacity(0.12), .white.opacity(0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 玻璃边框
    static let glassBorder = LinearGradient(
        colors: [.white.opacity(0.25), .white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Liquid Glass 效果修饰器

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var hasBorder: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(ClaudeGradients.glassHighlight)
                    }
                    .overlay {
                        if hasBorder {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(ClaudeGradients.glassBorder, lineWidth: 0.5)
                        }
                    }
            }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

extension View {
    /// Liquid Glass 主效果（大容器用）
    func liquidGlass(cornerRadius: CGFloat = 24) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, hasBorder: true))
    }

    /// 小型玻璃卡片效果
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, hasBorder: true))
    }

    /// 极简玻璃底（无边框）
    func glassBackground(cornerRadius: CGFloat = 12) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, hasBorder: false))
    }

    /// 统计页主卡片 — 半透明叠层（依赖窗口级 NSVisualEffectView 提供模糊）
    func statsCard(cornerRadius: CGFloat = 16) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        }
    }

    /// 统计页辅助底板 — 极淡叠层
    func statsBackground(cornerRadius: CGFloat = 12) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.05))
        }
    }
}

enum StatsPanelStyle {
    static let compactSpacing: CGFloat = 6
    static let regularSpacing: CGFloat = 10
    static let blockSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 12
    static let inactiveTextOpacity: Double = 0.64
    static let secondaryTextOpacity: Double = 0.68
    static let tertiaryTextOpacity: Double = 0.54

    static var miniLabel: Font {
        .system(size: 10, weight: .semibold)
    }

    static var secondaryLabel: Font {
        .system(size: 11, weight: .semibold)
    }

    static var miniValue: Font {
        .system(size: 12, weight: .semibold, design: .monospaced)
    }

    static var metaValue: Font {
        .system(size: 11, weight: .medium, design: .monospaced)
    }

    static var legendValue: Font {
        .system(size: 14, weight: .bold, design: .rounded)
    }

    static var sectionHeader: Font {
        .system(size: 12, weight: .semibold)
    }

    static var sectionTrailing: Font {
        .system(size: 11, weight: .medium)
    }
}

// MARK: - Glass 指标卡片

struct GlassMetricCard: View {
    let icon: String
    let value: String
    let label: String
    var accentColor: Color = .claudePurple
    var trend: Int? = nil
    var trendDouble: Double? = nil

    @State private var isHovered = false

    private var trendDirection: Int {
        if let t = trend { return t }
        if let d = trendDouble { return d > 0.001 ? 1 : (d < -0.001 ? -1 : 0) }
        return 0
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accentColor)

                if trendDirection != 0 {
                    Image(systemName: trendDirection > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(trendDirection > 0 ? .green : .red)
                }
            }

            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.primary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .glassCard(cornerRadius: 14)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .brightness(isHovered ? 0.04 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Glass 区域标题

struct GlassSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(StatsPanelStyle.sectionHeader)
                .foregroundStyle(.primary.opacity(StatsPanelStyle.secondaryTextOpacity))
                .textCase(.uppercase)
                .tracking(0.45)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(StatsPanelStyle.sectionTrailing)
                    .foregroundStyle(.primary.opacity(StatsPanelStyle.inactiveTextOpacity))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - 渐变文字修饰器

struct GradientTextModifier: ViewModifier {
    var gradient: LinearGradient

    func body(content: Content) -> some View {
        content
            .overlay { gradient.mask(content) }
    }
}

extension View {
    func gradientForeground(_ gradient: LinearGradient = ClaudeGradients.primary) -> some View {
        overlay { gradient.mask(self) }
    }
}

// MARK: - macOS 原生毛玻璃窗口背景

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

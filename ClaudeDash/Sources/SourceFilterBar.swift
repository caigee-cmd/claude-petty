// SourceFilterBar.swift
// ClaudeDash - 自定义来源筛选 Pill Bar（Liquid Glass 风格）

import SwiftUI

struct SourceFilterBar: View {
    @Binding var selection: StatsDataSource

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StatsDataSource.allCases) { source in
                SourcePill(
                    source: source,
                    isSelected: selection == source
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = source
                    }
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - 单个 Pill

private struct SourcePill: View {
    let source: StatsDataSource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                sourceIcon

                Text(source.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? AnyShapeStyle(source.accentGradient) : AnyShapeStyle(Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.white.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? source.color.opacity(0.35) : .clear,
                radius: 6, x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 0.96)
        .animation(.spring(response: 0.30, dampingFraction: 0.80), value: isSelected)
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch source {
        case .all:
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 11, weight: .semibold))
        case .claude:
            BrandIcon(source: .claude, size: 13)
        case .kimi:
            BrandIcon(source: .kimi, size: 13)
        }
    }
}

// MARK: - StatsDataSource 扩展颜色

extension StatsDataSource {
    var accentGradient: LinearGradient {
        switch self {
        case .all:
            return LinearGradient(
                colors: [.secondary.opacity(0.45), .secondary.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .claude:
            return LinearGradient(
                colors: [.claudePurple.opacity(0.85), .claudePurple.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .kimi:
            return LinearGradient(
                colors: [.kimiCyan.opacity(0.85), .kimiCyan.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var source: StatsDataSource = .all

    VStack(spacing: 20) {
        SourceFilterBar(selection: $source)
            .padding()
            .background(Color.black)

        SourceFilterBar(selection: $source)
            .padding()
            .background(Color.white)
    }
}

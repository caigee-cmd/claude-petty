// ActivityRingsView.swift
// ClaudeDash - Apple Fitness 风格三环进度组件
// 外环：今日 Session 进度 / 中环：7 日活跃度 / 内环：Token 消耗进度

import SwiftUI

struct ActivityRingsView: View {
    let sessionProgress: Double
    let weeklyProgress: Double
    let tokenProgress: Double
    let centerValue: String
    let centerSubtitle: String?
    var size: CGFloat = 150
    var showsResetCountdown: Bool = true

    @State private var animatedSession: Double = 0
    @State private var animatedWeekly: Double = 0
    @State private var animatedToken: Double = 0
    @State private var appeared = false
    @State private var midnightText: String = ""

    private let ringSpacing: CGFloat = 3

    private var outerWidth: CGFloat { size * 0.09 }
    private var middleWidth: CGFloat { size * 0.09 }
    private var innerWidth: CGFloat { size * 0.09 }

    private var outerDiameter: CGFloat { size }
    private var middleDiameter: CGFloat { size - (outerWidth * 2 + ringSpacing * 2) }
    private var innerDiameter: CGFloat { size - (outerWidth * 2 + middleWidth * 2 + ringSpacing * 4) }

    var body: some View {
        ZStack {
            // 外环：Session 进度 (紫色)
            SingleRingView(
                progress: animatedSession,
                startColor: .claudePurple,
                endColor: sessionProgress > 0.85 ? .claudeWarningOrange : .claudeCyan,
                ringWidth: outerWidth,
                diameter: outerDiameter
            )

            // 中环：7 日活跃度 (紫-青混合)
            SingleRingView(
                progress: animatedWeekly,
                startColor: .claudePurple.opacity(0.8),
                endColor: .claudeCyan.opacity(0.9),
                ringWidth: middleWidth,
                diameter: middleDiameter
            )

            // 内环：Token 进度 (青色)
            SingleRingView(
                progress: animatedToken,
                startColor: .claudeCyan,
                endColor: tokenProgress > 0.85 ? .claudeWarningRed : .claudePurple,
                ringWidth: innerWidth,
                diameter: innerDiameter
            )

            // 中心数字
            centerContent
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.1)) {
                animatedSession = sessionProgress
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2)) {
                animatedWeekly = weeklyProgress
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3)) {
                animatedToken = tokenProgress
            }
            midnightText = Self.timeUntilMidnight(from: Date())
        }
        .onChange(of: sessionProgress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                animatedSession = newValue
            }
        }
        .onChange(of: weeklyProgress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                animatedWeekly = newValue
            }
        }
        .onChange(of: tokenProgress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                animatedToken = newValue
            }
        }
    }

    private var centerContent: some View {
        VStack(spacing: 2) {
            Text(centerValue)
                .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            if let centerSubtitle, !centerSubtitle.isEmpty {
                Text(centerSubtitle)
                    .font(.system(size: size * 0.06, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // 日重置倒计时（popover 打开时刷新一次即可）
            if showsResetCountdown {
                Text(midnightText)
                    .font(.system(size: size * 0.055, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    static func timeUntilMidnight(from date: Date) -> String {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date)) else {
            return ""
        }
        let diff = tomorrow.timeIntervalSince(date)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        return "↻ \(hours)h \(minutes)m"
    }
}

// MARK: - 单环组件

struct SingleRingView: View {
    let progress: Double
    let startColor: Color
    let endColor: Color
    let ringWidth: CGFloat
    let diameter: CGFloat

    var body: some View {
        ZStack {
            // 轨道底色
            Circle()
                .stroke(startColor.opacity(0.1), lineWidth: ringWidth)
                .frame(width: diameter, height: diameter)

            // 渐变进度环
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    LinearGradient(
                        colors: [startColor, endColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(-90))

            // 末端发光
            if progress > 0.03 {
                Circle()
                    .fill(endColor)
                    .frame(width: ringWidth * 0.7, height: ringWidth * 0.7)
                    .shadow(color: endColor.opacity(0.6), radius: ringWidth * 0.5)
                    .offset(y: -(diameter / 2))
                    .rotationEffect(.degrees(360 * min(progress, 1) - 90))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.9)
        ActivityRingsView(
            sessionProgress: 0.72,
            weeklyProgress: 0.86,
            tokenProgress: 0.45,
            centerValue: "1.2M",
            centerSubtitle: "tokens today",
            size: 180
        )
    }
    .frame(width: 300, height: 300)
}

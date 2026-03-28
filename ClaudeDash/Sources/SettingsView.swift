import SwiftUI

private enum SettingsPanelStyle {
    static let windowWidth: CGFloat = 488
    static let sectionSpacing: CGFloat = 14
    static let shellPadding: CGFloat = 16
    static let shellSpacing: CGFloat = 14
    static let shellCornerRadius: CGFloat = 26
    static let previewHeight: CGFloat = 232
    static let controlPadding: CGFloat = 12
    static let optionSpacing: CGFloat = 8
    static let optionPreviewSize: CGFloat = 46
    static let appearanceColumns = Array(
        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: optionSpacing),
        count: 4
    )
}

struct SettingsView: View {
    let isFirstLaunchSetup: Bool
    let onFinishSetup: (() -> Void)?

    @AppStorage(
        FloatingMascotPreferences.enabledUserDefaultsKey,
        store: ClaudeDashDefaults.shared
    ) private var isMascotEnabled = false
    @AppStorage(
        FloatingMascotAppearanceOption.userDefaultsKey,
        store: ClaudeDashDefaults.shared
    ) private var mascotAppearanceRawValue = FloatingMascotAppearanceOption.runner.rawValue
    @AppStorage(
        FloatingMascotSizeOption.userDefaultsKey,
        store: ClaudeDashDefaults.shared
    ) private var mascotSizeRawValue = FloatingMascotSizeOption.extraLarge.rawValue
    @AppStorage(
        FloatingMascotAnimationSpeedOption.userDefaultsKey,
        store: ClaudeDashDefaults.shared
    ) private var mascotAnimationSpeedRawValue = FloatingMascotAnimationSpeedOption.normal.rawValue
    @AppStorage(
        FloatingMascotPreferences.didCompleteSetupUserDefaultsKey,
        store: ClaudeDashDefaults.shared
    ) private var didCompleteSetup = false

    init(
        isFirstLaunchSetup: Bool = false,
        onFinishSetup: (() -> Void)? = nil
    ) {
        self.isFirstLaunchSetup = isFirstLaunchSetup
        self.onFinishSetup = onFinishSetup
    }

    private var selectedAppearance: FloatingMascotAppearanceOption {
        FloatingMascotAppearanceOption(rawValue: mascotAppearanceRawValue) ?? .runner
    }

    private var selectedMascotSize: FloatingMascotSizeOption {
        FloatingMascotSizeOption(rawValue: mascotSizeRawValue) ?? .extraLarge
    }

    private var selectedAnimationSpeed: FloatingMascotAnimationSpeedOption {
        FloatingMascotAnimationSpeedOption(rawValue: mascotAnimationSpeedRawValue) ?? .normal
    }

    private var previewPlaybackState: FloatingMascotPlaybackState {
        isMascotEnabled ? .playing(speed: selectedAnimationSpeed.multiplier) : .stoppedAtFirstFrame
    }

    private var previewMascotLength: CGFloat {
        min(selectedMascotSize.mascotLength + 52, 196)
    }

    private var previewAccentColor: Color {
        isMascotEnabled ? .accentColor : .claudePurple
    }

    private var speedSymbolName: String {
        switch selectedAnimationSpeed {
        case .slow:
            return "tortoise.fill"
        case .normal:
            return "speedometer"
        case .fast:
            return "hare.fill"
        case .veryFast:
            return "bolt.fill"
        }
    }

    private var sizeSliderBinding: Binding<Double> {
        Binding(
            get: {
                Double(FloatingMascotSizeOption.allCases.firstIndex(of: selectedMascotSize) ?? 2)
            },
            set: { newValue in
                let allCases = FloatingMascotSizeOption.allCases
                let clampedIndex = min(max(Int(newValue.rounded()), 0), allCases.count - 1)
                applyMascotSize(allCases[clampedIndex])
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsPanelStyle.sectionSpacing) {
            contentCard
            footer
        }
        .padding(18)
        .frame(width: SettingsPanelStyle.windowWidth)
        .background(windowBackground)
        .onChange(of: isMascotEnabled) {
            didCompleteSetup = true
        }
    }

    private var windowBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            Circle()
                .fill(Color.claudePurple.opacity(0.09))
                .frame(width: 240, height: 240)
                .blur(radius: 120)
                .offset(x: -150, y: -140)

            Circle()
                .fill(Color.claudeCyan.opacity(0.06))
                .frame(width: 200, height: 200)
                .blur(radius: 96)
                .offset(x: 130, y: -90)
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: SettingsPanelStyle.shellSpacing) {
            previewStage
            appearanceGrid
            controlRail
        }
        .padding(SettingsPanelStyle.shellPadding)
        .background(contentShellBackground)
    }

    private var contentShellBackground: some View {
        RoundedRectangle(cornerRadius: SettingsPanelStyle.shellCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.055),
                        Color.white.opacity(0.028)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: SettingsPanelStyle.shellCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                previewAccentColor.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 24, y: 14)
    }

    private var previewStage: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        previewAccentColor.opacity(isMascotEnabled ? 0.15 : 0.09),
                        Color.white.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                previewAccentColor.opacity(isMascotEnabled ? 0.18 : 0.10),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(isMascotEnabled ? previewAccentColor : Color.white.opacity(0.18))
                        .frame(width: 8, height: 8)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.26), lineWidth: 0.8)
                        }

                    Toggle("", isOn: $isMascotEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("启用悬浮精灵")
                        .controlSize(.mini)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
                        }
                )
                .padding(14)
            }
            .overlay {
                ZStack {
                    Ellipse()
                        .fill(Color.black.opacity(0.07))
                        .frame(width: 144, height: 22)
                        .blur(radius: 16)
                        .offset(y: 48)

                    Circle()
                        .fill(previewAccentColor.opacity(isMascotEnabled ? 0.15 : 0.08))
                        .frame(width: 148, height: 148)
                        .blur(radius: 44)
                        .offset(y: 10)

                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .frame(width: 94, height: 94)
                        .blur(radius: 20)
                        .offset(y: -16)

                    FloatingMascotLottieView(
                        appearance: selectedAppearance,
                        playbackState: previewPlaybackState
                    )
                    .frame(width: previewMascotLength, height: previewMascotLength)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: SettingsPanelStyle.previewHeight)
            .help(selectedAppearance.title)
    }

    private var appearanceGrid: some View {
        LazyVGrid(columns: SettingsPanelStyle.appearanceColumns, spacing: SettingsPanelStyle.optionSpacing) {
            ForEach(FloatingMascotAppearanceOption.allCases) { option in
                MascotAppearanceTile(
                    option: option,
                    isSelected: option == selectedAppearance,
                    playbackState: option == selectedAppearance ? previewPlaybackState : .stoppedAtFirstFrame
                ) {
                    mascotAppearanceRawValue = option.rawValue
                }
            }
        }
    }

    private var controlRail: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Slider(
                    value: sizeSliderBinding.animation(.spring(response: 0.24, dampingFraction: 0.88)),
                    in: 0...Double(FloatingMascotSizeOption.allCases.count - 1),
                    step: 1
                )
                .accessibilityLabel("精灵大小")
                .accessibilityValue(selectedMascotSize.title)

                Image(systemName: "circle.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 22)

            Menu {
                ForEach(FloatingMascotAnimationSpeedOption.allCases) { option in
                    Button {
                        mascotAnimationSpeedRawValue = option.rawValue
                    } label: {
                        Label(option.title, systemImage: option.menuSymbolName)
                    }
                }
            } label: {
                Image(systemName: speedSymbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("动画速度")
            .accessibilityValue(selectedAnimationSpeed.title)
        }
        .padding(SettingsPanelStyle.controlPadding)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.034))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.6)
                }
        )
    }

    @ViewBuilder
    private var footer: some View {
        if isFirstLaunchSetup {
            HStack(spacing: 10) {
                Button("完成") {
                    didCompleteSetup = true
                    onFinishSetup?()
                }
                .buttonStyle(.borderedProminent)

                Button("稍后") {
                    onFinishSetup?()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        } else {
            HStack {
                Spacer(minLength: 0)

                Button {
                    restoreDefaults()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("恢复默认设置")
                .accessibilityLabel("恢复默认设置")
            }
        }
    }

    private func applyMascotSize(_ option: FloatingMascotSizeOption) {
        guard mascotSizeRawValue != option.rawValue else { return }
        mascotSizeRawValue = option.rawValue
        NotificationCenter.default.post(name: .floatingMascotSizeDidChange, object: nil)
    }

    private func restoreDefaults() {
        isMascotEnabled = false
        mascotAppearanceRawValue = FloatingMascotAppearanceOption.runner.rawValue
        mascotAnimationSpeedRawValue = FloatingMascotAnimationSpeedOption.normal.rawValue
        applyMascotSize(.extraLarge)
        didCompleteSetup = true
    }
}

private extension FloatingMascotAnimationSpeedOption {
    var menuSymbolName: String {
        switch self {
        case .slow:
            return "tortoise.fill"
        case .normal:
            return "speedometer"
        case .fast:
            return "hare.fill"
        case .veryFast:
            return "bolt.fill"
        }
    }
}

private struct MascotAppearanceTile: View {
    let option: FloatingMascotAppearanceOption
    let isSelected: Bool
    let playbackState: FloatingMascotPlaybackState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.accentColor.opacity(0.18), Color.white.opacity(0.08)]
                                : [Color.white.opacity(0.045), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.34) : Color.white.opacity(0.06),
                                lineWidth: isSelected ? 1.0 : 0.6
                            )
                    }

                Ellipse()
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 30, height: 7)
                    .blur(radius: 6)
                    .offset(y: 12)

                FloatingMascotLottieView(
                    appearance: option,
                    playbackState: playbackState
                )
                .frame(width: SettingsPanelStyle.optionPreviewSize, height: SettingsPanelStyle.optionPreviewSize)
            }
            .frame(height: 58)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .offset(y: isSelected ? -1 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择\(option.title)形象")
        .accessibilityValue(isSelected ? "已选中" : "未选中")
        .help(option.title)
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: isSelected)
    }
}

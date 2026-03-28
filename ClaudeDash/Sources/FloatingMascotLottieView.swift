import SwiftUI
import Lottie

struct FloatingMascotLottieView: View {
    let appearance: FloatingMascotAppearanceOption
    let playbackState: FloatingMascotPlaybackState

    var body: some View {
        LottieView(animation: .named(appearance.resourceName))
            .resizable()
            .playbackMode(lottiePlaybackMode)
            .animationSpeed(playbackSpeed)
            .configure(\.shouldRasterizeWhenIdle, to: true)
    }

    private var lottiePlaybackMode: LottiePlaybackMode {
        switch playbackState {
        case .stoppedAtFirstFrame:
            .paused(at: .progress(0))

        case .playing:
            .playing(.fromProgress(nil, toProgress: 1, loopMode: .loop))
        }
    }

    private var playbackSpeed: Double {
        switch playbackState {
        case .stoppedAtFirstFrame:
            1.0

        case let .playing(speed):
            speed
        }
    }
}

import SwiftUI

/// Album cover with a placeholder note while it loads.
struct MediaArtwork: View {
    let image: NSImage?
    var cornerRadius: CGFloat = 5

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.1))
                Image(systemName: "music.note")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .scaleEffect(cornerRadius / 5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(.easeOut(duration: 0.3), value: image)
    }
}

/// Four bars dancing while music plays, resting flat when paused.
struct EqualizerBars: View {
    var color: Color
    var playing: Bool

    private static let speeds: [Double] = [7.1, 9.3, 6.2, 8.4]
    private static let offsets: [Double] = [0, 1.7, 3.1, 0.9]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let wave = 0.5 + 0.5 * sin(t * Self.speeds[i] + Self.offsets[i]) * sin(t * 2.3 + Double(i))
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: playing ? 3 + 11 * CGFloat(abs(wave)) : 3)
                }
            }
            .frame(height: 14)
        }
        .animation(.easeOut(duration: 0.25), value: playing)
    }
}

/// The player shown when you hover the notch: cover, title, progress and controls.
struct MediaPlayerCard: View {
    @ObservedObject var media: NowPlaying

    var body: some View {
        if let track = media.track {
            HStack(spacing: 14) {
                MediaArtwork(image: media.artwork, cornerRadius: 12)
                    .frame(width: 62, height: 62)
                    .shadow(color: media.accent.opacity(0.45), radius: 10)
                    .id(track.id)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .onTapGesture { media.openPlayer() }

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                    ProgressRow(media: media, duration: track.duration)
                        .padding(.top, 5)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    ControlButton(symbol: "backward.fill", size: 13) { media.previous() }
                    ControlButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", size: 19, prominent: true) {
                        media.togglePlayPause()
                    }
                    ControlButton(symbol: "forward.fill", size: 13) { media.next() }
                }
            }
            .padding(.horizontal, 22)
            .frame(height: NotchViewModel.mediaCardHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: track.id)
        }
    }
}

private struct ProgressRow: View {
    @ObservedObject var media: NowPlaying
    let duration: TimeInterval?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let position = media.position(at: timeline.date)
            let progress = duration.map { $0 > 0 ? position / $0 : 0 } ?? 0
            HStack(spacing: 8) {
                Text(Self.clock(position))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule()
                            .fill(media.accent)
                            .frame(width: max(4, geo.size.width * progress))
                            .animation(.linear(duration: 0.5), value: progress)
                    }
                    .frame(height: 4)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                        media.seek(to: value.location.x / max(1, geo.size.width))
                    })
                }
                .frame(height: 12)
                Text(duration.map(Self.clock) ?? "–:––")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
        }
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct ControlButton: View {
    let symbol: String
    var size: CGFloat
    var prominent = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering || prominent ? 1 : 0.75))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: prominent ? 38 : 28, height: prominent ? 38 : 28)
                .background(Circle().fill(.white.opacity(hovering ? 0.14 : (prominent ? 0.08 : 0))))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// Small ✕ in the corner of a notification that sends the notch back to its resting state.
struct DismissButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(hovering ? 0.9 : 0.45))
                .frame(width: 20, height: 20)
                .background(Circle().fill(.white.opacity(hovering ? 0.18 : 0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

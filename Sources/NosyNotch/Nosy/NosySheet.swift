import SwiftUI

/// `NosyNotch --nosy-sheet <file.png>`: every mood side by side, for tuning the drawing without running the app.
@MainActor
enum NosySheet {
    static let moods: [(NosyMood, String)] = [
        (.idle, "idle"), (.working, "working"), (.typing, "typing"), (.sweating, "sweating"),
        (.dizzy, "dizzy"), (.needsYou, "needs you"), (.happy, "happy"), (.shocked, "shocked"),
        (.exhausted, "exhausted"), (.sleepy, "sleepy"), (.sleeping, "sleeping"), (.grooving, "grooving"),
        (.giggle, "giggle"), (.charging, "charging"), (.waking, "waking"),
    ]

    static func render(to url: URL) {
        let view = VStack(alignment: .leading, spacing: 18) {
            grid(level: 3, accessory: .none, hanging: false)
            HStack(spacing: 18) {
                ForEach(NosyAccessory.allCases) { accessory in
                    cell(.idle, accessory.title, level: 10, accessory: accessory, hanging: false)
                }
                cell(.idle, "hanging", level: 1, accessory: .none, hanging: true)
                cell(.happy, "hanging happy", level: 1, accessory: .none, hanging: true)
            }
            HStack(spacing: 18) {
                ForEach(NosyColor.allCases) { color in
                    VStack(spacing: 6) {
                        NosyFigure(mood: .idle, look: CGSize(width: 0.4, height: 0.2), tint: Theme.claude, color: color)
                            .frame(width: 70, height: 88)
                        Text(color.title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            HStack(spacing: 18) {
                ForEach([NosyMood.idle, .working, .needsYou, .happy, .sleeping, .shocked, .dizzy, .giggle], id: \.self) { mood in
                    VStack(spacing: 6) {
                        NosyWingEyes(mood: mood, look: CGSize(width: 0.5, height: 0.3), tint: Theme.claude)
                            .frame(width: 30, height: 18)
                            .padding(8)
                            .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                        Text(label(mood)).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(24)
        .background(Color(red: 0.12, green: 0.11, blue: 0.18))
        .environment(\.virtualDate, Date(timeIntervalSinceReferenceDate: 1000.3))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    private static func label(_ mood: NosyMood) -> String {
        moods.first { $0.0 == mood }?.1 ?? "\(mood)"
    }

    private static func grid(level: Int, accessory: NosyAccessory, hanging: Bool) -> some View {
        let rows = stride(from: 0, to: moods.count, by: 8).map { Array(moods[$0..<min($0 + 8, moods.count)]) }
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 18) {
                    ForEach(rows[i], id: \.1) { mood, name in
                        cell(mood, name, level: level, accessory: accessory, hanging: hanging)
                    }
                }
            }
        }
    }

    private static func cell(_ mood: NosyMood, _ name: String, level: Int, accessory: NosyAccessory, hanging: Bool) -> some View {
        VStack(spacing: 6) {
            NosyFigure(mood: mood, look: CGSize(width: 0.4, height: 0.2), level: level, accessory: accessory, hanging: hanging,
                       tint: Theme.claude)
                .frame(width: 90, height: 114)
            Text(name).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers

/// While you drag files near the notch: two targets – park them on the shelf, or AirDrop them.
struct DropZoneView: View {
    var onShelf: ([URL]) -> Void
    var onAirDrop: ([URL]) -> Void

    @State private var shelfTargeted = false
    @State private var airDropTargeted = false

    var body: some View {
        HStack(spacing: 12) {
            DropTile(title: "Shelf", subtitle: "Park it in the notch", symbol: "tray.and.arrow.down.fill",
                     tint: NosyPalette.top, targeted: shelfTargeted)
                .onDrop(of: [.fileURL], isTargeted: $shelfTargeted) { providers in
                    FileDrop.urls(from: providers, completion: onShelf)
                    return true
                }
            DropTile(title: "AirDrop", subtitle: "Send to a nearby device", symbol: "antenna.radiowaves.left.and.right",
                     tint: Theme.codex, targeted: airDropTargeted)
                .onDrop(of: [.fileURL], isTargeted: $airDropTargeted) { providers in
                    FileDrop.urls(from: providers, completion: onAirDrop)
                    return true
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shelfTargeted)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: airDropTargeted)
    }
}

private struct DropTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let targeted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .scaleEffect(targeted ? 1.2 : 1)
                .offset(y: targeted ? -2 : 0)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(targeted ? 0.22 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(targeted ? 0.9 : 0.3), style: StrokeStyle(lineWidth: 1.5, dash: targeted ? [] : [5, 4]))
        )
        .scaleEffect(targeted ? 1.03 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// The parked files in the hover view: drag one out, ✕ to remove, AirDrop or clear them all.
struct ShelfRow: View {
    @ObservedObject var shelf: Shelf

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NosyPalette.top)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(shelf.items, id: \.self) { url in
                        ShelfChip(url: url, onRemove: { shelf.remove(url) })
                    }
                }
            }
            .scrollIndicators(.never)
            ShelfButton(symbol: "antenna.radiowaves.left.and.right", help: "AirDrop all") { AirDrop.send(shelf.items) }
            ShelfButton(symbol: "trash", help: "Clear the shelf") { shelf.clear() }
        }
        .padding(.horizontal, 24)
        .frame(height: NotchViewModel.shelfRowHeight)
        .onAppear { shelf.prune() }
    }
}

private struct ShelfChip: View {
    let url: URL
    var onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 22, height: 22)
            Text(url.lastPathComponent)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 110, alignment: .leading)
            if hovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 32)
        .background(Capsule().fill(.white.opacity(hovering ? 0.12 : 0.07)))
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: url as NSURL) }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .help("\(url.path)\nDrag it out · double-click to open")
    }
}

private struct ShelfButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering ? 0.95 : 0.6))
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white.opacity(hovering ? 0.16 : 0.08)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

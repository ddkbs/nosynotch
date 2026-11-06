import SwiftUI

/// Top row of the hover view: Nosy's level, energy, streak and today's numbers.
struct NosyCard: View {
    @ObservedObject var pet: NosyPet
    /// Extra controls on the right (the focus timer button).
    var trailing: AnyView?

    var body: some View {
        HStack(spacing: 14) {
            levelBadge
            energy
            stat(symbol: "flame.fill", color: Color(red: 1, green: 0.55, blue: 0.3),
                 text: pet.streak == 1 ? "1 day" : "\(pet.streak) days", help: "Streak · best \(pet.state.bestStreak)")
            stat(symbol: "checkmark.circle.fill", color: Theme.success,
                 text: "\(pet.tasksToday) today", help: "Tasks finished today")
            if pet.secondsToday >= 60 {
                stat(symbol: "clock.fill", color: .white.opacity(0.55), text: Self.hours(pet.secondsToday),
                     help: "Agent time today")
            }
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
        .padding(.horizontal, 24)
        .frame(height: NotchViewModel.nosyCardHeight)
    }

    private var levelBadge: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: max(0.03, pet.levelProgress))
                    .stroke(NosyPalette.top, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                SparkleShape().fill(NosyPalette.spark).frame(width: 7, height: 7)
            }
            .frame(width: 16, height: 16)
            Text("Lv \(pet.level)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .help("Level \(pet.level) – \(Int(pet.levelProgress * 100)) % to the next")
    }

    private var energy: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(pet.isLowOnEnergy ? Theme.amber : NosyPalette.spark)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(LinearGradient(colors: [NosyPalette.top, NosyPalette.bottom], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * pet.energy))
                }
            }
            .frame(width: 54, height: 5)
        }
        .help("Energy \(Int(pet.energy * 100)) % – finished tasks feed Nosy")
        .animation(.easeOut(duration: 0.6), value: pet.energy)
    }

    private func stat(symbol: String, color: Color, text: String, help: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .fixedSize()
        .help(help)
    }

    static func hours(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}

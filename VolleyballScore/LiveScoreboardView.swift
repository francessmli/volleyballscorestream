import SwiftUI

struct LiveScoreboardView: View {
    let snapshot: LiveSessionSnapshot
    let code: String
    let onStopWatching: () -> Void

    private let blueSide = Color(red: 0.06, green: 0.28, blue: 0.62)
    private let redSide = Color(red: 0.78, green: 0.1, blue: 0.14)
    private let centerStrip = Color(white: 0.08)

    var body: some View {
        GeometryReader { geo in
            let boardHeight = max(geo.size.height - 100, 160)
            let scoreSize = min(boardHeight * 0.58, 320)
            let setLabelSize = max(15, min(boardHeight * 0.065, 24))

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    sidePanel(
                        name: snapshot.teamAName,
                        score: snapshot.currentPointsA,
                        setsWon: snapshot.setsWonA,
                        color: blueSide,
                        scoreSize: scoreSize,
                        setLabelSize: setLabelSize
                    )
                    centerPanel(setLabelSize: setLabelSize)
                    sidePanel(
                        name: snapshot.teamBName,
                        score: snapshot.currentPointsB,
                        setsWon: snapshot.setsWonB,
                        color: redSide,
                        scoreSize: scoreSize,
                        setLabelSize: setLabelSize
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
                    .padding(.bottom, max(10, geo.safeAreaInsets.bottom))
            }
        }
        .background(Color.black)
        .navigationTitle("Live scoreboard")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sidePanel(
        name: String,
        score: Int,
        setsWon: Int,
        color: Color,
        scoreSize: CGFloat,
        setLabelSize: CGFloat
    ) -> some View {
        ZStack {
            color
            VStack(spacing: scoreSize * 0.045) {
                Text("\(score)")
                    .font(.system(size: scoreSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

                Text(name)
                    .font(.system(size: max(17, setLabelSize * 1.15), weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 8)

                Text("Sets won: \(setsWon)")
                    .font(.system(size: max(10, setLabelSize * 0.5), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func centerPanel(setLabelSize: CGFloat) -> some View {
        ZStack {
            centerStrip
            VStack {
                Spacer(minLength: 0)
                Text("SET \(snapshot.completedSets.count + 1)")
                    .font(.system(size: max(12, setLabelSize * 0.72), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                Spacer(minLength: 0)
            }
        }
        .frame(width: 110)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Watching code \(code)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            if !snapshot.completedSets.isEmpty {
                Text(snapshot.completedSets.map { "\($0.0)-\($0.1)" }.joined(separator: "  ·  "))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Button("Stop watching", role: .destructive, action: onStopWatching)
                .buttonStyle(.bordered)
                .tint(.white)
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(0.95))
    }
}

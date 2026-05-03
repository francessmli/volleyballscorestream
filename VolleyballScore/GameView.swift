import SwiftData
import SwiftUI
import UIKit

private final class LiveJoinCodeRef {
    var value: String?
}

struct GameView: View {
    @Bindable var game: GameEngine
    let onReset: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var showEndGameConfirm = false
    @State private var showTiedSetAlert = false
    @State private var showMatchComplete = false
    @State private var didPersistCompletedMatch = false

    @State private var showLiveBroadcastSheet = false
    @State private var liveDraftCode = ""
    @State private var liveBroadcastError: String?
    @State private var liveJoinCodeRef = LiveJoinCodeRef()

    private let blueSide = Color(red: 0.06, green: 0.28, blue: 0.62)
    private let redSide = Color(red: 0.78, green: 0.1, blue: 0.14)
    private let centerStrip = Color(white: 0.08)

    /// Reserve space for caption + buttons + safe area so scores never sit under the bar.
    private func bottomBarHeight(safeBottom: CGFloat) -> CGFloat {
        12 + 18 + 10 + 48 + 12 + safeBottom
    }

    var body: some View {
        GeometryReader { geo in
            let barH = bottomBarHeight(safeBottom: geo.safeAreaInsets.bottom)
            let boardHeight = max(geo.size.height - barH, 160)
            let scoreSize = min(boardHeight * 0.58, 320)
            let setLabelSize = max(15, min(boardHeight * 0.065, 24))

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    scorePanel(
                        side: .a,
                        name: game.teamAName,
                        score: game.currentPointsA,
                        background: blueSide,
                        scoreSize: scoreSize,
                        setLabelSize: setLabelSize
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    centerColumn(setLabelSize: setLabelSize)
                        .frame(width: min(max(geo.size.width * 0.14, 96), 160))
                        .frame(maxHeight: .infinity)

                    scorePanel(
                        side: .b,
                        name: game.teamBName,
                        score: game.currentPointsB,
                        background: redSide,
                        scoreSize: scoreSize,
                        setLabelSize: setLabelSize
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomControls(extraBottomSafe: geo.safeAreaInsets.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Share to WhatsApp", systemImage: "message") {
                    shareToWhatsApp()
                }
                Button("Broadcast for spectators…", systemImage: "dot.radiowaves.left.and.right") {
                    liveBroadcastError = nil
                    if liveJoinCodeRef.value == nil, LiveMatchCloudKit.normalizeJoinCode(liveDraftCode) == nil {
                        liveDraftCode = LiveMatchCloudKit.generateJoinCode()
                    } else if let active = liveJoinCodeRef.value {
                        liveDraftCode = active
                    }
                    showLiveBroadcastSheet = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(12)
            }
            .padding(.top, 4)
            .padding(.trailing, 8)
        }
        .sheet(isPresented: $showLiveBroadcastSheet) {
            liveBroadcastSheet
        }
        .onAppear {
            OrientationHelper.preferLandscape()
            let engine = game
            let ref = liveJoinCodeRef
            engine.scoreDidChange = { [weak engine] in
                guard let engine else { return }
                if UserDefaults.standard.bool(forKey: "autoShareWhatsApp") {
                    let phone = UserDefaults.standard.string(forKey: "whatsAppPhoneDigits") ?? ""
                    WhatsAppShare.openCompose(
                        message: engine.summaryMessage(),
                        phoneDigits: phone.isEmpty ? nil : phone
                    )
                }
                guard let code = ref.value else { return }
                Task {
                    try? await LiveMatchCloudKit.shared.pushLiveSession(code: code, game: engine)
                }
            }
        }
        .onDisappear {
            OrientationHelper.preferPortrait()
            game.scoreDidChange = nil
        }
        .onChange(of: game.isMatchComplete) { _, done in
            guard done, !didPersistCompletedMatch else { return }
            didPersistCompletedMatch = true
            saveCompletedMatch()
            showMatchComplete = true
        }
        .alert("End match?", isPresented: $showEndGameConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("End game", role: .destructive) {
                endGameAndReturn()
            }
        } message: {
            Text("The score will be saved to history and you will return to setup.")
        }
        .alert("Set not finished", isPresented: $showTiedSetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Scores are tied. Change the score before ending the set.")
        }
        .alert("Match complete", isPresented: $showMatchComplete) {
            Button("OK") { onReset() }
        } message: {
            Text("\(winnerName) wins.")
        }
    }

    private var winnerName: String {
        if game.setsWonA > game.setsWonB { return game.teamAName }
        if game.setsWonB > game.setsWonA { return game.teamBName }
        return "Match"
    }

    private func scorePanel(
        side: VolleyballSide,
        name: String,
        score: Int,
        background: Color,
        scoreSize: CGFloat,
        setLabelSize: CGFloat
    ) -> some View {
        ZStack {
            background
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

                Text("↑ +1   ↓ −1")
                    .font(.system(size: max(9, setLabelSize * 0.42), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 16)
        }
        .contentShape(Rectangle())
        .gesture(swipeGesture(side: side))
    }

    private func centerColumn(setLabelSize: CGFloat) -> some View {
        ZStack {
            centerStrip
            VStack {
                Spacer(minLength: 0)
                Text("SET \(game.completedSets.count + 1)")
                    .font(.system(size: max(12, setLabelSize * 0.72), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                Spacer(minLength: 0)
            }
        }
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

    private func swipeGesture(side: VolleyballSide) -> some Gesture {
        DragGesture(minimumDistance: 44)
            .onEnded { value in
                let dy = value.translation.height
                if dy < -48 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    game.nudgeScore(side: side, up: true)
                } else if dy > 48 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    game.nudgeScore(side: side, up: false)
                }
            }
    }

    private func bottomControls(extraBottomSafe: CGFloat) -> some View {
        VStack(spacing: 10) {
            Text("Match sets \(game.setsWonA)–\(game.setsWonB)  ·  first to \(game.setsToWin)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                controlButton(title: "Restart set", color: Color.white.opacity(0.18)) {
                    game.restartCurrentSet()
                }
                .disabled(game.isMatchComplete || (game.currentPointsA == 0 && game.currentPointsB == 0))

                controlButton(title: "End set", color: Color.white.opacity(0.22)) {
                    if game.endCurrentSetManually() {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    } else {
                        showTiedSetAlert = true
                    }
                }
                .disabled(game.isMatchComplete || (game.currentPointsA == 0 && game.currentPointsB == 0))

                controlButton(title: "End game", color: Color.orange.opacity(0.35)) {
                    showEndGameConfirm = true
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, max(10, extraBottomSafe))
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(0.95))
    }

    private func controlButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .padding(.horizontal, 4)
                .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func shareToWhatsApp() {
        let phone = UserDefaults.standard.string(forKey: "whatsAppPhoneDigits") ?? ""
        WhatsAppShare.openCompose(
            message: game.summaryMessage(),
            phoneDigits: phone.isEmpty ? nil : phone
        )
    }

    private var liveBroadcastSheet: some View {
        NavigationStack {
            Form {
                Section {
                    if liveJoinCodeRef.value != nil {
                        Text(liveDraftCode)
                            .font(.title2.monospaced())
                            .textSelection(.enabled)
                        Text("Broadcasting. Spectators enter this code on the Watch tab.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("Join code", text: $liveDraftCode)
                            .font(.title3.monospaced())
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Text("Use a 6-character code (letters and numbers). Spectators open the Watch tab and enter it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let liveBroadcastError {
                    Section {
                        Text(liveBroadcastError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    if liveJoinCodeRef.value != nil {
                        Button("Stop broadcasting", role: .destructive) {
                            let code = liveJoinCodeRef.value!
                            liveJoinCodeRef.value = nil
                            Task {
                                await LiveMatchCloudKit.shared.deleteLiveSession(code: code)
                            }
                        }
                    } else {
                        Button("Start broadcasting") {
                            Task { await startLiveBroadcast() }
                        }
                    }
                }
            }
            .navigationTitle("Live broadcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showLiveBroadcastSheet = false }
                }
            }
        }
    }

    private func startLiveBroadcast() async {
        guard let normalized = LiveMatchCloudKit.normalizeJoinCode(liveDraftCode) else {
            await MainActor.run {
                liveBroadcastError = LiveMatchCloudError.invalidJoinCode.errorDescription
            }
            return
        }
        await MainActor.run {
            liveDraftCode = normalized
            liveBroadcastError = nil
        }
        do {
            try await LiveMatchCloudKit.shared.pushLiveSession(code: normalized, game: game)
            await MainActor.run {
                liveJoinCodeRef.value = normalized
            }
        } catch {
            await MainActor.run {
                liveBroadcastError = (error as? LiveMatchCloudError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func saveCompletedMatch() {
        let record = game.makeRecord(abandoned: false)
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func endGameAndReturn() {
        if !didPersistCompletedMatch {
            let record = game.makeRecord(abandoned: !game.isMatchComplete)
            modelContext.insert(record)
            try? modelContext.save()
            if game.isMatchComplete {
                didPersistCompletedMatch = true
            }
        }
        onReset()
    }
}

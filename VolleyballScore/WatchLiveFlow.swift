import CloudKit
import SwiftUI

/// Spectators enter the 6-character code from the scorekeeper and see scores update every few seconds via CloudKit (public database).
struct WatchLiveView: View {
    @Bindable var watchSession: LiveWatchSession
    let onOpenScoreboard: () -> Void

    @State private var codeInput = ""
    @State private var iCloudStatus: CKAccountStatus?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let status = iCloudStatus, status != .available {
                    GroupBox {
                        Label(icloudHint(for: status), systemImage: "icloud.slash")
                            .font(.subheadline)
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter the code from the scorekeeper")
                            .font(.subheadline.weight(.semibold))
                        TextField("Code", text: $codeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.title2.monospaced())
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        HStack(spacing: 12) {
                            Button(watchSession.isWatching ? "Stop" : "Watch") {
                                if watchSession.isWatching {
                                    stopWatching()
                                } else {
                                    Task { await startWatching() }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(codeInput.filter { $0.isLetter || $0.isNumber }.count != 6 && !watchSession.isWatching)

                            if watchSession.isWatching, watchSession.snapshot != nil {
                                Button("Open scoreboard") {
                                    onOpenScoreboard()
                                }
                            }
                        }
                    }
                }

                if let snap = watchSession.snapshot {
                    liveScoreCard(snap)
                } else if watchSession.isWatching {
                    VStack(spacing: 12) {
                        if watchSession.isAwaitingFirstSnapshotSilently {
                            Text(
                                "Connecting to iCloud… Ask the scorekeeper to confirm broadcasting is on and the code matches. If this lasts more than about a minute, both phones must use the same app source (Xcode build = CloudKit Development; TestFlight or App Store = Production)."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        }
                        ProgressView("Waiting for scores…")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                if let err = watchSession.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text(
                    "History syncs across your own devices with iCloud. This tab uses CloudKit’s public database so anyone with the code can read the live row the scorekeeper publishes."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .cappedWidth()
        }
        .navigationTitle("Watch")
        .task {
            iCloudStatus = await watchSession.accountStatus()
            if codeInput.isEmpty, let active = watchSession.activeCode {
                codeInput = active
            }
        }
    }

    private func icloudHint(for status: CKAccountStatus) -> String {
        switch status {
        case .available: return ""
        case .noAccount: return "Sign in to iCloud in Settings to watch or broadcast live scores."
        case .restricted: return "iCloud is restricted on this device."
        case .couldNotDetermine: return "Could not determine iCloud status."
        case .temporarilyUnavailable: return "iCloud is temporarily unavailable."
        @unknown default: return "iCloud is not available."
        }
    }

    @ViewBuilder
    private func liveScoreCard(_ snap: LiveSessionSnapshot) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(snap.teamAName)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    Text("\(snap.setsWonA)")
                        .font(.title.weight(.bold))
                }
                HStack {
                    Text(snap.teamBName)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    Text("\(snap.setsWonB)")
                        .font(.title.weight(.bold))
                }
                Divider()
                Text("Current set")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Text("\(snap.currentPointsA)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                    Text("–")
                        .font(.title2)
                    Text("\(snap.currentPointsB)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                }
                .frame(maxWidth: .infinity)

                if !snap.completedSets.isEmpty {
                    Text("Completed sets: " + snap.completedSets.map { "\($0.0)–\($0.1)" }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if snap.matchComplete {
                    Label("Match complete", systemImage: "flag.checkered")
                        .font(.subheadline.weight(.semibold))
                }

                if let u = snap.updatedAt {
                    Text("Updated \(u.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func startWatching() async {
        await watchSession.startWatching(code: codeInput)
        if let normalized = watchSession.activeCode {
            codeInput = normalized
        }
    }

    private func stopWatching() {
        watchSession.stopWatching()
    }
}

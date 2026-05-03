import CloudKit
import SwiftUI

/// Spectators enter the 6-character code from the scorekeeper and see scores update every few seconds via CloudKit (public database).
struct WatchLiveView: View {
    @State private var codeInput = ""
    @State private var snapshot: LiveSessionSnapshot?
    @State private var isWatching = false
    @State private var errorMessage: String?
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
                            Button(isWatching ? "Stop" : "Watch") {
                                if isWatching {
                                    stopWatching()
                                } else {
                                    Task { await startWatching() }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(codeInput.filter { $0.isLetter || $0.isNumber }.count != 6 && !isWatching)
                        }
                    }
                }

                if let snap = snapshot {
                    liveScoreCard(snap)
                } else if isWatching {
                    ProgressView("Waiting for scores…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }

                if let err = errorMessage {
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
        }
        .navigationTitle("Watch")
        .task {
            iCloudStatus = await LiveMatchCloudKit.shared.accountStatus()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            guard isWatching else { return }
            Task { await refresh() }
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
        errorMessage = nil
        snapshot = nil
        guard LiveMatchCloudKit.normalizeJoinCode(codeInput) != nil else {
            errorMessage = LiveMatchCloudError.invalidJoinCode.errorDescription
            return
        }
        isWatching = true
        await refresh()
    }

    private func stopWatching() {
        isWatching = false
        snapshot = nil
        errorMessage = nil
    }

    private func refresh() async {
        guard isWatching else { return }
        guard let normalized = LiveMatchCloudKit.normalizeJoinCode(codeInput) else { return }
        do {
            let next = try await LiveMatchCloudKit.shared.fetchLiveSession(code: normalized)
            await MainActor.run {
                snapshot = next
                errorMessage = nil
            }
        } catch let e as LiveMatchCloudError {
            await MainActor.run {
                if case .sessionNotFound = e, snapshot == nil {
                    errorMessage = e.errorDescription
                } else if case .sessionNotFound = e, snapshot != nil {
                    // keep last snapshot if briefly missing
                    errorMessage = nil
                } else {
                    errorMessage = e.errorDescription
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

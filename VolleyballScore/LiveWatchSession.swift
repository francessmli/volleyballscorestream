import CloudKit
import Foundation
import Observation

@MainActor
@Observable
final class LiveWatchSession {
    var isWatching = false
    var activeCode: String?
    var snapshot: LiveSessionSnapshot?
    var errorMessage: String?

    /// When the user tapped Watch; used to avoid flashing “no match” while CloudKit catches up.
    private(set) var watchStartedAt: Date?

    /// Invoked the first time a snapshot arrives after starting watch (e.g. switch to Score tab).
    var onLiveSnapshotReady: (() -> Void)?

    private var pollingTask: Task<Void, Never>?

    private var isWithinGracePeriod: Bool {
        guard let t = watchStartedAt else { return false }
        return Date().timeIntervalSince(t) < 40
    }

    /// True while we’re watching but haven’t received a row yet and we’re still inside the grace window (no hard error shown).
    var isAwaitingFirstSnapshotSilently: Bool {
        isWatching && snapshot == nil && errorMessage == nil && isWithinGracePeriod
    }

    func startWatching(code rawCode: String) async {
        errorMessage = nil
        snapshot = nil

        guard let normalized = LiveMatchCloudKit.normalizeJoinCode(rawCode) else {
            errorMessage = LiveMatchCloudError.invalidJoinCode.errorDescription
            watchStartedAt = nil
            return
        }

        activeCode = normalized
        isWatching = true
        watchStartedAt = Date()
        await refresh()
        startPolling()
    }

    func stopWatching(clearSnapshot: Bool = true) {
        let code = activeCode
        let viewerId = LiveMatchCloudKit.stableViewerId()
        isWatching = false
        activeCode = nil
        errorMessage = nil
        watchStartedAt = nil
        if clearSnapshot {
            snapshot = nil
        }
        pollingTask?.cancel()
        pollingTask = nil
        if let code {
            Task {
                await LiveMatchCloudKit.shared.deleteViewerPresence(code: code, viewerId: viewerId)
            }
        }
    }

    func refresh() async {
        guard isWatching, let activeCode else { return }
        try? await LiveMatchCloudKit.shared.registerViewerHeartbeat(
            code: activeCode,
            viewerId: LiveMatchCloudKit.stableViewerId()
        )
        do {
            let next = try await LiveMatchCloudKit.shared.fetchLiveSession(code: activeCode)
            let hadSnapshotBefore = snapshot != nil
            snapshot = next
            errorMessage = nil
            if !hadSnapshotBefore {
                onLiveSnapshotReady?()
            }
        } catch let e as LiveMatchCloudError {
            if case .sessionNotFound = e, snapshot != nil {
                // Keep the latest score visible during transient CloudKit misses.
                errorMessage = nil
            } else if case .sessionNotFound = e, snapshot == nil, isWithinGracePeriod {
                // Don’t show “no match” immediately; the scorekeeper may still be publishing.
                errorMessage = nil
            } else {
                errorMessage = e.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func accountStatus() async -> CKAccountStatus {
        await LiveMatchCloudKit.shared.accountStatus()
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                guard let self else { return }
                await self.refresh()
            }
        }
    }
}

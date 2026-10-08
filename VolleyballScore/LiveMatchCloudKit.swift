import CloudKit
import Foundation

/// CloudKit record type for **public** “watch live” sessions (spectators use a short code).
/// Deploy this type in the CloudKit Dashboard (Production) after testing; Development often auto-creates on first save.
enum LiveSessionCK {
    static let recordType = "VolleyballLiveSession"

    enum Field {
        /// Same as the record name / join code; used for CKQuery fallback when fetch-by-ID fails.
        static let joinCode = "joinCode"
        static let teamAName = "teamAName"
        static let teamBName = "teamBName"
        static let bestOf = "bestOf"
        static let setsWonA = "setsWonA"
        static let setsWonB = "setsWonB"
        static let currentPointsA = "currentPointsA"
        static let currentPointsB = "currentPointsB"
        static let completedSetsJSON = "completedSetsJSON"
        static let matchComplete = "matchComplete"
        static let updatedAt = "updatedAt"
    }
}

/// Spectator heartbeat rows in the public DB (`joinCode`, `updatedAt`). Deploy type **VolleyballLiveViewer** in the CloudKit Dashboard (Production); Development often auto-creates on first save. Add a queryable index on `joinCode` if the dashboard prompts you to — `updatedAt` is only read/filtered client-side, so it does not need a query index.
enum LiveViewerCK {
    static let recordType = "VolleyballLiveViewer"

    enum Field {
        static let joinCode = "joinCode"
        static let updatedAt = "updatedAt"
    }
}

struct LiveSessionSnapshot {
    var teamAName: String
    var teamBName: String
    var bestOf: Int
    var setsWonA: Int
    var setsWonB: Int
    var currentPointsA: Int
    var currentPointsB: Int
    var completedSets: [(Int, Int)]
    var matchComplete: Bool
    var updatedAt: Date?
}

enum LiveMatchCloudError: LocalizedError {
    case iCloudUnavailable
    case invalidJoinCode
    case sessionNotFound
    case cloudKit(String)

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "Sign in to iCloud on this device to use live scores."
        case .invalidJoinCode:
            return "Enter a 6-character code (letters and numbers)."
        case .sessionNotFound:
            return "No live match found for that code. Confirm the code matches the scorekeeper’s screen. If both sides are correct: Xcode/Debug uses CloudKit Development, while TestFlight/App Store uses Production—both devices must use the same channel. In CloudKit Database (developer.apple.com), ensure record type VolleyballLiveSession exists in that environment and that authenticated users can read public data for your container."
        case .cloudKit(let message):
            return message
        }
    }
}

/// Pushes and reads live match rows in the **default public database** (container `iCloud.<bundle id>`).
final class LiveMatchCloudKit {
    static let shared = LiveMatchCloudKit()

    /// Prefer the explicit container id from entitlements (`iCloud.<bundle id>`). `CKContainer.default()` can mis-resolve when multiple containers exist.
    private let container: CKContainer = {
        if let bid = Bundle.main.bundleIdentifier, !bid.isEmpty {
            return CKContainer(identifier: "iCloud.\(bid)")
        }
        return CKContainer.default()
    }()

    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private let pushSequencer = PushSequencer()

    /// Allowed charset for codes (avoids 0/O and 1/I confusion).
    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private init() {}

    private actor PushSequencer {
        private var lastTask: Task<Void, Never>?

        func enqueue<T>(_ operation: @escaping () async throws -> T) async throws -> T {
            let previous = lastTask
            let opTask = Task<T, Error> {
                if let previous {
                    _ = await previous.result
                }
                return try await operation()
            }
            lastTask = Task<Void, Never> {
                _ = await opTask.result
            }
            return try await opTask.value
        }
    }

    // MARK: - Join code

    static func generateJoinCode() -> String {
        (0..<6).map { _ in codeAlphabet.randomElement()! }.map(String.init).joined()
    }

    /// Returns normalized 6-character code, or nil if invalid.
    static func normalizeJoinCode(_ raw: String) -> String? {
        let upper = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard upper.count == 6 else { return nil }
        return String(upper)
    }

    // MARK: - Account

    func accountStatus() async -> CKAccountStatus {
        await withCheckedContinuation { cont in
            container.accountStatus { status, _ in
                cont.resume(returning: status)
            }
        }
    }

    // MARK: - Public DB

    private func recordID(forCode code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: code)
    }

    private func applyGame(_ game: GameEngine, to record: CKRecord) {
        record[LiveSessionCK.Field.joinCode] = record.recordID.recordName as CKRecordValue
        record[LiveSessionCK.Field.teamAName] = game.teamAName as CKRecordValue
        record[LiveSessionCK.Field.teamBName] = game.teamBName as CKRecordValue
        record[LiveSessionCK.Field.bestOf] = game.bestOf as CKRecordValue
        record[LiveSessionCK.Field.setsWonA] = game.setsWonA as CKRecordValue
        record[LiveSessionCK.Field.setsWonB] = game.setsWonB as CKRecordValue
        record[LiveSessionCK.Field.currentPointsA] = game.currentPointsA as CKRecordValue
        record[LiveSessionCK.Field.currentPointsB] = game.currentPointsB as CKRecordValue
        record[LiveSessionCK.Field.completedSetsJSON] = MatchRecordCoding.encodeSets(game.completedSets) as CKRecordValue
        record[LiveSessionCK.Field.matchComplete] = game.isMatchComplete as CKRecordValue
        record[LiveSessionCK.Field.updatedAt] = Date() as CKRecordValue
    }

    private func snapshot(from record: CKRecord) -> LiveSessionSnapshot? {
        guard
            let teamA = record[LiveSessionCK.Field.teamAName] as? String,
            let teamB = record[LiveSessionCK.Field.teamBName] as? String,
            let bestOf = record[LiveSessionCK.Field.bestOf] as? Int,
            let sa = record[LiveSessionCK.Field.setsWonA] as? Int,
            let sb = record[LiveSessionCK.Field.setsWonB] as? Int,
            let ca = record[LiveSessionCK.Field.currentPointsA] as? Int,
            let cb = record[LiveSessionCK.Field.currentPointsB] as? Int,
            let json = record[LiveSessionCK.Field.completedSetsJSON] as? String
        else { return nil }
        let complete: Bool
        if let b = record[LiveSessionCK.Field.matchComplete] as? Bool {
            complete = b
        } else if let n = record[LiveSessionCK.Field.matchComplete] as? Int {
            complete = n != 0
        } else if let n = record[LiveSessionCK.Field.matchComplete] as? NSNumber {
            complete = n.boolValue
        } else {
            complete = false
        }
        let updated = record[LiveSessionCK.Field.updatedAt] as? Date
        let sets = MatchRecordCoding.decodeSets(json)
        return LiveSessionSnapshot(
            teamAName: teamA,
            teamBName: teamB,
            bestOf: bestOf,
            setsWonA: sa,
            setsWonB: sb,
            currentPointsA: ca,
            currentPointsB: cb,
            completedSets: sets,
            matchComplete: complete,
            updatedAt: updated
        )
    }

    /// Creates or updates the public live session for this code.
    func pushLiveSession(code: String, game: GameEngine) async throws {
        try await pushSequencer.enqueue { [self] in
            try await performPushLiveSession(code: code, game: game)
        }
    }

    func fetchLiveSession(code: String) async throws -> LiveSessionSnapshot {
        let status = await accountStatus()
        guard status == .available else { throw LiveMatchCloudError.iCloudUnavailable }
        guard let normalized = Self.normalizeJoinCode(code) else { throw LiveMatchCloudError.invalidJoinCode }

        let id = recordID(forCode: normalized)
        do {
            let record = try await publicDB.record(for: id)
            guard let snap = snapshot(from: record) else {
                throw LiveMatchCloudError.cloudKit("Could not read live session data.")
            }
            return snap
        } catch let ck as CKError where ck.code == .permissionFailure {
            throw LiveMatchCloudError.cloudKit(
                "CloudKit denied read access to the live session. In CloudKit Database → your container → Public Database → Security / roles, allow authenticated users to read record type VolleyballLiveSession."
            )
        } catch let ck as CKError where ck.code == .unknownItem {
            if let snap = try? await fetchLiveSessionViaQuery(joinCode: normalized) {
                return snap
            }
            throw LiveMatchCloudError.sessionNotFound
        } catch {
            throw mapError(error)
        }
    }

    /// When `record(for:)` returns `unknownItem`, try a query on `joinCode` (needs a queryable index on that field in the CloudKit console for some containers).
    private func fetchLiveSessionViaQuery(joinCode normalized: String) async throws -> LiveSessionSnapshot? {
        let predicate = NSPredicate(format: "%K == %@", LiveSessionCK.Field.joinCode, normalized)
        let query = CKQuery(recordType: LiveSessionCK.recordType, predicate: predicate)
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let batch = try await {
                if let c = cursor {
                    return try await publicDB.records(continuingMatchFrom: c)
                }
                return try await publicDB.records(matching: query)
            }()
            for (_, result) in batch.matchResults {
                if case .success(let rec) = result, let snap = snapshot(from: rec) {
                    return snap
                }
            }
            cursor = batch.queryCursor
        } while cursor != nil
        return nil
    }

    func deleteLiveSession(code: String) async {
        guard let normalized = Self.normalizeJoinCode(code) else { return }
        let id = recordID(forCode: normalized)
        do {
            try await publicDB.deleteRecord(withID: id)
        } catch {
            // Best-effort cleanup
        }
    }

    // MARK: - Spectator presence (approximate viewer count)

    /// One id per app install, used for heartbeat records in the public database.
    static func stableViewerId() -> String {
        let key = "VolleyballScore.stableLiveViewerId"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    private func viewerRecordID(joinCode: String, viewerId: String) -> CKRecord.ID {
        let safeId = viewerId.replacingOccurrences(of: "/", with: "_")
        return CKRecord.ID(recordName: "\(joinCode)_\(safeId)")
    }

    /// Spectators call this on a short interval while watching so the scorekeeper can count recent heartbeats.
    func registerViewerHeartbeat(code: String, viewerId: String) async throws {
        let status = await accountStatus()
        guard status == .available else { throw LiveMatchCloudError.iCloudUnavailable }
        guard let normalized = Self.normalizeJoinCode(code) else { throw LiveMatchCloudError.invalidJoinCode }

        let id = viewerRecordID(joinCode: normalized, viewerId: viewerId)
        let record: CKRecord
        do {
            record = try await publicDB.record(for: id)
        } catch let ck as CKError where ck.code == .unknownItem {
            record = CKRecord(recordType: LiveViewerCK.recordType, recordID: id)
        } catch {
            throw mapError(error)
        }
        record[LiveViewerCK.Field.joinCode] = normalized as CKRecordValue
        record[LiveViewerCK.Field.updatedAt] = Date() as CKRecordValue
        _ = try await publicDB.save(record)
    }

    func deleteViewerPresence(code: String, viewerId: String) async {
        guard let normalized = Self.normalizeJoinCode(code) else { return }
        let id = viewerRecordID(joinCode: normalized, viewerId: viewerId)
        do {
            try await publicDB.deleteRecord(withID: id)
        } catch {
            // Best-effort: row will age out of the broadcaster’s count window.
        }
    }

    /// Number of distinct spectator devices that sent a heartbeat recently for this join code.
    ///
    /// Only queries on `joinCode` (a single-field predicate), then filters the time window
    /// client-side. This way the CloudKit Dashboard only needs a queryable index on `joinCode`
    /// for `VolleyballLiveViewer` — not a second one on `updatedAt` — which is the setup most
    /// commonly missing when this call fails with "couldn't load how many are watching".
    func fetchActiveViewerCount(joinCode rawCode: String, activeWithin seconds: TimeInterval = 45) async throws -> Int {
        let status = await accountStatus()
        guard status == .available else { throw LiveMatchCloudError.iCloudUnavailable }
        guard let normalized = Self.normalizeJoinCode(rawCode) else { throw LiveMatchCloudError.invalidJoinCode }

        let cutoff = Date().addingTimeInterval(-seconds)
        let predicate = NSPredicate(format: "%K == %@", LiveViewerCK.Field.joinCode, normalized)
        let query = CKQuery(recordType: LiveViewerCK.recordType, predicate: predicate)

        var total = 0
        var cursor: CKQueryOperation.Cursor?
        do {
            repeat {
                let batch = try await {
                    if let c = cursor {
                        return try await publicDB.records(continuingMatchFrom: c)
                    }
                    return try await publicDB.records(matching: query)
                }()
                for (_, result) in batch.matchResults {
                    guard case .success(let rec) = result else { continue }
                    let updated = rec[LiveViewerCK.Field.updatedAt] as? Date
                    if let updated, updated > cutoff {
                        total += 1
                    }
                }
                cursor = batch.queryCursor
            } while cursor != nil
        } catch let ck as CKError {
            // If the record type genuinely doesn't exist yet in this CloudKit environment
            // (e.g. no spectator has ever tapped "Watch" here yet, so no heartbeat row was
            // ever saved to create the type), there are simply zero active viewers right
            // now — that's not a configuration problem worth alarming the scorekeeper about.
            if Self.isMissingRecordTypeError(ck) {
                return 0
            }
            // Anything else (most commonly: `joinCode` not marked Queryable in the CloudKit
            // Dashboard for this environment) is a real setup problem — surface CloudKit's
            // own message so it's actionable instead of a generic guess.
            throw LiveMatchCloudError.cloudKit("Viewer count query failed: \(ck.localizedDescription)")
        }

        return total
    }

    /// True when CloudKit's error indicates the record type itself hasn't been created in this
    /// environment yet (as opposed to the type existing but `joinCode` lacking a query index).
    private static func isMissingRecordTypeError(_ ck: CKError) -> Bool {
        guard ck.code == .invalidArguments || ck.code == .unknownItem else { return false }
        let message = ck.localizedDescription.lowercased()
        return message.contains("did not find record type")
            || message.contains("record type") && message.contains("not") && message.contains("found")
    }

    private func mapError(_ error: Error) -> LiveMatchCloudError {
        if let ck = error as? CKError {
            return .cloudKit(ck.localizedDescription)
        }
        return .cloudKit(error.localizedDescription)
    }

    private func performPushLiveSession(code: String, game: GameEngine) async throws {
        let status = await accountStatus()
        guard status == .available else { throw LiveMatchCloudError.iCloudUnavailable }
        guard let normalized = Self.normalizeJoinCode(code) else { throw LiveMatchCloudError.invalidJoinCode }

        var lastError: Error?
        for attempt in 0..<4 {
            do {
                try await saveSnapshotForCode(normalized, game: game)
                return
            } catch {
                lastError = error
                guard shouldRetryAfterSaveError(error), attempt < 3 else {
                    throw mapError(error)
                }

                let delaySeconds = retryDelaySeconds(from: error) ?? (0.2 * Double(attempt + 1))
                try? await Task.sleep(for: .seconds(delaySeconds))
            }
        }

        throw mapError(lastError ?? LiveMatchCloudError.cloudKit("Could not save live session."))
    }

    private func saveSnapshotForCode(_ normalizedCode: String, game: GameEngine) async throws {
        let id = recordID(forCode: normalizedCode)
        let record: CKRecord
        do {
            record = try await publicDB.record(for: id)
            applyGame(game, to: record)
        } catch let ck as CKError where ck.code == .unknownItem {
            let fresh = CKRecord(recordType: LiveSessionCK.recordType, recordID: id)
            applyGame(game, to: fresh)
            record = fresh
        } catch {
            throw error
        }

        _ = try await publicDB.save(record)
    }

    private func shouldRetryAfterSaveError(_ error: Error) -> Bool {
        guard let ck = error as? CKError else { return false }
        switch ck.code {
        case .serverRecordChanged, .requestRateLimited, .zoneBusy, .serviceUnavailable, .networkFailure, .networkUnavailable, .batchRequestFailed:
            return true
        default:
            // Some server-side lock contention appears as generic server errors with an oplock message.
            return ck.localizedDescription.localizedCaseInsensitiveContains("oplock")
        }
    }

    private func retryDelaySeconds(from error: Error) -> Double? {
        guard let ck = error as? CKError else { return nil }
        return ck.userInfo[CKErrorRetryAfterKey] as? Double
    }
}

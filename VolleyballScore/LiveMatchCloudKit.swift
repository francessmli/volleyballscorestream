import CloudKit
import Foundation

/// CloudKit record type for **public** “watch live” sessions (spectators use a short code).
/// Deploy this type in the CloudKit Dashboard (Production) after testing; Development often auto-creates on first save.
enum LiveSessionCK {
    static let recordType = "VolleyballLiveSession"

    enum Field {
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
            return "No live match found for that code. Check the code or ask the scorekeeper to start broadcasting."
        case .cloudKit(let message):
            return message
        }
    }
}

/// Pushes and reads live match rows in the **default public database** (same container as SwiftData: `iCloud.<bundle id>`).
final class LiveMatchCloudKit {
    static let shared = LiveMatchCloudKit()

    private let container = CKContainer.default()
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    /// Allowed charset for codes (avoids 0/O and 1/I confusion).
    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private init() {}

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
        let status = await accountStatus()
        guard status == .available else { throw LiveMatchCloudError.iCloudUnavailable }
        guard let normalized = Self.normalizeJoinCode(code) else { throw LiveMatchCloudError.invalidJoinCode }

        let id = recordID(forCode: normalized)
        let record: CKRecord
        do {
            record = try await publicDB.record(for: id)
            applyGame(game, to: record)
        } catch let ck as CKError where ck.code == .unknownItem {
            let fresh = CKRecord(recordType: LiveSessionCK.recordType, recordID: id)
            applyGame(game, to: fresh)
            record = fresh
        } catch {
            throw mapError(error)
        }

        do {
            _ = try await publicDB.save(record)
        } catch {
            throw mapError(error)
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
        } catch let ck as CKError where ck.code == .unknownItem {
            throw LiveMatchCloudError.sessionNotFound
        } catch {
            throw mapError(error)
        }
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

    private func mapError(_ error: Error) -> LiveMatchCloudError {
        if let ck = error as? CKError {
            return .cloudKit(ck.localizedDescription)
        }
        return .cloudKit(error.localizedDescription)
    }
}

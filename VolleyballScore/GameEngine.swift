import Foundation
import Observation

enum VolleyballSide: String, CaseIterable {
    case a, b
}

@Observable
final class GameEngine {
    var teamAName: String
    var teamBName: String
    var bestOf: Int
    var startedAt: Date

    var setsWonA: Int = 0
    var setsWonB: Int = 0
    var currentPointsA: Int = 0
    var currentPointsB: Int = 0
    var completedSets: [(Int, Int)] = []

    /// True right after a set ends (cap reached + 2-point lead) while the match continues.
    /// The scoreboard intentionally keeps showing the just-finished set's final score
    /// (instead of silently snapping to 0–0) until `startNextSet()` is called explicitly,
    /// so everyone can see/confirm the result before the next set begins.
    var isSetAwaitingStart: Bool = false

    private struct Snapshot {
        var ca, cb, sa, sb: Int
        var completed: [(Int, Int)]
        var awaitingStart: Bool
    }

    private var undoStack: [Snapshot] = []

    /// Fired after each score change (swipe up/down, set end, restart set).
    var scoreDidChange: (() -> Void)?

    var canUndo: Bool { !undoStack.isEmpty }

    var isMatchComplete: Bool { setsWonA >= setsToWin || setsWonB >= setsToWin }

    var setsToWin: Int { (bestOf + 1) / 2 }

    init(teamAName: String, teamBName: String, bestOf: Int = 3, startedAt: Date = .now) {
        self.teamAName = teamAName
        self.teamBName = teamBName
        self.bestOf = bestOf
        self.startedAt = startedAt
    }

    private func pushSnapshot() {
        undoStack.append(Snapshot(
            ca: currentPointsA,
            cb: currentPointsB,
            sa: setsWonA,
            sb: setsWonB,
            completed: completedSets,
            awaitingStart: isSetAwaitingStart
        ))
    }

    func rallyCapForCurrentSet() -> Int {
        let deciding = setsWonA == setsToWin - 1 && setsWonB == setsToWin - 1
        return deciding ? 15 : 25
    }

    private func sideWonCurrentSet() -> VolleyballSide? {
        let cap = rallyCapForCurrentSet()
        let a = currentPointsA
        let b = currentPointsB
        if a >= cap && a - b >= 2 { return .a }
        if b >= cap && b - a >= 2 { return .b }
        return nil
    }

    func scorePoint(_ side: VolleyballSide) {
        guard !isMatchComplete, !isSetAwaitingStart else { return }
        pushSnapshot()
        switch side {
        case .a: currentPointsA += 1
        case .b: currentPointsB += 1
        }
        if let winner = sideWonCurrentSet() {
            completeCurrentSet(winner: winner)
        }
        scoreDidChange?()
    }

    /// Swipe up increases, swipe down decreases (that side only).
    func nudgeScore(side: VolleyballSide, up: Bool) {
        guard !isMatchComplete, !isSetAwaitingStart else { return }
        if up {
            scorePoint(side)
        } else {
            let cur = side == .a ? currentPointsA : currentPointsB
            guard cur > 0 else { return }
            pushSnapshot()
            if side == .a {
                currentPointsA -= 1
            } else {
                currentPointsB -= 1
            }
            scoreDidChange?()
        }
    }

    func undoLastPoint() {
        guard let snap = undoStack.popLast() else { return }
        currentPointsA = snap.ca
        currentPointsB = snap.cb
        setsWonA = snap.sa
        setsWonB = snap.sb
        completedSets = snap.completed
        isSetAwaitingStart = snap.awaitingStart
        scoreDidChange?()
    }

    /// Clears the current set to 0–0 without recording a winner.
    func restartCurrentSet() {
        guard !isMatchComplete, !isSetAwaitingStart else { return }
        guard currentPointsA > 0 || currentPointsB > 0 else { return }
        pushSnapshot()
        currentPointsA = 0
        currentPointsB = 0
        scoreDidChange?()
    }

    /// Records the current rally score as a finished set (higher score wins). Returns `false` if tied.
    @discardableResult
    func endCurrentSetManually() -> Bool {
        guard !isMatchComplete, !isSetAwaitingStart else { return false }
        if currentPointsA == currentPointsB { return false }
        let winner: VolleyballSide = currentPointsA > currentPointsB ? .a : .b
        pushSnapshot()
        completeCurrentSet(winner: winner)
        scoreDidChange?()
        return true
    }

    private func completeCurrentSet(winner: VolleyballSide) {
        completedSets.append((currentPointsA, currentPointsB))
        switch winner {
        case .a: setsWonA += 1
        case .b: setsWonB += 1
        }
        if isMatchComplete {
            // Keep the final set's score visible (no silent reset) — there's no next
            // set to start, and the GameView CTA ("End game") will persist + navigate
            // away explicitly once the scorekeeper confirms.
        } else {
            // Keep showing this set's final score until the scorekeeper explicitly
            // starts the next one via `startNextSet()`.
            isSetAwaitingStart = true
        }
    }

    /// Explicit action to dismiss the just-finished set's score and begin the next set at 0–0.
    /// No-ops if there is no set awaiting start (e.g. already dismissed, or match complete).
    func startNextSet() {
        guard isSetAwaitingStart, !isMatchComplete else { return }
        pushSnapshot()
        currentPointsA = 0
        currentPointsB = 0
        isSetAwaitingStart = false
        scoreDidChange?()
    }

    func summaryMessage() -> String {
        let setsLine = completedSets.enumerated().map { i, s in
            "Set \(i + 1): \(teamAName) \(s.0) – \(s.1) \(teamBName)"
        }.joined(separator: "\n")
        let match = "Sets: \(teamAName) \(setsWonA) – \(setsWonB) \(teamBName)"
        if isMatchComplete {
            // The final set's score is already included in `setsLine`; avoid repeating
            // it as a bogus "current set" line now that the match has ended.
            return setsLine.isEmpty ? match : [match, setsLine].joined(separator: "\n")
        }
        let current = "Current set \(completedSets.count + 1): \(teamAName) \(currentPointsA) – \(currentPointsB) \(teamBName)"
        if setsLine.isEmpty { return [match, current].joined(separator: "\n") }
        return [match, setsLine, current].joined(separator: "\n")
    }

    func makeRecord(endedAt: Date = .now, abandoned: Bool = false) -> MatchRecord {
        // When the match is complete, `currentPoints` still holds the final set's score
        // (kept on screen intentionally — see `completeCurrentSet`), which was already
        // captured in `completedSets`. Reporting it again here would incorrectly show up
        // as a duplicate "unfinished set" in History, so it's zeroed only for storage.
        let unfinishedA = isMatchComplete ? 0 : currentPointsA
        let unfinishedB = isMatchComplete ? 0 : currentPointsB
        return MatchRecord(
            teamAName: teamAName,
            teamBName: teamBName,
            bestOf: bestOf,
            startedAt: startedAt,
            endedAt: endedAt,
            completedSetsJSON: MatchRecordCoding.encodeSets(completedSets),
            setsWonA: setsWonA,
            setsWonB: setsWonB,
            finalPointsA: unfinishedA,
            finalPointsB: unfinishedB,
            winnerIsA: abandoned ? nil : (isMatchComplete ? setsWonA > setsWonB : nil)
        )
    }
}

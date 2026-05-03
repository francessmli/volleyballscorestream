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

    private struct Snapshot {
        var ca, cb, sa, sb: Int
        var completed: [(Int, Int)]
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
            completed: completedSets
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
        guard !isMatchComplete else { return }
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
        guard !isMatchComplete else { return }
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
        scoreDidChange?()
    }

    /// Clears the current set to 0–0 without recording a winner.
    func restartCurrentSet() {
        guard !isMatchComplete else { return }
        guard currentPointsA > 0 || currentPointsB > 0 else { return }
        pushSnapshot()
        currentPointsA = 0
        currentPointsB = 0
        scoreDidChange?()
    }

    /// Records the current rally score as a finished set (higher score wins). Returns `false` if tied.
    @discardableResult
    func endCurrentSetManually() -> Bool {
        guard !isMatchComplete else { return false }
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
        currentPointsA = 0
        currentPointsB = 0
    }

    func summaryMessage() -> String {
        let setsLine = completedSets.enumerated().map { i, s in
            "Set \(i + 1): \(teamAName) \(s.0) – \(s.1) \(teamBName)"
        }.joined(separator: "\n")
        let current = "Current set \(completedSets.count + 1): \(teamAName) \(currentPointsA) – \(currentPointsB) \(teamBName)"
        let match = "Sets: \(teamAName) \(setsWonA) – \(setsWonB) \(teamBName)"
        if setsLine.isEmpty { return [match, current].joined(separator: "\n") }
        return [match, setsLine, current].joined(separator: "\n")
    }

    func makeRecord(endedAt: Date = .now, abandoned: Bool = false) -> MatchRecord {
        MatchRecord(
            teamAName: teamAName,
            teamBName: teamBName,
            bestOf: bestOf,
            startedAt: startedAt,
            endedAt: endedAt,
            completedSetsJSON: MatchRecordCoding.encodeSets(completedSets),
            setsWonA: setsWonA,
            setsWonB: setsWonB,
            finalPointsA: currentPointsA,
            finalPointsB: currentPointsB,
            winnerIsA: abandoned ? nil : (isMatchComplete ? setsWonA > setsWonB : nil)
        )
    }
}

import Foundation
import SwiftData

@Model
final class MatchRecord {
    // CloudKit requires every non-optional attribute to have a default (SwiftData → Core Data).
    var id: UUID = UUID()
    var teamAName: String = ""
    var teamBName: String = ""
    var bestOf: Int = 3
    var startedAt: Date = Date(timeIntervalSince1970: 0)
    var endedAt: Date?
    /// JSON: [[a,b],...] completed sets
    var completedSetsJSON: String = "[]"
    var setsWonA: Int = 0
    var setsWonB: Int = 0
    var finalPointsA: Int = 0
    var finalPointsB: Int = 0
    var winnerIsA: Bool?

    init(
        id: UUID = UUID(),
        teamAName: String,
        teamBName: String,
        bestOf: Int,
        startedAt: Date,
        endedAt: Date? = nil,
        completedSetsJSON: String,
        setsWonA: Int,
        setsWonB: Int,
        finalPointsA: Int,
        finalPointsB: Int,
        winnerIsA: Bool? = nil
    ) {
        self.id = id
        self.teamAName = teamAName
        self.teamBName = teamBName
        self.bestOf = bestOf
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.completedSetsJSON = completedSetsJSON
        self.setsWonA = setsWonA
        self.setsWonB = setsWonB
        self.finalPointsA = finalPointsA
        self.finalPointsB = finalPointsB
        self.winnerIsA = winnerIsA
    }
}

enum MatchRecordCoding {
    static func encodeSets(_ sets: [(Int, Int)]) -> String {
        let arr = sets.map { [$0.0, $0.1] }
        let data = try! JSONEncoder().encode(arr)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func decodeSets(_ json: String) -> [(Int, Int)] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([[Int]].self, from: data) else { return [] }
        return arr.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return (pair[0], pair[1])
        }
    }
}

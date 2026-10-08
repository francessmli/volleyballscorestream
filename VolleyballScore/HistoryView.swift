import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MatchRecord.startedAt, order: .reverse) private var matches: [MatchRecord]

    /// Selected match id. Using `NavigationSplitView` (rather than a plain `NavigationStack`)
    /// gives us a sidebar + detail layout on iPad for free, while still collapsing to a normal
    /// push/pop stack on iPhone's compact width — no extra platform-specific code needed.
    @State private var selection: MatchRecord.ID?

    var body: some View {
        NavigationSplitView {
            Group {
                if matches.isEmpty {
                    ContentUnavailableView(
                        "No matches yet",
                        systemImage: "clock",
                        description: Text("Finished and saved games appear here.")
                    )
                } else {
                    List(selection: $selection) {
                        ForEach(matches) { record in
                            NavigationLink(value: record.id) {
                                HistoryRow(record: record)
                            }
                        }
                        .onDelete(perform: deleteMatches)
                    }
                }
            }
            .navigationTitle("History")
        } detail: {
            if let id = selection, let record = matches.first(where: { $0.id == id }) {
                MatchDetailView(record: record)
            } else {
                ContentUnavailableView(
                    "Select a match",
                    systemImage: "sportscourt",
                    description: Text("Choose a match from the list to see its details.")
                )
            }
        }
        .onChange(of: matches) { _, newMatches in
            // Keep selection valid if the selected match was deleted.
            if let id = selection, !newMatches.contains(where: { $0.id == id }) {
                selection = nil
            }
        }
    }

    private func deleteMatches(at offsets: IndexSet) {
        for index in offsets {
            if matches[index].id == selection { selection = nil }
            modelContext.delete(matches[index])
        }
        try? modelContext.save()
    }
}

private struct HistoryRow: View {
    let record: MatchRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(record.teamAName) vs \(record.teamBName)")
                .font(.headline)
            HStack {
                Text("\(record.setsWonA) – \(record.setsWonB) sets")
                if let w = record.winnerIsA {
                    Text("· \(w ? record.teamAName : record.teamBName) won")
                        .foregroundStyle(.secondary)
                } else {
                    Text("· saved in progress")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct MatchDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let record: MatchRecord

    @State private var confirmDelete = false

    private var sets: [(Int, Int)] {
        MatchRecordCoding.decodeSets(record.completedSetsJSON)
    }

    var body: some View {
        List {
            Section("Result") {
                LabeledContent("Teams", value: "\(record.teamAName) vs \(record.teamBName)")
                LabeledContent("Format", value: "Best of \(record.bestOf)")
                LabeledContent("Sets", value: "\(record.setsWonA) – \(record.setsWonB)")
                if let w = record.winnerIsA {
                    LabeledContent("Winner", value: w ? record.teamAName : record.teamBName)
                } else {
                    LabeledContent("Status", value: "No winner recorded")
                }
            }
            if !sets.isEmpty {
                Section("Set scores") {
                    ForEach(Array(sets.enumerated()), id: \.offset) { i, s in
                        Text("Set \(i + 1): \(record.teamAName) \(s.0) – \(s.1) \(record.teamBName)")
                    }
                }
            }
            if record.finalPointsA > 0 || record.finalPointsB > 0 {
                Section("Unfinished set snapshot") {
                    Text("\(record.teamAName) \(record.finalPointsA) – \(record.finalPointsB) \(record.teamBName)")
                        .font(.footnote)
                }
            }
            Section {
                Button("Delete this match", role: .destructive) {
                    confirmDelete = true
                }
            }
        }
        .cappedWidth(900)
        .navigationTitle("Match detail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Send via WhatsApp", systemImage: "message") {
                        let phone = UserDefaults.standard.string(forKey: "whatsAppPhoneDigits") ?? ""
                        WhatsAppShare.openCompose(
                            message: summaryText(record),
                            phoneDigits: phone.isEmpty ? nil : phone
                        )
                    }
                    ShareLink(item: summaryText(record)) {
                        Label("Share text…", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .alert("Delete this match?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(record)
                try? modelContext.save()
                // Note: selection clearing (and thus detail dismissal on iPhone's
                // collapsed stack) is handled by HistoryView's `onChange(of: matches)`.
            }
        } message: {
            Text("This removes the game from history on this device.")
        }
    }

    private func summaryText(_ r: MatchRecord) -> String {
        var lines: [String] = [
            "\(r.teamAName) vs \(r.teamBName)",
            "Sets: \(r.setsWonA) – \(r.setsWonB)",
        ]
        for (i, s) in sets.enumerated() {
            lines.append("Set \(i + 1): \(r.teamAName) \(s.0) – \(s.1) \(r.teamBName)")
        }
        if r.finalPointsA > 0 || r.finalPointsB > 0 {
            lines.append("Last partial set: \(r.teamAName) \(r.finalPointsA) – \(r.finalPointsB) \(r.teamBName)")
        }
        return lines.joined(separator: "\n")
    }
}

import SwiftUI

private enum AppTab: Hashable {
    case score, watch, history, settings
}

struct ContentView: View {
    @State private var activeGame: GameEngine?
    @State private var selectedTab: AppTab = .score

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                Group {
                    if let game = activeGame {
                        GameView(game: game, onReset: { activeGame = nil })
                    } else {
                        NewMatchView { a, b, bestOf in
                            activeGame = GameEngine(teamAName: a, teamBName: b, bestOf: bestOf)
                        }
                    }
                }
            }
            .tabItem {
                Label("Score", systemImage: "sportscourt")
            }
            .tag(AppTab.score)

            NavigationStack {
                WatchLiveView()
            }
            .tabItem {
                Label("Watch", systemImage: "person.2.wave.2")
            }
            .tag(AppTab.watch)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(AppTab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(AppTab.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToScoreTab)) { _ in
            selectedTab = .score
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToHistoryTab)) { _ in
            selectedTab = .history
        }
    }
}

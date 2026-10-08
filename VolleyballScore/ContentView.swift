import SwiftUI

private enum AppTab: Hashable {
    case score, watch, history, settings
}

struct ContentView: View {
    @State private var activeGame: GameEngine?
    @State private var selectedTab: AppTab = .score
    @State private var liveWatchSession = LiveWatchSession()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                Group {
                    if let game = activeGame {
                        GameView(game: game, onReset: { activeGame = nil })
                    } else if liveWatchSession.isWatching, let snapshot = liveWatchSession.snapshot, let code = liveWatchSession.activeCode {
                        LiveScoreboardView(snapshot: snapshot, code: code) {
                            liveWatchSession.stopWatching()
                        }
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
                WatchLiveView(watchSession: liveWatchSession) {
                    selectedTab = .score
                }
            }
            .tabItem {
                Label("Watch", systemImage: "person.2.wave.2")
            }
            .tag(AppTab.watch)

            // HistoryView owns a NavigationSplitView (sidebar + detail on iPad, a push
            // stack on iPhone), so it should not be nested in another NavigationStack.
            HistoryView()
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
        .onAppear {
            liveWatchSession.onLiveSnapshotReady = {
                selectedTab = .score
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToScoreTab)) { _ in
            selectedTab = .score
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToHistoryTab)) { _ in
            selectedTab = .history
        }
    }
}

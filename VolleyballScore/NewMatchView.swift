import SwiftUI
import UIKit

struct NewMatchView: View {
    @State private var teamA = ""
    @State private var teamB = ""
    @State private var bestOf = 3

    private enum Field: Hashable {
        case teamA, teamB
    }

    @FocusState private var focusedField: Field?

    var onStart: (String, String, Int) -> Void

    var body: some View {
        Form {
            Section {
                TextField("Team A", text: $teamA)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .teamA)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .teamB }

                TextField("Team B", text: $teamB)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .teamB)
                    .submitLabel(.done)
                    .onSubmit { dismissKeyboard() }
            } header: {
                Text("Teams")
            } footer: {
                Text("To hide the keyboard: tap Done above the keyboard, scroll this screen, or press Return or Next on the keyboard—then you can switch tabs.")
            }
            Section("Match format") {
                Picker("Best of", selection: $bestOf) {
                    Text("Best of 3").tag(3)
                    Text("Best of 5").tag(5)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Button("Start match") {
                    dismissKeyboard()
                    let a = teamA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Team A" : teamA.trimmingCharacters(in: .whitespacesAndNewlines)
                    let b = teamB.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Team B" : teamB.trimmingCharacters(in: .whitespacesAndNewlines)
                    onStart(a, b, bestOf)
                }
            }
        }
        .navigationTitle("New match")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done") {
                    dismissKeyboard()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

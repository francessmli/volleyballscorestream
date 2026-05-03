import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("autoShareWhatsApp") private var autoShareSaved = false
    @AppStorage("whatsAppPhoneDigits") private var phoneSaved = ""

    @State private var autoShareDraft = false
    @State private var phoneDraft = ""
    @FocusState private var phoneFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle("Open WhatsApp after each point", isOn: $autoShareDraft)
                    TextField("Country code + number (optional)", text: $phoneDraft)
                        .keyboardType(.phonePad)
                        .focused($phoneFieldFocused)
                } header: {
                    Text("WhatsApp")
                } footer: {
                    Text(
                        "Each score update can open WhatsApp with a prefilled message. You still tap Send in WhatsApp. Fully automatic sending is not available on iOS without the WhatsApp Business API."
                    )
                }
            }

            bottomActionBar
        }
        .navigationTitle("Settings")
        .onAppear {
            autoShareDraft = autoShareSaved
            phoneDraft = phoneSaved
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done") {
                    phoneFieldFocused = false
                    resignFirstResponder()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button {
                saveSettings()
            } label: {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 16) {
                Button("Score") {
                    saveSettings()
                    NotificationCenter.default.post(name: .switchToScoreTab, object: nil)
                }
                .font(.subheadline.weight(.medium))

                Button("History") {
                    saveSettings()
                    NotificationCenter.default.post(name: .switchToHistoryTab, object: nil)
                }
                .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func saveSettings() {
        autoShareSaved = autoShareDraft
        phoneSaved = phoneDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        phoneFieldFocused = false
        resignFirstResponder()
    }

    private func resignFirstResponder() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension Notification.Name {
    static let switchToScoreTab = Notification.Name("VolleyballScore.switchToScoreTab")
    static let switchToHistoryTab = Notification.Name("VolleyballScore.switchToHistoryTab")
}

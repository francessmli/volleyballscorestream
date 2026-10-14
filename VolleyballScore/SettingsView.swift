import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("autoShareWhatsApp") private var autoShareSaved = false
    @AppStorage("whatsAppPhoneDigits") private var phoneSaved = ""
    @AppStorage("webWatchBaseURL") private var webWatchBaseURLSaved = ""

    @State private var autoShareDraft = false
    @State private var phoneDraft = ""
    @State private var webWatchBaseURLDraft = ""
    @FocusState private var phoneFieldFocused: Bool
    @FocusState private var webLinkFieldFocused: Bool

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

                Section {
                    TextField("https://yourname.github.io/.../web/", text: $webWatchBaseURLDraft)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($webLinkFieldFocused)
                } header: {
                    Text("Web watch link (optional)")
                } footer: {
                    Text(
                        "If you've hosted the included web/index.html page (see web/README.md — e.g. via GitHub Pages), paste its URL here. While broadcasting, you'll then get a \"Share watch link\" option that shares a tappable link instead of (or alongside) the 6-character code."
                    )
                }
            }

            bottomActionBar
        }
        .cappedWidth()
        .navigationTitle("Settings")
        .onAppear {
            autoShareDraft = autoShareSaved
            phoneDraft = phoneSaved
            webWatchBaseURLDraft = webWatchBaseURLSaved
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done") {
                    phoneFieldFocused = false
                    webLinkFieldFocused = false
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
        webWatchBaseURLSaved = webWatchBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        phoneFieldFocused = false
        webLinkFieldFocused = false
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

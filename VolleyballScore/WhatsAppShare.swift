import UIKit

enum WhatsAppShare {
    /// Opens WhatsApp with a prefilled message. The user must tap Send in WhatsApp.
    /// iOS cannot send WhatsApp messages silently without the WhatsApp Business API.
    static func openCompose(message: String, phoneDigits: String?) {
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let phoneDigits, !phoneDigits.isEmpty {
            let digits = phoneDigits.filter { $0.isNumber }
            if let url = URL(string: "https://wa.me/\(digits)?text=\(encoded)") {
                UIApplication.shared.open(url)
                return
            }
        }

        if let url = URL(string: "whatsapp://send?text=\(encoded)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

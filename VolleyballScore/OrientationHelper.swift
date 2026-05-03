import UIKit

enum OrientationHelper {
    static func preferLandscape() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
        scene.requestGeometryUpdate(prefs) { _ in }
    }

    static func preferPortrait() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
        scene.requestGeometryUpdate(prefs) { _ in }
    }
}

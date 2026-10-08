import SwiftUI

extension View {
    /// Caps a view's width for comfortable reading/editing on large screens (iPad), while
    /// remaining full-width on compact devices (iPhone). The capped content stays centered
    /// in the available space, matching the look of Apple's own Settings app on iPad.
    func cappedWidth(_ maxWidth: CGFloat = 700) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

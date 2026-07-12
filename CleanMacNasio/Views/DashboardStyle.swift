//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import SwiftUI

enum DashboardStyle {
    static let text = Color(nsColor: .labelColor)
    static let mutedText = Color(nsColor: .secondaryLabelColor)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let backgroundOverlay = Color(nsColor: .underPageBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let recessedPanel = Color(nsColor: .textBackgroundColor)
    static let accent = Color(red: 0.02, green: 0.45, blue: 0.40)
    static let border = Color(nsColor: .separatorColor)
}

enum DashboardLayout {
    static let compactWidth: CGFloat = 720
    static let minimumWindowWidth: CGFloat = 480
    static let minimumWindowHeight: CGFloat = 520
    static let compactPadding: CGFloat = 16
    static let regularPadding: CGFloat = 28
    static let compactSpacing: CGFloat = 16
    static let regularSpacing: CGFloat = 22
    static let metricSpacing: CGFloat = 14
    static let sidebarWidth: CGFloat = 280
    static let compactHeaderTitleSize: CGFloat = 28
    static let regularHeaderTitleSize: CGFloat = 34
    static let compactHeaderPadding: CGFloat = 16
    static let regularHeaderPadding: CGFloat = 22
    static let scanProgressWidth: CGFloat = 420
}

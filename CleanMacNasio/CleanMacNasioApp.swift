//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import SwiftUI

@main
struct CleanMacNasioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Window("About CleanMacNasio", id: "about-window") {
            AboutWindowView()
        }
        .windowResizability(.contentSize)
    }
}

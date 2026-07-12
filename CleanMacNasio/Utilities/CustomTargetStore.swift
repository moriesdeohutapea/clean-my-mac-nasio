//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-07-12
//

import Foundation

protocol CustomTargetStoring {
    func load() -> [String]
    func save(_ paths: [String])
}

struct CustomTargetStore: CustomTargetStoring {
    private static let key = "clean_my_mac_me.custom_cleanup_targets"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> [String] {
        (userDefaults.array(forKey: Self.key) as? [String] ?? []).sorted()
    }

    func save(_ paths: [String]) {
        let normalized = Array(Set(paths.map(JunkCleanerService.normalizePath))).sorted()
        userDefaults.set(normalized, forKey: Self.key)
    }
}

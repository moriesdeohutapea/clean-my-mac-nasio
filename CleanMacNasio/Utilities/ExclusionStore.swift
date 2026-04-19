//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import Foundation

protocol ExclusionStoring {
    func load() -> [String]
    func save(_ paths: [String])
}

struct ExclusionStore: ExclusionStoring {
    private static let key = "clean_my_mac_me.excluded_paths"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> [String] {
        (userDefaults.array(forKey: Self.key) as? [String] ?? []).sorted()
    }

    func save(_ paths: [String]) {
        let normalized = Array(Set(paths)).sorted()
        userDefaults.set(normalized, forKey: Self.key)
    }
}

//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import Foundation

protocol SecurityScopedBookmarkStoring {
    func save(url: URL) throws
    func loadURL() -> URL?
}

struct SecurityScopedBookmarkStore: SecurityScopedBookmarkStoring {
    private static let key = "clean_my_mac_me.home.bookmark"

    func save(url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: Self.key)
    }

    func loadURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: Self.key) else {
            return nil
        }

        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try save(url: url)
            }

            return url
        } catch {
            return nil
        }
    }
}

//
//  DeepLinkHandler.swift
//  Stretheo
//

import Foundation

enum AppDeepLink: Equatable {
    case home
    case mood
    case breathing
    case article(UUID)
    case settings
}

enum DeepLinkHandler {
    static func parse(url: URL) -> AppDeepLink? {
        guard url.scheme == "stretheo" else { return nil }
        switch url.host {
        case "home": return .home
        case "mood": return .mood
        case "breathing": return .breathing
        case "settings": return .settings
        case "article":
            if let idString = url.pathComponents.dropFirst().first,
               let uuid = UUID(uuidString: idString) {
                return .article(uuid)
            }
            return nil
        default:
            return nil
        }
    }
}

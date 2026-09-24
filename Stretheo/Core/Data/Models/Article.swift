//
//  Article.swift
//  Stretheo
//

import Foundation
import SwiftData

@Model
final class Article {
    #Index<Article>([\.publishedDate])

    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var cloudKitRecordID: String
    var title: String
    var category: String
    var summary: String
    var content: String
    var author: String
    var publishedDate: Date
    var imageURL: String?
    var isFeatured: Bool
    var cachedAt: Date

    init(
        id: UUID = UUID(),
        cloudKitRecordID: String,
        title: String,
        category: String,
        summary: String,
        content: String,
        author: String,
        publishedDate: Date,
        imageURL: String? = nil,
        isFeatured: Bool = false,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.cloudKitRecordID = cloudKitRecordID
        self.title = title
        self.category = category
        self.summary = summary
        self.content = content
        self.author = author
        self.publishedDate = publishedDate
        self.imageURL = imageURL
        self.isFeatured = isFeatured
        self.cachedAt = cachedAt
    }
}

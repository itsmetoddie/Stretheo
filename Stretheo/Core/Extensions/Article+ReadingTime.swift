//
//  Article+ReadingTime.swift
//  Stretheo
//

import Foundation

extension Article {
    var estimatedReadingMinutes: Int {
        max(3, content.split(separator: " ").count / 200)
    }
}

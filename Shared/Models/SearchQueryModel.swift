import Foundation
import SwiftData

@Model
final class SearchQueryModel {
    var query: String = ""
    var normalizedQuery: String = ""
    var lastSearchedAt: Date = Date()

    init(query: String, lastSearchedAt: Date = Date()) {
        self.query = query
        self.normalizedQuery = SearchQueryModel.normalizedQuery(query)
        self.lastSearchedAt = lastSearchedAt
    }

    static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}

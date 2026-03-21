import Foundation

struct StorageInsight: Identifiable {
    let id = UUID()
    let category: String
    let usedGigabytes: Double
    let suggestedSavingsGigabytes: Double
}

extension StorageInsight {
    static let mockData: [StorageInsight] = [
        .init(category: "Photos", usedGigabytes: 28.4, suggestedSavingsGigabytes: 6.2),
        .init(category: "Downloads", usedGigabytes: 9.8, suggestedSavingsGigabytes: 3.5),
        .init(category: "Large Videos", usedGigabytes: 14.1, suggestedSavingsGigabytes: 4.0),
        .init(category: "Unused Files", usedGigabytes: 5.3, suggestedSavingsGigabytes: 2.1)
    ]
}

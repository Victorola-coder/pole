import SwiftUI

struct StorageBreakdownView: View {
    private let insights = StorageInsight.mockData

    var body: some View {
        NavigationStack {
            List(insights) { insight in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.category)
                        Text("Recoverable \(insight.suggestedSavingsGigabytes, specifier: "%.1f") GB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(insight.usedGigabytes, specifier: "%.1f") GB")
                        .bold()
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Storage")
        }
    }
}

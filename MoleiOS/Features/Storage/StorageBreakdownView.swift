import SwiftUI

struct StorageBreakdownView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.insights) { insight in
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
            .task {
                if viewModel.insights.isEmpty {
                    await viewModel.load()
                }
            }
        }
    }
}

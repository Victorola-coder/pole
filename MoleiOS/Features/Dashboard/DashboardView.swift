import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Scanning storage...")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Scan failed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    List {
                        Section("Overview") {
                            statRow(title: "Used Storage", value: "\(viewModel.totalUsed, specifier: "%.1f") GB")
                            statRow(title: "Potential Savings", value: "\(viewModel.totalRecoverable, specifier: "%.1f") GB")
                        }

                        Section("Suggestions") {
                            ForEach(viewModel.insights) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.category)
                                        .font(.headline)
                                    Text("Used: \(item.usedGigabytes, specifier: "%.1f") GB")
                                    Text("Recoverable: \(item.suggestedSavingsGigabytes, specifier: "%.1f") GB")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("MoleiOS")
            .task {
                if viewModel.insights.isEmpty {
                    await viewModel.load()
                }
            }
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).bold()
        }
    }
}

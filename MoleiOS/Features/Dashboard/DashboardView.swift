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
                        if !viewModel.canScanPhotos {
                            Section("Permissions") {
                                Button("Allow Photo Access") {
                                    Task {
                                        await viewModel.requestPhotoAccess()
                                        await viewModel.load()
                                    }
                                }
                            }
                        }

                        Section("Overview") {
                            statRow(title: "Used Storage", value: String(format: "%.1f GB", viewModel.totalUsed))
                            statRow(title: "Potential Savings", value: String(format: "%.1f GB", viewModel.totalRecoverable))
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

                        Section("Cleanup Candidates") {
                            if viewModel.candidates.isEmpty {
                                Text("No candidates found.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(viewModel.candidates.prefix(20)) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.displayName)
                                            Text(item.source.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(String(format: "%.2f GB", item.sizeGigabytes))
                                            .font(.footnote)
                                        Button("Delete", role: .destructive) {
                                            Task {
                                                await viewModel.delete(candidate: item)
                                            }
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pole")
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

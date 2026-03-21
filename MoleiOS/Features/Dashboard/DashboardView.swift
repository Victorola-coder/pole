import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var pendingDeleteCandidate: CleanupCandidate?

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
                                            pendingDeleteCandidate = item
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
            .sheet(item: $pendingDeleteCandidate) { item in
                NavigationStack {
                    List {
                        Section("Preview") {
                            CleanupCandidatePreview(candidate: item)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }

                        Section("Item") {
                            HStack(spacing: 12) {
                                Image(systemName: item.sourceSymbolName)
                                    .font(.title3)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayName)
                                        .font(.headline)
                                    Text(item.source.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Section("Metadata") {
                            statRow(title: "Size", value: String(format: "%.2f GB", item.sizeGigabytes))
                            if let createdAt = item.createdAt {
                                statRow(title: "Created", value: createdAt.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let detailText = item.detailText {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Details")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(detailText)
                                        .font(.footnote)
                                }
                            }
                        }

                        Section {
                            Button("Delete This Item", role: .destructive) {
                                Task {
                                    await viewModel.delete(candidate: item)
                                }
                                pendingDeleteCandidate = nil
                            }
                            Button("Cancel", role: .cancel) {
                                pendingDeleteCandidate = nil
                            }
                        } footer: {
                            Text("Deletion is permanent for files. Photo library deletion follows iOS behavior and may move items to Recently Deleted.")
                        }
                    }
                    .navigationTitle("Review Deletion")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
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

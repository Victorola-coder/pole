import SwiftUI
import UniformTypeIdentifiers

struct StorageBreakdownView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isFolderPickerPresented = false
    @State private var isProtectedFolderPickerPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Categories") {
                    ForEach(viewModel.insights) { insight in
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
                }

                Section("Files Access") {
                    Button("Add Folder From Files") {
                        isFolderPickerPresented = true
                    }
                    if viewModel.scopedFolders.isEmpty {
                        Text("No external folders granted yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.scopedFolders, id: \.self) { url in
                            Text(url.lastPathComponent)
                        }
                    }
                }

                Section("Protected Folders") {
                    Button("Add Protected Folder") {
                        isProtectedFolderPickerPresented = true
                    }
                    if viewModel.protectedFolders.isEmpty {
                        Text("No protected folders configured.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.protectedFolders, id: \.self) { url in
                            HStack {
                                Text(url.lastPathComponent)
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    viewModel.removeProtectedFolder(at: url)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                Section("Folder Analyzer") {
                    if viewModel.folderAnalysis.isEmpty {
                        Text("No folder analysis yet. Run a scan to populate this view.")
                            .foregroundStyle(.secondary)
                    } else {
                        OutlineGroup(viewModel.folderAnalysis, children: \.expandableChildren) { node in
                            HStack {
                                Text(node.name)
                                Spacer()
                                Text(node.sizeLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Storage")
            .refreshable {
                await viewModel.load()
            }
            .fileImporter(
                isPresented: $isFolderPickerPresented,
                allowedContentTypes: [.folder]
            ) { result in
                switch result {
                case .success(let url):
                    Task {
                        await viewModel.addScopedFolder(url: url)
                    }
                case .failure:
                    viewModel.importFolderFailed()
                }
            }
            .fileImporter(
                isPresented: $isProtectedFolderPickerPresented,
                allowedContentTypes: [.folder]
            ) { result in
                switch result {
                case .success(let url):
                    Task {
                        await viewModel.addProtectedFolder(url: url)
                    }
                case .failure:
                    viewModel.importFolderFailed()
                }
            }
            .task {
                viewModel.syncScopedFolders()
            }
        }
    }
}

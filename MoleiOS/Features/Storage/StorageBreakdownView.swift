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
                    if viewModel.scopedFolderNames.isEmpty {
                        Text("No external folders granted yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.scopedFolderNames, id: \.self) { name in
                            Text(name)
                        }
                    }
                }

                Section("Protected Folders") {
                    Button("Add Protected Folder") {
                        isProtectedFolderPickerPresented = true
                    }
                    if viewModel.protectedFolderNames.isEmpty {
                        Text("No protected folders configured.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.protectedFolderNames, id: \.self) { name in
                            HStack {
                                Text(name)
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    viewModel.removeProtectedFolder(named: name)
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
                if viewModel.insights.isEmpty {
                    await viewModel.load()
                }
            }
        }
    }
}
